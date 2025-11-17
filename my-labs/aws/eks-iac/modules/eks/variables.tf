##################################
#   2025.11.16 - LMK
#   EKS 모듈 입력 변수 정의
##################################

# 공통 태그용
variable "project_name" {
  description = "프로젝트 명 prefix(태그/Name에 사용)"
  type = string
}

#EKS 클러스터 명/ 버전
variable "cluster_name" {
  description = "EKS 클러스터 명"
  type = string
}

variable "cluster_version" {
  description = "EKS Kubernetes 버전(예:1.30)"
  type = string
}

#네트워크 모듈에서 넘겨받는 값들
variable "vpc_id" {
  description = "EKS가 붙을 VPC ID"
  type = string
}

variable "worker_subnet_ids" {
  description = "EKS 워커 노드가 위치할 서브넷 ID목록(보통 private worker 서브넷)"
  type = list(string)
}

variable "cluster_additional_sg_ids" {
  description = "EKS Control Plane에 추가로 붙일 SG 목록(선택)"
  type = list(string)
  default = []
}

#EKS NodeGroup에 사용할 SG(Network 모듈에서 만들어진 node_sg_id)
variable "node_sg_id" {
  description = "EKS 워커 노드용 Security Group ID"
  type = string
}

#default NodeGroup 스펙
variable "node_instance_types_default" {
  description = "EKS default 워커 노드 인스턴스 타입 목록"
  type = list(string)
  default = ["t3.small"]
}

#app NodeGroup 스펙
variable "node_instance_types_app" {
  description = "EKS app 워커 노드 인스턴스 타입 목록"
  type = list(string)
  default = [ "t3.small" ]
}

#obs NodeGroup 스펙
variable "node_instance_types_obs" {
  description = "EKS obs 워커노드 인스턴스 타입 목록"
  type = list(string)
  default = [ "t3.medium" ]
}

variable "node_capacity_type" {
  description = "용량 타입(On_demand 또는 Spot)"
  type = string
  default = "ON_DEMAND"
}

variable "node_desired_size" {
  description = "NodeGroup desired 사이즈" 
  type = number
  default = 2
}

variable "node_min_size" {
  description = "NodeGorup 최소 노드 수"
  type = number
  default = 1
}

variable "node_max_size" {
  description = "NodeGroup 최대 노드 수"
  type = number
  default = 4
}

variable "node_disk_siez" {
  description = "워커 노드 EBS 디스크 사이즈(GiB)"
  type = number
  default = 30
}


################
# 태깅 추가
################
variable "common_tags" {
  description = "공통 태그(root에서 내려주는 태그)"
  type = map(string)
}