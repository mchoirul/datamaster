# GCP Datastream Write - Append Demo

## Overview
A comprehensive tutorial showing an end-to-end Change Data Capture (CDC) pipeline.

**This tutorial highlights two core architectural approaches for source systems:**
1. **Hard CDC (Native Delete/Update)**: The source system performs standard `UPDATE`s (overriding data) and `DELETE`s (physically removing rows). Datastream captures these using native `change_type` metadata.
2. **Soft CDC (Payload-based Delete/Update)**: The source system retains all records and uses a label/status (e.g., `is_deleted = TRUE` or `status = 'inactive'`) to mark deletions. Datastream captures these as standard `UPDATE`s, requiring payload inspection to determine state.

**The tutorial also highlights two enterprise tools for the Bronze-to-Silver Merge:**
1. **Standard SQL MERGE**: Using BigQuery Scheduled Queries to perform idempotent upserts.
2. **Google Cloud Dataform**: Using Dataform's declarative `.sqlx` definitions with `incremental` and `pre_operations` to manage state dynamically.



## How to Use This Repository

Depending on your current environment and learning goals, choose your starting point:

1. **If you already have Cloud SQL and Datastream set up:**
   Jump straight into the transformation logic! Examine the Standard SQL merge scripts (`demo/hard_bronze_to_silver_merge.sql` and `demo/soft_bronze_to_silver_merge.sql`) and the `dataform/` directory to see exactly how to perform the merge from Bronze/Raw append-only logs into clean Silver tables.
2. **If you have GCP but no source database set up:**
   Start from the `setup/` folder (e.g., `setup/01_create_cloudsql.sh` and `setup/02_setup_database.sql`) to provision the database and Datastream infrastructure before running the merges.
3. **If you are new to Datastream and CDC merge operations:**
   Want to learn everything from scratch? Follow the step-by-step instructions in the `QUICK_START.md` guide for a complete end-to-end tutorial.

---

## Prerequisites

- **GCP Project**: `YOUR_PROJECT_ID`
- **Service Account**: `YOUR_SERVICE_ACCOUNT_EMAIL`
- **Key File**: `YOUR_WORKSPACE/YOUR_KEY_FILE.json`
- **Python venv**: `YOUR_VENV_PATH`
- **Tools**: gcloud CLI, bq CLI, Python 3.8+

---

## Architecture

```
PostgreSQL (Cloud SQL)     Datastream          BigQuery
┌─────────────────┐       ┌─────────┐       ┌────────────────────────┐
│  customers      │──CDC─→│ Stream  │──────→│ YOUR_DATASET_ID        │
│  (Hard CDC)     │       │ (append)│       │  - public_customer_bronze (Hard)
│                 │       │         │       │  - public_soft_customer_bronze (Soft)
│  soft_customers │       │         │       ├────────────────────────┤
│  (Soft CDC)     │       └─────────┘       │  - customer_silver     │
└─────────────────┘                         │  - customer_silver_soft│
                                             └────────────────────────┘
                                                       │
                                                       │ SQL MERGE / Dataform
                                                       ↓
```

---

## Tutorial Structure

### Phase 1: Infrastructure Setup
- Cloud SQL PostgreSQL with CDC enabled
- BigQuery dataset
- 50 initial customer records

### Phase 2: CDC Streaming
- Configure Datastream (append mode)
- Simulate INSERT/UPDATE/DELETE operations
- Watch data flow to bronze table
- Examine append-only CDC structure

### Phase 3: Bronze to Silver Transformation
- Incremental MERGE transformation (Standard SQL or Dataform)
- Bronze → Silver (current state)
- Validation and comparison
- Production scheduling

---

## Quick Start

### Infrastructure Setup

```bash
cd YOUR_WORKSPACE/demo-datastream-append/setup

# 0a. Activate service account
./00_activate_service_account.sh

# 0b. Verify permissions
./00_verify_permissions.sh
# If permissions missing, script will show commands to grant them

# 1. Setup Python environment
./00_setup_python_env.sh

# 2. Create Cloud SQL
./01_create_cloudsql.sh

# 3. Setup database
# Get Cloud SQL IP from previous step output
gcloud sql connect YOUR_INSTANCE_NAME --user=postgres --project=YOUR_PROJECT_ID
\i 02_setup_database.sql
\q

# 4. Create BigQuery dataset
./03_create_bq_dataset.sh

# 5. Create Datastream
./04_create_datastream.sh
```

---

## Execution Steps

### Phase 1: Initial State Validation

```bash
# Check source PostgreSQL
gcloud sql connect YOUR_INSTANCE_NAME --user=postgres --project=YOUR_PROJECT_ID
SELECT COUNT(*) FROM customers;  -- Should show 50
\q

# Check bronze BigQuery table
bq query --use_legacy_sql=false \
  "SELECT COUNT(*) FROM \`YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze\`"
```

---

### Phase 2: CDC Streaming Execution

**Step 1: Activate Python environment**
```bash
source YOUR_VENV_PATH/bin/activate
```

