import gzip
import io
import json
import os
from azure.storage.blob import BlobServiceClient
from collections import defaultdict, Counter
from pathlib import Path

# Get environment variables
blob_prefix       = os.getenv("BLOB_PREFIX")
conn_str          = os.getenv("STORAGE_ACCOUNT_CONNECTION_STRING")
container_name    = os.getenv("CONTAINER_NAME")
expected_messages = set(range(128000))  # 0 to 127999
topics_dir        = os.getenv("TOPICS_DIR")
prefix            = f"{topics_dir.rstrip('/')}/{blob_prefix.lstrip('/')}"

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

# Dictionary to hold all blob results
blob_results = defaultdict(list)

# Global tracking
global_msg_counter = Counter()

print(f"Scanning blobs under prefix: {prefix}\n")

for blob in container_client.list_blobs(name_starts_with=prefix):
    if not blob.name.endswith(".gz"):
        continue

    print(f"Reading blob: {blob.name}")
    downloader  = container_client.download_blob(blob.name)
    blob_bytes  = downloader.readall()
    blob_stream = io.BytesIO(blob_bytes)

    # Extract short filename (no path)
    short_name = Path(blob.name).name

    # Read and parse messages
    with gzip.GzipFile(fileobj=blob_stream) as decompressed:
        for line in decompressed:
            try:
                data       = json.loads(line.decode('utf-8'))
                msg_number = data.get("message_number")
                if msg_number is not None:
                    blob_results[short_name].append(msg_number)
                    global_msg_counter[msg_number] += 1
                    expected_messages.discard(msg_number)  # Remove if found
            except Exception as e:
                print(f"   Skipping line (error: {e})")

# 🔍 Per-blob Summary
print("\n📊 Per-Blob Summary:")
for blob_name, msg_numbers in blob_results.items():
    total  = len(msg_numbers)
    unique = len(set(msg_numbers))
    copies = total - unique
    print(f"- {blob_name}: {total} messages, {copies} duplicate(s)")

# 🔎 Global summary
total_messages     = sum(global_msg_counter.values())
unique_messages    = len(global_msg_counter)
duplicate_messages = total_messages - unique_messages
duplicates = [msg for msg, count in global_msg_counter.items() if count > 1]

print("\n🧮 Global Summary:")
print(f"- Total messages:              {total_messages}")
print(f"- Unique messages:             {unique_messages}")
print(f"- Duplicate messages (global): {duplicate_messages}")
print(f"- Duplicated message_numbers: {duplicates}")

# Belts and braces check
print("\n🛡️ Belts and Braces Check:")
if not expected_messages:
    print("- ✅ All expected message numbers (0 to 127999) are present.")
else:
    print(f"- ⚠️ Missing {len(expected_messages)} message number(s).")
    print(f"- Missing message numbers: {sorted(expected_messages)}")
