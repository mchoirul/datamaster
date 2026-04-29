/*
Bronze to Silver Incremental MERGE Transformation (Hard CDC Pattern)
Purpose: Convert raw append-only CDC events into a clean, current-state Silver table.
Strategy: Incremental processing - only scans new Bronze events since the last Silver sync.
Result: Silver matches Datastream Merge Mode output, but you keep full history in Bronze.
*/

-- Step 1: Initialize Silver Table
-- Partitioned by sync time for cost efficiency, clustered by PK for query performance.
CREATE TABLE IF NOT EXISTS `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver` (
  customer_id INT64,
  name STRING,
  email STRING,
  status STRING,
  total_purchases NUMERIC,
  country STRING,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  _last_sync_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(_last_sync_timestamp)
CLUSTER BY customer_id;

-- Step 2: Incremental MERGE execution
MERGE `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver` AS target
USING (
  -- Subquery: Extract ONLY the absolute latest state of each changed record
  SELECT * EXCEPT(row_num)
  FROM (
    SELECT 
      customer_id,
      name,
      email,
      status,
      total_purchases,
      country,
      created_at,
      updated_at,
      TIMESTAMP_MILLIS(datastream_metadata.source_timestamp) as source_event_time,
      datastream_metadata.change_type,
      -- Deduplication: Assigns row_num = 1 to the most recent event per customer_id
      ROW_NUMBER() OVER (
        PARTITION BY customer_id 
        ORDER BY 
          datastream_metadata.source_timestamp DESC,
          datastream_metadata.change_sequence_number DESC
      ) as row_num
    FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze`
    WHERE 
      -- Incremental Filter: 20-minute lookback window to catch late-arriving CDC events
      TIMESTAMP_MILLIS(datastream_metadata.source_timestamp) >= 
        COALESCE(
          (SELECT TIMESTAMP_SUB(MAX(_last_sync_timestamp), INTERVAL 20 MINUTE) FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver`),
          TIMESTAMP('2020-01-01')  -- Fallback for initial full load
        )
  )
  WHERE row_num = 1  -- Keep only the absolute latest event for each customer
) AS source
ON target.customer_id = source.customer_id

-- Scenario A: Record updated at source -> Update Silver
-- We rely on Datastream's native change_type metadata for Hard CDC
WHEN MATCHED AND source.change_type != 'DELETE' THEN
  UPDATE SET
    name = source.name,
    email = source.email,
    status = source.status,
    total_purchases = source.total_purchases,
    country = source.country,
    updated_at = source.updated_at,
    _last_sync_timestamp = CURRENT_TIMESTAMP()

-- Scenario B: Record hard-deleted at source -> Hard delete from Silver
WHEN MATCHED AND source.change_type = 'DELETE' THEN
  DELETE

-- Scenario C: New record inserted at source -> Insert into Silver
WHEN NOT MATCHED AND source.change_type != 'DELETE' THEN
  INSERT (
    customer_id, name, email, status, total_purchases, country, 
    created_at, updated_at, _last_sync_timestamp
  )
  VALUES (
    source.customer_id, source.name, source.email, source.status, 
    source.total_purchases, source.country, source.created_at, 
    source.updated_at, CURRENT_TIMESTAMP()
  );

-- Output validation metrics for demo purposes
SELECT 
  '============================================================' as separator
UNION ALL
SELECT 
  '✅ Bronze-to-Silver MERGE Complete' as separator
UNION ALL
SELECT 
  '============================================================' as separator;

SELECT 
  'Bronze (total events)' as metric,
  CAST(COUNT(*) AS STRING) as value
FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze`
UNION ALL
SELECT 
  'Silver (current customers)' as metric,
  CAST(COUNT(*) AS STRING) as value
FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver`
UNION ALL
SELECT 
  'Last sync time' as metric,
  CAST(MAX(_last_sync_timestamp) AS STRING) as value
FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver`;

SELECT 
  '============================================================' as separator
UNION ALL
SELECT 
  'Silver layer now represents current state' as separator
UNION ALL
SELECT 
  'Matches Datastream Merge Mode output' as separator
UNION ALL
SELECT 
  'But we preserved full history in Bronze!' as separator
UNION ALL
SELECT 
  '============================================================' as separator;
