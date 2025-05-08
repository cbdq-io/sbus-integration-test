terraform {
  required_version = "~> 1.10"
}

module "azure" {
  source = "./modules/azure"

  kafka_bootstrap = var.kafka_bootstrap
  kafka_password  = var.kafka_password
  location        = "UK South"
  sbns_capacity   = var.sbns_capacity
  subscription_id = var.subscription_id
  topic_count     = var.topic_count
}
