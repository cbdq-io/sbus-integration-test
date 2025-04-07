terraform {
  required_providers {
    kafka = {
      source  = "Mongey/kafka"
      version = "0.8.3"
    }
  }

  required_version = "~> 1.10"
}

provider "kafka" {
  bootstrap_servers = ["localhost:9092"]
  tls_enabled       = false
}
