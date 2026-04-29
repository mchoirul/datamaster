-- =========================================================================
-- Datastream Demo Database Setup (Dual Architecture)
-- 
-- This script sets up two separate tables to simulate two different 
-- Change Data Capture (CDC) patterns:
--
-- 1. HARD CDC (customer_bronze): 
--    Simulates a traditional database where records are physically deleted 
--    or updated. Datastream relies on its native metadata to track changes.
--
-- 2. SOFT CDC (soft_customer_bronze):
--    Simulates an enterprise pattern where records are never physically 
--    deleted. Instead, an `is_deleted` flag is used, and updates are 
--    tracked via `updated_at`. BigQuery must rely on the data payload 
--    rather than native metadata to resolve the current state.
-- =========================================================================

-- Execute via: gcloud sql connect YOUR_INSTANCE_NAME --user=postgres --project=YOUR_PROJECT_ID
-- Then: \i setup/02_setup_database.sql

-- Create database
CREATE DATABASE YOUR_DATABASE_NAME;

-- Connect to the database
\c YOUR_DATABASE_NAME

-- Create replication user for Datastream
CREATE USER datastream_user WITH REPLICATION LOGIN PASSWORD 'YOUR_DATASTREAM_USER_PASSWORD';
GRANT USAGE ON SCHEMA public TO datastream_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO datastream_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO datastream_user;

-- Create publication for logical replication
CREATE PUBLICATION datastream_publication FOR ALL TABLES;
ALTER PUBLICATION datastream_publication OWNER TO datastream_user;

-- =========================================================================
-- 1. HARD CDC TABLE (customer_bronze)
-- Purpose: Physical deletes and direct updates. 
-- Downstream MERGE will use Datastream's change_type metadata.
-- =========================================================================

