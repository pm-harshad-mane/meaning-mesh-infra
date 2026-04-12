#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "Usage: $0 <main-lambda-zip> <fetcher-lambda-zip> <categorizer-image-uri> <subnet-1,subnet-2> <sg-1,sg-2>"
  exit 1
fi

MAIN_ZIP="$1"
FETCHER_ZIP="$2"
CATEGORIZER_IMAGE="$3"
SUBNETS_CSV="$4"
SGS_CSV="$5"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${ROOT_DIR}/environments/dev"

IFS=',' read -r -a SUBNET_ARRAY <<< "${SUBNETS_CSV}"
IFS=',' read -r -a SG_ARRAY <<< "${SGS_CSV}"

SUBNETS_TF='['
for subnet in "${SUBNET_ARRAY[@]}"; do
  [[ "${SUBNETS_TF}" != "[" ]] && SUBNETS_TF+=", "
  SUBNETS_TF+="\"${subnet}\""
done
SUBNETS_TF+=']'

SGS_TF='['
for sg in "${SG_ARRAY[@]}"; do
  [[ "${SGS_TF}" != "[" ]] && SGS_TF+=", "
  SGS_TF+="\"${sg}\""
done
SGS_TF+=']'

terraform -chdir="${ENV_DIR}" init
terraform -chdir="${ENV_DIR}" apply \
  -var="main_lambda_package_file=${MAIN_ZIP}" \
  -var="fetcher_lambda_package_file=${FETCHER_ZIP}" \
  -var="categorizer_image=${CATEGORIZER_IMAGE}" \
  -var="subnet_ids=${SUBNETS_TF}" \
  -var="security_group_ids=${SGS_TF}"
