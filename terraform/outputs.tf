output "connection_string" {
  description = "The connection string for the Service Bus namespace."
  value       = module.azure.connection_string
  sensitive   = true
}

output "subscription_id" {
  description = "The subscription ID used."
  value       = var.subscription_id
  sensitive   = true
}
