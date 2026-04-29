#!YOUR_VENV_PATH/bin/python3
import psycopg2
import random
import time
from faker import Faker
from datetime import datetime

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

def get_existing_ids(conn, table_name, active_only=False):
    with conn.cursor() as cur:
        query = f"SELECT customer_id FROM {table_name}"
        if active_only:
            query += " WHERE is_deleted = FALSE"
        query += " ORDER BY customer_id"
        cur.execute(query)
        return [row[0] for row in cur.fetchall()]

def simulate_hard_cdc():
    print("Starting Hard CDC Simulation...")
    conn = get_connection()
    
    # 1. Insert 10
    print("Inserting 10 new customers (Hard CDC)...")
    for _ in range(10):
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO customer_bronze (name, email, status, total_purchases, country)
                VALUES (%s, %s, %s, %s, %s)
            """, (fake.name(), fake.email(), random.choice(['active', 'pending']), round(random.uniform(10, 500), 2), fake.country()))
        conn.commit()
    
    # 2. Update 5
    ids = get_existing_ids(conn, "customer_bronze")
    if len(ids) >= 5:
        to_update = random.sample(ids, 5)
        print(f"Updating 5 customers (Hard CDC): {to_update}")
        for cid in to_update:
            with conn.cursor() as cur:
                cur.execute("""
                    UPDATE customer_bronze 
                    SET total_purchases = total_purchases + %s, status = 'active', updated_at = CURRENT_TIMESTAMP
                    WHERE customer_id = %s
                """, (round(random.uniform(5, 50), 2), cid))
            conn.commit()
            
    # 3. Delete 3
    ids = get_existing_ids(conn, "customer_bronze")
    if len(ids) >= 3:
        to_delete = random.sample(ids, 3)
        print(f"Deleting 3 customers (Hard CDC): {to_delete}")
        for cid in to_delete:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM customer_bronze WHERE customer_id = %s", (cid,))
            conn.commit()
            
    conn.close()
    print("Hard CDC Simulation Complete.\n")

def simulate_soft_cdc():
    print("Starting Soft CDC Simulation...")
    conn = get_connection()
    
    # 1. Insert 10
    print("Inserting 10 new customers (Soft CDC)...")
    for _ in range(10):
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO soft_customer_bronze (name, email, status, total_purchases, country, is_deleted)
                VALUES (%s, %s, %s, %s, %s, FALSE)
            """, (fake.name(), fake.email(), random.choice(['active', 'pending']), round(random.uniform(10, 500), 2), fake.country()))
        conn.commit()
    
    # 2. Update 3
    ids = get_existing_ids(conn, "soft_customer_bronze", active_only=True)
    if len(ids) >= 3:
        to_update = random.sample(ids, 3)
        print(f"Updating 3 customers (Soft CDC): {to_update}")
        for cid in to_update:
            with conn.cursor() as cur:
                cur.execute("""
                    UPDATE soft_customer_bronze 
                    SET total_purchases = total_purchases + %s, status = 'active', updated_at = CURRENT_TIMESTAMP
                    WHERE customer_id = %s
                """, (round(random.uniform(5, 50), 2), cid))
            conn.commit()
            
    # 3. Delete 10 (Soft delete: UPDATE is_deleted = TRUE)
    ids = get_existing_ids(conn, "soft_customer_bronze", active_only=True)
    if len(ids) >= 10:
        to_delete = random.sample(ids, 10)
        print(f"Soft Deleting 10 customers (Soft CDC): {to_delete}")
        for cid in to_delete:
            with conn.cursor() as cur:
                cur.execute("""
                    UPDATE soft_customer_bronze
                    SET is_deleted = TRUE, deleted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
                    WHERE customer_id = %s
                """, (cid,))
            conn.commit()
            
    conn.close()
    print("Soft CDC Simulation Complete.\n")

if __name__ == "__main__":
    simulate_hard_cdc()
    simulate_soft_cdc()
    print("All simulations finished.")
