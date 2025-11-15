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

output "mgmt_subent_ids" {
  description = "프라이빗 서브넷 ID 리스트(MGMT 노드용)"
  value       = [for s in aws_subnet.mgmt : s.id]
}

output "node_subent_ids" {
  description = "프라이빗 서브넷 ID 리스트(Worker 노드용)"
  value       = [for s in aws_subnet.worker : s.id]
}

output "db_subnet_ids"{
  description = "DB 서브넷 ID 리스트(DB용)"
  value = [for s in aws_subnet.db : s.id]
}

output "bastion_sg_id"{
  description = "Bastion Security Group ID"
  value = aws_security_group.bastion.id
}

output "mgmt_sg_id"{
  description = "MGMT Security Group ID"
  value = aws_security_group.mgmt.id
}

output "node_sg_id"{
  description = "Node Security Group ID"
  value = aws_security_group.node.id
}

output "public_route_table_id" {
  description = "퍼블릭 라우트 테이블 ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "프라이빗 라우트 테이블 ID"
  value       = [for s in aws_route_table.private : s.id]
}

output "bastion_public_ip"{
  description = "Bastion 퍼블릭 IP"
  value = aws_instance.bastion.public_ip
}

output "mgmt_private_ip" {
  description = "MGMT 프라이빗 IP"
  value = aws_instance.mgmt.private_ip
}

