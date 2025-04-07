#!/usr/bin/env python
"""A script to inject data into Kafka."""
import argparse
import json
import logging
import os
import time

from random import choice, randrange
from string import ascii_uppercase

import lorem
from kafka import KafkaProducer

DEFAULT_MESSAGE_COUNT = 128_000
DEFAULT_TOPIC_COUNT = 10

MESSAGE_SIZES = [1024, 4500, 4800, 5000, 4116]
PROG_NAME = os.path.basename(__file__)

logging.basicConfig(
    format='%(asctime)s %(levelname)s:%(name)s:%(message)s',
    datefmt='%Y-%m-%dT%H:%M:%S',
)
logger = logging.getLogger(PROG_NAME)
logger.setLevel(logging.INFO)

parser = argparse.ArgumentParser(
    prog=PROG_NAME,
    description=__doc__
)
parser.add_argument('-d', '--debug', help='Run in debug mode.', action='store_true')
args = parser.parse_args()

if args.debug:
    logger.setLevel(logging.DEBUG)

logger.info(f'Log level is {logging.getLevelName(logger.getEffectiveLevel())}.')

producer = KafkaProducer(
    bootstrap_servers=os.getenv('KAFKA_BOOTSTRAP').split(','),
    security_protocol='SASL_SSL',
    sasl_mechanism='SCRAM-SHA-512',
    sasl_plain_username='sbox',
    sasl_plain_password=os.getenv('KAFKA_PASSWORD'),
    ssl_check_hostname=False,
    ssl_cafile='certs/ca.crt',
    value_serializer=lambda v: v.encode('utf-8'),
    key_serializer=lambda k: k.encode('utf-8'),
    linger_ms=10,
    batch_size=16384
)

start_time = time.time()
last_report_time = start_time
last_reported_percentage = 0
uk_record_number = randrange(DEFAULT_MESSAGE_COUNT)

for i in range(DEFAULT_MESSAGE_COUNT):
    topic_number = i % DEFAULT_TOPIC_COUNT
    topic_name = f'topic.{topic_number}'
    message_size = MESSAGE_SIZES[i % 5]

    if i == uk_record_number:
        country = 'UK'
    elif i % 2 == 0:
        country = 'GB'
    else:
        country = 'IE'

    record = {
        'message_number': i,
        'country': country,
        'text': lorem.sentence(),
        'payload': ''
    }
    json_record = json.dumps(record)
    payload_size = message_size - len(json_record)
    payload = ''.join(choice(ascii_uppercase) for _ in range(payload_size))  # nosec B311
    record['payload'] = payload
    message = json.dumps(record)

    logger.debug(f'{len(message)} - {message}')
    producer.send(topic_name, message, key=str(i))

    percentage_complete = round((i / DEFAULT_MESSAGE_COUNT) * 100, 0)

    if percentage_complete != last_reported_percentage:
        now = time.time()
        elapsed = now - last_report_time
        total_elapsed = now - start_time
        messages_since_last = (percentage_complete - last_reported_percentage) / 100 * DEFAULT_MESSAGE_COUNT
        tps = messages_since_last / elapsed if elapsed > 0 else 0
        cumulative_tps = i / total_elapsed if total_elapsed > 0 else 0

        logger.info(
            f'Processed {i:,} of {DEFAULT_MESSAGE_COUNT:,} messages '
            f'({percentage_complete}%) | '
            f'TPS (interval): {tps:,.2f} | TPS (cumulative): {cumulative_tps:,.2f}'
        )

        last_reported_percentage = percentage_complete
        last_report_time = now

flush_start = time.time()
producer.flush()
flush_duration = time.time() - flush_start
logger.info(f'Flush completed in {flush_duration:.2f} seconds')
