import json
from google.cloud import bigquery
import os

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "YOUR_WORKSPACE/YOUR_KEY_FILE.json"
client = bigquery.Client(project='YOUR_PROJECT_ID')

with open('YOUR_WORKSPACE/demo-datastream-append/dataform/compiled.json', 'r') as f:
    compiled = json.load(f)

# Run operations
print("Running Dataform operations...")
for target in compiled['tables']:
    name = target['target']['name']
    print(f"\nProcessing {name}...")
    
    # 1. Run pre_operations
    if 'preOps' in target:
        for pre_op in target['preOps']:
            print(f"Executing pre_operation...")
            # We need to handle the case where the table doesn't exist yet for pre_operations
            # If the query fails due to table not found, we ignore it for the first run
            try:
                job = client.query(pre_op)
                job.result()
                print("pre_operation succeeded.")
            except Exception as e:
                if "Not found" in str(e):
                    print("Table does not exist yet. Skipping pre_operation.")
                else:
                    raise e
                    
    # 2. Run the main query
    # Since Dataform CLI manages the actual MERGE logic generation from the SELECT, 
    # but `compiled.json` only contains the raw SELECT, we might need to construct the MERGE
    # Wait, compiled.json might contain the full generated MERGE in the `query` field?
    # Let's see what compiled.json has.
