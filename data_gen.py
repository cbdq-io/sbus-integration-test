#!/usr/bin/env python
"""A script to inject data into Kafka."""
import argparse
import json
import logging
import os
import sys

from random import choice, randrange
from string import ascii_uppercase

import lorem
from kafka import KafkaProducer
from kafka.errors import KafkaError

DEFAULT_MESSAGE_COUNT = 128_000
DEFAULT_TOPIC_COUNT = 10

MESSAGE_SIZES = [
    1024,
    4500,
    4800,
    5000,
    4116
]

PROG_NAME = os.path.basename(__file__)

logging.basicConfig()
logger = logging.getLogger(PROG_NAME)
logger.setLevel(logging.INFO)
parser = argparse.ArgumentParser(
    prog=PROG_NAME,
    description=__doc__
)
parser.add_argument(
    '-d', '--debug',
    help='Run in debug mode.',
    action='store_true'
)
args = parser.parse_args()

if args.debug:
    logger.setLevel(logging.DEBUG)

logger.info(
    f'Log level is {logging.getLevelName(logger.getEffectiveLevel())}.'
)

bootstrap_servers = ['localhost:9092']
producer = KafkaProducer(
    bootstrap_servers=bootstrap_servers,
    key_serializer=lambda k: k.encode('utf-8'),
    value_serializer=lambda v: v.encode('utf-8')

)
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
    payload = ''.join(
        choice(ascii_uppercase) for i in range(payload_size)  # nosec B311
    )
    record['payload'] = payload
    message = json.dumps(record)
    logger.debug(f'{len(message)} - {message}')
    future = producer.send(topic_name, message, key=str(i))

    try:
        record_metadata = future.get(timeout=10)
        logger.debug(
            f'Message {i:,} sent to {record_metadata.topic}-'
            f'{record_metadata.partition} with offset {record_metadata.offset:,}'
        )
    except KafkaError:
        logger.error("Failed to send message", exc_info=True)
        sys.exit(1)

    percentage_complete = round((i / DEFAULT_MESSAGE_COUNT) * 100, 0)

    if percentage_complete != last_reported_percentage:
        logger.info(f'Processed {i:,} messages of {DEFAULT_MESSAGE_COUNT} ({percentage_complete}%).')
        last_reported_percentage = percentage_complete
