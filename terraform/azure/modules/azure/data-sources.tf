data "azurerm_servicebus_namespace" "sbns" {
  name                = local.sbns_name
  resource_group_name = azurerm_resource_group.rg.name
  depends_on          = [azurerm_servicebus_namespace.sbns]
}
