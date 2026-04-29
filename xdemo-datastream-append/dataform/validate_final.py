import json
from google.cloud import bigquery
import os

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "YOUR_WORKSPACE/YOUR_KEY_FILE.json"
client = bigquery.Client(project='YOUR_PROJECT_ID')

print("=== Hard CDC Results ===")
q = "SELECT COUNT(*) as c FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze`"
print("Bronze events:", list(client.query(q).result())[0].c)

q = "SELECT COUNT(*) as c FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver_dataform`"
print("Silver current state:", list(client.query(q).result())[0].c)

print("\n=== Soft CDC Results ===")
q = "SELECT COUNT(*) as c FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_soft_customer_bronze`"
print("Bronze events:", list(client.query(q).result())[0].c)

q = "SELECT COUNT(*) as c FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver_soft_dataform`"
print("Silver current active:", list(client.query(q).result())[0].c)
