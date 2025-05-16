variable "kafka_bootstrap" {
  description = "The bootstrap server(s) for Kafka."
  type        = string
}

variable "kafka_password" {
  description = "The SASL password for Kafka."
  sensitive   = true
  type        = string
}

variable "sbns_capacity" {
  description = "The capacity for the Azure Service Bus namespace."
  default     = 2
  type        = number
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
