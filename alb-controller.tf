locals {
  lbc_role_arn   = data.terraform_remote_state.infra.outputs.eks_lbc_role_arn
  cluster_name   = data.terraform_remote_state.infra.outputs.eks_cluster_name
}

# ServiceAccount com a IAM Role via IRSA
resource "kubernetes_service_account_v1" "lbc" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = local.lbc_role_arn
    }
  }
}

# Helm chart do AWS Load Balancer Controller
resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account_v1.lbc.metadata[0].name
  }

  depends_on = [kubernetes_service_account_v1.lbc]
}
