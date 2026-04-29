from google.cloud import bigquery
import os

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "YOUR_WORKSPACE/YOUR_KEY_FILE.json"
client = bigquery.Client(project='YOUR_PROJECT_ID')

q = "SELECT DISTINCT customer_id FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze` WHERE customer_id IN (36, 37, 38, 7, 9, 42, 13, 46, 16, 17, 18, 48, 50, 21, 23, 24)"
found = set([row.customer_id for row in client.query(q).result()])
print("Found in Bronze:", found)
