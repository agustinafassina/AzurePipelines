#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:?AWS_REGION required}"
S3_BUCKET="${S3_BUCKET:?S3_BUCKET required}"
S3_PREFIX="${S3_PREFIX:-inspector/sbom}"
KMS_KEY_ARN="${KMS_KEY_ARN:-}"
ECR_REPOSITORY="${ECR_REPOSITORY:-}"
REPORT_FORMAT="${REPORT_FORMAT:-CYCLONEDX_1_4}"
POLL_INTERVAL="${POLL_INTERVAL:-30}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-40}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed"
  exit 1
fi

if [[ -n "${ECR_REPOSITORY}" ]]; then
  BASE_PREFIX="${S3_PREFIX}/${ECR_REPOSITORY}/current"
  REPOSITORY_VALUE="${ECR_REPOSITORY}"
else
  BASE_PREFIX="${S3_PREFIX}/all/current"
  REPOSITORY_VALUE="all"
fi

RAW_PREFIX="${BASE_PREFIX}/raw"
LATEST_KEY="${BASE_PREFIX}/latest.json"
METADATA_KEY="${BASE_PREFIX}/metadata.json"

echo "Cleaning previous raw export: s3://${S3_BUCKET}/${RAW_PREFIX}/"
aws s3 rm "s3://${S3_BUCKET}/${RAW_PREFIX}/" --recursive --region "${AWS_REGION}" || true

echo "Removing previous latest.json: s3://${S3_BUCKET}/${LATEST_KEY}"
aws s3 rm "s3://${S3_BUCKET}/${LATEST_KEY}" --region "${AWS_REGION}" || true

echo "Removing previous metadata.json: s3://${S3_BUCKET}/${METADATA_KEY}"
aws s3 rm "s3://${S3_BUCKET}/${METADATA_KEY}" --region "${AWS_REGION}" || true

S3_DEST="bucketName=${S3_BUCKET},keyPrefix=${RAW_PREFIX}"
if [[ -n "${KMS_KEY_ARN}" ]]; then
  S3_DEST="${S3_DEST},kmsKeyArn=${KMS_KEY_ARN}"
fi

CREATE_ARGS=(
  inspector2 create-sbom-export
  --region "${AWS_REGION}"
  --report-format "${REPORT_FORMAT}"
  --s3-destination "${S3_DEST}"
  --output json
)

if [[ -n "${ECR_REPOSITORY}" ]]; then
  RESOURCE_FILTER="ecrRepositoryName=[{comparison=\"EQUALS\",value=\"${ECR_REPOSITORY}\"}]"
  CREATE_ARGS+=(--resource-filter-criteria "${RESOURCE_FILTER}")
fi

CREATE_OUTPUT="$(aws "${CREATE_ARGS[@]}")"
REPORT_ID="$(echo "${CREATE_OUTPUT}" | jq -r '.reportId')"

if [[ -z "${REPORT_ID}" || "${REPORT_ID}" == "null" ]]; then
  echo "Could not obtain reportId from create-sbom-export response"
  echo "${CREATE_OUTPUT}"
  exit 1
fi

echo "SBOM export started. reportId=${REPORT_ID}"

STATUS_OUTPUT=""
attempt=1
while [[ "${attempt}" -le "${MAX_ATTEMPTS}" ]]; do
  STATUS_OUTPUT="$(aws inspector2 get-sbom-export \
    --region "${AWS_REGION}" \
    --report-id "${REPORT_ID}" \
    --output json)"

  STATUS="$(echo "${STATUS_OUTPUT}" | jq -r '.status')"
  echo "Attempt ${attempt}/${MAX_ATTEMPTS} - status=${STATUS}"

  case "${STATUS}" in
    SUCCEEDED)
      echo "SBOM export completed successfully"
      break
      ;;
    FAILED|CANCELLED)
      echo "SBOM export failed"
      echo "${STATUS_OUTPUT}" | jq .
      exit 1
      ;;
    IN_PROGRESS)
      sleep "${POLL_INTERVAL}"
      ;;
    *)
      echo "Unexpected status: ${STATUS}"
      echo "${STATUS_OUTPUT}" | jq .
      sleep "${POLL_INTERVAL}"
      ;;
  esac

  attempt=$((attempt + 1))