-- Create customers table
CREATE TABLE customer_bronze (
  customer_id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  status VARCHAR(20) DEFAULT 'active',
  total_purchases NUMERIC(10,2) DEFAULT 0.00,
  country VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create trigger to update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_customer_bronze_updated_at 
  BEFORE UPDATE ON customer_bronze 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Insert initial seed data (50 customers)
INSERT INTO customer_bronze (name, email, status, total_purchases, country) VALUES
  ('Alice Johnson', 'alice.johnson@email.com', 'active', 1250.00, 'USA'),
  ('Bob Smith', 'bob.smith@email.com', 'active', 890.50, 'UK'),
  ('Carol White', 'carol.white@email.com', 'active', 2100.75, 'Canada'),
  ('David Brown', 'david.brown@email.com', 'inactive', 450.00, 'Australia'),
  ('Emma Davis', 'emma.davis@email.com', 'active', 3200.00, 'USA'),
  ('Frank Wilson', 'frank.wilson@email.com', 'active', 670.25, 'Germany'),
  ('Grace Lee', 'grace.lee@email.com', 'active', 1890.00, 'Singapore'),
  ('Henry Taylor', 'henry.taylor@email.com', 'inactive', 120.50, 'USA'),
  ('Ivy Martinez', 'ivy.martinez@email.com', 'active', 5600.00, 'Mexico'),
  ('Jack Anderson', 'jack.anderson@email.com', 'active', 980.75, 'UK'),
  ('Karen Thomas', 'karen.thomas@email.com', 'active', 1450.00, 'Canada'),
  ('Leo Garcia', 'leo.garcia@email.com', 'active', 2300.50, 'Spain'),
  ('Maria Rodriguez', 'maria.rodriguez@email.com', 'active', 1120.00, 'Mexico'),
  ('Nathan King', 'nathan.king@email.com', 'inactive', 340.25, 'USA'),
  ('Olivia Scott', 'olivia.scott@email.com', 'active', 4100.00, 'Australia'),
  ('Paul Green', 'paul.green@email.com', 'active', 890.50, 'UK'),
  ('Quinn Adams', 'quinn.adams@email.com', 'active', 1670.75, 'USA'),
  ('Rachel Baker', 'rachel.baker@email.com', 'active', 2900.00, 'Canada'),
  ('Sam Nelson', 'sam.nelson@email.com', 'active', 560.25, 'Germany'),
  ('Tina Carter', 'tina.carter@email.com', 'inactive', 780.00, 'France'),
  ('Uma Mitchell', 'uma.mitchell@email.com', 'active', 3400.50, 'India'),
  ('Victor Perez', 'victor.perez@email.com', 'active', 1230.00, 'Spain'),
  ('Wendy Roberts', 'wendy.roberts@email.com', 'active', 2100.75, 'USA'),
  ('Xavier Turner', 'xavier.turner@email.com', 'active', 890.00, 'UK'),
  ('Yara Phillips', 'yara.phillips@email.com', 'active', 4500.25, 'UAE'),
  ('Zack Campbell', 'zack.campbell@email.com', 'inactive', 230.50, 'USA'),
  ('Amy Parker', 'amy.parker@email.com', 'active', 1890.00, 'Canada'),
  ('Ben Evans', 'ben.evans@email.com', 'active', 3200.75, 'Australia'),
  ('Chloe Edwards', 'chloe.edwards@email.com', 'active', 670.00, 'UK'),
  ('Dan Collins', 'dan.collins@email.com', 'active', 1450.50, 'USA'),
  ('Ella Stewart', 'ella.stewart@email.com', 'inactive', 890.25, 'Germany'),
  ('Finn Morris', 'finn.morris@email.com', 'active', 5200.00, 'Sweden'),
  ('Gina Rogers', 'gina.rogers@email.com', 'active', 1120.75, 'USA'),
  ('Hugo Reed', 'hugo.reed@email.com', 'active', 2340.00, 'UK'),
  ('Iris Cook', 'iris.cook@email.com', 'active', 780.50, 'Canada'),
  ('Jake Morgan', 'jake.morgan@email.com', 'active', 4100.25, 'Australia'),
  ('Kelly Bell', 'kelly.bell@email.com', 'inactive', 340.00, 'USA'),
  ('Liam Murphy', 'liam.murphy@email.com', 'active', 1670.75, 'Ireland'),
  ('Mia Bailey', 'mia.bailey@email.com', 'active', 2900.50, 'UK'),
  ('Noah Rivera', 'noah.rivera@email.com', 'active', 560.00, 'Mexico'),
  ('Olive Cooper', 'olive.cooper@email.com', 'active', 3400.25, 'USA'),
  ('Pete Richardson', 'pete.richardson@email.com', 'active', 1230.75, 'Canada'),
  ('Rose Cox', 'rose.cox@email.com', 'active', 2100.00, 'Australia'),
  ('Seth Howard', 'seth.howard@email.com', 'inactive', 890.50, 'USA'),
  ('Tara Ward', 'tara.ward@email.com', 'active', 4500.25, 'UK'),
  ('Umar Torres', 'umar.torres@email.com', 'active', 1890.00, 'Spain'),
  ('Vera Peterson', 'vera.peterson@email.com', 'active', 3200.75, 'Germany'),
  ('Will Gray', 'will.gray@email.com', 'active', 670.00, 'USA'),
  ('Xena Ramirez', 'xena.ramirez@email.com', 'active', 1450.50, 'Mexico'),
  ('York James', 'york.james@email.com', 'active', 5200.25, 'Canada');

-- Grant permissions to datastream user
GRANT SELECT ON customer_bronze TO datastream_user;
GRANT SELECT ON SEQUENCE customer_bronze_customer_id_seq TO datastream_user;


-- =========================================================================
-- 2. SOFT CDC TABLE (soft_customer_bronze)
-- Purpose: Logical deletes and payload-based tracking.
-- Downstream MERGE will rely on `is_deleted` instead of change_type.
-- =========================================================================

-- Create soft_customer_bronze table
CREATE TABLE soft_customer_bronze (
  customer_id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  status VARCHAR(20) DEFAULT 'active',
  total_purchases NUMERIC(10,2) DEFAULT 0.00,
  country VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMP
);

-- Use the existing trigger function to update updated_at
CREATE TRIGGER update_soft_customers_updated_at 
  BEFORE UPDATE ON soft_customer_bronze 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Insert initial seed data (50 customers)
INSERT INTO soft_customer_bronze (name, email, status, total_purchases, country) VALUES
  ('Alice Johnson', 'alice.johnson_s@email.com', 'active', 1250.00, 'USA'),
  ('Bob Smith', 'bob.smith_s@email.com', 'active', 890.50, 'UK'),
  ('Carol White', 'carol.white_s@email.com', 'active', 2100.75, 'Canada'),
  ('David Brown', 'david.brown_s@email.com', 'inactive', 450.00, 'Australia'),
  ('Emma Davis', 'emma.davis_s@email.com', 'active', 3200.00, 'USA'),
  ('Frank Wilson', 'frank.wilson_s@email.com', 'active', 670.25, 'Germany'),
  ('Grace Lee', 'grace.lee_s@email.com', 'active', 1890.00, 'Singapore'),
  ('Henry Taylor', 'henry.taylor_s@email.com', 'inactive', 120.50, 'USA'),
  ('Ivy Martinez', 'ivy.martinez_s@email.com', 'active', 5600.00, 'Mexico'),
  ('Jack Anderson', 'jack.anderson_s@email.com', 'active', 980.75, 'UK'),
  ('Karen Thomas', 'karen.thomas_s@email.com', 'active', 1450.00, 'Canada'),
  ('Leo Garcia', 'leo.garcia_s@email.com', 'active', 2300.50, 'Spain'),
  ('Maria Rodriguez', 'maria.rodriguez_s@email.com', 'active', 1120.00, 'Mexico'),
  ('Nathan King', 'nathan.king_s@email.com', 'inactive', 340.25, 'USA'),
  ('Olivia Scott', 'olivia.scott_s@email.com', 'active', 4100.00, 'Australia'),
  ('Paul Green', 'paul.green_s@email.com', 'active', 890.50, 'UK'),
  ('Quinn Adams', 'quinn.adams_s@email.com', 'active', 1670.75, 'USA'),
  ('Rachel Baker', 'rachel.baker_s@email.com', 'active', 2900.00, 'Canada'),
  ('Sam Nelson', 'sam.nelson_s@email.com', 'active', 560.25, 'Germany'),
  ('Tina Carter', 'tina.carter_s@email.com', 'inactive', 780.00, 'France'),
  ('Uma Mitchell', 'uma.mitchell_s@email.com', 'active', 3400.50, 'India'),
  ('Victor Perez', 'victor.perez_s@email.com', 'active', 1230.00, 'Spain'),
  ('Wendy Roberts', 'wendy.roberts_s@email.com', 'active', 2100.75, 'USA'),
  ('Xavier Turner', 'xavier.turner_s@email.com', 'active', 890.00, 'UK'),
  ('Yara Phillips', 'yara.phillips_s@email.com', 'active', 4500.25, 'UAE'),
  ('Zack Campbell', 'zack.campbell_s@email.com', 'inactive', 230.50, 'USA'),
  ('Amy Parker', 'amy.parker_s@email.com', 'active', 1890.00, 'Canada'),
  ('Ben Evans', 'ben.evans_s@email.com', 'active', 3200.75, 'Australia'),
  ('Chloe Edwards', 'chloe.edwards_s@email.com', 'active', 670.00, 'UK'),
  ('Dan Collins', 'dan.collins_s@email.com', 'active', 1450.50, 'USA'),
  ('Ella Stewart', 'ella.stewart_s@email.com', 'inactive', 890.25, 'Germany'),
  ('Finn Morris', 'finn.morris_s@email.com', 'active', 5200.00, 'Sweden'),
  ('Gina Rogers', 'gina.rogers_s@email.com', 'active', 1120.75, 'USA'),
  ('Hugo Reed', 'hugo.reed_s@email.com', 'active', 2340.00, 'UK'),
  ('Iris Cook', 'iris.cook_s@email.com', 'active', 780.50, 'Canada'),
  ('Jake Morgan', 'jake.morgan_s@email.com', 'active', 4100.25, 'Australia'),
  ('Kelly Bell', 'kelly.bell_s@email.com', 'inactive', 340.00, 'USA'),
  ('Liam Murphy', 'liam.murphy_s@email.com', 'active', 1670.75, 'Ireland'),
  ('Mia Bailey', 'mia.bailey_s@email.com', 'active', 2900.50, 'UK'),
  ('Noah Rivera', 'noah.rivera_s@email.com', 'active', 560.00, 'Mexico'),
  ('Olive Cooper', 'olive.cooper_s@email.com', 'active', 3400.25, 'USA'),
  ('Pete Richardson', 'pete.richardson_s@email.com', 'active', 1230.75, 'Canada'),
  ('Rose Cox', 'rose.cox_s@email.com', 'active', 2100.00, 'Australia'),
  ('Seth Howard', 'seth.howard_s@email.com', 'inactive', 890.50, 'USA'),
  ('Tara Ward', 'tara.ward_s@email.com', 'active', 4500.25, 'UK'),
  ('Umar Torres', 'umar.torres_s@email.com', 'active', 1890.00, 'Spain'),
  ('Vera Peterson', 'vera.peterson_s@email.com', 'active', 3200.75, 'Germany'),
  ('Will Gray', 'will.gray_s@email.com', 'active', 670.00, 'USA'),
  ('Xena Ramirez', 'xena.ramirez_s@email.com', 'active', 1450.50, 'Mexico'),
  ('York James', 'york.james_s@email.com', 'active', 5200.25, 'Canada');

-- Grant permissions to datastream user
GRANT SELECT ON soft_customer_bronze TO datastream_user;
GRANT SELECT ON SEQUENCE soft_customer_bronze_customer_id_seq TO datastream_user;

-- Verify setup
\echo '============================================================'
\echo 'Database setup complete (Hard and Soft CDC)!'
\echo '============================================================'
\echo ''

SELECT 'Hard CDC customer count:' as info, COUNT(*) as count FROM customer_bronze;
SELECT 'Soft CDC customer count:' as info, COUNT(*) as count FROM soft_customer_bronze;

\echo ''
\echo '============================================================'
\echo 'Next steps:'
\echo '============================================================'
\echo '1. Exit psql: \q'
\echo '2. Run: ./03_create_bq_dataset.sh'
\echo '============================================================'
