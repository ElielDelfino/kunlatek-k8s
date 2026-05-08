# k8s-desafiodevops

Terraform responsável por instalar os componentes Kubernetes e fazer o deploy da aplicação no EKS.

## Pré-requisitos

- `terraform apply` do `infra-desafiodevops` já executado
- Imagem da API enviada para o ECR

## Enviar imagem para o ECR

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 890871562295.dkr.ecr.us-east-1.amazonaws.com

docker build -t kunlatek-app ../api

docker tag kunlatek-app:latest 890871562295.dkr.ecr.us-east-1.amazonaws.com/kunlatek-app:latest

docker push 890871562295.dkr.ecr.us-east-1.amazonaws.com/kunlatek-app:latest
```

## Deploy

### 1. Inicializar

```bash
terraform init -reconfigure
```

### 2. Instalar Helm charts primeiro (obrigatório)

O `SecretProviderClass` e o `Deployment` dependem dos CRDs instalados pelos Helms.
Se der `apply` direto sem este passo, vai falhar.

```bash
terraform apply \
  -var="datadog_app_key=SUA_APP_KEY" \
  -target=kubernetes_namespace_v1.datadog \
  -target=helm_release.lbc \
  -target=helm_release.secrets_store_csi \
  -target=helm_release.aws_secrets_provider \
  -target=helm_release.cluster_autoscaler \
  -target=helm_release.datadog
```

### 3. Apply completo

```bash
terraform apply -var="datadog_app_key=SUA_APP_KEY"
```

## Variáveis

| Variável | Descrição | Default |
|---|---|---|
| `datadog_app_key` | Datadog Application Key (Organization Settings > Application Keys) | obrigatória |
| `app_image_tag` | Tag da imagem no ECR | `latest` |
| `app_replicas` | Número de réplicas do deployment | `2` |

## O que é instalado

- **AWS Load Balancer Controller** — cria o ALB via Ingress
- **Cluster Autoscaler** — escala os nodes automaticamente
- **Secrets Store CSI Driver** — sincroniza secrets do AWS Secrets Manager para o pod
- **Datadog Agent** — coleta métricas, logs e traces (APM)
- **Aplicação** — Deployment, Service, Ingress, HPA no namespace `kunlatek`
