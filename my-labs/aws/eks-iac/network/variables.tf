#####
#
# 네트워크 변수 정의
#
####
# 네트워크 구성 시 변경 가능성이 있는 값들을 변수로 분리
# main.tf는 구조에 집중 terraform.tfvars는 환경별 값에 집중

variable "aws_region" {
  description = "리소스를 생성할 AWS 리전(예: ap-northeast-2)"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트 명 prefix(태그/이름에 사용)"
  type        = string
  default     = "persoanl-eks"
}

variable "cluster_name" {
  description = "EKS 클러스터 이름(서브넷 태그에 사용)"
  type        = string
  default     = "k8s-eks"
}

variable "vpc_cidr" {
  description = "VPC CIDR대역(추후 서브넷 쪼개기 기준)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 목록(각 AZ용)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 목록(각 AZ용)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "azs" {
  description = "사용할 AZ목록(퍼블릭/프라이빗 서브넷 매칭에 사용)"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}
