import os
import sys
from google.cloud import bigquery

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "YOUR_WORKSPACE/YOUR_KEY_FILE.json"
client = bigquery.Client(project='YOUR_PROJECT_ID')

def run_sql_file(filepath):
    print(f"\n{'='*80}\nExecuting: {filepath}\n{'='*80}")
    with open(filepath, 'r') as f:
        sql = f.read()
    
    # Split by semicolon to run statements sequentially and print their outputs
    statements = [s.strip() for s in sql.split(';') if s.strip()]
    
    for stmt in statements:
        if stmt.upper().startswith('--') or stmt == '':
            continue
            
        try:
            query_job = client.query(stmt)
            results = list(query_job.result())
            
            if not results:
                print("No results returned.")
                print("-" * 40)
                continue
                
            # Get column names
            columns = list(results[0].keys())
            
            # Print header
            header = " | ".join(f"{col:<30}" if "separator" not in col.lower() and "section" not in col.lower() else col for col in columns)
            if "section" not in header.lower() and "separator" not in header.lower() and "blank_line" not in header.lower():
                print(header)
                print("-" * len(header))
                
            # Print rows
            for row in results:
                row_str = " | ".join(f"{str(val):<30}" if "separator" not in columns[i].lower() and "section" not in columns[i].lower() else str(val) for i, val in enumerate(row))
                if "blank_line" not in columns[0].lower():
                    print(row_str)
            print("-" * 40)
            
        except Exception as e:
            print(f"Error executing statement:\n{stmt[:100]}...\n{e}")
            print("-" * 40)

if __name__ == "__main__":
    run_sql_file('YOUR_WORKSPACE/demo-datastream-append/demo/hard_validation_queries.sql')
    run_sql_file('YOUR_WORKSPACE/demo-datastream-append/demo/soft_validation_queries.sql')
