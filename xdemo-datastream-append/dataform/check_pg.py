import psycopg2
DB_CONFIG = {
    'host': 'YOUR_CLOUDSQL_IP',
    'port': 5432,
    'database': 'YOUR_DATABASE_NAME',
    'user': 'postgres',
    'password': 'YOUR_DB_PASSWORD'
}
conn = psycopg2.connect(**DB_CONFIG)
with conn.cursor() as cur:
    cur.execute("SELECT COUNT(*) FROM customer_bronze")
    print("PostgreSQL Hard customers:", cur.fetchone()[0])
    cur.execute("SELECT COUNT(*) FROM soft_customer_bronze WHERE is_deleted = FALSE")
    print("PostgreSQL Soft active customers:", cur.fetchone()[0])
