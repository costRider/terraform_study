########################################################
# 2025.11.15 - LMK
# EKS 모듈에 넘길 값들
# EKS 모듈, EC2 모듈 등이 재사용하기 쉽게 필요한 값들을 출력
########################################################

output "vpc_id" {
  description = "생성된 VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 리스트"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subent01_ids" {
  description = "프라이빗 서브넷 ID 리스트(MGMT 노드용)"
  value       = [for s in aws_subnet.private01 : s.id]
}

output "private_subent02_ids" {
  description = "프라이빗 서브넷 ID 리스트(MGMT 노드용)"
  value       = [for s in aws_subnet.private02 : s.id]
}

output "public_route_table_id" {
  description = "퍼블릭 라우트 테이블 ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "프라이빗 라우트 테이블 ID"
  value       = aws_route_table.private.id
}
/*
output "bastion_instance_ips"{
    description = "퍼블릭 IP, 프라이빗 IP"
    value = [aws_instance.bastion.public_ip,aws_instance.bastion.private_ip]
}

output "mgmt_instance_ip"{
    description = "프라이빗 IP"
    value = aws_instance.management.private_ip
}
*/