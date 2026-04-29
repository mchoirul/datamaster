#!/bin/bash
# Creates BigQuery dataset for bronze and silver tables

set -e

PROJECT_ID="YOUR_PROJECT_ID"
LOCATION="us-central1"
DATASET_NAME="YOUR_DATASET_ID"

echo "============================================================"
echo "Creating BigQuery Dataset"
echo "============================================================"
echo "Project: ${PROJECT_ID}"
echo "Dataset: ${DATASET_NAME}"
echo "Location: ${LOCATION}"
echo ""

echo "Creating BigQuery dataset..."

bq mk \
  --project_id=${PROJECT_ID} \
  --location=${LOCATION} \
  --dataset \
  --description="Datastream demo - Bronze and Silver tables" \
  ${DATASET_NAME}

echo ""
echo "============================================================"
echo "✅ BigQuery dataset created successfully!"
echo "============================================================"
echo ""
echo "Dataset: ${PROJECT_ID}.${DATASET_NAME}"
echo "Location: ${LOCATION}"
echo ""
echo "Tables that will be created:"
echo "  - customer_bronze (created by Datastream automatically)"
echo "  - customer_silver (created by MERGE query)"
echo ""
echo "Verify dataset:"
echo "  bq ls --project_id=${PROJECT_ID}"
echo ""
echo "============================================================"
echo "Next step: ./04_create_datastream.sh"
echo "============================================================"
