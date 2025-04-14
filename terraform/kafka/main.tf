resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.ns_name
  }
}

resource "helm_release" "strimzi" {
  name      = "strimzi-kafka-operator"
  namespace = kubernetes_namespace.ns.metadata[0].name
  chart     = "oci://quay.io/strimzi-helm/strimzi-kafka-operator"
  version   = "0.45.0"
  wait      = true
}

resource "kubernetes_manifest" "kafkanodepool_controller" {
  manifest = {
    "apiVersion" = "kafka.strimzi.io/v1beta2"
    "kind"       = "KafkaNodePool"
    "metadata" = {
      "labels" = {
        "strimzi.io/cluster" = "sbox"
      }
      "name"      = "controller"
      "namespace" = helm_release.strimzi.namespace
    }
    "spec" = {
      "replicas" = 3
      "resources" = {
        "limits" = {
          "cpu"    = "2"
          "memory" = "4Gi"
        }
        "requests" = {
          "cpu"    = "1"
          "memory" = "2Gi"
        }
      }
      "roles" = [
        "controller",
        "broker",
      ]
      "storage" = {
        "type" = "jbod"
        "volumes" = [
          {
            "id"            = 0
            "kraftMetadata" = "shared"
            "type"          = "ephemeral"
          },
        ]
      }
      "template" = {
        "pod" = {
          "topologySpreadConstraints" = [
            {
              "labelSelector" = {
                "matchLabels" = {
                  "strimzi.io/cluster" = "sbox"
                  "strimzi.io/name"    = "sbox-kafka"
                }
              }
              "maxSkew"           = 1
              "topologyKey"       = "kubernetes.io/hostname"
              "whenUnsatisfiable" = "DoNotSchedule"
            },
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "kafka_sbox" {
  manifest = {
    "apiVersion" = "kafka.strimzi.io/v1beta2"
    "kind"       = "Kafka"
    "metadata" = {
      "annotations" = {
        "strimzi.io/kraft"      = "enabled"
        "strimzi.io/node-pools" = "enabled"
      }
      "name"      = "sbox"
      "namespace" = var.ns_name
    }
    "spec" = {
      "entityOperator" = {
        "topicOperator" = {}
        "userOperator"  = {}
      }
      "kafka" = {
        "authorization" = {
          "type" = "simple"
        }
        "config" = {
          "default.replication.factor"               = 3
          "log.flush.interval.messages"              = 10000
          "log.flush.interval.ms"                    = 1000
          "min.insync.replicas"                      = 2
          "num.io.threads"                           = 12
          "num.network.threads"                      = 8
          "offsets.topic.replication.factor"         = 3
          "queued.max.requests"                      = 1000
          "transaction.state.log.min.isr"            = 2
          "transaction.state.log.replication.factor" = 3
        }
        "listeners" = [
          {
            "configuration" = {
              "useServiceDnsDomain" = true
            }
            "name" = "plain"
            "port" = 9092
            "tls"  = false
            "type" = "internal"
          },
          {
            "name" = "tls"
            "port" = 9093
            "tls"  = true
            "type" = "internal"
          },
          {
            "authentication" = {
              "type" = "scram-sha-512"
            }
            "name" = "external"
            "port" = 9094
            "tls"  = true
            "type" = "nodeport"
          },
        ]
        "metadataVersion" = "3.9-IV0"
        "version"         = "3.9.0"
      }
    }
  }

  depends_on = [kubernetes_manifest.kafkanodepool_controller]

  wait {
    fields = {
      "status.conditions[0].type"   = "Ready"
      "status.conditions[0].status" = "True"
    }
  }
}

resource "kubernetes_manifest" "kafkatopic_vault_infra_external_kafkaconnect_default_config" {
  manifest = {
    "apiVersion" = "kafka.strimzi.io/v1beta2"
    "kind"       = "KafkaTopic"
    "metadata" = {
      "labels" = {
        "strimzi.io/cluster" = "sbox"
      }
      "name"      = "vault.infra.external.kafkaconnect.default.config"
      "namespace" = var.ns_name
    }
    "spec" = {
      "config" = {
        "cleanup.policy" = "compact"
      }
      "partitions" = 1
      "replicas"   = 3
    }
  }

  wait {
    fields = {
      "status.conditions[0].type"   = "Ready"
      "status.conditions[0].status" = "True"
    }
  }

  depends_on = [kubernetes_manifest.kafka_sbox]
}

resource "kubernetes_manifest" "kafkatopic_vault_infra_external_kafkaconnect_default_offset" {
  manifest = {
    "apiVersion" = "kafka.strimzi.io/v1beta2"
    "kind"       = "KafkaTopic"
    "metadata" = {
      "labels" = {
        "strimzi.io/cluster" = "sbox"
      }
      "name"      = "vault.infra.external.kafkaconnect.default.offset"
      "namespace" = var.ns_name
    }
    "spec" = {
      "config" = {
        "cleanup.policy" = "compact"
      }
      "partitions" = 25
      "replicas"   = 3
    }
  }

  wait {
    fields = {
      "status.conditions[0].type"   = "Ready"
      "status.conditions[0].status" = "True"
    }
  }

  depends_on = [kubernetes_manifest.kafka_sbox]
}

resource "kubernetes_manifest" "kafkatopic_vault_infra_external_kafkaconnect_default_status" {
  manifest = {
    "apiVersion" = "kafka.strimzi.io/v1beta2"
    "kind"       = "KafkaTopic"
    "metadata" = {
      "labels" = {
        "strimzi.io/cluster" = "sbox"
      }
      "name"      = "vault.infra.external.kafkaconnect.default.status"
      "namespace" = var.ns_name
    }
    "spec" = {
      "config" = {
        "cleanup.policy" = "compact"
      }
      "partitions" = 5
      "replicas"   = 3
    }
  }

  wait {
    fields = {
      "status.conditions[0].type"   = "Ready"
      "status.conditions[0].status" = "True"
    }
  }

  depends_on = [kubernetes_manifest.kafka_sbox]
}

resource "kubernetes_manifest" "kafkatopic_topics" {
  count = 10

  manifest = {
    "apiVersion" = "kafka.strimzi.io/v1beta2"
    "kind"       = "KafkaTopic"
    "metadata" = {
      "labels" = {
        "strimzi.io/cluster" = "sbox"
      }
      "name"      = "topic.${count.index}"
      "namespace" = var.ns_name
    }
    "spec" = {
      "partitions" = 4
      "replicas"   = 3
    }
  }

  wait {
    fields = {
      "status.conditions[0].type"   = "Ready"
      "status.conditions[0].status" = "True"
    }
  }

  depends_on = [kubernetes_manifest.kafka_sbox]
}

resource "kubernetes_manifest" "kafkauser_sbox" {
  manifest = {
    "apiVersion" = "kafka.strimzi.io/v1beta2"
    "kind"       = "KafkaUser"
    "metadata" = {
      "labels" = {
        "strimzi.io/cluster" = "sbox"
      }
      "name"      = "sbox"
      "namespace" = var.ns_name
    }
    "spec" = {
      "authentication" = {
        "type" = "scram-sha-512"
      }
      "authorization" = {
        "acls" = [
          {
            "operations" = [
              "Describe",
              "Read"
            ]
            "resource" = {
              "name"        = "connect-"
              "patternType" = "prefix"
              "type"        = "group"
            }
          },
          {
            "operations" = [
              "Describe",
              "Read",
              "Write"
            ]
            "resource" = {
              "name"        = "topic."
              "patternType" = "prefix"
              "type"        = "topic"
            }
          },
          {
            "operations" = [
              "Describe",
              "DescribeConfigs",
              "Read",
              "Write",
            ]
            "resource" = {
              "name"        = "vault."
              "patternType" = "prefix"
              "type"        = "topic"
            }
          },
          {
            "operations" = [
              "Read",
            ]
            "resource" = {
              "name"        = "external_kafka_connect_docker"
              "patternType" = "literal"
              "type"        = "group"
            }
          },
        ]
        "type" = "simple"
      }
    }
  }

  wait {
    fields = {
      "status.conditions[0].type"   = "Ready"
      "status.conditions[0].status" = "True"
    }
  }

  depends_on = [kubernetes_manifest.kafkatopic_topics]
}
