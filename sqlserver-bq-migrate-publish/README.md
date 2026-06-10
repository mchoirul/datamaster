# SQL Server to BigQuery Migration Sample

A hands-on reference project demonstrating the key differences when migrating from **Microsoft SQL Server (T-SQL)** to **Google Cloud BigQuery (GoogleSQL)**.

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

Follow this comprehensive procedure to enable the required APIs and configure granular IAM permissions for the SQL Translation Service.

### 1. Enable Required APIs

Before configuring roles, ensure the necessary services are enabled in your Google Cloud project.

#### A. BigQuery Migration API
This API handles both interactive and batch SQL translation workflows.
*   **Service Name**: `bigquerymigration.googleapis.com`
*   *Note: For projects created after February 15, 2022, this is enabled automatically.*

#### B. Cloud AI Companion API (Required for Role 2)
Required if you want to enable generative AI features, autocomplete, and Gemini chat assistance.
*   **Service Name**: `cloudaicompanion.googleapis.com`

---

#### Method 1: Using the Cloud Console
1. Go to the [APIs & Services Library](https://console.cloud.google.com/apis/library) in the Google Cloud Console.
2. Search for **BigQuery Migration API** and click **Enable**.
3. (Optional) Search for **Cloud AI Companion API** and click **Enable**.

#### Method 2: Using the gcloud CLI
Run the following commands in your terminal:
```bash
# Enable the BigQuery Migration API
gcloud services enable bigquerymigration.googleapis.com

# Enable the Cloud AI Companion API (for Gemini capabilities)
gcloud services enable cloudaicompanion.googleapis.com
```

---

### 2. Custom Role Configuration

To enforce strict security boundaries, define these two custom IAM roles. They separate deterministic translation from generative AI capabilities.

> [!WARNING]
> The legacy permission `bigquerymigration.translation.translate` is deprecated and will stop working on **September 8, 2026**. These roles are configured using the recommended replacement permissions `bigquerymigration.workflows.create` and `bigquerymigration.workflows.get`.

#### Custom Role 1: SQL Translation Operator (Deterministic & Batch, No Gemini)
Grants permission to use interactive and batch SQL translation. It restricts access to rules-based mappings and completely blocks generative AI/Gemini.

##### **YAML Definition (`sql_translation_operator.yaml`)**
```yaml
title: "SQL Translation Operator"
description: "Allows interactive and batch SQL translation using deterministic rules. Generative AI is disabled."
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

##### **Creation Steps:**
*   **Via gcloud CLI**:
    ```bash
    gcloud iam roles create sql_translation_operator \
        --project=[YOUR_PROJECT_ID] \
        --file=sql_translation_operator.yaml
    ```
*   **Via Cloud Console**:
    1. Navigate to **IAM & Admin > Roles** in the Cloud Console.
    2. Click **+ Create Role**.
    3. Enter `SQL Translation Operator` for the title.
    4. Click **+ Add Permissions** and search for/add the permissions listed in the YAML above.
    5. Click **Create**.

---

#### Custom Role 2: SQL Translation & AI Developer (Role 1 + Gemini)
Grants the core SQL translation permissions and adds full access to inline autocomplete, coding companion assistance, and Gemini Chat inside BigQuery Studio.

##### **YAML Definition (`sql_translation_ai_developer.yaml`)**
```yaml
title: "SQL Translation & AI Developer"
description: "Allows interactive and batch SQL translation, plus full Gemini AI coding assistance."
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
  - cloudaicompanion.entitlements.get
  - cloudaicompanion.instances.completeCode
  - cloudaicompanion.instances.generateCode
  - cloudaicompanion.instances.completeTask
  - cloudaicompanion.instances.generateText
  - cloudaicompanion.topics.create
  - cloudaicompanion.operations.get
```

##### **Creation Steps:**
*   **Via gcloud CLI**:
    ```bash
    gcloud iam roles create sql_translation_ai_developer \
        --project=[YOUR_PROJECT_ID] \
        --file=sql_translation_ai_developer.yaml
    ```
*   **Via Cloud Console**:
    1. Navigate to **IAM & Admin > Roles** in the Cloud Console.
    2. Click **+ Create Role**.
    3. Enter `SQL Translation & AI Developer` for the title.
    4. Click **+ Add Permissions** and search for/add the permissions listed in the YAML above.
    5. Click **Create**.

---

### 3. Assigning the Roles to Users

Once created, assign these roles to developers as appropriate:

```bash
# Assign SQL Translation Operator (Deterministic-only) to a developer
gcloud projects add-iam-policy-binding [YOUR_PROJECT_ID] \
    --member="user:developer-deterministic@example.com" \
    --role="projects/[YOUR_PROJECT_ID]/roles/sql_translation_operator"

# Assign SQL Translation & AI Developer (with Gemini) to an AI-assisted developer
gcloud projects add-iam-policy-binding [YOUR_PROJECT_ID] \
    --member="user:developer-ai@example.com" \
    --role="projects/[YOUR_PROJECT_ID]/roles/sql_translation_ai_developer"
```

> [!NOTE]
> **Base BigQuery Access**: Users still require standard BigQuery Studio permissions (e.g., `roles/bigquery.user` or `roles/bigquery.metadataViewer`) to access the console, write, and execute queries in the BigQuery interface.

## License

This project is provided as-is for educational and reference purposes.
