#!/usr/bin/env python
"""Reliable Kafka data injector."""
import argparse
import datetime
import json
import logging
import os
import sys
import time
from random import choice, randrange
from string import ascii_uppercase

import lorem
from confluent_kafka import Producer, Message, KafkaError

# ---- Config ----
DEFAULT_MESSAGE_COUNT = 1_000_000
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
payloads = {}

# ---- Kafka Producer ----
conf = {
    'bootstrap.servers': os.getenv('KAFKA_BOOTSTRAP'),
    'security.protocol': 'SASL_SSL',
    'sasl.mechanisms': 'SCRAM-SHA-512',
    'sasl.username': 'sbox',
    'sasl.password': os.getenv('KAFKA_PASSWORD'),
    'ssl.ca.location': './certs/ca.crt',
    'enable.ssl.certificate.verification': False,
    'message.max.bytes': 4194304,

    # Reliability
    'acks': '1',  # or 'all' for strongest delivery guarantee
    'retries': MAX_RETRIES,
    'retry.backoff.ms': 500,

    # Performance
    'linger.ms': 10,              # small delay to allow batching
    'batch.num.messages': 1000,   # max messages per batch
    'queue.buffering.max.kbytes': 10240,  # default 4MB, increase if needed
    'queue.buffering.max.messages': 100000,
    'message.send.max.retries': 5,
    'compression.type': 'none',

    # Timeouts
    'request.timeout.ms': 60000,
    'delivery.timeout.ms': 120000,  # total time to deliver before error
}
producer = Producer(conf)

uk_record_number = randrange(DEFAULT_MESSAGE_COUNT)
submitted = 0


def delivery_report(err, msg):
    global submitted

    if err is not None:
        logger.error(f"Message delivery failed: {err}")
    else:
        submitted += 1


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

    if country == 'UK':
        logger.info('Creating large random message')
        payload_size = 3_750_000
        payload = ''.join(choice(ascii_uppercase) for _ in range(payload_size))
    elif payload_size in payloads:
        payload = payloads[payload_size]
    else:
        payload = ''.join(choice(ascii_uppercase) for _ in range(payload_size))
        payloads[payload_size] = payload

    record['payload'] = payload
    return record


# ---- Main Logic ----
start = time.time()

for i in range(DEFAULT_MESSAGE_COUNT):
    topic = f'topic.{i % DEFAULT_TOPIC_COUNT}'
    msg = generate_message(i)

    while True:
        try:
            producer.produce(
                topic=topic,
                key=str(i),
                value=json.dumps(msg),
                callback=delivery_report
            )
            break  # success
        except BufferError:
            producer.poll(0.1)  # Wait and clear events
        except Exception as e:
            logger.error(f"Produce failed for message {i}: {e}")
            break

    if i % 1000 == 0 and i > 0:
        producer.poll(0)
        elapsed = time.time() - start
        logger.info(f"Submitted {i:,} of {DEFAULT_MESSAGE_COUNT:,} messages ({i * 100 // DEFAULT_MESSAGE_COUNT}%) | TPS: {i / elapsed:,.2f}")

producer.flush(timeout=60)
duration = time.time() - start

if submitted == DEFAULT_MESSAGE_COUNT:
    logger.info(f"All {submitted:,} messages sent successfully in {duration:.2f}s | Final TPS: {submitted / duration:,.2f}")
else:
    logger.error(f'There were {DEFAULT_MESSAGE_COUNT:,} messages sent, but only {submitted:,} were acknowledged.')
    sys.exit(1)
