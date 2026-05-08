output "ingress_hostname" {
  description = "Hostname do ALB criado pelo Ingress"
  value       = try(kubernetes_ingress_v1.app.status[0].load_balancer[0].ingress[0].hostname, "pending")
}
