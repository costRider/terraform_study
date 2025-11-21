########################################
#   2025-11-21 - LMK
#   강의 실습
#   2 tier 서비스 구성
########################################

##################################
# VPC/SUBNET 생성
##################################

resource "aws_vpc" "web" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "tf-web"
  }
}

resource "aws_subnet" "web_a" {
  vpc_id                  = aws_vpc.web.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "tf-web-a"
  }
}

resource "aws_subnet" "web_c" {
  vpc_id                  = aws_vpc.web.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = {
    Name = "tf-web-c"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.web.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "tf-private-a"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.web.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "tf-private-c"
  }
}

##################################
# VPC/SUBNET 생성 종료
##################################

#############################
# WEB/WAS 인스턴스 생성
#############################

# foreach group을 만들기 위한 local 묶음(타겟그룹 사용위함)
locals {
  web_instances = {
    web01 = "ap-northeast-2a"
    web02 = "ap-northeast-2c"
  }
}

resource "aws_instance" "web" {
  for_each = local.web_instances

  ami                    = var.image_id
  instance_type          = var.instance_type
  subnet_id              = each.value == "ap-northeast-2a" ? aws_subnet.web_a.id : aws_subnet.web_c.id
  vpc_security_group_ids = [aws_security_group.lb_security.id]
  key_name               = aws_key_pair.my-keypair.key_name

  user_data = templatefile("${path.module}/userdata-proxy.tftpl", {
    backend_host = aws_instance.private01.private_ip #프록시 할 서버
    lb_port      = tostring(var.lb_port)             # nginx가 listen 할 포트
    backend_port = tostring(var.server_port)         # 뒤에서 띄울 앱 포트 (동일 인스턴스 or 다른 곳)
  })

  user_data_replace_on_change = true
  depends_on                  = [aws_instance.private01]
  tags = {
    Name = "tf-${each.key}"
  }
}

resource "aws_instance" "private01" {
  ami                    = var.image_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_c.id
  vpc_security_group_ids = [aws_security_group.private.id]

  user_data = templatefile("${path.module}/userdata-wasserver.tftpl", {
    db_host = aws_db_instance.petclinic.address,
    db_user = var.db_user,
    db_pass = var.db_pass
  })

  user_data_replace_on_change = true

  key_name = aws_key_pair.my-keypair.key_name

  tags = {
    Name = "tf-private"
  }
}

#############################
# WEB/WAS 인스턴스 생성 종료
#############################

#############################
# RDS 생성
#############################

#서브넷 생성
resource "aws_db_subnet_group" "petclinic" {
  name       = "petclinic-db-subnet"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_c.id]

  tags = {
    Name = "petclinic-db-subnet"
  }
}

#인스턴스 생성
resource "aws_db_instance" "petclinic" {
  identifier        = "petclinic-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_subnet_group_name   = aws_db_subnet_group.petclinic.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  db_name  = "petclinic"
  username = var.db_user
  password = var.db_pass
  port     = 3306

  skip_final_snapshot = true

  publicly_accessible = false
}

#############################
# RDS 생성 종료
#############################


#############################
# LB 생성
#############################

resource "aws_lb" "alb" {
  name               = var.lb_name
  load_balancer_type = "application"
  subnets = [
    aws_subnet.web_a.id,
    aws_subnet.web_c.id,
  ]
  security_groups = [aws_security_group.lb_security.id]
}

# 리스너
resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = var.lb_port
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: not found"
      status_code  = "404"
    }
  }

}

#타겟 그룹
resource "aws_lb_target_group" "target" {
  name                 = "tf-lb-alb-tg"
  target_type          = "instance"
  port                 = var.lb_port
  protocol             = "HTTP"
  vpc_id               = aws_vpc.web.id
  deregistration_delay = 60 #기본 300초 (빠른 테스트를 위한 시간 줄임)

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
# 타겟 그룹에 webserver add
resource "aws_lb_target_group_attachment" "web" {
  for_each = aws_instance.web

  target_group_arn = aws_lb_target_group.target.arn
  target_id        = each.value.id
  port             = var.lb_port
}

# 연결
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.lb_listener.arn
  priority     = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target.arn
  }
}

#############################
# LB 생성 종료
#############################

