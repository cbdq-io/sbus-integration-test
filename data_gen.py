#!/usr/bin/env python
"""A script to inject data into Kafka."""
import argparse
import logging
import os
import sys

import lorem
from kafka import KafkaProducer
from kafka.errors import KafkaError

DEFAULT_MESSAGE_COUNT = 10_000
DEFAULT_TOPIC_COUNT = 10
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
producer = KafkaProducer(bootstrap_servers=bootstrap_servers)

for i in range(DEFAULT_MESSAGE_COUNT):
    topic_number = i % DEFAULT_TOPIC_COUNT
    topic_name = f'topic.{topic_number}'
    message = lorem.sentence().encode()
    future = producer.send(topic_name, message)

    try:
        record_metadata = future.get(timeout=10)
        logger.debug(
            f'Message {i:,} sent to {record_metadata.topic}-'
            f'{record_metadata.partition} with offset {record_metadata.offset:,}'
        )
    except KafkaError:
        logger.error("Failed to send message", exc_info=True)
        sys.exit(1)
