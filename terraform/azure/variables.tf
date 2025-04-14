variable "kafka_bootstrap" {
  description = "The bootstrap server(s) for Kafka."
  type        = string
}

variable "kafka_password" {
  description = "The SASL password for Kafka."
  sensitive   = true
  type        = string
}

variable "subscription_id" {
  description = "The Azure subscription ID to be used."
  type        = string
  sensitive   = true
}

variable "topic_count" {
  description = "The number of topics to be created."
  type        = number
  default     = 10
}
