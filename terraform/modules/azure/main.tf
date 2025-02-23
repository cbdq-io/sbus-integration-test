locals {
  archive_topic = "landing.topic.0"

  location_abbreviation = {
    "UK South" = "uks",
    "UK West"  = "ukw"
  }

  resource_name_prefix = "sbox-${local.location_abbreviation[var.location]}"
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.resource_name_prefix}-rg"
  location = var.location
}

resource "azurerm_servicebus_namespace" "sbns" {
  name                = "${local.resource_name_prefix}-sbns"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
}

resource "azurerm_servicebus_topic" "sbt_landing" {
  count = var.topic_count

  name                          = "landing.topic.${count.index}"
  namespace_id                  = azurerm_servicebus_namespace.sbns.id
  max_message_size_in_kilobytes = null
  partitioning_enabled          = true
}

resource "azurerm_servicebus_subscription" "sbts_landing" {
  count = var.topic_count

  name               = "router"
  topic_id           = azurerm_servicebus_topic.sbt_landing[count.index].id
  max_delivery_count = 1
}

resource "azurerm_servicebus_subscription" "sbts_archivist" {
  count = var.topic_count

  name               = "archivist"
  topic_id           = azurerm_servicebus_topic.sbt_landing[count.index].id
  max_delivery_count = 1
}

resource "azurerm_servicebus_topic" "sbt" {
  count = var.topic_count

  name                 = "topic.${count.index}"
  namespace_id         = azurerm_servicebus_namespace.sbns.id
  partitioning_enabled = true
}

resource "azurerm_servicebus_subscription" "sbts" {
  count = var.topic_count

  name               = "client"
  topic_id           = azurerm_servicebus_topic.sbt[count.index].id
  max_delivery_count = 1
}

resource "azurerm_storage_account" "sa" {
  name                     = format("%sarcsa", replace(local.resource_name_prefix, "-", ""))
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_replication_type = "LRS"
  account_tier             = "Standard"
}

resource "azurerm_storage_container" "landing_archive" {
  name                  = "landing-archive"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}
