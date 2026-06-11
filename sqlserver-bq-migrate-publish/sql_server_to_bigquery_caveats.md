# Exhaustive SQL Server to BigQuery Migration Guide

> Cross-referenced against official Google Cloud documentation as of June 2026.

---

## 1. Data Type Mapping Reference

When migrating from Microsoft SQL Server to Google Cloud BigQuery, you must account for data type conversions at two distinct levels:
1. **Query & DDL Translation (GoogleSQL Dialect)**: Standard SQL mappings used by the SQL Translator when converting schemas, views, and stored procedures.
2. **Data Transfer Service (DTS) Schema Ingestion**: The default mappings automatically applied when using the official BigQuery Data Transfer Service connector.

For the authoritative Google Cloud schema ingestion reference, see the official [BigQuery SQL Server Data Transfer Service Type Mapping Guide](https://docs.cloud.google.com/bigquery/docs/sqlserver-transfer#data_type_mapping).

### Data Type Mapping Table

| SQL Server Type | Query Translator Type (GoogleSQL) | DTS Connector Ingestion Type | Migration Notes & Caveats |
| :--- | :--- | :--- | :--- |
| `TINYINT` | `INT64` | `INTEGER` | Widens from 1-byte unsigned (0–255) to 8-byte signed. No data loss. (`INTEGER` is a query-level alias for `INT64` in BigQuery). |
| `SMALLINT` | `INT64` | `INTEGER` | Widens from 2-byte signed to 8-byte signed. No data loss. |
| `INT` | `INT64` | `INTEGER` | Widens from 4-byte signed to 8-byte signed. No data loss. |
| `BIGINT` | `INT64` | `BIGNUMERIC` | Dialect translation maps directly to `INT64`. DTS connector uses `BIGNUMERIC` by default to prevent overflow. |
| `BIT` | `BOOL` | `BOOLEAN` | Boolean type (`BOOLEAN` is an alias for `BOOL`). **Caveat:** `BOOL` does not implicitly cast to/from integers; `WHERE bit_col = 1` must be refactored to `WHERE bool_col = TRUE`. |
| `DECIMAL(p,s)` / `NUMERIC(p,s)` | `NUMERIC(p,s)` or `BIGNUMERIC(p,s)` | `BIGNUMERIC` (for `DECIMAL`) / `NUMERIC` (for `NUMERIC`) | `NUMERIC` supports precision ≤ 38, scale ≤ 9. `BIGNUMERIC` supports precision ≤ 76, scale ≤ 38. `DECIMAL` is a dialect alias for `NUMERIC` in BigQuery. |
| `MONEY` | `NUMERIC(19,4)` | `BIGNUMERIC` | Maps to high-precision decimal. |
| `SMALLMONEY` | `NUMERIC(10,4)` | `BIGNUMERIC` | Maps to high-precision decimal. |
| `FLOAT` / `REAL` | `FLOAT64` | `FLOAT` | Widens to double-precision `FLOAT64` (`FLOAT` is an alias for `FLOAT64` in BigQuery). Minor rounding differences possible. |
| `DATE` | `DATE` | `DATE` | Maps 1:1. Range: 0001-01-01 to 9999-12-31. |
| `TIME` | `TIME` | `TIME` | Maps 1:1. Microsecond precision in BigQuery vs. 100-nanosecond in SQL Server. |
| `DATETIME` | `DATETIME` | `TIMESTAMP` (*`DATETIME` after March 16, 2027*) | SQL Server is timezone-independent. DTS historically loaded as `TIMESTAMP` in UTC, but is being updated to load as `DATETIME` on March 16, 2027 to align with query semantics. ([Ref](https://cloud.google.com/bigquery/docs/transfer-changes#Mar16-sqlserver)) |
| `DATETIME2` | `DATETIME` | `TIMESTAMP` (*`DATETIME` after March 16, 2027*) | BigQuery `DATETIME` has microsecond precision. Sub-microsecond (100ns) data from `DATETIME2(7)` will be truncated. |
| `SMALLDATETIME` | `DATETIME` | `TIMESTAMP` (*`DATETIME` after March 16, 2027*) | Minute precision widens to microsecond precision. No data loss. |
| `DATETIMEOFFSET` | `TIMESTAMP` | `TIMESTAMP` | Stored as UTC. Original offset timezone indicator is **not preserved** — only UTC-normalized point in time. |
| `CHAR(n)` / `NCHAR(n)` | `STRING` | `STRING` | Fixed-length padding is not preserved in BigQuery's variable-length UTF-8 `STRING`. |
| `VARCHAR(n)` / `NVARCHAR(n)` | `STRING` | `STRING` | BigQuery does not enforce `(n)` length limits at the schema level unless parameterized. |
| `VARCHAR(MAX)` / `NVARCHAR(MAX)` | `STRING` | `STRING` | Maps directly. Max `STRING` size in BigQuery is 10 MB. |
| `TEXT` / `NTEXT` | `STRING` | `STRING` | Deprecated SQL Server types map to standard `STRING`. |
| `BINARY(n)` / `VARBINARY(n)` | `BYTES` | `BYTES` | Fixed and variable-length binary data maps to variable-length `BYTES`. |
| `VARBINARY(MAX)` / `IMAGE` | `BYTES` | `BYTES` | Deprecated SQL Server `IMAGE` maps to `BYTES`. |
| `GEOGRAPHY` / `GEOMETRY` | `GEOGRAPHY` | `STRING` | DTS loads spatial objects as WKT/WKB `STRING` representation. For GIS queries, convert using GoogleSQL `ST_GEOGFROMTEXT()` or `ST_GEOGFROMWKB()`. |
| `HIERARCHYID` | `STRING` | `BYTES` | DTS loads raw byte path. Dialect query translation parses hierarchies using `STRING` paths. |
| `ROWVERSION` | `BYTES` | `BYTES` | Stored as raw sequence bytes. |
| `SQL_VARIANT` | `STRING` or `JSON` | `BYTES` | Custom serialization needed for query translation; DTS loads raw bytes. |
| `UNIQUEIDENTIFIER` | `STRING` | `STRING` | Stored as canonical string representation. Generate new values via `GENERATE_UUID()`. |
| `XML` | `STRING` | `STRING` | No native XML type in BigQuery. Store as `STRING` and query via Javascript UDFs or preprocess during ETL. |
| `JSON` | `JSON` | `STRING` | BigQuery native `JSON` type used for semi-structured querying. Note: `JSON` type in DTS ingestion is currently supported for Azure sources. |
| `VECTOR` | `STRING` | `STRING` | Vector type only supported in Azure sources by DTS connector. |

> [!WARNING]
> **Data Loss Prevention:** Some migration tools (e.g., BigQuery Data Transfer Service) may map numeric types **without** explicitly defined precision/scale to `STRING` to prevent silent truncation. Always verify the schema assessment from your migration tool.

---

## 2. T-SQL to GoogleSQL Function Mapping

### 2.1 Date & Time Functions

| SQL Server (T-SQL) | BigQuery (GoogleSQL) | Caveat |
| :--- | :--- | :--- |
| `GETDATE()` | `CURRENT_DATETIME()` | Returns local time (timezone-independent `DATETIME`). Use `CURRENT_TIMESTAMP()` for UTC `TIMESTAMP`. |
| `GETUTCDATE()` | `CURRENT_TIMESTAMP()` | Returns UTC as `TIMESTAMP`. |
| `SYSDATETIME()` | `CURRENT_DATETIME()` | Higher precision in SQL Server (100ns) vs. BigQuery (microseconds). |
| `DATEADD(day, 1, @date)` | `DATE_ADD(@date, INTERVAL 1 DAY)` | GoogleSQL uses `INTERVAL` keyword. Part names are the same (`YEAR`, `MONTH`, `DAY`, `HOUR`, `MINUTE`, `SECOND`). ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/date_functions#date_add)) |
| `DATEDIFF(day, @start, @end)` | `DATE_DIFF(@end, @start, DAY)` | **CRITICAL:** Parameter order is **swapped** — BigQuery takes `(end, start, part)` vs. SQL Server `(part, start, end)`. Also, BigQuery counts **boundary crossings**, not elapsed time (e.g., Dec 31 to Jan 1 = 1 `YEAR`). ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/date_functions#date_diff)) |
| `DATEPART(year, @date)` | `EXTRACT(YEAR FROM @date)` | Standard SQL `EXTRACT()` syntax. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/date_functions#extract)) |
| `DATENAME(month, @date)` | `FORMAT_DATE('%B', @date)` | `%B` returns full month name (e.g., `January`). |
| `EOMONTH(@date)` | `LAST_DAY(@date, MONTH)` | ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/date_functions#last_day)) |
| `ISDATE(@str)` | `SAFE.PARSE_DATE(fmt, @str) IS NOT NULL` | `SAFE.` prefix returns `NULL` on parse failure instead of an error. |
| `CONVERT(VARCHAR, @date, 103)` | `FORMAT_DATE('%d/%m/%Y', @date)` | **No style codes.** BigQuery uses explicit format strings (`%Y`, `%m`, `%d`, etc.). ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/date_functions#format_date)) |
| `FORMAT(@ts, 'yyyy-MM-dd')` | `FORMAT_TIMESTAMP('%Y-%m-%d', @ts)` | Different format element syntax: `yyyy` → `%Y`, `MM` → `%m`, `dd` → `%d`. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/timestamp_functions#format_timestamp)) |
| `AT TIME ZONE 'Eastern Standard Time'` | `DATETIME(ts, 'America/New_York')` | **CRITICAL:** BigQuery uses IANA timezone names, not Windows registry names. |

### 2.2 String Functions

| SQL Server (T-SQL) | BigQuery (GoogleSQL) | Caveat |
| :--- | :--- | :--- |
| `'A' + 'B'` (concatenation) | `'A' \|\| 'B'` or `CONCAT('A','B')` | **CRITICAL:** `+` is strictly arithmetic in BigQuery. Using it on strings throws an error. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/string_functions#concat)) |
| `LEN(@str)` | `LENGTH(@str)` | `LEN` excludes trailing spaces; `LENGTH` counts them. Use `LENGTH(RTRIM(@str))` for exact parity. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/string_functions#length)) |
| `CHARINDEX('x', @str)` | `STRPOS(@str, 'x')` | **Parameter order is swapped.** SQL Server: `(substring, string)`. BigQuery: `(string, substring)`. Returns 0 if not found. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/string_functions#strpos)) |
| `SUBSTRING(@str, 1, 5)` | `SUBSTR(@str, 1, 5)` | Functionally equivalent. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/string_functions#substr)) |
| `REPLACE(@str, 'a', 'b')` | `REPLACE(@str, 'a', 'b')` | Identical syntax. |
| `UPPER(@str)` / `LOWER(@str)` | `UPPER(@str)` / `LOWER(@str)` | Identical syntax. |
| `LTRIM(@str)` / `RTRIM(@str)` | `LTRIM(@str)` / `RTRIM(@str)` | Identical syntax. |
| `TRIM(@str)` | `TRIM(@str)` | Identical syntax. |
| `LEFT(@str, n)` | `LEFT(@str, n)` | Identical syntax. |
| `RIGHT(@str, n)` | `RIGHT(@str, n)` | Identical syntax. |
| `STUFF(@str, start, len, new)` | `CONCAT(SUBSTR(@str,1,start-1), new, SUBSTR(@str,start+len))` | No direct equivalent. Must compose with `SUBSTR` + `CONCAT`. |
| `PATINDEX('%pat%', @str)` | Use `REGEXP_CONTAINS(@str, r'pat')` | No direct equivalent. Use regex functions. |
| `STRING_AGG(col, ',')` | `STRING_AGG(col, ',')` | Identical syntax. Add `ORDER BY` inside the function for deterministic results. |

### 2.3 Conversion & Casting

| SQL Server (T-SQL) | BigQuery (GoogleSQL) | Caveat |
| :--- | :--- | :--- |
| `CAST(x AS INT)` | `CAST(x AS INT64)` | Must use BigQuery type names (`INT64`, not `INT`). ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/conversion_functions#cast)) |
| `CONVERT(type, x)` | `CAST(x AS type)` | `CONVERT` does not exist in BigQuery. Use `CAST`. |
| `CONVERT(type, x, style)` | `PARSE_DATE` / `FORMAT_DATE` | Style-code conversions require explicit format strings. |
| `TRY_CAST(x AS INT)` | `SAFE_CAST(x AS INT64)` | Returns `NULL` on failure instead of an error. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/conversion_functions#safe_casting)) |
| `TRY_CONVERT(type, x)` | `SAFE_CAST(x AS type)` | Same as above. |
| `PARSE(@str AS DATE)` | `PARSE_DATE(fmt, @str)` | Explicit format string required. |

### 2.4 NULL Handling & Conditional

| SQL Server (T-SQL) | BigQuery (GoogleSQL) | Caveat |
| :--- | :--- | :--- |
| `ISNULL(@val, 'default')` | `IFNULL(@val, 'default')` | `IFNULL` takes exactly 2 args. Use `COALESCE` for multiple. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/conditional_expressions#ifnull)) |
| `COALESCE(a, b, c)` | `COALESCE(a, b, c)` | Identical syntax. |
| `NULLIF(a, b)` | `NULLIF(a, b)` | Identical syntax. |
| `IIF(cond, a, b)` | `IF(cond, a, b)` | Different function name. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/conditional_expressions#if)) |
| `CASE WHEN ... END` | `CASE WHEN ... END` | Identical syntax. |

### 2.5 Aggregate Functions

| SQL Server (T-SQL) | BigQuery (GoogleSQL) | Caveat |
| :--- | :--- | :--- |
| `COUNT(*)`, `SUM()`, `AVG()`, `MIN()`, `MAX()` | Same | Identical syntax. |
| `COUNT_BIG(*)` | `COUNT(*)` | BigQuery `COUNT` always returns `INT64`. No separate `COUNT_BIG`. |
| `STDEV()` / `STDEVP()` | `STDDEV()` / `STDDEV_POP()` | Different function names. `STDDEV()` = sample std dev. |
| `VAR()` / `VARP()` | `VARIANCE()` / `VARIANCE_POP()` | Different function names. |

### 2.6 Window Functions

| SQL Server (T-SQL) | BigQuery (GoogleSQL) | Caveat |
| :--- | :--- | :--- |
| `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()` | Same | Identical syntax. |
| `NTILE(n)` | `NTILE(n)` | Identical syntax. |
| `LEAD()` / `LAG()` | `LEAD()` / `LAG()` | Identical syntax. |
| `FIRST_VALUE()` / `LAST_VALUE()` | `FIRST_VALUE()` / `LAST_VALUE()` | **Caveat:** `LAST_VALUE()` requires explicit `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` in both systems for correct behavior, but this is more commonly forgotten in BigQuery. |

---

## 3. DML & Procedural Language Caveats

### 3.1 MERGE Statement
*   BigQuery supports `MERGE` with `WHEN MATCHED`, `WHEN NOT MATCHED`, and `WHEN NOT MATCHED BY SOURCE`. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/dml-syntax#merge_statement))
*   **Key Caveat:** BigQuery enforces that each target row can match **at most one source row**. If multiple source rows match a single target row, BigQuery throws: `UPDATE/MERGE must match at most one source row for each target row`.
*   SQL Server allows multiple source matches by default (last write wins).

### 3.2 Temporary Tables
*   SQL Server: `CREATE TABLE #temp (...)` or `SELECT INTO #temp`
*   BigQuery: **No session-scoped temp tables in the same way.** Options:
    *   `CREATE TEMP TABLE temp_name (...)` — scoped to the current script/session.
    *   CTEs (`WITH temp AS (...)`) — for query-scoped intermediate results.

### 3.3 Stored Procedures & Functions
*   SQL Server: `CREATE PROCEDURE` / `CREATE FUNCTION`
*   BigQuery: `CREATE PROCEDURE` / `CREATE FUNCTION` are supported but with restrictions. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/procedural-language))
    *   **No cursors.** Use `FOR...IN` loops over query results instead.
    *   **No triggers.** Must be handled in ETL/application layer.
    *   **No `OUTPUT` parameters** on procedures. Use `OUT` or `INOUT` parameters instead.
    *   **`EXECUTE IMMEDIATE`** replaces `sp_executesql` / `EXEC(@sql)`. Supports `USING` clause for parameterization. **Cannot be nested** (i.e., `EXECUTE IMMEDIATE` inside another `EXECUTE IMMEDIATE` is not allowed). ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/procedural-language#execute_immediate))

### 3.4 Error Handling
*   SQL Server: `TRY...CATCH`, `@@ERROR`, `RAISERROR`, `THROW`
*   BigQuery: `BEGIN...EXCEPTION WHEN ERROR THEN...END`. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/procedural-language#exception))
    *   Use `@@error.message`, `@@error.statement_text` to inspect the error.
    *   No equivalent of `RAISERROR` with severity levels.

---

## 4. Architecture & DDL Caveats

### 4.1 Indexing → Partitioning & Clustering

| Concept | SQL Server | BigQuery |
| :--- | :--- | :--- |
| **Primary optimization** | Clustered + Non-Clustered B-Tree indexes | Partitioning + Clustering (no indexes) |
| **Partitioning** | Partition by any column, multiple partition schemes | **One column only**: `DATE`, `TIMESTAMP`, `DATETIME`, `DATE_TRUNC`, or integer range. ([Ref](https://cloud.google.com/bigquery/docs/partitioned-tables)) |
| **Clustering** | Clustered index (1 per table) | `CLUSTER BY` up to **4 columns**. Auto-maintained (no manual rebuild). ([Ref](https://cloud.google.com/bigquery/docs/clustered-tables)) |
| **Changing scheme** | `ALTER PARTITION` | Must **recreate the table**. Cannot alter partitioning/clustering in place. |
| **Index hints** | `WITH (INDEX(...))` | Not applicable. No indexes exist. |

### 4.2 Constraints

| Constraint | SQL Server | BigQuery |
| :--- | :--- | :--- |
| `PRIMARY KEY` | Enforced. Prevents duplicates. | Declared as `NOT ENFORCED`. Used by optimizer for join elimination only. Does **not** prevent duplicate rows. ([Ref](https://cloud.google.com/bigquery/docs/information-schema-table-constraints)) |
| `FOREIGN KEY` | Enforced. Prevents orphan rows. | Declared as `NOT ENFORCED`. Informational only. |
| `UNIQUE` | Enforced. | **Not supported** as a table constraint. Must be enforced in ETL. |
| `CHECK` | Enforced. | **Not supported.** Must be enforced in ETL/application layer. |
| `DEFAULT` | Column-level default values. | Supported in BigQuery DDL. ([Ref](https://cloud.google.com/bigquery/docs/default-values)) |
| `NOT NULL` | Enforced. | **Enforced** in BigQuery. This is one of the few enforced constraints. |

### 4.3 Identity / Auto-Number

| Feature | SQL Server | BigQuery |
| :--- | :--- | :--- |
| Auto-increment | `IDENTITY(1,1)` | No direct equivalent for streaming inserts. |
| UUID generation | `NEWID()` | `GENERATE_UUID()` — recommended for surrogate keys. |
| Sequential numbering | `IDENTITY` | `ROW_NUMBER() OVER()` at query/transform time. Not persisted automatically on insert. |
| Sequences | `CREATE SEQUENCE` | BigQuery supports `CREATE SEQUENCE` but behavior differs from OLTP workloads. |

### 4.4 Compute & Storage Model

| Aspect | SQL Server | BigQuery |
| :--- | :--- | :--- |
| Architecture | Row-based, coupled compute+storage | Columnar (Capacitor format), decoupled compute+storage |
| `SELECT *` cost | Same as selective query (row store) | **Expensive.** Scans all columns. Always select only needed columns. |
| Concurrency model | Row-level locking (OLTP) | Snapshot isolation (OLAP). No row-level locks. |
| Transactions | Full ACID with savepoints | Multi-statement transactions supported but with [limitations](https://cloud.google.com/bigquery/docs/reference/standard-sql/transactions). |
| Filegroups | Used for storage management | Not applicable. Storage is fully managed. |

---

## 5. Authoritative Reference Links

| Topic | URL |
| :--- | :--- |
| BigQuery Data Types | https://cloud.google.com/bigquery/docs/reference/standard-sql/data-types |
| Date Functions | https://cloud.google.com/bigquery/docs/reference/standard-sql/date_functions |
| String Functions | https://cloud.google.com/bigquery/docs/reference/standard-sql/string_functions |
| Conversion Functions | https://cloud.google.com/bigquery/docs/reference/standard-sql/conversion_functions |
| DML Syntax (MERGE, INSERT, UPDATE, DELETE) | https://cloud.google.com/bigquery/docs/reference/standard-sql/dml-syntax |
| Procedural Language (Stored Procs, EXECUTE IMMEDIATE) | https://cloud.google.com/bigquery/docs/reference/standard-sql/procedural-language |
| Partitioned Tables | https://cloud.google.com/bigquery/docs/partitioned-tables |
| Clustered Tables | https://cloud.google.com/bigquery/docs/clustered-tables |
| Table Constraints | https://cloud.google.com/bigquery/docs/information-schema-table-constraints |
| Migration Service | https://cloud.google.com/bigquery/docs/migration-intro |
| SQL Translation | https://cloud.google.com/bigquery/docs/migration/sql-translation |
| SQL Server Data Transfer Service Mapping | https://docs.cloud.google.com/bigquery/docs/sqlserver-transfer#data_type_mapping |

---

## 6. SQL Translation Service Setup & Permissions

To set up the BigQuery SQL Translation Service, the following project configuration and IAM roles are required:

### 6.1 Required API
*   **BigQuery Migration API** (`bigquerymigration.googleapis.com`) must be enabled.

### 6.2 IAM Roles & Permissions
*   **Recommended Role**: **`roles/bigquerymigration.editor`** (Migration Workflow Editor) is required to run translation workflows.
*   **Cloud Storage Access**: For batch translation, the executing account must also be granted the **`roles/storage.objectUser`** role on the GCS buckets used for input/output files.

> [!CAUTION]
> **Critical Permission Deprecation Warning**
> The permission **`bigquerymigration.translation.translate`** is deprecated and will stop working on **2026-09-08**.
> *   Do not use custom roles or legacy configurations relying on `bigquerymigration.translation.translate`.
> *   Ensure all users and automated pipelines migrate to using **`bigquerymigration.workflows.create`** and **`bigquerymigration.workflows.get`** instead.

