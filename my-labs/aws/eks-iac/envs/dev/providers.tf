########################################
#   2025.11.15 -LMK
#    - module 분리 구조 작성
#   backend와 provider 정의
########################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  #처음엔 local backend로 (추후 S3로 변경)
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  #root 하위의 모듈에서 생성하는 리소스에 Tag가 자동으로 붙는다.
  default_tags {
    tags = local.common_tags
  }

}

