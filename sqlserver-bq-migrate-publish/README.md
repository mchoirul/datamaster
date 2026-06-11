# SQL Server to BigQuery Migration Sample

A hands-on reference project demonstrating the key differences when migrating from **Microsoft SQL Server (T-SQL)** to **Google Cloud BigQuery (GoogleSQL)**.

> [!NOTE]
> **Scope of this Reference**: This guide, code examples, schemas, and configurations are strictly scoped for migrating workloads **from Microsoft SQL Server to Google Cloud BigQuery**. They demonstrate 1:1 dialect mappings and establish a secure environment specifically for SQL Server-to-BigQuery translators.

## What's Included

### Source T-SQL Scripts (Original SQL Server)
| File | Description |
| :--- | :--- |
| `original_schema.sql` | SQL Server DDL — tables, constraints, identity columns |
| `original_dml_and_sp.sql` | Stored procedures, MERGE, dynamic SQL, temp tables |
| `original_queries.sql` | Query patterns: date math, string ops, timezone conversion |

### Translated BigQuery (GoogleSQL) Scripts
| File | Description |
| :--- | :--- |
| `bigquery_translated_schema.sql` | BigQuery DDL with `NOT ENFORCED` keys, type mappings |
| `bigquery_translated_dml_and_sp.sql` | BigQuery procedures, MERGE, `EXECUTE IMMEDIATE` |
| `bigquery_translated_queries.sql` | GoogleSQL equivalents of all T-SQL query patterns |

### Migration Reference
| File | Description |
| :--- | :--- |
| `sql_server_to_bigquery_caveats.md` | **Exhaustive migration guide** — data type mappings, function translations, architecture caveats (partitioning, clustering, constraints, identity), verified against official Google Cloud documentation |

## Key Migration Caveats Covered

- **Data Types**: Full 1:1 mapping table (30+ types)
- **Functions**: Date/time, string, conversion, NULL handling, aggregates, window functions
- **Architecture**: Partitioning vs indexing, clustering, constraint enforcement, identity/auto-number alternatives
- **DML**: MERGE one-source-row rule, temp tables, error handling
- **Procedural**: `EXECUTE IMMEDIATE` vs `sp_executesql`, no cursors/triggers

## References

