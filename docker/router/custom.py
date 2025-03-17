"""Set the session ID for outgoing messages."""
import hashlib

from azure.servicebus import ServiceBusMessage
from azure.servicebus.aio import ServiceBusSender


async def custom_sender(sender: ServiceBusSender, topic_name: str, message_body: object, application_properties: dict):
    """
    Set the session ID as a string representation of an integer between 0 and 9.

    Parameters
    ----------
    sender : ServiceBusSender
        The sender to use to send the message.
    message_body : str | bytes
        The message body that is to be sent to the topic.
    application_properties : dict | None
        An optional set of properties that may have been set on the source message.
    """
    kafka_key = str(application_properties.get(b'__kafka_key'))
    i = int(hashlib.md5(kafka_key.encode()).hexdigest(), 16)
    session_id = str(i % 10)

    session_message = ServiceBusMessage(
        body=message_body,
        application_properties=application_properties,
        session_id=session_id
    )
    await sender.send_messages(message=session_message)
