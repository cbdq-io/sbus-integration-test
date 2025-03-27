resource "random_integer" "numeric_suffix" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.resource_name_prefix}-rg"
  location = var.location
}

resource "azurerm_servicebus_namespace" "sbns" {
  name                = local.sbns_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  # capacity                     = 1
  # premium_messaging_partitions = 1
}

resource "azurerm_servicebus_topic" "sbt_landing" {
  count = var.topic_count

  name                          = "landing.topic.${count.index}"
  auto_delete_on_idle           = "P14D"
  namespace_id                  = azurerm_servicebus_namespace.sbns.id
  max_message_size_in_kilobytes = null
  partitioning_enabled          = true
}

resource "azurerm_servicebus_subscription" "sbts_landing" {
  count = var.topic_count

  name               = "router"
  topic_id           = azurerm_servicebus_topic.sbt_landing[count.index].id
  max_delivery_count = 8
  requires_session   = true
}

resource "azurerm_servicebus_subscription" "sbts_archivist" {
  count = var.topic_count

  name               = "archivist"
  topic_id           = azurerm_servicebus_topic.sbt_landing[count.index].id
  max_delivery_count = 8
}

resource "azurerm_servicebus_topic" "sbt" {
  count = var.topic_count

  name                 = "routed.topic.${count.index}"
  auto_delete_on_idle  = "P14D"
  namespace_id         = azurerm_servicebus_namespace.sbns.id
  partitioning_enabled = true
}

resource "azurerm_servicebus_subscription" "client" {
  count = var.topic_count

  name               = "client"
  topic_id           = azurerm_servicebus_topic.sbt[count.index].id
  max_delivery_count = 8
  requires_session   = true
}

resource "azurerm_storage_account" "st" {
  name                     = format("%sarcsa${random_integer.numeric_suffix.result}", replace(local.resource_name_prefix, "-", ""))
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_replication_type = "LRS"
  account_tier             = "Standard"
}

resource "azurerm_storage_container" "landing_archive" {
  name                  = "landing-archive"
  storage_account_id    = azurerm_storage_account.st.id
  container_access_type = "private"
}

resource "azurerm_log_analytics_workspace" "log" {
  name                = "${local.resource_name_prefix}-log"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "sbns" {
  name                       = "${local.resource_name_prefix}-sbns"
  target_resource_id         = azurerm_servicebus_namespace.sbns.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id

  enabled_log {
    category = "OperationalLogs"
  }

  metric {
    category = "AllMetrics"
  }
}
