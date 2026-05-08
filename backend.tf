terraform {
  backend "s3" {
    bucket         = "terraform-state-guinho-virginia"
    key            = "kunlatek/k8s/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}
