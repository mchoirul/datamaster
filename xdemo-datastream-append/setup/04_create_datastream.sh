#!/bin/bash
# Creates Datastream connection profiles and stream (append mode)

set -e

PROJECT_ID="YOUR_PROJECT_ID"
REGION="us-central1"
CLOUDSQL_INSTANCE="YOUR_INSTANCE_NAME"
STREAM_NAME="postgres-to-bq-append"

echo "============================================================"
echo "Creating Datastream Configuration"
echo "============================================================"

# Get Cloud SQL public IP
CLOUDSQL_IP=$(gcloud sql instances describe ${CLOUDSQL_INSTANCE} \
  --project=${PROJECT_ID} \
  --format="value(ipAddresses[0].ipAddress)")

echo "Creating PostgreSQL connection profile..."
gcloud datastream connection-profiles create postgres-source-profile \
  --location=${REGION} \
  --project=${PROJECT_ID} \
  --type=postgresql \
  --display-name="PostgreSQL Source Profile" \
  --postgresql-hostname=${CLOUDSQL_IP} \
  --postgresql-port=5432 \
  --postgresql-username=postgres \
  --postgresql-password="YOUR_DB_PASSWORD" \
  --postgresql-database=YOUR_DATABASE_NAME

echo "Creating BigQuery connection profile..."
gcloud datastream connection-profiles create bigquery-destination-profile \
  --location=${REGION} \
  --project=${PROJECT_ID} \
  --type=bigquery \
  --display-name="BigQuery Destination Profile"

echo "Creating Datastream stream (APPEND mode)..."

cat > /tmp/postgres-config.json <<JSON
{
  "publication": "datastream_publication",
  "replicationSlot": "datastream_slot_demo",
  "includeObjects": {
    "postgresqlSchemas": [
      {
        "schema": "public",
        "postgresqlTables": [
          {
            "table": "customer_bronze"
          },
          {
            "table": "soft_customer_bronze"
          }
        ]
      }
    ]
  }
}
JSON

cat > /tmp/bq-config.json <<JSON
{
  "dataFreshness": "0s",
  "singleTargetDataset": {
    "datasetId": "YOUR_PROJECT_ID:YOUR_DATASET_ID"
  },
  "appendOnly": {}
}
JSON

gcloud datastream streams create ${STREAM_NAME} \
  --location=${REGION} \
  --project=${PROJECT_ID} \
  --display-name="PostgreSQL to BigQuery (Append Mode)" \
  --source=postgres-source-profile \
  --destination=bigquery-destination-profile \
  --postgresql-source-config=/tmp/postgres-config.json \
  --bigquery-destination-config=/tmp/bq-config.json \
  --backfill-none

echo "Starting Datastream stream..."
gcloud datastream streams update ${STREAM_NAME} \
  --location=${REGION} \
  --project=${PROJECT_ID} \
  --state=RUNNING

echo "✅ Datastream stream created and started for both hard and soft CDC tables!"