- [BigQuery Data Types](https://cloud.google.com/bigquery/docs/reference/standard-sql/data-types)
- [BigQuery DML Syntax](https://cloud.google.com/bigquery/docs/reference/standard-sql/dml-syntax)
- [BigQuery Procedural Language](https://cloud.google.com/bigquery/docs/reference/standard-sql/procedural-language)
- [BigQuery Partitioned Tables](https://cloud.google.com/bigquery/docs/partitioned-tables)
- [BigQuery Migration Service](https://cloud.google.com/bigquery/docs/migration-intro)

## Permission Configuration Procedure

Follow this comprehensive procedure to enable the required APIs and configure granular IAM permissions for the SQL Translation Service. For official Google Cloud reference, see the [BigQuery Interactive Translator Permissions & Roles Guide](https://docs.cloud.google.com/bigquery/docs/interactive-sql-translator#permissions_and_roles) and the [BigQuery Batch Translator Required Permissions Guide](https://docs.cloud.google.com/bigquery/docs/batch-sql-translator#required_permissions).

### 1. Enable Required APIs

Before configuring roles, ensure the necessary services are enabled in your Google Cloud project.

#### A. BigQuery Migration API
This API handles both interactive and batch SQL translation workflows.
*   **Service Name**: `bigquerymigration.googleapis.com`
*   *Note: For projects created after February 15, 2022, this is enabled automatically.*

---

#### Method 1: Using the Cloud Console
1. Go to the [APIs \u0026 Services Library](https://console.cloud.google.com/apis/library) in the Google Cloud Console.
2. Search for **BigQuery Migration API** and click **Enable**.

#### Method 2: Using the gcloud CLI
Run the following command in your terminal:
```bash
# Enable the BigQuery Migration API
gcloud services enable bigquerymigration.googleapis.com
```

---

### 2. Custom Role Configuration

Define a custom IAM role for SQL translation access.

> [!WARNING]
> The legacy permission `bigquerymigration.translation.translate` is deprecated and will stop working on **September 8, 2026** (verified from in-product deprecation warning in BigQuery Studio). This role is configured using the recommended replacement permissions `bigquerymigration.workflows.create` and `bigquerymigration.workflows.get`.

#### Custom Role: SQL Translation Operator
Grants permission to use interactive and batch SQL translation, including the Gemini-enhanced customize menu within the translator (gated by the same `bigquerymigration.workflows.*` permissions).

##### **YAML Definition (`sql_translation_operator.yaml`)**
```yaml
title: "SQL Translation Operator"
description: "Allows interactive and batch SQL translation, including the Gemini customize menu within the translator."
stage: "GA"
includedPermissions:
  - bigquerymigration.workflows.create
  - bigquerymigration.workflows.get
  - bigquerymigration.workflows.list
  - bigquerymigration.subtasks.get
  - bigquerymigration.subtasks.list
  - storage.objects.get
  - storage.objects.list
  - storage.objects.create
```

> [!NOTE]
> **Why Cloud Storage Permissions Are Included**:
> The `storage.objects.*` permissions are required so that the operator or translation pipeline can upload the migration input files (the raw SQL/T-SQL scripts to be translated) as well as any database schema metadata or name mapping files to Google Cloud Storage. It also allows the translation service to read these files and write back the generated GoogleSQL files.

##### **Creation Steps:**
*   **Via gcloud CLI**:
    ```bash
    gcloud iam roles create sql_translation_operator \
        --project=[YOUR_PROJECT_ID] \
        --file=sql_translation_operator.yaml
    ```
*   **Via Cloud Console**:
    1. Navigate to **IAM \u0026 Admin > Roles** in the Cloud Console.
    2. Click **+ Create Role**.
    3. Enter `SQL Translation Operator` for the title.
    4. Click **+ Add Permissions** and search for/add the permissions listed in the YAML above.
    5. Click **Create**.

---

### 3. Assigning the Role to Users

Once created, assign the role to developers as needed:

```bash
gcloud projects add-iam-policy-binding [YOUR_PROJECT_ID] \
    --member="user:developer@example.com" \
    --role="projects/[YOUR_PROJECT_ID]/roles/sql_translation_operator"
```

> [!NOTE]
> **Base BigQuery Access**: Users still require standard BigQuery Studio permissions (e.g., `roles/bigquery.user` or `roles/bigquery.metadataViewer`) to access the console, write, and execute queries in the BigQuery interface.

## Running the BigQuery SQL Translator (Interactive & Batch)

Follow these procedures to configure your runtime environment and translate your schema, queries, and scripts.

### 1. Interactive SQL Translation (Ad-hoc)
Interactive translation allows you to translate SQL Server queries on-the-fly directly inside the BigQuery Studio console. For role details, see the official [Interactive Translator Permissions and Roles Docs](https://docs.cloud.google.com/bigquery/docs/interactive-sql-translator#permissions_and_roles).

#### Setup & Execution:
1. **Open BigQuery Studio**: Navigate to the Google Cloud Console and select BigQuery.
2. **Enable Interactive Translation**:
   - In the SQL Editor tab, click **More > Query settings**.
   - Under **SQL translation**, check **Enable interactive translation**.
   - Select **Source dialect** as **Microsoft SQL Server**.
3. **Translate**:
   - Paste any T-SQL code from `original_queries.sql` or `original_dml_and_sp.sql` into the query editor.
   - The translator automatically translates the T-SQL query to GoogleSQL in real-time or highlights it with translation tooltips.

---

### 2. Batch SQL Translation (Bulk Processing)
Batch translation is designed to process hundreds of SQL files or full database schemas in a single bulk job. For setup details, see the official [Batch Translator Required Permissions Docs](https://docs.cloud.google.com/bigquery/docs/batch-sql-translator#required_permissions).

#### Environment Setup & Execution:
1. **Prepare Cloud Storage Buckets**:
   - Create an **Input GCS Bucket** (e.g., `gs://my-migration-input-bucket/`) and upload your SQL Server T-SQL files (input files) along with any database schema metadata, schema files, or object name mapping files.
   - Create an **Output GCS Bucket** (e.g., `gs://my-migration-output-bucket/`) where the translated GoogleSQL files will be written.
   - *Note: Cloud Storage permissions (`storage.objects.*`) are strictly required so that users can upload their input files and database metadata/schema files to Cloud Storage, and so that the translation service has read/write access to execute the translation and generate the output files.*
2. **Configure the Translation Job**:
   - In the Google Cloud Console, navigate to **BigQuery > SQL Translation**.
   - Click **+ Start Translation**.
   - Enter a translation configuration name.
   - Set the **Source dialect** to `SQL Server` and **Target dialect** to `GoogleSQL`.
   - Specify your input GCS path and output GCS path, then click **Create** to trigger the batch translation workflow.

---

## Migration Caveats & Key Architectural Considerations

While the BigQuery SQL Translation Service is highly accurate, automatic translators cannot resolve fundamental differences in platform architecture. Before running translation or deploying generated SQL, review [sql_server_to_bigquery_caveats.md](file:///home/choirul/antigrav/bigquerymigration/sqlserver-bq-migrate/sql_server_to_bigquery_caveats.md) for comprehensive mapping tables and workarounds.

### Key Considerations to Watch Out For:
*   **No Native Identity Columns**: BigQuery does not support auto-incrementing `IDENTITY` columns. Use sequences, `GENERATE_UUID()`, or handle surrogate keys during the ETL/ingestion pipeline.
*   **Unenforced Constraints**: Primary and foreign keys are created with `NOT ENFORCED` metadata. They are utilized strictly by the query optimizer and require upstream enforcement during your data pipeline phase.
*   **Datetime Precision & Timezones**: Be cautious with date conversions. SQL Server and BigQuery handle datetimes and fractional seconds differently (BigQuery supports microsecond precision).
*   **DML & MERGE Behavior**: BigQuery's `MERGE` is optimized for analytics and is subject to strict concurrency controls. Ensure your ingestion pipelines avoid parallel `MERGE` operations on the same table.
*   **Procedural Loops vs Set-Based Operations**: GoogleSQL supports loops and cursors, but they can be highly inefficient in analytical warehouses. Translate transactional T-SQL loops into set-based analytical queries where possible.

## License

This project is provided as-is for educational and reference purposes.