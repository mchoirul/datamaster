import os
from google.cloud import bigquery

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "YOUR_WORKSPACE/YOUR_KEY_FILE.json"
client = bigquery.Client(project='YOUR_PROJECT_ID')

def run_script(filepath):
    print(f"Executing: {filepath}")
    with open(filepath, 'r') as f:
        sql = f.read()
    
    # Split queries by semicolon to execute them in order
    queries = [q.strip() for q in sql.split(';') if q.strip()]
    
    for q in queries:
        try:
            job = client.query(q)
            results = job.result()
            
            # Print output if it's a SELECT query (like the validation metrics at the end of the script)
            if q.upper().startswith('SELECT') or (q.upper().startswith('WITH') and 'SELECT' in q.upper()):
                for row in results:
                    print(" | ".join(str(val) for val in row))
                    
        except Exception as e:
            print(f"Error executing statement:\n{e}")

print("--- Running Hard CDC SQL Merge ---")
run_script('YOUR_WORKSPACE/demo-datastream-append/demo/hard_bronze_to_silver_merge.sql')

print("\n--- Running Soft CDC SQL Merge ---")
run_script('YOUR_WORKSPACE/demo-datastream-append/demo/soft_bronze_to_silver_merge.sql')

print("\nMerge executions complete.")
