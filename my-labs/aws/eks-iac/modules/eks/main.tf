######################################
#   2025-11-16 - LMK
#   작성 내용
#   EKS Cluster IAM Role + 정책
#   EKS Node IAM Role + 정책
#   EKS Cluster Security Group
#   EKS Cluster
#   EKS NodeGroup(Managed)
######################################

####################################
#   1. EKS Cluster IAM Role
####################################

# 역할 생성
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"
  assume_role_policy = jsonencode(
    {
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "eks.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        ]
    }
  )
}

# 역할에 정책 Mapping 
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSServicePolicy" {
  role = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

####################################
#   2. EKS NodeGroup IAM Role
####################################

resource "aws_iam_role" "eks_node" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Principal = {
                Service = "ec2.amazonaws.com"
            }
            Action = "sts:AssumeRole"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
  role = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
  role = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
  role = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

####################################
#   3. EKS Cluster Security Group
####################################

resource "aws_security_group" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-sg"
  description = "Security group for EKS control plane endpoint"
  vpc_id = var.vpc_id

  #기본 VPC 전체에서 443으로 접근 허용
  # 더 조이고 싶으면 node_sg에서만 허용하도록 변경할 수 있음
  ingress {
    description = "Allow HTTPS from worker nodes SG"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    security_groups = [var.node_sg_id]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags,{
    Name = "${var.project_name}-eks-cluster-sg"
  })

}

####################################
#   4. EKS Cluster (Control Plane)
####################################
resource "aws_eks_cluster" "this" {
  name = var.cluster_name
  version = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    #EKS ENI가 생성될 서브넷들(worker 서브넷 재사용)
    subnet_ids = var.worker_subnet_ids

    #control plane sg + 필요시 추가 SG
    security_group_ids = concat([aws_security_group.eks_cluster.id],var.cluster_additional_sg_ids)
  
    endpoint_public_access = false # 퍼블릭 차단
    endpoint_private_access = true # 내부 접근용으로 활성화
  }

  kubernetes_network_config {
    #cluster_ip CIDR - 기본 값 쓰려면 생략 가능, 명시하고 싶으면 설정
    #service_ipv4_cidr = "192.10.0.0/16"
  }

  tags = var.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSServicePolicy
  ]
}

########################################
# 5. EKS Managed Node Group(app)
########################################

resource "aws_eks_node_group" "app" {
  cluster_name = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng-app"

  node_role_arn = aws_iam_role.eks_node.arn

  subnet_ids = var.worker_subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    min_size = var.node_min_size
    max_size = var.node_max_size
  }

  capacity_type = var.node_capacity_type # ON_DEMAND or Spot

  instance_types = var.node_instance_types_app

  disk_size = var.node_disk_siez

  //labels = var.node_lables

  labels = {
    role = "app"
    nodegroup = "app"
  }

  taint {
    key = "role"
    value = "app"
    effect = "NO_SCHEDULE"
  }

  tags = merge(var.common_tags,{
    Name = "${var.cluster_name}-ng-app"
  })

  depends_on = [ aws_eks_cluster.this,
  aws_iam_role_policy_attachment.eks_node_AmazonEC2ContainerRegistryReadOnly,
  aws_iam_role_policy_attachment.eks_node_AmazonEKS_CNI_Policy,
  aws_iam_role_policy_attachment.eks_node_AmazonEKSWorkerNodePolicy 
  ]
}

########################################
# 5. EKS Managed Node Group(obs)
########################################

resource "aws_eks_node_group" "obs" {
  cluster_name = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng-obs"

  node_role_arn = aws_iam_role.eks_node.arn

  subnet_ids = var.worker_subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    min_size = var.node_min_size
    max_size = var.node_max_size
  }

  capacity_type = var.node_capacity_type # ON_DEMAND or Spot

  instance_types = var.node_instance_types_obs

  disk_size = var.node_disk_siez

  //labels = var.node_lables

  labels = {
    role = "obs"
    nodegroup = "obs"
  }

  taint {
    key = "role"
    value = "obs"
    effect = "NO_SCHEDULE"
  }

  tags = merge(var.common_tags,{
    Name = "${var.cluster_name}-ng-obs"
  })

  depends_on = [ aws_eks_cluster.this,
  aws_iam_role_policy_attachment.eks_node_AmazonEC2ContainerRegistryReadOnly,
  aws_iam_role_policy_attachment.eks_node_AmazonEKS_CNI_Policy,
  aws_iam_role_policy_attachment.eks_node_AmazonEKSWorkerNodePolicy 
  ]
}

########################################
# 5. EKS Managed Node Group(default)
########################################

resource "aws_eks_node_group" "default" {
  cluster_name = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng-default"

  node_role_arn = aws_iam_role.eks_node.arn

  subnet_ids = var.worker_subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    min_size = var.node_min_size
    max_size = var.node_max_size
  }

  capacity_type = var.node_capacity_type # ON_DEMAND or Spot

  instance_types = var.node_instance_types_default

  disk_size = var.node_disk_siez

  //labels = var.node_lables

  tags = merge(var.common_tags,{
    Name = "${var.cluster_name}-ng-default"
  })

  depends_on = [ aws_eks_cluster.this,
  aws_iam_role_policy_attachment.eks_node_AmazonEC2ContainerRegistryReadOnly,
  aws_iam_role_policy_attachment.eks_node_AmazonEKS_CNI_Policy,
  aws_iam_role_policy_attachment.eks_node_AmazonEKSWorkerNodePolicy 
  ]
}

