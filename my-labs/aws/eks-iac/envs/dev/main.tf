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
}


/*
module "eks" {
  source = "../../modules/eks"

  cluster_name = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id = module.network.vpc_id
  private_subnet02_ids = module.network.private_subent02_ids

  node_sg_id = module.network.node_sg_id
}

*/
