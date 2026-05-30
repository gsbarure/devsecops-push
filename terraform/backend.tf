terraform {
  backend "s3" {
    bucket         = "devsecops-tfstate-REPLACE_WITH_ACCOUNT_ID"
    key            = "eks/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "devsecops-tfstate-lock"
    encrypt        = true
  }
  required_version = ">= 1.5.0"
  required_providers {
    aws        = { source = "hashicorp/aws";        version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes";  version = "~> 2.0" }
    helm       = { source = "hashicorp/helm";        version = "~> 2.0" }
  }
}

provider "aws" { region = var.aws_region }

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}
