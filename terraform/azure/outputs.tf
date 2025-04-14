output "sbns_connection_string" {
  description = "The connection string for the Service Bus namespace."
  value       = module.azure.sbns_connection_string
  sensitive   = true
}

output "st_connection_string" {
  description = "The connection string for the Storage Account."
  value       = module.azure.st_connection_string
  sensitive   = true
}
