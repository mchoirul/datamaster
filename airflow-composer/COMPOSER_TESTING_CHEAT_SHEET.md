# Cloud Composer 3: Testing & Configuration Commands

All commands from the Deferrable Operators stress testing, organized by topic.

> **Parameter Convention:**
> | Placeholder | Example Value | Description |
> |---|---|---|
> | `${PROJECT_ID}` | `my-gcp-project` | GCP project ID |
> | `${ENV_NAME}` | `gcpairflow01` | Composer 3 environment name |
> | `${REGION}` | `us-central1` | GCP region |
> | `${SERVICE_URL}` | `https://mock-airbyte-xxx-uc.a.run.app` | Cloud Run URL (from deploy output) |
> | `${DAG_BUCKET}` | `us-central1-composer-...-bucket` | Composer DAG GCS bucket path |
>

---
## 1. Preparation & Authentication

# Authenticate gcloud (required before any API calls)
gcloud auth login
gcloud auth login --no-launch-browser

# Enable required GCP services
gcloud services enable run.googleapis.com \
    cloudbuild.googleapis.com \
    --project="${PROJECT_ID}"

---
## 2. Deploy Mock Airbyte (API Simulation)

# Deploy to Cloud Run
gcloud run deploy mock-airbyte \
    --source . \
    --region "${REGION}" \
    --project "${PROJECT_ID}" \
    --allow-unauthenticated \
    --max-instances=1 \
    --set-env-vars="SYNC_DURATION_SECONDS=120" \
    --quiet

# Retrieve the service URL
gcloud run services describe mock-airbyte \
    --region "${REGION}" \
    --project "${PROJECT_ID}" \
    --format="value(status.url)" \
    | tee /tmp/mock_airbyte_url.txt

# Verify the mock is healthy
curl -s "${SERVICE_URL}/v1/health" | python3 -m json.tool

---
## 3. Environment Tuning

### 3a. Install Airbyte Provider Package
# NOTE: Triggers full environment rebuild (~10-15 min)
gcloud composer environments update "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    --update-pypi-package="apache-airflow-providers-airbyte>=5.4.1"

### 3b. Scale Infrastructure Components
# Schedulers, Workers (with concurrency), Triggerer, Web Server
gcloud composer environments update "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    --scheduler-count=2 \
    --scheduler-cpu=0.5 \
    --scheduler-memory=2GB \
    --worker-cpu=1 \
    --worker-memory=4GB \
    --min-workers=1 \
    --max-workers=6 \
    --worker-concurrency=8 \
    --triggerer-count=1 \
    --triggerer-cpu=0.5 \
    --triggerer-memory=1GB

### 3c. Override Airflow Configurations
# Raises parallelism gates to allow 70+ concurrent tasks per DAG
gcloud composer environments update "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    --update-airflow-configs=core-parallelism=150,core-max_active_tasks_per_dag=150

### 3d. Expand default_pool Slots
gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    pools set -- default_pool \
    --slots 1000

### 3e. Enable include_deferred on default_pool
# Required to prevent deferred tasks from being counted against pool capacity.
# Set via Airflow REST API (not available in gcloud CLI):
AIRFLOW_URI=$(gcloud composer environments describe "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    --format="value(config.airflowUri)")

curl -X PATCH \
    "${AIRFLOW_URI}/api/v1/pools/default_pool" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/json" \
    -d '{"include_deferred": true, "slots": 1000}'

# Or set via Airflow UI:
#   Environments > ${ENV_NAME} > Open Airflow UI > Admin > Pools >
#   edit default_pool > check "Include deferred tasks" > Save

---
## 4. Configure Airflow Connection

# Delete existing (if any)
gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    connections delete -- airbyte_default 2>/dev/null || true

# Create new connection pointing to mock Airbyte
gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    connections add -- airbyte_default \
    --conn-type airbyte \
    --conn-host "${SERVICE_URL}/v1"

# Verify connection was created
gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    connections list -- --output table

---
## 5. Deploy DAGs to Composer

# Retrieve the DAG bucket path
DAG_BUCKET=$(gcloud composer environments describe "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    --format="value(config.dagGcsPrefix)")

# Upload stress test DAGs (70 tasks each = 140 total)
gsutil cp dags/airbyte_deferrable_stress_test.py "${DAG_BUCKET}/"
gsutil cp dags/airbyte_deferrable_stress_test_2.py "${DAG_BUCKET}/"
gsutil cp dags/airbyte_broken_stress_test.py "${DAG_BUCKET}/"

# Wait for DAG processor to parse (recommended: 90 seconds)
sleep 90

---
## 6. Execute Stress Tests

# Unpause DAGs (first run only)
gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    dags unpause -- airbyte_deferrable_stress_test

gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    dags unpause -- airbyte_deferrable_stress_test_2

gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    dags unpause -- airbyte_broken_stress_test

# Trigger DAG runs (typically run one at a time for measurement)
gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    dags trigger -- airbyte_deferrable_stress_test

gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    dags trigger -- airbyte_deferrable_stress_test_2

# To run both DAGs simultaneously (140 concurrent tasks):
gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    dags trigger -- airbyte_deferrable_stress_test & \
gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    dags trigger -- airbyte_deferrable_stress_test_2

# Also trigger the broken DAG for comparison (anti-pattern demo)
gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    dags trigger -- airbyte_broken_stress_test

---
## 7. Observability

### 7a. Environment State & Health
# Check if environment is RUNNING (critical after updates)
gcloud composer environments describe "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    --format="value(state)"

# Full environment details
gcloud composer environments describe "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}"

### 7b. View Applied Configuration
# See which airflow.cfg overrides are active
gcloud composer environments describe "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    --format="value(config.softwareConfig.airflowConfigOverrides)"

### 7c. Component Counts
# Triggerer count
gcloud composer environments describe "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    --format="value(config.workloadsConfig.triggerer.count)"

# Scheduler count
gcloud composer environments describe "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    --format="value(config.workloadsConfig.scheduler.count)"

# Worker configuration
gcloud composer environments describe "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    --format="value(config.workloadsConfig.worker)"

### 7d. Airflow CLI Diagnostics
# List all parsed DAGs
gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    dags list -- --output table

# List Airflow pools and slot usage
gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    pools list -- --output table

# List Airflow connections
gcloud composer environments run "${ENV_NAME}" \
    --location "${REGION}" \
    --project "${PROJECT_ID}" \
    connections list -- --output table

### 7e. Poll for Environment Ready (Post-Update)
# Use this loop to wait for environment to become RUNNING after updates
while true; do
    STATE=$(gcloud composer environments describe "${ENV_NAME}" \
        --location "${REGION}" \
        --project "${PROJECT_ID}" \
        --format="value(state)")
    echo "[$(date +%H:%M:%S)] ${STATE}"
    [ "${STATE}" = "RUNNING" ] && break
    sleep 30
done

