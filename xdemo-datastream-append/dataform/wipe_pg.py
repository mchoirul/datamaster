import psycopg2

DB_CONFIG = {
    'host': 'YOUR_CLOUDSQL_IP',
    'port': 5432,
    'database': 'YOUR_DATABASE_NAME',
    'user': 'postgres',
    'password': 'YOUR_DB_PASSWORD'
}

def wipe_data():
    conn = psycopg2.connect(**DB_CONFIG)
    with conn.cursor() as cur:
        # Hard delete all remaining rows in customer_bronze
        cur.execute("DELETE FROM customer_bronze")
        hard_deleted = cur.rowcount
        print(f"Hard deleted {hard_deleted} rows from customer_bronze.")
        
        # Soft delete all remaining active rows in soft_customer_bronze
        cur.execute("UPDATE soft_customer_bronze SET is_deleted = TRUE, deleted_at = CURRENT_TIMESTAMP WHERE is_deleted = FALSE")
        soft_deleted = cur.rowcount
        print(f"Soft deleted {soft_deleted} rows from soft_customer_bronze.")
        
    conn.commit()
    conn.close()
    print("Database wipe complete.")

if __name__ == "__main__":
    wipe_data()
