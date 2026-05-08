# -------------------------------------------------------
# NetworkPolicy — namespace kunlatek
# -------------------------------------------------------

# 1. Bloqueia todo ingress por padrão
resource "kubernetes_network_policy_v1" "default_deny_ingress" {
  metadata {
    name      = "default-deny-ingress"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    pod_selector {} # aplica a todos os pods do namespace

    policy_types = ["Ingress"]
  }
}

# 2. Permite ingress vindo do ALB (porta 3000)
resource "kubernetes_network_policy_v1" "allow_alb_ingress" {
  metadata {
    name      = "allow-alb-ingress"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { app = "kunlatek-api" }
    }

    policy_types = ["Ingress"]

    ingress {
      ports {
        port     = "3000"
        protocol = "TCP"
      }
      # ALB usa IPs do VPC — libera o CIDR da VPC
      from {
        ip_block {
          cidr = "10.0.0.0/16"
        }
      }
    }
  }
}

# 3. Bloqueia todo egress por padrão
resource "kubernetes_network_policy_v1" "default_deny_egress" {
  metadata {
    name      = "default-deny-egress"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Egress"]
  }
}

# 4. Permite egress para o RDS (porta 3306) e Secrets Manager (HTTPS 443)
resource "kubernetes_network_policy_v1" "allow_egress" {
  metadata {
    name      = "allow-egress"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { app = "kunlatek-api" }
    }

    policy_types = ["Egress"]

    # RDS MySQL
    egress {
      ports {
        port     = "3306"
        protocol = "TCP"
      }
      to {
        ip_block {
          cidr = "10.0.0.0/16"
        }
      }
    }

    # Secrets Manager + ECR + AWS APIs (HTTPS)
    egress {
      ports {
        port     = "443"
        protocol = "TCP"
      }
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
    }

    # CoreDNS (resolução de nomes)
    egress {
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
      }
    }
  }
}
