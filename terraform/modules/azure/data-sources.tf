data "azurerm_servicebus_namespace" "sbns" {
  name                = "${local.resource_name_prefix}-sbns"
  resource_group_name = azurerm_resource_group.rg.name
  depends_on          = [azurerm_servicebus_namespace.sbns]
}
