terraform {
  required_version = "~> 1.10"
}

module "azure" {
  source = "./modules/azure"

  location        = "UK South"
  subscription_id = var.subscription_id
  topic_count     = var.topic_count
}

module "kafka" {
  source = "./modules/kafka"

  topic_count = var.topic_count
}
