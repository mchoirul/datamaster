#!/bin/bash
# Creates Cloud SQL PostgreSQL instance with public IP and Datastream configuration
# Enables logical replication for CDC

set -e

PROJECT_ID="YOUR_PROJECT_ID"
REGION="us-central1"
INSTANCE_NAME="YOUR_INSTANCE_NAME"
ROOT_PASSWORD="YOUR_DB_PASSWORD"  # Change for production

echo "============================================================"
echo "Creating Cloud SQL PostgreSQL Instance"
echo "============================================================"
echo "Instance Name: ${INSTANCE_NAME}"
echo "Region: ${REGION}"
echo "Project: ${PROJECT_ID}"
echo ""

echo "Creating Cloud SQL PostgreSQL instance..."
echo "This will take 5-10 minutes..."
echo ""

gcloud sql instances create ${INSTANCE_NAME} \
  --project=${PROJECT_ID} \
  --database-version=POSTGRES_14 \
  --tier=db-custom-2-7680 \
  --region=${REGION} \
  --database-flags=cloudsql.logical_decoding=on,max_replication_slots=10,max_wal_senders=10,cloudsql.enable_pglogical=on \
  --root-password=${ROOT_PASSWORD} \
  --backup-start-time=03:00 \
  --maintenance-window-day=SUN \
  --maintenance-window-hour=4 \
  --assign-ip

echo ""
echo "Instance created. Configuring network access..."
echo ""

# Add authorized network (allow all for demo - restrict in production)
echo "Adding authorized network (0.0.0.0/0 for demo)..."
gcloud sql instances patch ${INSTANCE_NAME} \
  --project=${PROJECT_ID} \
  --authorized-networks=0.0.0.0/0 \
  --quiet

echo ""
echo "Waiting for instance to be fully ready..."
sleep 30

# Get public IP
PUBLIC_IP=$(gcloud sql instances describe ${INSTANCE_NAME} \
  --project=${PROJECT_ID} \
  --format="value(ipAddresses[0].ipAddress)")

echo ""
echo "============================================================"
echo "✅ Cloud SQL instance created successfully!"
echo "============================================================"
echo ""
echo "Instance Name: ${INSTANCE_NAME}"
echo "Public IP: ${PUBLIC_IP}"
echo "Root Password: ${ROOT_PASSWORD}"
echo "Database Version: PostgreSQL 14"
echo "Region: ${REGION}"
echo ""
echo "CDC Configuration:"
echo "  ✅ Logical decoding: ENABLED"
echo "  ✅ Max replication slots: 10"
echo "  ✅ Max WAL senders: 10"
echo "  ✅ pglogical: ENABLED"
echo ""
echo "Network Access:"
echo "  ⚠️  Public IP with 0.0.0.0/0 access (DEMO ONLY)"
echo "  🔒 For production, restrict to specific IPs"
echo ""
echo "============================================================"
echo "Next Steps:"
echo "============================================================"
echo ""
echo "1. Connect to database and run setup:"
echo "   gcloud sql connect ${INSTANCE_NAME} --user=postgres --project=${PROJECT_ID}"
echo ""
echo "2. Then in psql prompt:"
echo "   \i 02_setup_database.sql"
echo ""
echo "3. Save this Public IP for later: ${PUBLIC_IP}"
echo "   (You'll need it in simulate_cdc.py)"
echo ""
