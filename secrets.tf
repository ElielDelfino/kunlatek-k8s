# -------------------------------------------------------
# Secrets Store CSI Driver
# -------------------------------------------------------

resource "helm_release" "secrets_store_csi" {
  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
  version    = "1.4.3"

  set {
    name  = "syncSecret.enabled"
    value = "true" # sincroniza como K8s Secret nativo
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }
}

resource "helm_release" "aws_secrets_provider" {
  name       = "aws-secrets-provider"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  version    = "0.3.9"

  depends_on = [helm_release.secrets_store_csi]
}

# -------------------------------------------------------
# ServiceAccount da aplicação com IRSA
# -------------------------------------------------------

resource "kubernetes_service_account_v1" "app" {
  metadata {
    name      = "kunlatek-api-sa"
    namespace = kubernetes_namespace_v1.this.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = data.terraform_remote_state.infra.outputs.secrets_csi_role_arn
    }
  }
}

# -------------------------------------------------------
# SecretProviderClass — mapeia o secret do AWS para o pod
# -------------------------------------------------------

resource "kubernetes_manifest" "secret_provider" {
  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"

    metadata = {
      name      = "kunlatek-api-secrets"
      namespace = local.namespace
    }

    spec = {
      provider = "aws"

      parameters = {
        objects = yamlencode([
          {
            objectName  = "kunlatek/app"
            objectType  = "secretsmanager"
            jmesPath = [
              { path = "DATABASE_URL",        objectAlias = "DATABASE_URL" },
              { path = "JWT_SECRET",          objectAlias = "JWT_SECRET" },
              { path = "GCS_PROJECT_ID",      objectAlias = "GCS_PROJECT_ID" },
              { path = "GCS_PUBLIC_BUCKET_NAME",  objectAlias = "GCS_PUBLIC_BUCKET_NAME" },
              { path = "GCS_PRIVATE_BUCKET_NAME", objectAlias = "GCS_PRIVATE_BUCKET_NAME" },
              { path = "GCS_CREDENTIALS",     objectAlias = "GCS_CREDENTIALS" },
              { path = "DATADOG_API_KEY",     objectAlias = "DATADOG_API_KEY" },
              { path = "SQS_WORKER_URL",      objectAlias = "SQS_WORKER_URL" },
            ]
          }
        ])
      }

      # Sincroniza como K8s Secret para uso via envFrom
      secretObjects = [
        {
          secretName = "kunlatek-api-secret"
          type       = "Opaque"
          data = [
            { objectName = "DATABASE_URL",        key = "DATABASE_URL" },
            { objectName = "JWT_SECRET",          key = "JWT_SECRET" },
            { objectName = "GCS_PROJECT_ID",      key = "GCS_PROJECT_ID" },
            { objectName = "GCS_PUBLIC_BUCKET_NAME",  key = "GCS_PUBLIC_BUCKET_NAME" },
            { objectName = "GCS_PRIVATE_BUCKET_NAME", key = "GCS_PRIVATE_BUCKET_NAME" },
            { objectName = "GCS_CREDENTIALS",     key = "GCS_CREDENTIALS" },
            { objectName = "DATADOG_API_KEY",     key = "DATADOG_API_KEY" },
            { objectName = "SQS_WORKER_URL",      key = "SQS_WORKER_URL" },
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.aws_secrets_provider]
}