done

if [[ "${attempt}" -gt "${MAX_ATTEMPTS}" ]]; then
  echo "Timeout waiting for SBOM export reportId=${REPORT_ID}"
  exit 1
fi

echo "Searching generated JSON under s3://${S3_BUCKET}/${RAW_PREFIX}/"

RAW_JSON_KEY="$(
  aws s3api list-objects-v2 \
    --bucket "${S3_BUCKET}" \
    --prefix "${RAW_PREFIX}/" \
    --region "${AWS_REGION}" \
    --query 'reverse(sort_by(Contents[?ends_with(Key, .json)], &LastModified))[0].Key' \
    --output text
)"

if [[ -z "${RAW_JSON_KEY}" || "${RAW_JSON_KEY}" == "None" ]]; then
  echo "No JSON file found in raw export prefix"
  exit 1
fi

echo "Found raw JSON: s3://${S3_BUCKET}/${RAW_JSON_KEY}"
echo "Copying to stable file: s3://${S3_BUCKET}/${LATEST_KEY}"

aws s3 cp \
  "s3://${S3_BUCKET}/${RAW_JSON_KEY}" \
  "s3://${S3_BUCKET}/${LATEST_KEY}" \
  --region "${AWS_REGION}"

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

TMP_METADATA_FILE="$(mktemp)"

jq -n \
  --arg reportId "${REPORT_ID}" \
  --arg status "$(echo "${STATUS_OUTPUT}" | jq -r '.status')" \
  --arg format "$(echo "${STATUS_OUTPUT}" | jq -r '.format')" \
  --arg repository "${REPOSITORY_VALUE}" \
  --arg generatedAt "${GENERATED_AT}" \
  --arg awsRegion "${AWS_REGION}" \
  --arg bucket "${S3_BUCKET}" \
  --arg basePrefix "${BASE_PREFIX}" \
  --arg rawPrefix "${RAW_PREFIX}" \
  --arg latestKey "${LATEST_KEY}" \
  --arg metadataKey "${METADATA_KEY}" \
  --arg rawJsonKey "${RAW_JSON_KEY}" \
  --arg kmsKeyArn "${KMS_KEY_ARN}" \
  --argjson filterCriteria "$(echo "${STATUS_OUTPUT}" | jq '.filterCriteria // {}')" \
  --argjson s3Destination "$(echo "${STATUS_OUTPUT}" | jq '.s3Destination // {}')" \
  '{
    reportId: $reportId,
    status: $status,
    format: $format,
    repository: $repository,
    generatedAt: $generatedAt,
    awsRegion: $awsRegion,
    bucket: $bucket,
    basePrefix: $basePrefix,
    rawPrefix: $rawPrefix,
    latestKey: $latestKey,
    metadataKey: $metadataKey,
    rawJsonKey: $rawJsonKey,
    kmsKeyArn: $kmsKeyArn,
    filterCriteria: $filterCriteria,
    s3Destination: $s3Destination
  }' > "${TMP_METADATA_FILE}"

echo "Uploading metadata file: s3://${S3_BUCKET}/${METADATA_KEY}"
aws s3 cp "${TMP_METADATA_FILE}" "s3://${S3_BUCKET}/${METADATA_KEY}" --region "${AWS_REGION}"

rm -f "${TMP_METADATA_FILE}"

echo "Stable SBOM file ready: s3://${S3_BUCKET}/${LATEST_KEY}"
echo "Metadata file ready: s3://${S3_BUCKET}/${METADATA_KEY}"
echo "Raw export available under: s3://${S3_BUCKET}/${RAW_PREFIX}/"