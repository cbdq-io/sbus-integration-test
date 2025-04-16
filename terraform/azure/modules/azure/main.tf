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

resource "azurerm_storage_share" "certs_share" {
  name               = "certsshare"
  storage_account_id = azurerm_storage_account.st.id
  quota              = 5
}

resource "null_resource" "upload_certs" {
  count = length(local.cert_files)

  triggers = {
    filename = local.cert_files[count.index]
  }

  provisioner "local-exec" {
    command = <<EOT
      az storage file upload \
        --account-name ${azurerm_storage_account.st.name} \
        --account-key ${azurerm_storage_account.st.primary_access_key} \
        --share-name ${azurerm_storage_share.certs_share.name} \
        --source "${local.certs_abs_path}/${local.cert_files[count.index]}" \
        --path "${local.cert_files[count.index]}"
  EOT
  }
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

resource "azurerm_container_group" "kafka_connect" {
  name                = "kafka-connect"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"

  ip_address_type = "Public"
  dns_name_label  = "kafka-connect-${random_integer.numeric_suffix.result}"
  restart_policy  = "OnFailure"

  container {
    name     = "kafka-connect"
    image    = var.kc_image
    cpu      = "2.0"
    memory   = "4.0"
    commands = ["/etc/confluent/docker/run"]

    ports {
      port     = 8083
      protocol = "TCP"
    }

    ports {
      port     = 9400
      protocol = "TCP"
    }

    environment_variables = {
      CONNECT_CONFIG_STORAGE_TOPIC                  = "vault.infra.external.kafkaconnect.default.config"
      CONNECT_GROUP_ID                              = "external_kafka_connect_docker"
      CONNECT_KEY_CONVERTER                         = "org.apache.kafka.connect.storage.StringConverter"
      CONNECT_LOG4J_LOGGERS                         = "org.apache.qpid=DEBUG,io.cbdq=DEBUG,org.apache.kafka.connect.runtime.WorkerSinkTask=DEBUG,org.apache.kafka.clients.consumer.internals.Fetcher=TRACE"
      CONNECT_LOG4J_ROOT_LOGLEVEL                   = "INFO"
      CONNECT_OFFSET_STORAGE_TOPIC                  = "vault.infra.external.kafkaconnect.default.offset"
      CONNECT_REST_ADVERTISED_HOST_NAME             = "localhost"
      CONNECT_SASL_MECHANISM                        = "SCRAM-SHA-512"
      CONNECT_SASL_PLAIN_USERNAME                   = "sbox"
      CONNECT_SECURITY_PROTOCOL                     = "SASL_SSL"
      CONNECT_SSL_CAFILE                            = "/mnt/certs/ca.crt"
      CONNECT_SSL_CHECK_HOSTNAME                    = "false"
      CONNECT_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM = ""
      CONNECT_SSL_TRUSTSTORE_LOCATION               = "/mnt/certs/kafka-truststore.jks"
      CONNECT_STATUS_STORAGE_TOPIC                  = "vault.infra.external.kafkaconnect.default.status"
      CONNECT_VALUE_CONVERTER                       = "org.apache.kafka.connect.converters.ByteArrayConverter"
      KAFKA_OPTS                                    = "-Djava.security.auth.login.config=/mnt/certs/kafka-client-jaas.conf"
    }

    secure_environment_variables = {
      CONNECT_BOOTSTRAP_SERVERS       = var.kafka_bootstrap
      CONNECT_SASL_PLAIN_PASSWORD     = var.kafka_password
      CONNECT_SSL_TRUSTSTORE_PASSWORD = "changeit"
    }

    volume {
      name                 = "certvol"
      mount_path           = "/mnt/certs"
      read_only            = true
      share_name           = azurerm_storage_share.certs_share.name
      storage_account_name = azurerm_storage_account.st.name
      storage_account_key  = azurerm_storage_account.st.primary_access_key
    }
  }

  container {
    name   = "kccinit"
    image  = var.kc_image
    cpu    = "0.2"
    memory = "0.5"

    commands = ["/usr/local/bin/kccinit.py"]

    environment_variables = {
      CONNECTOR_AzureServiceBusSink_CONNECTOR_CLASS                                         = "io.cbdq.AzureServiceBusSinkConnector"
      CONNECTOR_AzureServiceBusSink_CONSUMER_OVERRIDE_AUTO_OFFSET_RESET                     = "earliest"
      CONNECTOR_AzureServiceBusSink_CONSUMER_OVERRIDE_SASL_MECHANISM                        = "SCRAM-SHA-512"
      CONNECTOR_AzureServiceBusSink_CONSUMER_OVERRIDE_SECURITY_PROTOCOL                     = "SASL_SSL"
      CONNECTOR_AzureServiceBusSink_CONSUMER_OVERRIDE_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM = ""
      CONNECTOR_AzureServiceBusSink_CONSUMER_OVERRIDE_SSL_TRUSTSTORE_LOCATION               = "/mnt/certs/kafka-truststore.jks"
      CONNECTOR_AzureServiceBusSink_CONSUMER_OVERRIDE_SSL_TRUSTSTORE_TYPE                   = "PKCS12"
      CONNECTOR_AzureServiceBusSink_ERRORS_LOG_ENABLE                                       = "true"
      CONNECTOR_AzureServiceBusSink_ERRORS_LOG_INCLUDE_MESSAGES                             = "true"
      CONNECTOR_AzureServiceBusSink_ERRORS_TOLERANCE                                        = "all"
      CONNECTOR_AzureServiceBusSink_RETRY_MAX_ATTEMPTS                                      = "5"
      CONNECTOR_AzureServiceBusSink_RETRY_WAIT_TIME_MS                                      = "1000"
      CONNECTOR_AzureServiceBusSink_SET_KAFKA_PARTITION_AS_SESSION_ID                       = "true"
      CONNECTOR_AzureServiceBusSink_TASKS_MAX                                               = "5"
      CONNECTOR_AzureServiceBusSink_TOPIC_RENAME_FORMAT                                     = "landing.$${topic}"
      CONNECTOR_AzureServiceBusSink_TOPICS                                                  = "topic.0,topic.1,topic.2,topic.3,topic.4,topic.5,topic.6,topic.7,topic.8,topic.9"
      KAFKA_CONNECT_ENDPOINT                                                                = "http://localhost:8083"
      LOG_LEVEL                                                                             = "DEBUG"
    }

    secure_environment_variables = {
      CONNECT_SASL_PLAIN_PASSWORD                                             = var.kafka_password
      CONNECT_SSL_TRUSTSTORE_PASSWORD                                         = "changeit"
      CONNECTOR_AzureServiceBusSink_AZURE_SERVICEBUS_CONNECTION_STRING        = data.azurerm_servicebus_namespace.sbns.default_primary_connection_string
      CONNECTOR_AzureServiceBusSink_CONSUMER_OVERRIDE_SASL_JAAS_CONFIG        = "org.apache.kafka.common.security.scram.ScramLoginModule required username='sbox' password='${var.kafka_password}';"
      CONNECTOR_AzureServiceBusSink_CONSUMER_OVERRIDE_SSL_TRUSTSTORE_PASSWORD = "changeit"
    }
  }

  diagnostics {
    log_analytics {
      log_type      = "ContainerInsights"
      workspace_id  = azurerm_log_analytics_workspace.log.workspace_id
      workspace_key = azurerm_log_analytics_workspace.log.primary_shared_key
    }
  }
}
