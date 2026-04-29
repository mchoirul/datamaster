from google.cloud import datastream_v1
import os

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "YOUR_WORKSPACE/YOUR_KEY_FILE.json"

try:
    client = datastream_v1.DatastreamClient()
    parent = "projects/YOUR_PROJECT_ID/locations/us-central1"
    profiles = client.list_connection_profiles(parent=parent)
    for p in profiles:
        print(p.name)
except Exception as e:
    print(f"Error: {e}")
