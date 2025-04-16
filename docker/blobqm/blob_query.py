import gzip
import io
import json
import os
from azure.storage.blob import BlobServiceClient

# Get environment variables
blob_prefix    = os.getenv("BLOB_PREFIX")
blob_root      = "topics/"
conn_str       = os.getenv("STORAGE_ACCOUNT_CONNECTION_STRING")
container_name = os.getenv("BLOB_CONTAINER_NAME")
prefix         = f"{blob_root.rstrip('/')}/{blob_prefix.lstrip('/')}"

# Validate required variables
if not conn_str:
    raise Exception("STORAGE_ACCOUNT_CONNECTION_STRING is not set")
if not container_name:
    raise Exception("BLOB_CONTAINER_NAME is not set")
if not blob_prefix:
    raise Exception("BLOB_PREFIX is not set")

# Connect to Blob Storage
blob_service_client = BlobServiceClient.from_connection_string(conn_str)
container_client    = blob_service_client.get_container_client(container_name)

# List blobs with specified prefix
print(f"Blobs in container '{container_name}' starting with prefix '{prefix}':")

for blob in container_client.list_blobs(name_starts_with=prefix):
    if not blob.name.endswith(".gz"):
        continue

    print(f"\nReading blob: {blob.name}")
    downloader  = container_client.download_blob(blob.name)
    blob_bytes  = downloader.readall()
    blob_stream = io.BytesIO(blob_bytes)

    with gzip.GzipFile(fileobj=blob_stream) as decompressed:
        for line in decompressed:
            try:
                data = json.loads(line.decode('utf-8'))
                print(f" - Timestamp: {data.get('create_timestamp')}, Msg #: {data.get('message_number')}")
            except Exception as e:
                print(f"   Skipping line (error: {e})")
