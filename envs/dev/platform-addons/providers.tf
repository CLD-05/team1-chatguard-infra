terraform {
  required_version = ">= 1.14.0, < 1.16.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "final"
}

data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "tfstate-lionkdt5-team1"
    key    = "team1/dev/infra/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks_cluster_certificate_authority)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.infra.outputs.eks_cluster_name, "--profile", "final"]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks_cluster_certificate_authority)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.infra.outputs.eks_cluster_name, "--profile", "final"]
      command     = "aws"
    }
  }
}
