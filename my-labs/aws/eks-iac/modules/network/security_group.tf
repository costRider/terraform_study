########################################
# 2025.11.15 - LMK
# - EC2(퍼블릭 서브넷)에 달릴 보안그룹
# - SSH 22번 포트만 내 IP에서 허용
########################################

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "SSH Allow Bastion"
  vpc_id      = aws_vpc.this.id

  # SSH를 내 IP에서만 허용
  ingress {
    description = "Allow SSH From MyIP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  #아웃바운드는 전체 허용(필수)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags,{
    Name    = "${var.project_name}-bastion-sg"
  })

}

#MGMT - Bastion에서만 SSH 허용
resource "aws_security_group" "mgmt" {
  name = "${var.project_name}-mgmt-sg"
  description = "SSH From bastion to MGMT"
  vpc_id = aws_vpc.this.id

  ingress {
    description = "Allow SSH from bastion SG"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags,{
    Name = "${var.project_name}-mgmt-sg"
  })
}

########################################
# Private Node 보안그룹
# - EKS NodeGroup 또는 Private EC2에 적용될 SG default
# - 내부 통신은 VPC 내부에서 전부 허용
########################################

resource "aws_security_group" "node" {
  name        = "${var.project_name}-node-sg"
  description = "Private node security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow all inbound traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags,{
    Name    = "${var.project_name}-node-sg"
  })
}

