# envs/prod/platform-addons/providers.tf

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

  default_tags {
    tags = {
      Team        = "team1"
      Environment = "prod"
      Project     = "chatguard"
      Owner       = "infra-lead"
    }
  }
}

# ==============================================================================
# 1층 Prod Infra 레이어의 완공 결과물(Output) 동적 파싱선
# ==============================================================================
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "tfstate-lionkdt5-team1"
    key    = "team1/prod/infra/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ==============================================================================
# Kubernetes 공급자 설정 (Prod EKS 전용 터널링)
# ==============================================================================
provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks_cluster_certificate_authority) # 🟢 PR-1 출력명(eks_cluster_certificate_authority)과 정합

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.infra.outputs.eks_cluster_name, "--profile", "final"] # AWS_PROFILE=final (dev·prod 공통, CLAUDE.md §0)
    command     = "aws"
  }
}

# ==============================================================================
# Helm 차트 공급자 설정 (ArgoCD, KEDA 주입용 프로바이더)
# ==============================================================================
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks_cluster_certificate_authority) # 🟢 PR-1 출력명(eks_cluster_certificate_authority)과 정합

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.infra.outputs.eks_cluster_name, "--profile", "final"] # AWS_PROFILE=final (dev·prod 공통, CLAUDE.md §0)
      command     = "aws"
    }
  }
}
