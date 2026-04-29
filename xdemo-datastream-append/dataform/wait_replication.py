from google.cloud import bigquery
import os
import time

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "YOUR_WORKSPACE/YOUR_KEY_FILE.json"
client = bigquery.Client(project='YOUR_PROJECT_ID')

def check_counts():
    q1 = "SELECT COUNT(*) as c FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_customer_bronze`"
    q2 = "SELECT COUNT(*) as c FROM `YOUR_PROJECT_ID.YOUR_DATASET_ID.public_soft_customer_bronze`"
    
    c1 = list(client.query(q1).result())[0].c
    c2 = list(client.query(q2).result())[0].c
    return c1, c2

print("Waiting for Datastream to replicate new simulation events...")
while True:
    c1, c2 = check_counts()
    print(f"Current Bronze Counts -> Hard: {c1} (Target: ~319), Soft: {c2} (Target: ~308)")
    if c1 >= 319 and c2 >= 308:
        print("Replication complete!")
        break
    time.sleep(10)
