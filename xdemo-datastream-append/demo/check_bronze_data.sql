/*
Bronze Layer Examination Queries
Shows the append-only CDC structure and metadata for both Hard and Soft CDC tables.
This script checks for the existence of the tables before running queries.
*/

DECLARE hard_bronze_exists BOOL;
DECLARE soft_bronze_exists BOOL;

-- Check if tables exist
SET hard_bronze_exists = (
  SELECT COUNT(1) = 1 
  FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.INFORMATION_SCHEMA.TABLES` 
  WHERE table_name = 'public_customer_bronze'
);

SET soft_bronze_exists = (
  SELECT COUNT(1) = 1 
  FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.INFORMATION_SCHEMA.TABLES` 
  WHERE table_name = 'public_soft_customer_bronze'
);

IF NOT hard_bronze_exists THEN
  SELECT '❌ Table public_customer_bronze does not exist yet. Run Datastream and wait for data.' as message;
END IF;

IF NOT soft_bronze_exists THEN
  SELECT '❌ Table public_soft_customer_bronze does not exist yet. Run Datastream and wait for data.' as message;
END IF;


-- =========================================================================================
-- 1. HARD CDC BRONZE TABLE ANALYSIS
-- =========================================================================================
IF hard_bronze_exists THEN

  SELECT '=== HARD CDC BRONZE LAYER OVERVIEW ===' as section;
  
  -- Show overview
  SELECT 
    COUNT(*) as total_cdc_events,
    COUNT(DISTINCT customer_id) as unique_customers,
    MIN(TIMESTAMP_MILLIS(datastream_metadata.source_timestamp)) as earliest_event,
    MAX(TIMESTAMP_MILLIS(datastream_metadata.source_timestamp)) as latest_event
  FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze`;

  -- Change type breakdown
  SELECT '=== CHANGE TYPE DISTRIBUTION ===' as section;
  SELECT 
    datastream_metadata.change_type,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
  FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze`
  GROUP BY datastream_metadata.change_type
  ORDER BY count DESC;

  -- Metadata structure example
  SELECT '=== DATASTREAM METADATA STRUCTURE ===' as section;
  SELECT 
    customer_id,
    name,
    datastream_metadata.uuid,
    datastream_metadata.change_type,
    datastream_metadata.change_sequence_number,
    TIMESTAMP_MILLIS(datastream_metadata.source_timestamp) as event_time
  FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze`
  ORDER BY datastream_metadata.source_timestamp DESC
  LIMIT 5;

  -- Customers with multiple events
  SELECT '=== CUSTOMERS WITH MULTIPLE EVENTS ===' as section;
  SELECT 
    customer_id,
    COUNT(*) as total_events,
    STRING_AGG(datastream_metadata.change_type ORDER BY datastream_metadata.source_timestamp) as event_sequence
  FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze`
  GROUP BY customer_id
  HAVING COUNT(*) > 1
  ORDER BY total_events DESC
  LIMIT 5;

END IF;

-- =========================================================================================
-- 2. SOFT CDC BRONZE TABLE ANALYSIS
-- =========================================================================================
IF soft_bronze_exists THEN

  SELECT '' as separator;
  SELECT '=== SOFT CDC BRONZE LAYER OVERVIEW ===' as section;
  
  -- Show overview
  SELECT 
    COUNT(*) as total_cdc_events,
    COUNT(DISTINCT customer_id) as unique_customers,
    MIN(TIMESTAMP_MILLIS(datastream_metadata.source_timestamp)) as earliest_event,
    MAX(TIMESTAMP_MILLIS(datastream_metadata.source_timestamp)) as latest_event
  FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_soft_customer_bronze`;

  -- Change type breakdown (Notice: Should have very few/no native DELETEs!)
  SELECT '=== SOFT CDC: CHANGE TYPE DISTRIBUTION (Notice the lack of native DELETEs!) ===' as section;
  SELECT 
    datastream_metadata.change_type,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
  FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_soft_customer_bronze`
  GROUP BY datastream_metadata.change_type
  ORDER BY count DESC;

  -- Actual Payload Deletes vs Datastream Metadata
  SELECT '=== SOFT CDC: PAYLOAD DELETES vs METADATA ===' as section;
  SELECT 
    is_deleted as payload_is_deleted,
    datastream_metadata.change_type as native_change_type,
    COUNT(*) as total_events
  FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_soft_customer_bronze`
  GROUP BY is_deleted, datastream_metadata.change_type
  ORDER BY is_deleted, total_events DESC;

END IF;

-- Summary message
IF hard_bronze_exists OR soft_bronze_exists THEN
  SELECT 
    '=== BRONZE LAYER SUMMARY ===' as section;
  SELECT 
    'Bronze layer contains ALL CDC events - complete audit trail' as message
  UNION ALL SELECT 'Every INSERT, UPDATE, DELETE is a separate row'
  UNION ALL SELECT 'Querying current state requires complex deduplication'
  UNION ALL SELECT 'Solution: Transform to Silver layer!';
END IF;
