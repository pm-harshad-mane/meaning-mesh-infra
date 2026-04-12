#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <categorizer-ecr-image-uri>"
  exit 1
fi

IMAGE_URI="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

"${ROOT_DIR}/meaning-mesh-main-service/scripts/build_lambda_package.sh"
"${ROOT_DIR}/meaning-mesh-url-fetcher/scripts/build_lambda_package.sh"
"${ROOT_DIR}/meaning-mesh-url-categorizer/scripts/build_and_push_image.sh" "${IMAGE_URI}"

echo "Artifacts built:"
echo "  ${ROOT_DIR}/meaning-mesh-main-service/dist/lambda.zip"
echo "  ${ROOT_DIR}/meaning-mesh-url-fetcher/dist/lambda.zip"
echo "  ${IMAGE_URI}"
