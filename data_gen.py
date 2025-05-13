#!/usr/bin/env python
"""Reliable Kafka data injector."""
import argparse
import datetime
import json
import logging
import os
import time
from concurrent.futures import ThreadPoolExecutor
from random import choice, randrange
from string import ascii_uppercase
from threading import BoundedSemaphore, Lock
from kafka import KafkaProducer
from kafka.errors import KafkaTimeoutError
import lorem

# ---- Config ----
DEFAULT_MESSAGE_COUNT = 128_000
DEFAULT_TOPIC_COUNT = 10
MESSAGE_SIZES = [1024, 4500, 4800, 5000, 4116]
BATCH_SIZE = 100  # Messages per batch
MAX_RETRIES = 5
PROG_NAME = os.path.basename(__file__)

# ---- Logging ----
logging.basicConfig(format='%(asctime)s %(levelname)s:%(name)s:%(message)s',
                    datefmt='%Y-%m-%dT%H:%M:%S')
logger = logging.getLogger(PROG_NAME)
logger.setLevel(logging.INFO)

# ---- CLI ----
parser = argparse.ArgumentParser(prog=PROG_NAME, description=__doc__)
parser.add_argument('-d', '--debug', help='Run in debug mode.', action='store_true')
args = parser.parse_args()
if args.debug:
    logger.setLevel(logging.DEBUG)
logger.info(f'Log level is {logging.getLevelName(logger.getEffectiveLevel())}.')

# ---- Kafka Producer ----
producer = KafkaProducer(
    bootstrap_servers=os.getenv('KAFKA_BOOTSTRAP').split(','),
    security_protocol='SASL_SSL',
    sasl_mechanism='SCRAM-SHA-512',
    sasl_plain_username='sbox',
    sasl_plain_password=os.getenv('KAFKA_PASSWORD'),
    ssl_check_hostname=False,
    ssl_cafile='certs/ca.crt',
    value_serializer=lambda v: json.dumps(v).encode('utf-8'),
    key_serializer=lambda k: k.encode('utf-8'),
    linger_ms=5,
    batch_size=32768,
    compression_type='snappy',
    max_in_flight_requests_per_connection=10,
    buffer_memory=33554432,
    retries=MAX_RETRIES,
    retry_backoff_ms=500,
    max_block_ms=300000,
    request_timeout_ms=60000,
    acks=1
)

# ---- State Tracking ----
semaphore = BoundedSemaphore(500)
executor = ThreadPoolExecutor(max_workers=100)
futures = []
failed = 0
submitted = 0
failed_lock = Lock()
submitted_lock = Lock()
uk_record_number = randrange(DEFAULT_MESSAGE_COUNT)

# ---- Helpers ----
def generate_message(i):
    create_timestamp = datetime.datetime.now(datetime.UTC).isoformat().replace('+00:00', 'Z')
    country = 'UK' if i == uk_record_number else ('GB' if i % 2 == 0 else 'IE')
    message_size = MESSAGE_SIZES[i % len(MESSAGE_SIZES)]

    record = {
        'create_timestamp': create_timestamp,
        'message_number': i,
        'country': country,
        'text': lorem.sentence(),
        'payload': ''
    }

    json_record = json.dumps(record)
    payload_size = message_size - len(json_record)
    payload = ''.join(choice(ascii_uppercase) for _ in range(payload_size))
    record['payload'] = payload
    return record

def send_batch(topic, messages):
    global failed, submitted
    with semaphore:
        for msg in messages:
            retries = 0
            key = str(msg['message_number'])
            while retries < MAX_RETRIES:
                try:
                    future = producer.send(topic, key=key, value=msg)
                    with submitted_lock:
                        submitted += 1
                    futures.append(future)
                    break
                except KafkaTimeoutError as e:
                    retries += 1
                    time.sleep(1)
                    logger.warning(f"Retry {retries}/{MAX_RETRIES} for {topic}:{key} — {e}")
            else:
                with failed_lock:
                    failed += 1
                logger.error(f"Permanent failure sending {key} to {topic}")

# ---- Main Logic ----
start = time.time()
batch = []
batch_topic = None

for i in range(DEFAULT_MESSAGE_COUNT):
    topic = f'topic.{i % DEFAULT_TOPIC_COUNT}'
    msg = generate_message(i)

    if batch_topic is None:
        batch_topic = topic
    if topic != batch_topic or len(batch) >= BATCH_SIZE:
        executor.submit(send_batch, batch_topic, batch[:])
        batch = []
        batch_topic = topic

    batch.append(msg)

    if i % 1280 == 0 and i > 0:
        elapsed = time.time() - start
        logger.info(f"Submitted {i:,} of {DEFAULT_MESSAGE_COUNT:,} messages ({i * 100 // DEFAULT_MESSAGE_COUNT}%) | TPS: {i / elapsed:,.2f}")

# Final flush
if batch:
    executor.submit(send_batch, batch_topic, batch)

executor.shutdown(wait=True)
producer.flush()

# ---- Final Checks ----
duration = time.time() - start
if failed > 0 or submitted != DEFAULT_MESSAGE_COUNT:
    logger.critical(f"{failed} messages failed. {submitted} successfully submitted.")
    raise RuntimeError("Message loss detected.")
else:
    logger.info(f"All {submitted:,} messages sent successfully in {duration:.2f}s | Final TPS: {submitted / duration:,.2f}")
