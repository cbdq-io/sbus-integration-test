variable "archivist_image" {
  description = "The archivist image and tag."
  default     = "ghcr.io/cbdq-io/archivist:latest"
  type        = string
}

variable "kafka_bootstrap" {
  description = "The bootstrap server(s) for Kafka."
  type        = string
}

variable "kafka_password" {
  description = "The SASL password for Kafka."
  sensitive   = true
  type        = string
}

variable "kc_image" {
  description = "The Kafka Connect image and tag."
  default     = "ghcr.io/cbdq-io/kc-connectors:0.4.2"
  type        = string
}

variable "location" {
  description = "The Azure location to deploy resources into."
  type        = string
}

variable "router_image" {
  description = "The sbus-router image and tag."
  default     = "ghcr.io/cbdq-io/router:latest"
  type        = string
}

variable "router_instance_count" {
  description = "The number of instances of the sbus-router to deploy."
  default     = "3"
  type        = number
}

variable "sbns_capacity" {
  description = "The capacity for the Azure Service Bus namespace."
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
