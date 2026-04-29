#!YOUR_VENV_PATH/bin/python3
"""
Simulates CDC operations on Cloud SQL PostgreSQL
Generates exactly 50 operations:
- 25 INSERTs (50%)
- 10 UPDATEs (20%)
- 15 DELETEs (30%)

Usage:
  # Activate venv first
  source YOUR_VENV_PATH/bin/activate
  python3 simulate_cdc.py
  
  # OR run directly (shebang uses venv python)
  chmod +x simulate_cdc.py
  ./simulate_cdc.py
  
Prerequisites:
  Virtual environment: YOUR_VENV_PATH
  Packages: psycopg2-binary, Faker (installed via 00_setup_python_env.sh)
  
Configuration:
  Update DB_CONFIG['host'] with your Cloud SQL public IP
"""

import psycopg2
import random
import time
from faker import Faker
from datetime import datetime
import sys
import os

# Verify running in correct environment
def check_venv():
    """Verify script is running in the correct virtual environment"""
    expected_venv = "YOUR_VENV_PATH"
    current_venv = os.environ.get('VIRTUAL_ENV', '')
    
    if expected_venv in current_venv:
        print(f"✅ Running in correct venv: {current_venv}\n")
    elif current_venv:
        print(f"⚠️  Warning: Running in different venv: {current_venv}")
        print(f"   Expected: {expected_venv}")
    else:
        print("⚠️  Warning: Not running in a virtual environment")
        print(f"   Activate with: source {expected_venv}/bin/activate")

# Configuration
DB_CONFIG = {
    'host': 'YOUR_CLOUDSQL_IP',
    'port': 5432,
    'database': 'YOUR_DATABASE_NAME',
    'user': 'postgres',
    'password': 'YOUR_DB_PASSWORD'
}

fake = Faker()

def get_connection():
    """Create database connection"""
    try:
        return psycopg2.connect(**DB_CONFIG)
    except psycopg2.OperationalError as e:
        print(f"\n❌ Error: Cannot connect to Cloud SQL")
        print(f"   {e}")
        print(f"\nTroubleshooting:")
        print(f"1. Verify Cloud SQL public IP in DB_CONFIG (currently: {DB_CONFIG['host']})")
        print(f"2. Check Cloud SQL instance is running:")
        print(f"   gcloud sql instances describe YOUR_INSTANCE_NAME --project=YOUR_PROJECT_ID")
        print(f"   (Look for ipAddresses -> ipAddress)")
        print(f"2. Ensure your IP is in authorized networks:")
        print(f"   gcloud sql instances describe YOUR_INSTANCE_NAME --format='value(settings.ipConfiguration.authorizedNetworks)'")
        sys.exit(1)

def get_existing_customer_ids(conn):
    """Get list of existing customer IDs for updates/deletes"""
    with conn.cursor() as cur:
        cur.execute("SELECT customer_id FROM customer_bronze ORDER BY customer_id")
        return [row[0] for row in cur.fetchall()]

def insert_customer(conn):
    """Insert a new customer"""
    with conn.cursor() as cur:
        name = fake.name()
        email = fake.email()
        status = random.choice(['active', 'active', 'active', 'inactive'])  # 75% active
        total_purchases = round(random.uniform(100, 5000), 2)
        country = random.choice(['USA', 'UK', 'Canada', 'Australia', 'Germany', 'France', 'Spain', 'Mexico'])
        
        cur.execute("""
            INSERT INTO customer_bronze (name, email, status, total_purchases, country)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING customer_id
        """, (name, email, status, total_purchases, country))
        
        customer_id = cur.fetchone()[0]
        conn.commit()
        
        print(f"✅ INSERT: customer_id={customer_id}, name={name}, email={email}")
        return customer_id

