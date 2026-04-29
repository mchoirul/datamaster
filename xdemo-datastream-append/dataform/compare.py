from google.cloud import bigquery
import os
import psycopg2

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "YOUR_WORKSPACE/YOUR_KEY_FILE.json"
client = bigquery.Client(project='YOUR_PROJECT_ID')

DB_CONFIG = {
    'host': 'YOUR_CLOUDSQL_IP',
    'port': 5432,
    'database': 'YOUR_DATABASE_NAME',
    'user': 'postgres',
    'password': 'YOUR_DB_PASSWORD'
}
conn = psycopg2.connect(**DB_CONFIG)

with conn.cursor() as cur:
    cur.execute("SELECT customer_id FROM customer_bronze")
    pg_hard = set([row[0] for row in cur.fetchall()])
    
q = "SELECT customer_id FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver_dataform`"
bq_hard = set([row.customer_id for row in client.query(q).result()])

print("Missing from BQ:", pg_hard - bq_hard)
print("Extra in BQ:", bq_hard - pg_hard)
