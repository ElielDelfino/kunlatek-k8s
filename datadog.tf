# -------------------------------------------------------
# Namespace do Datadog
# -------------------------------------------------------

resource "kubernetes_namespace_v1" "datadog" {
  metadata {
    name = "datadog"
  }
}

# -------------------------------------------------------
# Kubernetes Secret com a API Key do Datadog
# (lida do AWS Secrets Manager via data source)
# -------------------------------------------------------

data "aws_secretsmanager_secret" "app" {
  name = "kunlatek/app"
}

data "aws_secretsmanager_secret_version" "datadog_api_key" {
  secret_id = data.aws_secretsmanager_secret.app.id
}

locals {
  datadog_api_key = jsondecode(data.aws_secretsmanager_secret_version.datadog_api_key.secret_string)["DATADOG_API_KEY"]
}

resource "kubernetes_secret_v1" "datadog" {
  metadata {
    name      = "datadog-secret"
    namespace = kubernetes_namespace_v1.datadog.metadata[0].name
  }

  data = {
    api-key = local.datadog_api_key
  }
}

# -------------------------------------------------------
# Datadog Agent via Helm
# -------------------------------------------------------

resource "helm_release" "datadog" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = kubernetes_namespace_v1.datadog.metadata[0].name
  version    = "3.69.0"

  set {
    name  = "datadog.apiKeyExistingSecret"
    value = kubernetes_secret_v1.datadog.metadata[0].name
  }

  set {
    name  = "datadog.site"
    value = "datadoghq.com"
  }

  # Coleta de logs
  set {
    name  = "datadog.logs.enabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = "true"
  }

  # APM
  set {
    name  = "datadog.apm.portEnabled"
    value = "true"
  }

  # Métricas de processo
  set {
    name  = "datadog.processAgent.enabled"
    value = "true"
  }

  # Métricas Kubernetes (pods, nodes, HPA)
  set {
    name  = "datadog.kubeStateMetricsEnabled"
    value = "true"
  }

  # Cluster Agent (necessário para métricas de cluster e HPA)
  set {
    name  = "clusterAgent.enabled"
    value = "true"
  }

  set {
    name  = "clusterAgent.metricsProvider.enabled"
    value = "true"
  }

  depends_on = [kubernetes_secret_v1.datadog, helm_release.lbc]

  timeout = 600
}
