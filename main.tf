locals {
  app_name  = "kunlatek-api"
  namespace = "kunlatek"
  image_uri = "${data.terraform_remote_state.infra.outputs.ecr_backend_repository_url}:${var.app_image_tag}"
}

# -------------------------------------------------------
# Namespace
# -------------------------------------------------------

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = local.namespace
  }

  # Garante que o LBC seja destruído DEPOIS do namespace
  # (e portanto depois do Ingress), para que o finalizer seja processado
  depends_on = [helm_release.lbc]
}

# -------------------------------------------------------
# Secret com variáveis sensíveis — SUBSTITUÍDO pelo Secrets Manager
# Mantido apenas como fallback local (docker-compose)
# -------------------------------------------------------

# resource "kubernetes_secret_v1" "app" { ... }

# -------------------------------------------------------
# Deployment
# -------------------------------------------------------

resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = local.app_name }
  }

  spec {
    replicas = var.app_replicas

    selector {
      match_labels = { app = local.app_name }
    }

    template {
      metadata {
        labels = {
          app                                   = local.app_name
          "tags.datadoghq.com/env"              = "dev"
          "tags.datadoghq.com/service"          = local.app_name
          "tags.datadoghq.com/version"          = var.app_image_tag
        }
        annotations = {
          "admission.datadoghq.com/enabled"     = "true"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.app.metadata[0].name

        # Volume CSI que busca os secrets do AWS Secrets Manager
        volume {
          name = "secrets-store"
          csi {
            driver            = "secrets-store.csi.k8s.io"
            read_only         = true
            volume_attributes = {
              secretProviderClass = kubernetes_manifest.secret_provider.manifest.metadata.name
            }
          }
        }

        container {
          name  = local.app_name
          image = local.image_uri

          port {
            container_port = 3000
          }

          # Lê as envs do K8s Secret sincronizado pelo CSI Driver
          env_from {
            secret_ref {
              name = "kunlatek-api-secret"
            }
          }

          # O volume precisa ser montado para o CSI Driver sincronizar o secret
          volume_mount {
            name       = "secrets-store"
            mount_path = "/mnt/secrets"
            read_only  = true
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 3000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 15
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.secret_provider]
}

# -------------------------------------------------------
# Service (ClusterIP — tráfego interno, ALB acessa via Ingress)
# -------------------------------------------------------

resource "kubernetes_service_v1" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    selector = { app = local.app_name }

    port {
      port        = 80
      target_port = 3000
    }

    type = "ClusterIP"
  }
}

# -------------------------------------------------------
# Ingress (AWS Load Balancer Controller)
# -------------------------------------------------------

resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"               = "alb"
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  # O LBC precisa estar rodando para processar o finalizer durante o destroy
  depends_on = [helm_release.lbc]
}

# -------------------------------------------------------
# HPA
# -------------------------------------------------------

resource "kubernetes_horizontal_pod_autoscaler_v2" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.app.metadata[0].name
    }

    min_replicas = 2
    max_replicas = 6

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}
