#!/bin/bash
# Verify service account permissions before running demo
# Checks: APIs enabled, IAM roles, authentication

set -e

PROJECT_ID="YOUR_PROJECT_ID"
REGION="us-central1"
SERVICE_ACCOUNT="YOUR_SERVICE_ACCOUNT_EMAIL"
KEY_FILE="YOUR_WORKSPACE/YOUR_KEY_FILE.json"

echo "============================================================"
echo "Datastream Demo - Service Account Permission Verification"
echo "============================================================"
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Service Account: ${SERVICE_ACCOUNT}"
echo ""

# Check if key file exists
if [ ! -f "${KEY_FILE}" ]; then
  echo "❌ Error: Key file not found: ${KEY_FILE}"
  exit 1
fi
echo "✅ Key file found: ${KEY_FILE}"
echo ""

# Get project number
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)" 2>/dev/null)
if [ -z "$PROJECT_NUMBER" ]; then
  echo "❌ Error: Cannot access project ${PROJECT_ID}"
  echo "   Make sure service account is activated: ./00_activate_service_account.sh"
  exit 1
fi
echo "Project number: ${PROJECT_NUMBER}"
echo ""

#-----------------------------------------------------------
# Section 1: Check Required APIs
#-----------------------------------------------------------
echo "============================================================"
echo "1. Checking Required APIs"
echo "============================================================"

REQUIRED_APIS=(
  "sqladmin.googleapis.com:Cloud SQL Admin API"
  "datastream.googleapis.com:Datastream API"
  "bigquery.googleapis.com:BigQuery API"
  "servicenetworking.googleapis.com:Service Networking API"
  "compute.googleapis.com:Compute Engine API"
)

MISSING_APIS=()

for api_info in "${REQUIRED_APIS[@]}"; do
  IFS=':' read -r api_name api_desc <<< "$api_info"
  
  if gcloud services list --enabled --filter="name:${api_name}" --format="value(name)" --project=${PROJECT_ID} 2>/dev/null | grep -q "${api_name}"; then
    echo "  ✅ ${api_desc}"
  else
    echo "  ❌ ${api_desc} - NOT ENABLED"
    MISSING_APIS+=("${api_name}")
  fi
done

if [ ${#MISSING_APIS[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  Missing APIs. Enable with:"
  echo ""
  echo "gcloud services enable \\"
  for i in "${!MISSING_APIS[@]}"; do
    if [ $i -eq $((${#MISSING_APIS[@]} - 1)) ]; then
      echo "  ${MISSING_APIS[$i]} \\"
    else
      echo "  ${MISSING_APIS[$i]} \\"
    fi
  done
  echo "  --project=${PROJECT_ID}"
fi

echo ""

#-----------------------------------------------------------
# Section 2: Check Service Account Permissions
#-----------------------------------------------------------
echo "============================================================"
echo "2. Checking Service Account IAM Roles"
echo "============================================================"

# Get all roles for this service account
SA_ROLES=$(gcloud projects get-iam-policy ${PROJECT_ID} \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT}" \
  --format="value(bindings.role)" 2>/dev/null)

if [ -z "$SA_ROLES" ]; then
  echo "  ❌ Service account has NO project-level roles"
  echo ""
  echo "  Required roles must be granted. Run these commands:"
  echo ""
  cat <<'EOF'
PROJECT_ID="YOUR_PROJECT_ID"
SERVICE_ACCOUNT="YOUR_SERVICE_ACCOUNT_EMAIL"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudsql.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/datastream.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/bigquery.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/servicenetworking.networksAdmin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudsql.client"
EOF
  echo ""
  exit 1
else
  echo "  Current roles:"
  echo "$SA_ROLES" | while read -r role; do
    echo "    ✅ ${role}"
  done
  echo ""
  
  # Check for required roles
  REQUIRED_ROLES=(
    "roles/cloudsql.admin"
    "roles/datastream.admin"
    "roles/bigquery.admin"
    "roles/cloudsql.client"
  )
  
  MISSING_ROLES=()
  for req_role in "${REQUIRED_ROLES[@]}"; do
    if echo "$SA_ROLES" | grep -q "$req_role"; then
      : # Role exists
    else
      echo "  ⚠️  Missing recommended role: ${req_role}"
      MISSING_ROLES+=("${req_role}")
    fi
  done
  
  if [ ${#MISSING_ROLES[@]} -gt 0 ]; then
    echo ""
    echo "  Grant missing roles:"
    for role in "${MISSING_ROLES[@]}"; do
      echo "  gcloud projects add-iam-policy-binding ${PROJECT_ID} \\"
      echo "    --member=\"serviceAccount:${SERVICE_ACCOUNT}\" \\"
      echo "    --role=\"${role}\""
      echo ""
    done
  fi
fi

echo ""

#-----------------------------------------------------------
# Section 3: Test Service Account Authentication
#-----------------------------------------------------------
echo "============================================================"
echo "3. Testing Service Account Operations"
echo "============================================================"

# Test Cloud SQL
echo -n "  Cloud SQL operations... "
if gcloud sql instances list --project=${PROJECT_ID} --format="value(name)" --limit=1 &>/dev/null; then
  echo "✅"
else
  echo "❌ FAILED"
  echo "     Check that service account has roles/cloudsql.admin"
fi

# Test BigQuery
echo -n "  BigQuery operations... "
if bq ls --project_id=${PROJECT_ID} --max_results=1 &>/dev/null; then
  echo "✅"
else
  echo "❌ FAILED"
  echo "     Check that service account has roles/bigquery.admin"
fi

# Test Datastream
echo -n "  Datastream operations... "
if gcloud datastream streams list --location=${REGION} --project=${PROJECT_ID} --format="value(name)" --limit=1 &>/dev/null; then
  echo "✅"
else
  echo "❌ FAILED"
  echo "     Check that service account has roles/datastream.admin"
fi

echo ""

#-----------------------------------------------------------
# Section 4: Summary
#-----------------------------------------------------------
echo "============================================================"
echo "4. Summary"
echo "============================================================"

if [ ${#MISSING_APIS[@]} -eq 0 ] && [ ${#MISSING_ROLES[@]} -eq 0 ]; then
  echo "✅ All required permissions and APIs are configured!"
  echo ""
  echo "Service account ready: ${SERVICE_ACCOUNT}"
  echo ""
  echo "Proceed with demo setup:"
  echo "  ./00_setup_python_env.sh"
  echo "  ./01_create_cloudsql.sh"
  echo "  ./02_setup_database.sql"
  echo "  ./03_create_bq_dataset.sh"
  echo "  ./04_create_datastream.sh"
  exit 0
else
  echo "⚠️  Configuration incomplete."
  echo ""
  
  if [ ${#MISSING_APIS[@]} -gt 0 ]; then
    echo "Missing APIs: ${#MISSING_APIS[@]}"
  fi
  
  if [ ${#MISSING_ROLES[@]} -gt 0 ]; then
    echo "Missing/recommended roles: ${#MISSING_ROLES[@]}"
  fi
  
  echo ""
  echo "Please review the output above and run the suggested commands."
  echo "Then re-run this script to verify."
  exit 1
fi