**Step 2: Update Cloud SQL IP in simulation scripts**
```bash
cd demo
# Edit simulate_cdc.py (Hard CDC) and simulate_soft_cdc.py (Soft CDC)
nano simulate_cdc.py 
# Replace YOUR_CLOUDSQL_PUBLIC_IP with actual IP
```

**Step 3: Run CDC simulations**
```bash
python3 simulate_cdc.py
python3 simulate_soft_cdc.py
# Both scripts generate Inserts, Updates, and Deletes (Hard vs Soft)
```

**Explanation:**
- We simulate real-world application behavior for both Hard and Soft architectural patterns.
- Datastream captures every physical deletion as a `DELETE` metadata event, and every soft deletion as an `UPDATE` payload event.

**Step 4: Wait for replication**
```bash
cd ../utils
./check_datastream_status.sh
# Polls every 15 seconds until data arrives
```

**Step 5: Examine bronze layer**
```bash
cd ../demo
bq query --use_legacy_sql=false < check_bronze_data.sql
```

**Expected output:**
- Hard and Soft bronze tables populated with events.
- Change types: Native INSERT, UPDATE, DELETE vs Payload `is_deleted` flags.
- Full customer journey visible per record.

**Key Concepts:**
- **Immutable Audit Trail:** The Bronze layer captures ALL events.
- **State Changes:** Every physical state change is appended as a new row.
- **The Challenge:** Querying the current state reliably and efficiently from an append-only log requires structural transformation. Phase 3 solves this.

---

### Phase 3: Bronze to Silver Transformation

**Step 1: Understand the Challenge**

Currently, PostgreSQL holds exactly 60 active customers (the current state). However, the Bronze layer in BigQuery contains 100 CDC events encompassing all historical changes. Querying the Bronze layer directly for current state requires complex window functions every time.

**The Solution:** Transform the Bronze layer into a Silver layer once incrementally. This allows you to query a simple current-state table forever, replicating "Merge Mode" behavior while safely preserving the full history in Bronze.

**Step 2: Review the Transformation Logic**
*Option A: Standard SQL MERGE*
```bash
cat hard_bronze_to_silver_merge.sql
cat soft_bronze_to_silver_merge.sql
```

*Option B: Google Cloud Dataform (Recommended for production)*
```bash
cat ../dataform/definitions/customer_silver.sqlx
cat ../dataform/definitions/customer_silver_soft.sqlx
```

**Explain:**
1. Incremental processing (using a **20-minute lookback window** to catch late-arriving events).
2. Deduplication (`ROW_NUMBER` window function strictly selecting the latest micro-batch event).
3. Hard vs Soft Handling: Native `DELETE` metadata vs `is_deleted = TRUE` payload checking.
4. Explain how Dataform `pre_operations` is required because the `incremental` materialization native engine does not automatically handle physical deletions.

**Step 3: Execute the Transformation**

*Option A: Standard SQL MERGE*
```bash
python3 ../run_sql_merge.py
# Alternatively: bq query < hard_bronze_to_silver_merge.sql
```

*Option B: Dataform*
```bash
cd ../dataform
npx @dataform/cli run
cd ../demo
```

**Step 4: Validate Results**
```bash
python3 ../run_validation_python.py
# Validates both Hard and Soft datasets simultaneously
```
*(If using Dataform, run assertions via: `npx @dataform/cli run --tags assertion`)*

**Show:**
- Count comparison (100 events → 60 customers)
- Deleted customers (in bronze, not in silver)
- Updated customers (only latest version in silver)
- Silver structure (clean, current-state table)

**Validation Takeaways:**
- The Silver layer perfectly matches the source database's current state.
- This produces the exact same output as Datastream's native Merge Mode.
- The full historical audit trail remains securely preserved in the Bronze layer.

**Step 5: Production Automation**
```bash
./create_scheduled_query.sh
```

**Automation Concepts:**
- You can schedule the MERGE queries to run every 15-60 minutes.
- Incremental processing ensures cost-efficiency.
- Additional business logic can be injected cleanly inside the transformation stage.

---

## Cleanup

```bash
cd cleanup
./cleanup_all.sh
deactivate  # Exit Python venv
```

---

## Key Takeaways

### Architecture Patterns Displayed
1. **Hard CDC (Native `DELETE`)**: Ideal when the source system genuinely removes records and you must rely entirely on Datastream's binary `change_type` metadata. 
2. **Soft CDC (`is_deleted`)**: Ideal when the source system maintains physical rows but updates an active/inactive status column. The downstream Merge must inspect the data payload rather than Datastream's operational metadata.

### What We Demonstrated

1. **Append Mode = Full History**
   - Every CDC event is securely captured.
   - Complete audit trails are retained.
   - Time-travel queries are natively supported.

2. **Transformation = Clean Layer**
   - Implemented via a fully idempotent **20-minute lookback window** to prevent any data loss from Datastream latency.
   - Leveraged two enterprise tools: **Standard Scheduled SQL** and **Google Cloud Dataform**.

3. **Best of Both Worlds**
   - The final Silver tables flawlessly replicate what Datastream's "Merge Mode" would produce automatically.
   - ...but we kept the underlying historical Bronze tables indefinitely!

