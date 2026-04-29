#!/bin/bash
# Cleanup all demo resources
# Run this after demo to avoid ongoing costs

set -e

PROJECT_ID="YOUR_PROJECT_ID"
REGION="us-central1"

echo "============================================================"
echo "🧹 Cleaning up Datastream Demo Resources"
echo "============================================================"
echo ""

#-----------------------------------------------------------
# 1. Delete Datastream stream
#-----------------------------------------------------------
echo "1. Deleting Datastream stream..."
if gcloud datastream streams describe postgres-to-bq-append \
   --location=${REGION} --project=${PROJECT_ID} &>/dev/null; then
  
  gcloud datastream streams delete postgres-to-bq-append \
    --location=${REGION} \
    --project=${PROJECT_ID} \
    --quiet
  
  echo "   ✅ Datastream stream deleted"
else
  echo "   ⚠️  Stream not found or already deleted"
fi

echo ""

#-----------------------------------------------------------
# 2. Delete connection profiles
#-----------------------------------------------------------
echo "2. Deleting Datastream connection profiles..."

if gcloud datastream connection-profiles describe postgres-source-profile \
   --location=${REGION} --project=${PROJECT_ID} &>/dev/null; then
  
  gcloud datastream connection-profiles delete postgres-source-profile \
    --location=${REGION} \
    --project=${PROJECT_ID} \
    --quiet
  
  echo "   ✅ PostgreSQL connection profile deleted"
else
  echo "   ⚠️  PostgreSQL profile not found"
fi

if gcloud datastream connection-profiles describe bigquery-destination-profile \
   --location=${REGION} --project=${PROJECT_ID} &>/dev/null; then
  
  gcloud datastream connection-profiles delete bigquery-destination-profile \
    --location=${REGION} \
    --project=${PROJECT_ID} \
    --quiet
  
  echo "   ✅ BigQuery connection profile deleted"
else
  echo "   ⚠️  BigQuery profile not found"
fi

echo ""

#-----------------------------------------------------------
# 3. Delete Cloud SQL instance
#-----------------------------------------------------------
echo "3. Deleting Cloud SQL instance..."
echo "   ⚠️  This will permanently delete all data!"
echo ""

read -p "   Delete Cloud SQL instance YOUR_INSTANCE_NAME? (y/N): " confirm

if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
  if gcloud sql instances describe YOUR_INSTANCE_NAME \
     --project=${PROJECT_ID} &>/dev/null; then
    
    echo "   Deleting Cloud SQL instance (this may take a few minutes)..."
    gcloud sql instances delete YOUR_INSTANCE_NAME \
      --project=${PROJECT_ID} \
      --quiet
    
    echo "   ✅ Cloud SQL instance deleted"
  else
    echo "   ⚠️  Cloud SQL instance not found"
  fi
else
  echo "   ⏭️  Skipping Cloud SQL deletion"
  echo "   Note: Instance will continue to incur costs (~$0.10/hour)"
fi

echo ""

#-----------------------------------------------------------
# 4. Delete BigQuery dataset
#-----------------------------------------------------------
echo "4. Deleting BigQuery dataset..."
echo "   This will delete bronze and silver tables"
echo ""

read -p "   Delete BigQuery dataset YOUR_DATASET_ID? (y/N): " confirm_bq

if [ "$confirm_bq" = "y" ] || [ "$confirm_bq" = "Y" ]; then
  if bq ls --project_id=${PROJECT_ID} YOUR_DATASET_ID &>/dev/null; then
    
    bq rm -r -f -d ${PROJECT_ID}:YOUR_DATASET_ID
    
    echo "   ✅ BigQuery dataset deleted"
  else
    echo "   ⚠️  BigQuery dataset not found"
  fi
else
  echo "   ⏭️  Keeping BigQuery dataset for reference"
  echo "   Note: Storage costs are minimal"
fi

echo ""

#-----------------------------------------------------------
# 5. Delete scheduled queries (if created)
#-----------------------------------------------------------
echo "5. Checking for scheduled queries..."

SCHEDULED_QUERIES=$(bq ls --transfer_config --project_id=${PROJECT_ID} \
  --format="value(name,displayName)" 2>/dev/null | grep "bronze_to_silver_merge_scheduled" | awk '{print $1}')

if [ -n "$SCHEDULED_QUERIES" ]; then
  echo "   Found scheduled query, deleting..."
  for query_id in $SCHEDULED_QUERIES; do
    bq rm -f --transfer_config "$query_id"
  done
  echo "   ✅ Scheduled queries deleted"
else
  echo "   ⚠️  No scheduled queries found"
fi

echo ""

#-----------------------------------------------------------
# Summary
#-----------------------------------------------------------
echo "============================================================"
echo "✅ Cleanup Complete!"
echo "============================================================"
echo ""
echo "Resources cleaned up:"
echo "  - Datastream stream and connection profiles"
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
  echo "  - Cloud SQL instance"
else
  echo "  - Cloud SQL instance (KEPT - still incurring costs)"
fi
if [ "$confirm_bq" = "y" ] || [ "$confirm_bq" = "Y" ]; then
  echo "  - BigQuery dataset and tables"
else
  echo "  - BigQuery dataset (KEPT for reference)"
fi
echo "  - Scheduled queries (if any)"
echo ""

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "⚠️  WARNING: Cloud SQL instance is still running!"
  echo "   To delete manually:"
  echo "   gcloud sql instances delete YOUR_INSTANCE_NAME --project=${PROJECT_ID}"
  echo ""
fi

echo "Demo environment cleanup completed."
echo ""
