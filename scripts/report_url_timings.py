#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from dataclasses import dataclass
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

TRACKING_QUERY_KEYS = {"gclid", "fbclid", "mc_cid", "mc_eid"}


class AwsCommandError(RuntimeError):
    pass


class InvalidUrlError(ValueError):
    pass


@dataclass(frozen=True)
class CategorizationRecord:
    url: str
    normalized_url: str
    url_hash: str
    trace_id: str | None
    status: str
    categorizer_dequeued_at_ms: int | None
    categorizer_started_at_ms: int | None
    categorizer_finished_at_ms: int | None
    categorizer_queue_wait_ms: int | None
    categorization_compute_ms: int | None


@dataclass(frozen=True)
class LogEvent:
    timestamp_ms: int
    request_id: str
    raw_message: str
    log_stream_name: str
    payload: dict[str, Any] | None = None


def _normalized_path(path: str) -> str:
    if not path:
        return "/"
    if path != "/" and path.endswith("/"):
        return path.rstrip("/")
    return path


def _filter_and_sort_query(query: str, strip_tracking_params: bool) -> str:
    pairs = parse_qsl(query, keep_blank_values=True)
    filtered_pairs: list[tuple[str, str]] = []

    for key, value in pairs:
        if strip_tracking_params and (
            key.lower().startswith("utm_") or key.lower() in TRACKING_QUERY_KEYS
        ):
            continue
        filtered_pairs.append((key, value))

    filtered_pairs.sort(key=lambda item: (item[0], item[1]))
    return urlencode(filtered_pairs, doseq=True)


def normalize_url(url: str, *, strip_tracking_params: bool = True) -> str:
    parts = urlsplit(url)
    scheme = parts.scheme.lower()
    host = (parts.hostname or "").lower()

    if scheme not in {"http", "https"} or not host:
        raise InvalidUrlError("Only absolute http(s) URLs are supported")

    port = parts.port
    if (scheme == "http" and port == 80) or (scheme == "https" and port == 443):
        port = None

    auth = ""
    if parts.username:
        auth = parts.username
        if parts.password:
            auth = f"{auth}:{parts.password}"
        auth = f"{auth}@"

    netloc = f"{auth}{host}"
    if port is not None:
        netloc = f"{netloc}:{port}"

    return urlunsplit(
        (
            scheme,
            netloc,
            _normalized_path(parts.path),
            _filter_and_sort_query(parts.query, strip_tracking_params),
            "",
        )
    )


