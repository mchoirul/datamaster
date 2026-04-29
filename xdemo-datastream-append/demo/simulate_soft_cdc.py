#!YOUR_VENV_PATH/bin/python3
import psycopg2
import random
import time
from faker import Faker
from datetime import datetime
import sys

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
    return psycopg2.connect(**DB_CONFIG)

def get_existing_customer_ids(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT customer_id FROM soft_customer_bronze WHERE is_deleted = FALSE ORDER BY customer_id")
        return [row[0] for row in cur.fetchall()]

def insert_customer(conn):
    with conn.cursor() as cur:
        name = fake.name()
        email = fake.email()
        status = random.choice(['active', 'active', 'inactive'])
        total_purchases = round(random.uniform(100, 5000), 2)
        country = random.choice(['USA', 'UK', 'Canada', 'Australia', 'Germany'])
        
        cur.execute("""
            INSERT INTO soft_customer_bronze (name, email, status, total_purchases, country)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING customer_id
        """, (name, email, status, total_purchases, country))
        customer_id = cur.fetchone()[0]
        conn.commit()
        print(f"✅ INSERT: ID={customer_id}")
        return customer_id

def update_customer(conn, customer_id):
    with conn.cursor() as cur:
        additional_purchase = round(random.uniform(50, 500), 2)
        cur.execute("""
            UPDATE soft_customer_bronze 
            SET total_purchases = total_purchases + %s 
            WHERE customer_id = %s
        """, (additional_purchase, customer_id))
        conn.commit()
        print(f"🔄 SOFT UPDATE (using updated_at): ID={customer_id}, added ${additional_purchase}")

def delete_customer(conn, customer_id):
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE soft_customer_bronze 
            SET is_deleted = TRUE, deleted_at = CURRENT_TIMESTAMP 
            WHERE customer_id = %s
        """, (customer_id,))
        conn.commit()
        print(f"❌ SOFT DELETE: ID={customer_id}")

def main():
    conn = get_connection()
    try:
        existing_ids = get_existing_customer_ids(conn)
        new_customer_ids = []
        
        print("--- INSERT Operations (25) ---")
        for i in range(25):
            customer_id = insert_customer(conn)
            new_customer_ids.append(customer_id)
            time.sleep(0.3)
            
        all_ids = existing_ids + new_customer_ids
        random.shuffle(all_ids)
        
        print("\n--- SOFT UPDATE Operations (10) ---")
        update_ids = random.sample(all_ids, min(10, len(all_ids)))
        for customer_id in update_ids:
            update_customer(conn, customer_id)
            time.sleep(0.3)
            
        print("\n--- SOFT DELETE Operations (15) ---")
        remaining_ids = [id for id in all_ids if id not in update_ids]
        delete_ids = random.sample(remaining_ids, min(15, len(remaining_ids)))
        for customer_id in delete_ids:
            delete_customer(conn, customer_id)
            time.sleep(0.3)
            
    except Exception as e:
        print(f"Error: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    main()
