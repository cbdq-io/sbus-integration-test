resource "kafka_topic" "topic" {
  count = var.topic_count

  name               = "topic.${count.index}"
  replication_factor = 1
  partitions         = 4

  config = {
    "segment.ms"     = "20000"
    "cleanup.policy" = "delete"
  }
}
