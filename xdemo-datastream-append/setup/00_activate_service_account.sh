#!/bin/bash
# Activate service account using YOUR_KEY_FILE.json
# This sets the service account as the active account for all gcloud commands

set -e

PROJECT_ID="YOUR_PROJECT_ID"
SERVICE_ACCOUNT="YOUR_SERVICE_ACCOUNT_EMAIL"
KEY_FILE="YOUR_WORKSPACE/YOUR_KEY_FILE.json"

echo "============================================================"
echo "Activating Service Account"
echo "============================================================"
echo "Service Account: ${SERVICE_ACCOUNT}"
echo "Key File: ${KEY_FILE}"
echo "Project: ${PROJECT_ID}"
echo ""

# Check if key file exists
if [ ! -f "${KEY_FILE}" ]; then
  echo "❌ Error: Key file not found: ${KEY_FILE}"
  echo ""
  echo "Expected location: ${KEY_FILE}"
  echo "Please ensure the service account key file exists."
  exit 1
fi

echo "✅ Key file found"
echo ""

# Activate service account
echo "Activating service account..."
gcloud auth activate-service-account \
  ${SERVICE_ACCOUNT} \
  --key-file=${KEY_FILE} \
  --project=${PROJECT_ID}

# Set as active account
gcloud config set account ${SERVICE_ACCOUNT}
gcloud config set project ${PROJECT_ID}

# Verify activation
ACTIVE_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
ACTIVE_PROJECT=$(gcloud config get-value project 2>/dev/null)

echo ""
echo "✅ Service account activated!"
echo "Active account: ${ACTIVE_ACCOUNT}"
echo "Active project: ${ACTIVE_PROJECT}"
echo ""

# Test authentication
echo "Testing authentication..."
if gcloud auth list --filter="status:ACTIVE" 2>/dev/null | grep -q "${SERVICE_ACCOUNT}"; then
  echo "✅ Authentication successful"
else
  echo "❌ Authentication failed"
  exit 1
fi

echo ""
echo "============================================================"
echo "Service account is ready for use."
echo "All subsequent gcloud commands will use this service account."
echo "============================================================"
echo ""
echo "Next step: ./00_verify_permissions.sh"
