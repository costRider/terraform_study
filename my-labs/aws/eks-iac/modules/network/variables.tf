#####
#
# 네트워크 변수 정의
#
####
# 네트워크 구성 시 변경 가능성이 있는 값들을 변수로 분리
# main.tf는 구조에 집중 terraform.tfvars는 환경별 값에 집중

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
  description = "퍼블릭 서브넷(Bastion) CIDR 목록(각 AZ용)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "mgmt_subnet_cidrs" {
  description = "MGMT(관리용EC2)용 CIDR 목록(각 AZ용)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "worker_subnet_cidrs" {
  description = "WorkerNode용 CIDR 목록(각 AZ용)"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "db_subnet_cidrs" {
  description = "Database용 CIDR 목록(각 AZ용)"
  type = list(string)
  default = [ "10.0.31.0/24","10.0.32.0/24" ]
}

variable "azs" {
  description = "사용할 AZ목록(퍼블릭/프라이빗 서브넷 매칭에 사용)"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "my_ip_cidr" {
  description = "로컬 공인 IP(SSH용)"
  type        = string
}

variable "bastion_ami_id" {
  description = "Bastion 용 AMI ID"
  type = string
}

variable "mgmt_ami_id" {
  description = "MGMT용 AMI ID"
  type = string
}

variable "instance_type_bastion" {
  description = "Bastion용 인스턴스 타입"
  type        = string
  default = "t3.micro"
}

variable "instance_type_mgmt" {
  description = "MGMT용 인스턴스 타입"
  type = string
  default = "t3.small"
}

variable "ssh_key_name" {
  description = "SSH 키페어"
  type        = string
}

################
# 태깅 추가
################
variable "common_tags" {
  description = "공통 태그(root에서 내려주는 태그)"
  type = map(string)
}