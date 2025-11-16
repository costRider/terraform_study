#############################
#   2025.11.16 - LMK
#   EKS 모듈에서 노출 시킬 값들
#
#############################

output "cluster_name"{ 
    description = "EKS 클러스터 이름"
    value = aws_eks_cluster.this.name
}

output "cluster_endpoint"{
    description = "EKS API 서버 엔드포인트 URL"
    value = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate"{
    description = "클러스터 CA 인증서 (base64)"
    value = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_role_arn"{
    description = "EKS 노드 IAM Role ARN"
    value = aws_iam_role.eks_node.arn
}

output "node_group_name"{
    description = "기본 NodeGroup 이름"
    value = aws_eks_node_group.default.node_group_name
}