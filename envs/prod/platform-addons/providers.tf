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
  profile = "final-prod"
}

# ==============================================================================
# 1층 Prod Infra 레이어의 완공 결과물(Output) 동적 파싱선
# ==============================================================================
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "team1-prod-tfstate"
    key    = "team1/prod/infra/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ==============================================================================
# Kubernetes 공급자 설정 (Prod EKS 전용 터널링)
# ==============================================================================
provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks_cluster_ca_certificate) # 🟢 1층 아웃풋 명칭 정합성 동기화

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.infra.outputs.eks_cluster_name, "--profile", "final-prod"] # 🟢 prod 프로파일 적용
    command     = "aws"
  }
}

# ==============================================================================
# Helm 차트 공급자 설정 (ArgoCD, KEDA 주입용 프로바이더)
# ==============================================================================
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks_cluster_ca_certificate) # 🟢 1층 아웃풋 명칭 정합성 동기화

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.infra.outputs.eks_cluster_name, "--profile", "final-prod"] # 🟢 prod 프로파일 적용
      command     = "aws"
    }
  }
}
