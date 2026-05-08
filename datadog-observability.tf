# -------------------------------------------------------
# Dashboard — Kunlatek API
# -------------------------------------------------------

resource "datadog_dashboard" "kunlatek" {
  title       = "Kunlatek API — Overview"
  layout_type = "ordered"

  widget {
    group_definition {
      title       = "Status da API"
      layout_type = "ordered"

      widget {
        query_value_definition {
          title    = "Pods Running"
          autoscale = true
          request {
            q          = "sum:kubernetes.pods.running{kube_namespace:kunlatek}"
            aggregator = "last"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Requisições por segundo"
          request {
            q            = "sum:trace.express.request.hits{service:kunlatek-api}.as_rate()"
            display_type = "line"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Latência média (ms)"
          request {
            q            = "avg:trace.express.request.duration{service:kunlatek-api} * 1000"
            display_type = "line"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Taxa de erros (4xx/5xx)"
          request {
            q            = "sum:trace.express.request.errors{service:kunlatek-api}.as_rate()"
            display_type = "bars"
          }
        }
      }
    }
  }

  widget {
    group_definition {
      title       = "Uso de Recursos"
      layout_type = "ordered"

      widget {
        timeseries_definition {
          title = "CPU dos Pods (%)"
          request {
            q            = "avg:kubernetes.cpu.usage.total{kube_namespace:kunlatek} by {pod_name}"
            display_type = "line"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Memória dos Pods (MB)"
          request {
            q            = "avg:kubernetes.memory.rss{kube_namespace:kunlatek} by {pod_name} / 1048576"
            display_type = "line"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "HPA — Réplicas"
          request {
            q            = "max:kubernetes_state.hpa.current_replicas{kube_namespace:kunlatek}"
            display_type = "line"
          }
          request {
            q            = "max:kubernetes_state.hpa.desired_replicas{kube_namespace:kunlatek}"
            display_type = "line"
          }
        }
      }
    }
  }

  widget {
    group_definition {
      title       = "Nodes do Cluster"
      layout_type = "ordered"

      widget {
        timeseries_definition {
          title = "CPU dos Nodes (%)"
          request {
            q            = "avg:system.cpu.user{kube_cluster_name:kunlatek-eks} by {host}"
            display_type = "line"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Memória dos Nodes (%)"
          request {
            q            = "avg:system.mem.pct_usable{kube_cluster_name:kunlatek-eks} by {host}"
            display_type = "line"
          }
        }
      }
    }
  }
}

# -------------------------------------------------------
# Alertas (Monitors)
# -------------------------------------------------------

resource "datadog_monitor" "alta_latencia" {
  name    = "[kunlatek-api] Alta Latência"
  type    = "metric alert"
  message = "Latência da API acima de 200ms por mais de 2 minutos. @webhook-slack"

  query = "avg(last_2m):avg:trace.express.request.duration{service:kunlatek-api} * 1000 > 200"

  monitor_thresholds {
    critical = 200
    warning  = 150
  }

  notify_no_data    = false
  renotify_interval = 10
}

resource "datadog_monitor" "taxa_erro" {
  name    = "[kunlatek-api] Taxa de Erro Elevada"
  type    = "metric alert"
  message = "Taxa de erros acima de 1% por mais de 1 minuto. @webhook-slack"

  query = "sum(last_1m):sum:trace.express.request.errors{service:kunlatek-api}.as_rate() / sum:trace.express.request.hits{service:kunlatek-api}.as_rate() * 100 > 1"

  monitor_thresholds {
    critical = 1
    warning  = 0.5
  }

  notify_no_data    = false
  renotify_interval = 10
}

resource "datadog_monitor" "cpu_alta" {
  name    = "[kunlatek-eks] CPU Alta nos Nodes"
  type    = "metric alert"
  message = "CPU dos nodes acima de 80%. @webhook-slack"

  query = "avg(last_5m):avg:system.cpu.user{kube_cluster_name:kunlatek-eks} by {host} > 80"

  monitor_thresholds {
    critical = 80
    warning  = 70
  }

  notify_no_data    = false
  renotify_interval = 30
}

resource "datadog_monitor" "pods_reiniciando" {
  name    = "[kunlatek-api] Pods Reiniciando"
  type    = "metric alert"
  message = "Pods da kunlatek-api estão reiniciando. @webhook-slack"

  query = "sum(last_5m):sum:kubernetes.containers.restarts{kube_namespace:kunlatek} by {pod_name}.as_count() > 3"

  monitor_thresholds {
    critical = 3
    warning  = 1
  }

  notify_no_data    = false
  renotify_interval = 10
}
