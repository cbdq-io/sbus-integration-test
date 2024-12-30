output "connection_string" {
  description = "The connection string for the Service Bus namespace."
  value       = data.azurerm_servicebus_namespace.sbns.default_primary_connection_string
  sensitive   = true
}
