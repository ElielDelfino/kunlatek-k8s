locals {
  worker_name  = "kunlatek-worker"
  worker_image = "${data.terraform_remote_state.infra.outputs.ecr_backend_repository_url}:${var.app_image_tag}"
}

# -------------------------------------------------------
# Deployment do Worker SQS
# -------------------------------------------------------

resource "kubernetes_deployment_v1" "worker" {
  metadata {
    name      = local.worker_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = local.worker_name }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = local.worker_name }
    }

    template {
      metadata {
        labels = {
          app                          = local.worker_name
          "tags.datadoghq.com/env"     = "dev"
          "tags.datadoghq.com/service" = local.worker_name
          "tags.datadoghq.com/version" = var.app_image_tag
        }
        annotations = {
          "admission.datadoghq.com/enabled" = "true"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.app.metadata[0].name

        volume {
          name = "secrets-store"
          csi {
            driver    = "secrets-store.csi.k8s.io"
            read_only = true
            volume_attributes = {
              secretProviderClass = kubernetes_manifest.secret_provider.manifest.metadata.name
            }
          }
        }

        container {
          name    = local.worker_name
          image   = local.worker_image
          command = ["node", "dist/worker"]

          env_from {
            secret_ref {
              name = "kunlatek-api-secret"
            }
          }

          volume_mount {
            name       = "secrets-store"
            mount_path = "/mnt/secrets"
            read_only  = true
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.secret_provider]
}

# -------------------------------------------------------
# HPA baseado em CPU
# -------------------------------------------------------

resource "kubernetes_horizontal_pod_autoscaler_v2" "worker" {
  metadata {
    name      = local.worker_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.worker.metadata[0].name
    }

    min_replicas = 1
    max_replicas = 4

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
  }
}