4. **Production Ready**
   - Scheduled automation
   - Incremental processing
   - Scalable pattern

### When to Use This Pattern

✅ **Use Append + Transform when:**
- Need audit trail and compliance
- Want to analyze change patterns
- Require custom business logic
- Have large tables (partition pruning matters)

❌ **Use Merge Mode directly when:**
- Only care about current state
- Don't need change history
- Want simplest setup
- Small tables

---

## Troubleshooting

### Permission Errors

If you encounter permission errors:
```bash
# Re-run permission check
./setup/00_verify_permissions.sh

# Grant missing permissions (script will show exact commands)
```

### Datastream Connection Errors

If Datastream cannot connect to Cloud SQL:
```bash
# Check authorized networks
gcloud sql instances describe YOUR_INSTANCE_NAME \
  --format="value(settings.ipConfiguration.authorizedNetworks)"

# Verify Cloud SQL IP
gcloud sql instances describe YOUR_INSTANCE_NAME \
  --format="value(ipAddresses[0].ipAddress)"
```

### Python Script Errors

If simulate_cdc.py fails to connect:
```bash
# Verify venv is activated
echo $VIRTUAL_ENV
# Should show: YOUR_VENV_PATH

# Verify dependencies installed
pip list | grep -E "(psycopg2|Faker|google)"

# Check Cloud SQL IP in script
grep "host" demo/simulate_cdc.py
```

---

## Files Structure

| Folder / Category | File | Purpose |
| ----------------- | ---- | ------- |
| **Root** | `README.md` | Main project documentation and overview. |
| | `QUICK_START.md` | Step-by-step end-to-end tutorial guide. |
| | `requirements.txt` | Python dependencies (psycopg2, google-cloud-bigquery, Faker). |
| | `run_sql_merge.py` | Python wrapper to dynamically execute standard SQL MERGE queries. |
| | `run_validation_python.py` | Python wrapper to run and display validation query results. |
| **`setup/`**<br>*(Infrastructure)* | `00_activate_service_account.sh` | Activates GCP service account authentication. |
| | `00_verify_permissions.sh` | Validates necessary GCP IAM roles before starting. |
| | `00_setup_python_env.sh` | Creates Python virtual environment for scripts. |
| | `01_create_cloudsql.sh` | Provisions the Cloud SQL PostgreSQL instance. |
| | `02_setup_database.sql` | Initializes database schema and base customer records. |
| | `03_create_bq_dataset.sh` | Creates BigQuery dataset for Bronze/Silver tables. |
| | `04_create_datastream.sh` | Configures unified Datastream stream (Hard & Soft CDC). |
| **`demo/`**<br>*(Execution)* | `simulate_cdc.py` | Generates Hard CDC mock events (Inserts/Updates/Deletes). |
| | `simulate_soft_cdc.py` | Generates Soft CDC mock events (Payload flag changes). |
| | `check_bronze_data.sql` | Queries raw BigQuery append-only log to view all events. |
| | `hard_bronze_to_silver_merge.sql` | Standard SQL MERGE script (Hard CDC pattern). |
| | `soft_bronze_to_silver_merge.sql` | Standard SQL MERGE script (Soft CDC pattern). |
| | `hard_validation_queries.sql` | Validates Hard CDC Silver state against historical Bronze. |
| | `soft_validation_queries.sql` | Validates Soft CDC Silver state against historical Bronze. |
| | `create_scheduled_query.sh` | Automates SQL merge pipelines via BQ Scheduled Queries. |
| **`dataform/`**<br>*(Dataform)* | `dataform.json` & `package.json` | Core Dataform configuration and dependencies. |
| | `definitions/*_bronze.sqlx` | Dataform source declarations representing Datastream tables. |
| | `definitions/customer_silver.sqlx` | Dataform incremental merge logic (Hard CDC). |
| | `definitions/customer_silver_soft.sqlx` | Dataform incremental merge logic (Soft CDC). |
| | `definitions/*_unique.sqlx` | Data Quality Assertions (Uniqueness). |
| | `definitions/*_no_deletes.sqlx` | Data Quality Assertions (Delete mapping validations). |
| **`utils/`** | `check_datastream_status.sh` | Polls BQ to verify Datastream replication completion. |
| **`cleanup/`** | `cleanup_all.sh` | Safely tears down all GCP resources to stop billing. |

## Support

For issues or questions about this tutorial:
1. Check the troubleshooting section above
2. Review error messages from `00_verify_permissions.sh`
3. Verify service account key file exists: `YOUR_WORKSPACE/YOUR_KEY_FILE.json`

---

## Cost Estimate

Running this tutorial will incur GCP costs:
- **Cloud SQL**: ~$0.10/hour (db-custom-2-7680)
- **Datastream**: ~$0.04/GB streamed
- **BigQuery**: Storage (minimal) + query processing

**Estimated total for tutorial**: $2-5 (if cleaned up after 1-2 hours)

**To minimize costs**: Run `cleanup/cleanup_all.sh` immediately after tutorial.