#############################
# 보안그룹 생성
#############################

resource "aws_security_group" "private" {
  vpc_id      = aws_vpc.web.id
  name        = var.web_security_group_name
  description = "Allow HTTP inbound traffic"

  tags = {
    Name = "tf-web"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http-web" {

  description                  = "HTTP from VPC"
  from_port                    = var.server_port
  to_port                      = var.server_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.lb_security.id

  security_group_id = aws_security_group.private.id
}

resource "aws_vpc_security_group_egress_rule" "egress-web" {

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  security_group_id = aws_security_group.private.id
}

resource "aws_vpc_security_group_ingress_rule" "ssh-web" {

  description = "SSH Port"
  from_port   = var.ssh_port
  to_port     = var.ssh_port
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  security_group_id = aws_security_group.private.id
}

resource "aws_security_group" "lb_security" {
  vpc_id      = aws_vpc.web.id
  name        = var.lb_security_group_name
  description = "Allow HTTP inbound traffic"

  tags = {
    Name = "tf-lb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http-lb-security" {

  description = "HTTP from VPC"
  from_port   = var.lb_port
  to_port     = var.lb_port
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  security_group_id = aws_security_group.lb_security.id
}

resource "aws_vpc_security_group_ingress_rule" "ssh-lb-security" {

  description = "SSH Port"
  from_port   = var.ssh_port
  to_port     = var.ssh_port
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  security_group_id = aws_security_group.lb_security.id
}

resource "aws_vpc_security_group_egress_rule" "egress-lb-security" {

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  security_group_id = aws_security_group.lb_security.id
}

# RDS 보안그룹

resource "aws_security_group" "rds" {
  vpc_id = aws_vpc.web.id
  name   = "rds-sg"

  tags = {
    Name = "rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_private" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.private.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "rds_egress" {
  security_group_id = aws_security_group.rds.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

#############################
# 보안그룹 생성 종료
#############################

#############################
# GW 생성 / NAT Route
#############################

resource "aws_internet_gateway" "web" {
  vpc_id = aws_vpc.web.id

  tags = {
    Name = "tf-web"
  }
}

resource "aws_nat_gateway" "private_a" {
  allocation_id = aws_eip.private_a.id
  subnet_id     = aws_subnet.web_a.id
  depends_on    = [aws_internet_gateway.web]
  tags = {
    Name = "tf-nat-private-a"
  }
}

resource "aws_nat_gateway" "private_c" {
  allocation_id = aws_eip.private_c.id
  subnet_id     = aws_subnet.web_c.id
  depends_on    = [aws_internet_gateway.web]
  tags = {
    Name = "tf-nat-private-c"
  }
}

resource "aws_eip" "private_a" {
  domain = "vpc"

  tags = {
    Name = "tf-eip-private-a"
  }
}

resource "aws_eip" "private_c" {
  domain = "vpc"

  tags = {
    Name = "tf-eip-private_c"
  }
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.web.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private_a.id
  }

  tags = {
    Name = "tf-private-a-rt"
  }
}

resource "aws_route_table" "private_c" {
  vpc_id = aws_vpc.web.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private_c.id
  }

  tags = {
    Name = "tf-private-c-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_c.id
}

resource "aws_route_table" "web" {
  vpc_id = aws_vpc.web.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web.id
  }

  tags = {
    Name = "tf-web"
  }
}

resource "aws_route_table_association" "web_a" {
  subnet_id      = aws_subnet.web_a.id
  route_table_id = aws_route_table.web.id
}

resource "aws_route_table_association" "web_c" {
  subnet_id      = aws_subnet.web_c.id
  route_table_id = aws_route_table.web.id
}


#############################
# GW 생성 / NAT Route 종료
#############################
/*
# 1) 키 생성
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}
*/

# 2) 퍼블릭 키를 AWS에 등록
resource "aws_key_pair" "my-keypair" {
  key_name   = "my-keypair"
  public_key = file("${path.module}/sshkey/mykey.pub")
}
/*
# 3) 프라이빗 키를 로컬 파일로 저장 (선택)
resource "local_file" "ssh_private_key" {
  content  = tls_private_key.ssh.private_key_pem
  filename = "${path.module}/my-keypair.pem"
}
*/

