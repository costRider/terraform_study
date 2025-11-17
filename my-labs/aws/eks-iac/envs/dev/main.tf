####################################################
#   2025.11.15 - LMK
#    - 모듈 호출
#   network, eks
####################################################

module "network" {
  source = "../../modules/network"
  # 위 변수들 그대로 전달
  project_name          = var.project_name
  cluster_name          = var.cluster_name
  vpc_cidr              = var.vpc_cidr
  azs                   = var.azs
  public_subnet_cidrs   = var.public_subnet_cidrs
  mgmt_subnet_cidrs     = var.mgmt_subnet_cidrs
  worker_subnet_cidrs   = var.worker_subnet_cidrs
  db_subnet_cidrs       = var.db_subnet_cidrs
  my_ip_cidr            = var.my_ip_cidr
  bastion_ami_id        = var.bastion_ami_id
  mgmt_ami_id           = var.mgmt_ami_id
  instance_type_bastion = var.instance_type_bastion
  instance_type_mgmt    = var.instance_type_mgmt
  ssh_key_name          = var.ssh_key_name

  common_tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  project_name    = var.project_name
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id            = module.network.vpc_id
  worker_subnet_ids = module.network.node_subent_ids

  #network 모듈에서 output한 node_sg_id 사용
  node_sg_id = module.network.node_sg_id

  #필요하면 ALB SG나 추가 SG를 여기 리스트로 전달
  cluster_additional_sg_ids = []

  node_instance_types_default = var.node_instance_types_default
  node_instance_types_app     = var.node_instance_types_app
  node_instance_types_obs     = var.node_instance_types_obs

  node_capacity_type = var.node_capacity_type
  node_desired_size  = var.node_desired_size
  node_disk_siez     = var.node_disk_siez
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size

  common_tags = local.common_tags

}