def hash_normalized_url(normalized_url: str) -> str:
    digest = hashlib.sha256(normalized_url.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"


def run_aws_json(args: list[str]) -> dict[str, Any]:
    result = subprocess.run(
        ["aws", *args],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise AwsCommandError(result.stderr.strip() or "aws command failed")
    try:
        return json.loads(result.stdout or "{}")
    except json.JSONDecodeError as exc:
        raise AwsCommandError(f"failed to decode aws output: {exc}") from exc


def decode_dynamodb_value(value: dict[str, Any]) -> Any:
    if "S" in value:
        return value["S"]
    if "N" in value:
        raw = value["N"]
        return int(raw) if raw.isdigit() or (raw.startswith("-") and raw[1:].isdigit()) else float(raw)
    if "NULL" in value:
        return None
    if "BOOL" in value:
        return value["BOOL"]
    if "L" in value:
        return [decode_dynamodb_value(item) for item in value["L"]]
    if "M" in value:
        return {key: decode_dynamodb_value(item) for key, item in value["M"].items()}
    raise AwsCommandError(f"unsupported dynamodb value: {value}")


def get_categorization_record(region: str, table_name: str, url: str) -> CategorizationRecord:
    normalized_url = normalize_url(url, strip_tracking_params=True)
    url_hash = hash_normalized_url(normalized_url)
    payload = run_aws_json(
        [
            "dynamodb",
            "get-item",
            "--region",
            region,
            "--table-name",
            table_name,
            "--key",
            json.dumps({"url_hash": {"S": url_hash}}),
        ]
    )
    item = payload.get("Item")
    if not item:
        raise AwsCommandError(
            f"no categorization record found for {normalized_url} ({url_hash})"
        )

    decoded = {key: decode_dynamodb_value(value) for key, value in item.items()}
    return CategorizationRecord(
        url=url,
        normalized_url=normalized_url,
        url_hash=url_hash,
        trace_id=decoded.get("trace_id"),
        status=str(decoded.get("status")),
        categorizer_dequeued_at_ms=decoded.get("categorizer_dequeued_at_ms"),
        categorizer_started_at_ms=decoded.get("categorizer_started_at_ms"),
        categorizer_finished_at_ms=decoded.get("categorizer_finished_at_ms"),
        categorizer_queue_wait_ms=decoded.get("categorizer_queue_wait_ms"),
        categorization_compute_ms=decoded.get("categorization_compute_ms"),
    )


def parse_request_id(message: str, marker: str) -> str | None:
    if marker not in message:
        return None
    suffix = message.split(marker, 1)[1].strip()
    token = suffix.split()[0]
    return token or None


def parse_tabbed_request_id(message: str) -> str | None:
    parts = message.strip().split("\t")
    if len(parts) < 3:
        return None
    return parts[2].strip() or None


def parse_json_log_event(message: str) -> tuple[str | None, dict[str, Any] | None]:
    try:
        payload = json.loads(message)
    except json.JSONDecodeError:
        return None, None

    trace_id = payload.get("trace_id")
    if not isinstance(trace_id, str):
        return None, payload
    return trace_id, payload


def fetch_log_events(
    region: str,
    log_group_name: str,
    start_time_ms: int,
    filter_pattern: str,
    parser: callable,
) -> list[LogEvent]:
    payload = run_aws_json(
        [
            "logs",
            "filter-log-events",
            "--region",
            region,
            "--log-group-name",
            log_group_name,
            "--start-time",
            str(start_time_ms),
            "--filter-pattern",
            filter_pattern,
        ]
    )
    events: list[LogEvent] = []
    for event in payload.get("events", []):
        message = event.get("message", "")
        request_id = parser(message)
        if not request_id:
            continue
        events.append(
            LogEvent(
                timestamp_ms=int(event["timestamp"]),
                request_id=request_id,
                raw_message=message,
                log_stream_name=str(event.get("logStreamName", "")),
            )
        )
    events.sort(key=lambda item: item.timestamp_ms)
    return events


def fetch_json_log_events(
    region: str,
    log_group_name: str,
    start_time_ms: int,
    filter_pattern: str,
) -> list[LogEvent]:
    payload = run_aws_json(
        [
            "logs",
            "filter-log-events",
            "--region",
            region,
            "--log-group-name",
            log_group_name,
            "--start-time",
            str(start_time_ms),
            "--filter-pattern",
            filter_pattern,
        ]
    )
    events: list[LogEvent] = []
    for event in payload.get("events", []):
        message = event.get("message", "")
        request_id, parsed_payload = parse_json_log_event(message)
        if not request_id or not parsed_payload:
            continue
        events.append(
            LogEvent(
                timestamp_ms=int(event["timestamp"]),
                request_id=request_id,
                raw_message=message,
                log_stream_name=str(event.get("logStreamName", "")),
                payload=parsed_payload,
            )
        )
    events.sort(key=lambda item: item.timestamp_ms)
    return events


def index_by_request_id(events: list[LogEvent]) -> dict[str, LogEvent]:
    return {event.request_id: event for event in events}


def find_same_stream_prior_event(
    events: list[LogEvent],
    log_stream_name: str,
    cutoff_ms: int,
) -> LogEvent | None:
    for event in reversed(events):
        if event.log_stream_name != log_stream_name:
            continue
        if event.timestamp_ms <= cutoff_ms:
            return event
    return None


def ms_or_none(value: int | None) -> str:
    return "n/a" if value is None else str(value)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Report main, fetcher, and categorizer timings for previously processed URLs."
    )
    parser.add_argument("urls", nargs="+", help="One or more absolute http(s) URLs.")
    parser.add_argument("--environment", default="dev")
    parser.add_argument("--region", default="us-east-1")
    parser.add_argument(
        "--window-minutes",
        type=int,
        default=120,
        help="How far back to search CloudWatch logs.",
    )
    args = parser.parse_args()

    try:
        records = [
            get_categorization_record(args.region, "url_categorization", url)
            for url in args.urls
        ]
    except (AwsCommandError, InvalidUrlError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    exact_records = sorted(
        records,
        key=lambda record: (
            record.categorizer_dequeued_at_ms or 0,
            record.categorizer_finished_at_ms or 0,
        ),
    )

    latest_needed_ms = max(
        record.categorizer_finished_at_ms or 0 for record in exact_records
    )
    start_time_ms = latest_needed_ms - (args.window_minutes * 60 * 1000)

    try:
        main_start_events = fetch_log_events(
            args.region,
            f"/aws/lambda/meaning-mesh-main-service-{args.environment}",
            start_time_ms,
            "START RequestId",
            lambda message: parse_request_id(message, "START RequestId:"),
        )
        main_enqueue_events = fetch_log_events(
            args.region,
            f"/aws/lambda/meaning-mesh-main-service-{args.environment}",
            start_time_ms,
            "fetch_enqueued",
            parse_tabbed_request_id,
        )
        fetch_start_events = fetch_log_events(
            args.region,
            f"/aws/lambda/meaning-mesh-url-fetcher-{args.environment}",
            start_time_ms,
            "START RequestId",
            lambda message: parse_request_id(message, "START RequestId:"),
        )
        fetch_done_events = fetch_log_events(
            args.region,
            f"/aws/lambda/meaning-mesh-url-fetcher-{args.environment}",
            start_time_ms,
            "fetch_batch_processed",
            parse_tabbed_request_id,
        )
        main_enqueue_json_events = fetch_json_log_events(
            args.region,
            f"/aws/lambda/meaning-mesh-main-service-{args.environment}",
            start_time_ms,
            "fetch_enqueued",
        )
        fetch_completed_json_events = fetch_json_log_events(
            args.region,
            f"/aws/lambda/meaning-mesh-url-fetcher-{args.environment}",
            start_time_ms,
            "fetch_completed",
        )
    except AwsCommandError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    main_start_by_request = index_by_request_id(main_start_events)
    fetch_start_by_request = index_by_request_id(fetch_start_events)
    main_enqueue_by_url_hash = {
        str(event.payload.get("url_hash")): event
        for event in main_enqueue_json_events
        if event.payload and isinstance(event.payload.get("url_hash"), str)
    }
    fetch_completed_by_url_hash = {
        str(event.payload.get("url_hash")): event
        for event in fetch_completed_json_events
        if event.payload and isinstance(event.payload.get("url_hash"), str)
    }

    results: list[dict[str, Any]] = []
    for record in exact_records:
        if record.categorizer_dequeued_at_ms is None or record.categorizer_finished_at_ms is None:
            results.append(
                {
                    "url": record.url,
                    "normalized_url": record.normalized_url,
                    "url_hash": record.url_hash,
                    "status": record.status,
                    "note": "categorizer timing fields missing in DynamoDB",
                }
            )
            continue

        main_enqueue_event = main_enqueue_by_url_hash.get(record.url_hash)
        fetch_completed_event = fetch_completed_by_url_hash.get(record.url_hash)
        fetch_done_event = fetch_completed_event

        if main_enqueue_event is None:
            main_enqueue_event = next(
                (
                    event
                    for event in reversed(main_enqueue_events)
                    if event.timestamp_ms <= record.categorizer_dequeued_at_ms
                ),
                None,
            )
        if fetch_done_event is None:
            fetch_done_event = next(
                (
                    event
                    for event in reversed(fetch_done_events)
                    if event.timestamp_ms <= record.categorizer_dequeued_at_ms
                ),
                None,
            )

        main_start_event = (
            main_start_by_request.get(main_enqueue_event.request_id)
            if main_enqueue_event
            else None
        )
        if main_start_event is None and main_enqueue_event is not None:
            main_start_event = find_same_stream_prior_event(
                main_start_events,
                main_enqueue_event.log_stream_name,
                main_enqueue_event.timestamp_ms,
            )
        fetch_start_event = (
            fetch_start_by_request.get(fetch_done_event.request_id)
            if fetch_done_event
            else None
        )
        if fetch_start_event is None and fetch_done_event is not None:
            fetch_start_event = find_same_stream_prior_event(
                fetch_start_events,
                fetch_done_event.log_stream_name,
                fetch_done_event.timestamp_ms,
            )

        main_until_enqueue_ms = (
            main_enqueue_event.timestamp_ms - main_start_event.timestamp_ms
            if main_enqueue_event and main_start_event
            else None
        )
        enqueue_to_fetch_done_ms = (
            fetch_done_event.timestamp_ms - main_enqueue_event.timestamp_ms
            if main_enqueue_event and fetch_done_event
            else None
        )
        fetch_processing_ms = (
            fetch_done_event.timestamp_ms - fetch_start_event.timestamp_ms
            if fetch_done_event and fetch_start_event
            else None
        )
        fetch_to_categorizer_handoff_ms = (
            record.categorizer_dequeued_at_ms - fetch_done_event.timestamp_ms
            if fetch_done_event
            else None
        )
        end_to_end_ms = (
            record.categorizer_finished_at_ms - main_start_event.timestamp_ms
            if main_start_event
            else None
        )

        results.append(
            {
                "url": record.url,
                "normalized_url": record.normalized_url,
                "url_hash": record.url_hash,
                "status": record.status,
                "trace_id": record.trace_id,
                "main_start_at_ms": main_start_event.timestamp_ms if main_start_event else None,
                "fetch_enqueued_at_ms": (
                    main_enqueue_event.timestamp_ms if main_enqueue_event else None
                ),
                "fetch_completed_at_ms": (
                    fetch_done_event.timestamp_ms if fetch_done_event else None
                ),
                "categorizer_dequeued_at_ms": record.categorizer_dequeued_at_ms,
                "categorizer_started_at_ms": record.categorizer_started_at_ms,
                "categorizer_finished_at_ms": record.categorizer_finished_at_ms,
                "main_until_enqueue_ms": main_until_enqueue_ms,
                "enqueue_to_fetch_done_ms": enqueue_to_fetch_done_ms,
                "fetch_processing_ms": fetch_processing_ms,
                "fetch_to_categorizer_handoff_ms": fetch_to_categorizer_handoff_ms,
                "categorizer_queue_wait_ms": record.categorizer_queue_wait_ms,
                "categorization_compute_ms": record.categorization_compute_ms,
                "end_to_end_ms": end_to_end_ms,
                "matching_mode": (
                    "exact url_hash match for main/fetch logs"
                    if main_enqueue_by_url_hash.get(record.url_hash)
                    and fetch_completed_by_url_hash.get(record.url_hash)
                    else "categorizer exact; main/fetch fell back to nearest prior event order"
                ),
            }
        )

    print(json.dumps(results, indent=2))
    print("\nSummary:")
    for result in results:
        print(f"- URL: {result['normalized_url']}")
        print(f"  status: {result.get('status', 'unknown')}")
        print(f"  end_to_end_ms: {ms_or_none(result.get('end_to_end_ms'))}")
        print(f"  main_until_enqueue_ms: {ms_or_none(result.get('main_until_enqueue_ms'))}")
        print(f"  enqueue_to_fetch_done_ms: {ms_or_none(result.get('enqueue_to_fetch_done_ms'))}")
        print(f"  fetch_processing_ms: {ms_or_none(result.get('fetch_processing_ms'))}")
        print(
            f"  fetch_to_categorizer_handoff_ms: {ms_or_none(result.get('fetch_to_categorizer_handoff_ms'))}"
        )
        print(f"  categorizer_queue_wait_ms: {ms_or_none(result.get('categorizer_queue_wait_ms'))}")
        print(f"  categorization_compute_ms: {ms_or_none(result.get('categorization_compute_ms'))}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
