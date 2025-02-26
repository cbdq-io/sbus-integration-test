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
  name                     = format("%sarcsa${random_integer.numeric_suffix.result}", replace(local.resource_name_prefix, "-", ""))
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

resource "azurerm_log_analytics_workspace" "log" {
  name                = "${local.resource_name_prefix}-log"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "appi" {
  name                = "${local.resource_name_prefix}-appi"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.log.id
  application_type    = "web"
}

resource "azurerm_service_plan" "app_service_plan" {
  name                = "${local.resource_name_prefix}-asp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_function_app" "archivist" {
  name                 = "archivist${random_integer.numeric_suffix.result}"
  service_plan_id      = azurerm_service_plan.app_service_plan.id
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  storage_account_name = azurerm_storage_account.sa.name

  app_settings = {
    "CONTAINER_NAME"                      = azurerm_storage_container.landing_archive.name
    "DOCKER_CUSTOM_IMAGE_NAME"            = "ghcr.io/cbdq-io/func-sbt-to-blob:latest"
    "FUNCTIONS_WORKER_RUNTIME"            = "python"
    "PATH_FORMAT"                         = "year=YYYY/month=MM/day=dd/hour=HH"
    "SERVICE_BUS_CONNECTION_STRING"       = data.azurerm_servicebus_namespace.sbns.default_primary_connection_string
    "STORAGE_ACCOUNT_CONNECTION_STRING"   = azurerm_storage_account.sa.primary_connection_string
    "SUBSCRIPTION_NAME"                   = "archivist"
    "TIMER_SCHEDULE"                      = "0 */15 * * * *"
    "TOPIC_NAME"                          = local.archive_topic
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.appi.connection_string
  }
}