def update_customer(conn, customer_id):
    """Update an existing customer"""
    with conn.cursor() as cur:
        # Randomly update different fields
        update_type = random.choice(['status', 'purchases', 'both'])
        
        if update_type == 'status':
            new_status = random.choice(['active', 'inactive'])
            cur.execute("""
                UPDATE customer_bronze 
                SET status = %s 
                WHERE customer_id = %s
            """, (new_status, customer_id))
            print(f"🔄 UPDATE: customer_id={customer_id}, status={new_status}")
            
        elif update_type == 'purchases':
            additional_purchase = round(random.uniform(50, 500), 2)
            cur.execute("""
                UPDATE customer_bronze 
                SET total_purchases = total_purchases + %s 
                WHERE customer_id = %s
            """, (additional_purchase, customer_id))
            print(f"🔄 UPDATE: customer_id={customer_id}, added purchase=${additional_purchase}")
            
        else:  # both
            new_status = random.choice(['active', 'inactive'])
            additional_purchase = round(random.uniform(50, 500), 2)
            cur.execute("""
                UPDATE customer_bronze 
                SET status = %s, total_purchases = total_purchases + %s 
                WHERE customer_id = %s
            """, (new_status, additional_purchase, customer_id))
            print(f"🔄 UPDATE: customer_id={customer_id}, status={new_status}, added ${additional_purchase}")
        
        conn.commit()

def delete_customer(conn, customer_id):
    """Delete a customer (hard delete)"""
    with conn.cursor() as cur:
        cur.execute("DELETE FROM customer_bronze WHERE customer_id = %s", (customer_id,))
        conn.commit()
        print(f"❌ DELETE: customer_id={customer_id}")

def main():
    """Run CDC simulation"""
    print("=" * 70)
    print("Datastream CDC Simulation")
    print("Generating 50 operations: 25 INSERTs, 10 UPDATEs, 15 DELETEs")
    print("=" * 70)
    print()
    
    conn = get_connection()
    
    try:
        # Get existing customers for updates/deletes
        existing_ids = get_existing_customer_ids(conn)
        print(f"Found {len(existing_ids)} existing customers in database")
        print()
        
        # Track new inserts for potential updates/deletes
        new_customer_ids = []
        
        # Generate 25 INSERTs
        print("-" * 70)
        print("Phase 1: INSERT Operations (25 new customers)")
        print("-" * 70)
        for i in range(25):
            customer_id = insert_customer(conn)
            new_customer_ids.append(customer_id)
            time.sleep(0.3)  # Small delay for visibility
        print()
        
        # Combine old and new IDs for updates/deletes
        all_ids = existing_ids + new_customer_ids
        random.shuffle(all_ids)
        
        # Generate 10 UPDATEs
        print("-" * 70)
        print("Phase 2: UPDATE Operations (10 modifications)")
        print("-" * 70)
        update_ids = random.sample(all_ids, min(10, len(all_ids)))
        for customer_id in update_ids:
            update_customer(conn, customer_id)
            time.sleep(0.3)
        print()
        
        # Generate 15 DELETEs
        print("-" * 70)
        print("Phase 3: DELETE Operations (15 deletions)")
        print("-" * 70)
        # Remove updated IDs from potential deletes to show cleaner examples
        remaining_ids = [id for id in all_ids if id not in update_ids]
        delete_ids = random.sample(remaining_ids, min(15, len(remaining_ids)))
        for customer_id in delete_ids:
            delete_customer(conn, customer_id)
            time.sleep(0.3)
        print()
        
        # Summary
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM customer_bronze")
            final_count = cur.fetchone()[0]
        
        print("=" * 70)
        print("✅ CDC Simulation Complete!")
        print("=" * 70)
        print()
        print(f"Final customer count in PostgreSQL: {final_count}")
        print(f"Expected: ~60 customers (50 initial + 25 new - 15 deleted)")
        print()
        print("Operations summary:")
        print(f"  ✅ INSERTs:  25 new customers")
        print(f"  🔄 UPDATEs:  10 modifications")
        print(f"  ❌ DELETEs:  15 removals")
        print(f"  📊 Total:    50 CDC events")
        print()
        print("=" * 70)
        print("Next Steps:")
        print("=" * 70)
        print()
        print("1. Wait 2-3 minutes for Datastream to replicate changes")
        print()
        print("2. Check bronze table:")
        print("   bq query --use_legacy_sql=false \\")
        print("     'SELECT COUNT(*) FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze`'")
        print()
        print("3. Or use the status checker:")
        print("   cd ../utils")
        print("   ./check_datastream_status.sh")
        print()
        print("4. Then examine bronze data:")
        print("   cd ../demo")
        print("   bq query --use_legacy_sql=false < check_bronze_data.sql")
        print()
        print("=" * 70)
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        conn.rollback()
        import traceback
        traceback.print_exc()
    finally:
        conn.close()

if __name__ == "__main__":
    check_venv()
    main()
