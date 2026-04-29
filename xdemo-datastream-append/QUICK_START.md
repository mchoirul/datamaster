# Quick Start Guide - GCP Datastream Write - Append Demo

## Overview
This is a complete, ready-to-run tutorial on Datastream append mode with bronze-to-silver transformation.

It highlights two major architectural patterns:
1. **Hard CDC**: Physical deletions (`DELETE FROM`) captured natively by Datastream.
2. **Soft CDC**: Logical deletions (`UPDATE is_deleted=TRUE`) via payload.

It also highlights two major processing tools:
1. **Standard SQL MERGE**
2. **Google Cloud Dataform**



## How to Use This Guide

1. **If you already have Cloud SQL and Datastream set up:**
   Skip the setup! Jump straight to **Phase 3: Bronze to Silver Transformation** or examine the SQL scripts (`demo/hard_bronze_to_silver_merge.sql`, `demo/soft_bronze_to_silver_merge.sql`) and the `dataform/` directory to learn how to merge Bronze/Raw data into Silver.
2. **If you do not have a source database set up:**
   Start from the **Preparation Checklist** below to provision your Cloud SQL database and Datastream configuration.
3. **If you are new to Datastream and CDC merge operations:**
   Follow this entire guide step-by-step from the beginning to learn from scratch!

---

## Preparation Checklist

### Step 0: Service Account Setup
```bash
cd YOUR_WORKSPACE/demo-datastream-append/setup

# Activate service account
./00_activate_service_account.sh

# Verify permissions
./00_verify_permissions.sh
```

**If permissions are missing**, the script will show exact commands to grant them. Run those commands, then re-verify.

---

### Step 1: Python Environment
```bash
./00_setup_python_env.sh
```

---

### Step 2: Cloud SQL
```bash
./01_create_cloudsql.sh
```

**IMPORTANT**: Save the Public IP shown at the end!

---

### Step 3: Database Setup
```bash
# Connect to Cloud SQL
gcloud sql connect YOUR_INSTANCE_NAME --user=postgres --project=YOUR_PROJECT_ID

# In psql prompt, run:
\i YOUR_WORKSPACE/demo-datastream-append/setup/02_setup_database.sql

# Exit psql
\q
```

---

### Step 4: BigQuery Dataset
```bash
./03_create_bq_dataset.sh
```

---

### Step 5: Datastream Configuration
```bash
./04_create_datastream.sh
```

Wait for initial sync to complete (script will show how to check).

---

## Execution Steps

### Phase 1: Initial State Validation

```bash
# PostgreSQL
gcloud sql connect YOUR_INSTANCE_NAME --user=postgres --project=YOUR_PROJECT_ID
SELECT COUNT(*) FROM customers;
\q

# BigQuery bronze
bq query --use_legacy_sql=false \
  "SELECT COUNT(*) FROM \`YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze\`"
```

---

### Phase 2: CDC Streaming Execution

**Step 1: Activate Python venv**
```bash
source YOUR_VENV_PATH/bin/activate
```

**Step 2: Update Cloud SQL IP in scripts**
```bash
cd YOUR_WORKSPACE/demo-datastream-append/demo
nano simulate_cdc.py
nano simulate_soft_cdc.py
# Replace YOUR_CLOUDSQL_PUBLIC_IP with actual IP in both scripts
```

**Step 3: Run simulation**
```bash
python3 simulate_cdc.py
python3 simulate_soft_cdc.py
```

**Step 4: Wait for replication**
```bash
cd ../utils
./check_datastream_status.sh
```

**Step 5: Examine bronze**
```bash
cd ../demo
bq query --use_legacy_sql=false < check_bronze_data.sql
```

**Educational Note**: Bronze retains ALL events—providing a complete audit trail. However, querying this raw structure for the current state requires complex logic.

---

### Phase 3: Bronze to Silver Transformation

**Step 1: Understand the Challenge**
- The Bronze layer holds all raw CDC history events.
- PostgreSQL holds the active current state.
- **Problem**: We need an efficient way to extract the current state from the raw Bronze history log without losing data.

