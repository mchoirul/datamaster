from google.cloud import bigquery
import os

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "YOUR_WORKSPACE/YOUR_KEY_FILE.json"
client = bigquery.Client(project='YOUR_PROJECT_ID')

print("=== Final Verification: Are the tables empty? ===")
q = "SELECT COUNT(*) as c FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver`"
print("Hard CDC Silver table count:", list(client.query(q).result())[0].c)

q = "SELECT COUNT(*) as c FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.customer_silver_soft`"
print("Soft CDC Silver table count:", list(client.query(q).result())[0].c)
