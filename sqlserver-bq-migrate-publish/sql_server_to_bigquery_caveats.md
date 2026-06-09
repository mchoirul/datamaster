# Exhaustive SQL Server to BigQuery Migration Guide

> Cross-referenced against official Google Cloud documentation as of June 2026.

---

## 1. Data Type Mapping Reference

BigQuery uses a simplified set of data types compared to SQL Server. All integer types collapse to `INT64`, all string types collapse to `STRING`, etc.

| SQL Server (T-SQL) Type | BigQuery (GoogleSQL) Type | Migration Notes & Caveats |
| :--- | :--- | :--- |
| `TINYINT` | `INT64` | Widens from 1-byte unsigned (0–255) to 8-byte signed. No data loss. |
| `SMALLINT` | `INT64` | Widens from 2-byte signed to 8-byte signed. No data loss. |
| `INT` | `INT64` | Widens from 4-byte signed to 8-byte signed. No data loss. |
| `BIGINT` | `INT64` | Maps 1:1 (both 8-byte signed). |
| `CHAR(n)`, `NCHAR(n)` | `STRING` | BigQuery `STRING` is variable-length UTF-8. Fixed-length padding is not preserved. |
| `VARCHAR(n)`, `NVARCHAR(n)` | `STRING` | BigQuery does **not** enforce `(n)` length limits at the schema level. |
| `VARCHAR(MAX)`, `NVARCHAR(MAX)` | `STRING` | Maps directly. Max `STRING` size in BigQuery is 10 MB. |
| `TEXT`, `NTEXT` | `STRING` | Deprecated in SQL Server; maps to `STRING`. |
| `DECIMAL(p,s)`, `NUMERIC(p,s)` | `NUMERIC(P,S)` or `BIGNUMERIC(P,S)` | `NUMERIC` supports max precision 29, scale 9. `BIGNUMERIC` supports max precision 76, scale 38. `DECIMAL` is an alias for `NUMERIC` in BigQuery. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/data-types#numeric_type)) |
| `MONEY` | `NUMERIC` | `MONEY` has 4 decimal places. Map to `NUMERIC(19,4)`. |
| `SMALLMONEY` | `NUMERIC` | Map to `NUMERIC(10,4)`. |
| `REAL` | `FLOAT64` | Widens from single-precision to double-precision. Minor rounding differences possible. |
| `FLOAT(n)` | `FLOAT64` | BigQuery only has double-precision `FLOAT64`. |
| `DATE` | `DATE` | Maps 1:1. Range: 0001-01-01 to 9999-12-31. |
| `TIME` | `TIME` | Maps 1:1. Microsecond precision in BigQuery vs. 100-nanosecond in SQL Server. |
| `DATETIME` | `DATETIME` | Both timezone-independent. BigQuery `DATETIME` has microsecond precision vs. ~3.33ms in SQL Server. |
| `DATETIME2(n)` | `DATETIME` | BigQuery `DATETIME` has microsecond (6-digit) precision. SQL Server `DATETIME2(7)` has 100-nanosecond precision — **sub-microsecond data will be truncated**. |
| `SMALLDATETIME` | `DATETIME` | Minute precision widens to microsecond precision. No data loss. |
| `DATETIMEOFFSET` | `TIMESTAMP` | `TIMESTAMP` in BigQuery is an absolute point in time stored in UTC. The original offset is **not preserved** — only the UTC-normalized value is stored. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/data-types#timestamp_type)) |
| `BINARY(n)`, `VARBINARY(n)` | `BYTES` | Variable-length binary data. |
| `VARBINARY(MAX)`, `IMAGE` | `BYTES` | `IMAGE` is deprecated in SQL Server. Maps to `BYTES`. |
| `BIT` | `BOOL` | **Caveat:** `BOOL` does not implicitly cast to/from integers. `WHERE bit_col = 1` must become `WHERE bool_col = TRUE`. |
| `UNIQUEIDENTIFIER` | `STRING` | Stored as a string representation. Generate new UUIDs with `GENERATE_UUID()`. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/functions-and-operators#generate_uuid)) |
| `XML` | `STRING` | BigQuery has no native XML type. Parse with UDFs or pre-process in ETL. |
| `SQL_VARIANT` | `STRING` or `JSON` | No equivalent. Serialize to `STRING` or use native `JSON` type. |
| `GEOGRAPHY` / `GEOMETRY` | `GEOGRAPHY` | BigQuery supports `GEOGRAPHY` (WGS84 spherical). SQL Server `GEOMETRY` (planar) must be reprojected. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/data-types#geography_type)) |
| `HIERARCHYID` | `STRING` | No native equivalent. Serialize the hierarchy path as a string. |
| `JSON` (SQL Server 2016+) | `JSON` | BigQuery has a native `JSON` type for semi-structured data. ([Ref](https://cloud.google.com/bigquery/docs/reference/standard-sql/data-types#json_type)) |

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