**Step 2: Review Transformation Logic**
*Option A: Standard SQL*
```bash
cat hard_bronze_to_silver_merge.sql
cat soft_bronze_to_silver_merge.sql
```
*Option B: Dataform (Recommended for production)*
```bash
cat ../dataform/definitions/customer_silver.sqlx
cat ../dataform/definitions/customer_silver_soft.sqlx
```
Explain: incremental processing (with 20-minute lookback window), deduplication, three-way MERGE (or pre_operations DELETE)

**Step 3: Execute Transformation**
*Option A: Standard SQL*
```bash
python3 ../run_sql_merge.py
# Or: bq query --use_legacy_sql=false < hard_bronze_to_silver_merge.sql
```
*Option B: Dataform*
```bash
cd ../dataform
npx @dataform/cli run
cd ../demo
```

**Step 4: Validate Output**
```bash
python3 ../run_validation_python.py
# Or: bq query < hard_validation_queries.sql
```
*(If using Dataform, run assertions: `npx @dataform/cli run --tags assertion`)*

**Key Concepts**:
- The Silver layer perfectly reflects the current state (equivalent to Datastream native Merge Mode).
- The Bronze layer securely preserves full history (native Append Mode advantage).
- This structure provides the best of both worlds.

**Step 5: Production Automation**
```bash
./create_scheduled_query.sh
```

---

## Teardown

### Cleanup
```bash
cd YOUR_WORKSPACE/demo-datastream-append/cleanup
./cleanup_all.sh
deactivate  # Exit Python venv
```

---

## Troubleshooting

### Permission errors
```bash
./setup/00_verify_permissions.sh
# Follow the commands shown
```

### Datastream not connecting
```bash
# Check Cloud SQL IP and authorized networks
gcloud sql instances describe YOUR_INSTANCE_NAME \
  --format="value(ipAddresses[0].ipAddress,settings.ipConfiguration.authorizedNetworks)"
```

### Python script fails
```bash
# Verify venv
echo $VIRTUAL_ENV  # Should show path to your venv

# Check dependencies
pip list | grep -E "(psycopg2|Faker)"

# Verify Cloud SQL IP in script
grep "host" demo/simulate_cdc.py
```

---

## Key Files

**Setup**:
- `setup/00_activate_service_account.sh` - Auth setup
- `setup/00_verify_permissions.sh` - Permission check
- `setup/01_create_cloudsql.sh` - Cloud SQL creation
- `setup/02_setup_database.sql` - Database + 50 customers
- `setup/03_create_bq_dataset.sh` - BigQuery dataset
- `setup/04_create_datastream.sh` - Datastream configuration

**Tutorial**:
- `demo/simulate_cdc.py` - Generate Hard CDC events
- `demo/simulate_soft_cdc.py` - Generate Soft CDC events
- `demo/check_bronze_data.sql` - Examine bronze layer
- `demo/hard_bronze_to_silver_merge.sql` - ⭐ Standard SQL Hard Merge
- `demo/soft_bronze_to_silver_merge.sql` - ⭐ Standard SQL Soft Merge
- `demo/hard_validation_queries.sql` - Validate Hard CDC
- `demo/soft_validation_queries.sql` - Validate Soft CDC
- `demo/create_scheduled_query.sh` - Production setup

**Dataform**:
- `dataform/definitions/customer_silver.sqlx` - ⭐ Dataform Hard Merge
- `dataform/definitions/customer_silver_soft.sqlx` - ⭐ Dataform Soft Merge

**Utilities**:
- `utils/check_datastream_status.sh` - Wait for replication
- `cleanup/cleanup_all.sh` - Delete all resources

---

## Expected Results

| Metric | Value |
|--------|-------|
| Initial customers (PostgreSQL) | 50 |
| CDC operations simulated | 50 (25 INSERT + 10 UPDATE + 15 DELETE) |
| Final customers (PostgreSQL) | ~60 |
| Bronze total events | ~100 |
| Silver current customers | ~60 |
| Validation | ✅ MATCH |

---

## Cost Estimate

- **Cloud SQL**: ~$0.10/hour
- **Datastream**: ~$0.04/GB
- **BigQuery**: Minimal (storage + queries)

**Total for 2-hour tutorial**: $2-5

**Minimize costs**: Run `cleanup/cleanup_all.sh` immediately after tutorial!

---

## Support

For issues:
1. Check troubleshooting section above
2. Review `00_verify_permissions.sh` output
3. Verify service account key exists: `YOUR_WORKSPACE/YOUR_KEY_FILE.json`
