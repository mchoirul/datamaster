#!/bin/bash
# Creates a scheduled query to run bronze-to-silver merge every 15 minutes
# This demonstrates the production setup for automated transformation

set -e

PROJECT_ID="YOUR_PROJECT_ID"
SCHEDULE_NAME="bronze_to_silver_merge_scheduled"
DEMO_ROOT="YOUR_WORKSPACE/demo-datastream-append"

echo "============================================================"
echo "Creating Scheduled Query for Bronze-to-Silver MERGE"
echo "============================================================"
echo "Project: ${PROJECT_ID}"
echo "Schedule: Every 15 minutes"
echo "Query: hard_bronze_to_silver_merge.sql"
echo ""

echo "Creating scheduled query..."
echo ""

bq query \
  --project_id=${PROJECT_ID} \
  --use_legacy_sql=false \
  --schedule='every 15 minutes' \
  --display_name="${SCHEDULE_NAME}" \
  --replace=true \
  "$(cat ${DEMO_ROOT}/demo/hard_bronze_to_silver_merge.sql)"

echo "Creating scheduled query for soft CDC..."
bq query \
  --project_id=${PROJECT_ID} \
  --use_legacy_sql=false \
  --schedule='every 15 minutes' \
  --display_name="${SCHEDULE_NAME}_soft" \
  --replace=true \
  "$(cat ${DEMO_ROOT}/demo/soft_bronze_to_silver_merge.sql)"

echo ""
echo "============================================================"
echo "✅ Scheduled query created!"
echo "============================================================"
echo ""
echo "Schedule Details:"
echo "  Name: ${SCHEDULE_NAME}"
echo "  Frequency: Every 15 minutes"
echo "  Query: Incremental MERGE from bronze to silver"
echo ""
echo "What this does:"
echo "  - Runs automatically every 15 minutes"
echo "  - Only processes new changes (incremental)"
echo "  - Keeps silver table up-to-date"
echo "  - Cost-efficient (processes delta only)"
echo ""
echo "To view scheduled queries:"
echo "  1. BigQuery Console > Scheduled queries"
echo "  2. Or run: bq ls --transfer_config --project_id=${PROJECT_ID}"
echo ""
echo "To update schedule:"
echo "  bq update --transfer_config <transfer_config_id> --schedule='every 30 minutes'"
echo ""
echo "To disable:"
echo "  bq update --transfer_config <transfer_config_id> --no_enable_schedule"
echo ""
echo "============================================================"
