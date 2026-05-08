variable "app_image_tag" {
  type        = string
  description = "Tag da imagem da API no ECR"
  default     = "latest"
}

variable "app_replicas" {
  type    = number
  default = 2
}

variable "datadog_app_key" {
  type      = string
  sensitive = true
  description = "Datadog Application Key"
}
