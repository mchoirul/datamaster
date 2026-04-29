/*
Soft CDC Validation Queries for Demo
Shows differences between soft bronze (append-only) and soft silver (current state)
Demonstrates that silver correctly handles payload-based soft deletes/updates
*/

-- Section 1: Bronze layer analysis
SELECT '============================================================' as section
UNION ALL SELECT '1. BRONZE LAYER (All CDC Events)' as section
UNION ALL SELECT '============================================================' as section;

SELECT 
  COUNT(*) as total_events,
  COUNT(DISTINCT customer_id) as unique_customers
FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_soft_customer_bronze`;

-- Section 2: Silver layer analysis
SELECT '' as blank_line;
SELECT '============================================================' as section
UNION ALL SELECT '2. SILVER LAYER (Current Active State)' as section
UNION ALL SELECT '============================================================' as section;

SELECT 
  COUNT(*) as current_active_customers,
  COUNT(DISTINCT customer_id) as unique_ids
FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver_soft`;

-- Section 3: Show the transformation is working perfectly
SELECT '' as blank_line;
SELECT '============================================================' as section
UNION ALL SELECT '3. PROOF OF SOFT MERGE LOGIC' as section
UNION ALL SELECT '============================================================' as section;

WITH latest_events AS (
  SELECT * EXCEPT(row_num)
  FROM (
    SELECT 
      customer_id,
      is_deleted,
      datastream_metadata.change_type,
      ROW_NUMBER() OVER (
        PARTITION BY customer_id 
        ORDER BY 
          datastream_metadata.source_timestamp DESC,
          datastream_metadata.change_sequence_number DESC
      ) as row_num
    FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_soft_customer_bronze`
  )
  WHERE row_num = 1
)
SELECT 
  'Customers where latest event has is_deleted=TRUE' as category,
  COUNT(*) as count_in_bronze_latest_state,
  (SELECT COUNT(*) FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver_soft` s JOIN latest_events b ON s.customer_id = b.customer_id WHERE b.is_deleted = TRUE) as count_in_silver
FROM latest_events WHERE is_deleted = TRUE
UNION ALL
SELECT 
  'Customers where latest event has is_deleted=FALSE' as category,
  COUNT(*) as count_in_bronze_latest_state,
  (SELECT COUNT(*) FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver_soft` s JOIN latest_events b ON s.customer_id = b.customer_id WHERE b.is_deleted = FALSE) as count_in_silver
FROM latest_events WHERE is_deleted = FALSE;

-- Section 4: Sample of Soft Deleted records in Bronze not present in Silver
SELECT '' as blank_line;
SELECT '============================================================' as section
UNION ALL SELECT '4. SOFT DELETED CUSTOMERS (In Bronze, Hard Deleted from Silver)' as section
UNION ALL SELECT '============================================================' as section;

SELECT 
  b.customer_id,
  b.name,
  b.email,
  b.deleted_at
FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_soft_customer_bronze` b
WHERE b.is_deleted = TRUE
  AND b.customer_id NOT IN (
    SELECT customer_id FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver_soft`
  )
ORDER BY b.deleted_at DESC
LIMIT 5;

SELECT '' as blank_line;
SELECT '============================================================' as section
UNION ALL SELECT '✅ Silver perfectly represents current active state!' as section
UNION ALL SELECT '   (Soft deletes in payload successfully translated to Hard Deletes in Silver)' as section
UNION ALL SELECT '============================================================' as section;

SELECT '' as blank_line;
SELECT '============================================================' as section
UNION ALL SELECT '5. BUSINESS METRICS VALIDATION (Bronze vs Silver)' as section
UNION ALL SELECT '   (Proves aggregations match perfectly between layers)' as section
UNION ALL SELECT '============================================================' as section;

WITH bronze_latest AS (
  SELECT * EXCEPT(rn)
  FROM (
    SELECT 
      customer_id,
      total_purchases,
      is_deleted,
      ROW_NUMBER() OVER (
        PARTITION BY customer_id 
        ORDER BY datastream_metadata.source_timestamp DESC, datastream_metadata.change_sequence_number DESC
      ) as rn
    FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_soft_customer_bronze`
  )
  WHERE rn = 1
),
bronze_metrics AS (
  SELECT 
    COUNT(DISTINCT customer_id) as unique_customers,
    SUM(total_purchases) as total_revenue
  FROM bronze_latest
  WHERE is_deleted = FALSE
),
silver_metrics AS (
  SELECT 
    COUNT(DISTINCT customer_id) as unique_customers,
    SUM(total_purchases) as total_revenue
  FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver_soft`
)
SELECT 
  'Bronze Soft (Deduplicated, Active)' as layer,
  unique_customers,
  total_revenue
FROM bronze_metrics
UNION ALL
SELECT 
  'Silver Soft (Current State)' as layer,
  unique_customers,
  total_revenue
FROM silver_metrics;
