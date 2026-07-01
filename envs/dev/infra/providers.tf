terraform {
  required_version = ">= 1.14.0, < 1.16.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Team        = "team1"
      Environment = "dev"
      Project     = "chatguard"
      Owner       = "infra-lead"
    }
  }
}

# 1. 메인 열쇠: 기본적으로 모든 리소스는 서울에 만듭니다.
provider "aws" {
  region = "ap-northeast-2"
}

# 2. 서브 열쇠: 'aws.us_east_1'이라는 별명을 붙인 미국 버지니아 열쇠
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
