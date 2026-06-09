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

## License

This project is provided as-is for educational and reference purposes.
