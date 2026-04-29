#!/bin/bash
# Checks if Datastream has replicated data to BigQuery
# Polls every 15 seconds until data arrives

set -e

PROJECT_ID="YOUR_PROJECT_ID"
TABLE="YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze"

echo "============================================================"
echo "Checking Datastream Replication Status"
echo "============================================================"
echo "Waiting for data to arrive in BigQuery..."
echo "Table: ${TABLE}"
echo ""

MAX_ATTEMPTS=20
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  
  echo -n "Attempt ${ATTEMPT}/${MAX_ATTEMPTS}: "
  
  ROW_COUNT=$(bq query --use_legacy_sql=false --format=csv --quiet \
    "SELECT COUNT(*) as count FROM \`${TABLE}\`" 2>/dev/null | tail -n 1)
  
  if [ "$ROW_COUNT" -gt 0 ]; then
    echo "✅ Data arrived! Row count: ${ROW_COUNT}"
    echo ""
    
    # Show latest event timestamp and breakdown
    echo "============================================================"
    echo "Bronze Table Status:"
    echo "============================================================"
    
    bq query --use_legacy_sql=false --format=pretty \
      "SELECT 
        COUNT(*) as total_rows,
        COUNT(DISTINCT customer_id) as unique_customers,
        MIN(TIMESTAMP_MILLIS(datastream_metadata.source_timestamp)) as earliest_event,
        MAX(TIMESTAMP_MILLIS(datastream_metadata.source_timestamp)) as latest_event
       FROM \`${TABLE}\`"
    
    echo ""
    echo "Change type breakdown:"
    bq query --use_legacy_sql=false --format=pretty \
      "SELECT 
        datastream_metadata.change_type,
        COUNT(*) as count
       FROM \`${TABLE}\`
       GROUP BY datastream_metadata.change_type
       ORDER BY count DESC"
    
    echo ""
    echo "============================================================"
    echo "✅ Ready to proceed with demo!"
    echo "============================================================"
    echo ""
    echo "Next step: Examine bronze data"
    echo "  cd demo"
    echo "  bq query --use_legacy_sql=false < check_bronze_data.sql"
    echo ""
    exit 0
  fi
  
  echo "No data yet, waiting 15 seconds..."
  sleep 15
done

echo ""
echo "❌ Timeout: Data did not arrive after $((MAX_ATTEMPTS * 15)) seconds"
echo ""
echo "Troubleshooting:"
echo "1. Check Datastream stream status:"
echo "   gcloud datastream streams describe postgres-to-bq-append \\"
echo "     --location=us-central1 --project=${PROJECT_ID}"
echo ""
echo "2. Check for errors in stream:"
echo "   gcloud datastream streams describe postgres-to-bq-append \\"
echo "     --location=us-central1 --project=${PROJECT_ID} \\"
echo "     --format='value(errors)'"
echo ""
echo "3. Verify Cloud SQL has data:"
echo "   gcloud sql connect YOUR_INSTANCE_NAME --user=postgres --project=${PROJECT_ID}"
echo "   Then: SELECT COUNT(*) FROM customers;"
echo ""
exit 1
