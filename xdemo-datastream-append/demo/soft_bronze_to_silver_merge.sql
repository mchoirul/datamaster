/*
Soft Bronze to Silver Incremental MERGE Transformation (Soft CDC Pattern)
Purpose: Convert raw append-only CDC events into a clean, current-state Silver table.
Strategy: In a Soft CDC pattern, source deletions are just UPDATEs. 
          Therefore, we must look at the DATA PAYLOAD (is_deleted) rather than 
          Datastream's native metadata (change_type) to determine the merge action.
*/

-- Step 1: Initialize Silver Table
-- Partitioned by sync time for cost efficiency, clustered by PK for query performance.
CREATE TABLE IF NOT EXISTS `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver_soft` (
  customer_id INT64,
  name STRING,
  email STRING,
  status STRING,
  total_purchases NUMERIC,
  country STRING,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  is_deleted BOOLEAN,
  deleted_at TIMESTAMP,
  _last_sync_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(_last_sync_timestamp)
CLUSTER BY customer_id;

-- Step 2: Incremental MERGE execution
MERGE `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver_soft` AS target
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
      is_deleted, -- Critical: We will use this payload field to drive merge logic
      deleted_at,
      TIMESTAMP_MILLIS(datastream_metadata.source_timestamp) as source_event_time,
      datastream_metadata.change_type,
      -- Deduplication: Assigns row_num = 1 to the most recent event per customer_id
      ROW_NUMBER() OVER (
        PARTITION BY customer_id 
        ORDER BY 
          datastream_metadata.source_timestamp DESC,
          datastream_metadata.change_sequence_number DESC
      ) as row_num
    FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_soft_customer_bronze`
    WHERE 
      -- Incremental Filter: 20-minute lookback window to catch late-arriving CDC events
      TIMESTAMP_MILLIS(datastream_metadata.source_timestamp) >= 
        COALESCE(
          (SELECT TIMESTAMP_SUB(MAX(_last_sync_timestamp), INTERVAL 20 MINUTE) FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver_soft`),
          TIMESTAMP('2020-01-01') -- Fallback for initial full load
        )
  )
  WHERE row_num = 1 -- Keep only the absolute latest event for each customer
) AS source
ON target.customer_id = source.customer_id

-- Scenario A: Record soft-deleted at source -> Hard delete from Silver
-- Datastream sees an UPDATE, but the payload says is_deleted = TRUE
WHEN MATCHED AND source.is_deleted = TRUE THEN
  DELETE

-- Scenario B: Record updated at source -> Update Silver
-- Datastream sees an UPDATE, and the payload confirms it is still active (FALSE)
WHEN MATCHED AND source.is_deleted = FALSE THEN
  UPDATE SET
    name = source.name,
    email = source.email,
    status = source.status,
    total_purchases = source.total_purchases,
    country = source.country,
    updated_at = source.updated_at,
    _last_sync_timestamp = CURRENT_TIMESTAMP()

-- Scenario C: New record inserted at source -> Insert into Silver
WHEN NOT MATCHED AND source.is_deleted = FALSE THEN
  INSERT (
    customer_id, name, email, status, total_purchases, country, 
    created_at, updated_at, is_deleted, deleted_at, _last_sync_timestamp
  )
  VALUES (
    source.customer_id, source.name, source.email, source.status, 
    source.total_purchases, source.country, source.created_at, 
    source.updated_at, source.is_deleted, source.deleted_at, CURRENT_TIMESTAMP()
  );
