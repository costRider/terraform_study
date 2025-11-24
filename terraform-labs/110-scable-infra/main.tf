########################################
#   2025-11-24 - LMK
#   강의 실습
#   2 tier 서비스 구성
########################################

##################################
# VPC/SUBNET 생성
##################################

#VPC 생성
resource "aws_vpc" "web" {
  cidr_block = "192.168.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "tf-web-vpc"
  }
}

#퍼블릭 서브넷 1
resource "aws_subnet" "web_a" {
  vpc_id                  = aws_vpc.web.id
  cidr_block              = "192.168.0.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "tf-web-subnet-a"
  }
}

#퍼블릭 서브넷 2
resource "aws_subnet" "web_c" {
  vpc_id                  = aws_vpc.web.id
  cidr_block              = "192.168.3.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = {
    Name = "tf-web-subnet-c"
  }
}

#프라이빗 서브넷 1
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.web.id
  cidr_block        = "192.168.1.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "tf-private-subnet-a"
  }
}

#프라이빗 서브넷 2
resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.web.id
  cidr_block        = "192.168.4.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "tf-private-subnet-c"
  }
}

#DB 서브넷 1
resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.web.id
  cidr_block        = "192.168.2.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "tf-db-subnet-a"
  }
}

#DB 서브넷 2
resource "aws_subnet" "db_c" {
  vpc_id            = aws_vpc.web.id
  cidr_block        = "192.168.5.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "tf-db-subnet-c"
  }
}

##################################
# VPC/SUBNET 생성 종료
##################################

#############################
# GW 생성 / NAT Route
#############################

# 인터넷 게이트웨이
resource "aws_internet_gateway" "web" {
  vpc_id = aws_vpc.web.id

  tags = {
    Name = "tf-web"
  }
}

#NAT 게이트 웨이 Zone A
resource "aws_nat_gateway" "private_a" {
  allocation_id = aws_eip.private_a.id
  subnet_id     = aws_subnet.web_a.id
  depends_on    = [aws_internet_gateway.web]
  tags = {
    Name = "tf-nat-private-db-a"
  }
}

#NAT 게이트 웨이 Zone C
resource "aws_nat_gateway" "private_c" {
  allocation_id = aws_eip.private_c.id
  subnet_id     = aws_subnet.web_c.id
  depends_on    = [aws_internet_gateway.web]
  tags = {
    Name = "tf-nat-private-db-c"
  }
}


# Elastic IP(공인 IP) NAT용 Zone A
resource "aws_eip" "private_a" {
  domain = "vpc"

  tags = {
    Name = "tf-eip-private-a"
  }
}

# Elastic IP(공인 IP) NAT용 Zone C
resource "aws_eip" "private_c" {
  domain = "vpc"

  tags = {
    Name = "tf-eip-private_c"
  }
}

# 라우팅 테이블 Zone A nat gw 모든 트래픽
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

# 라우팅 테이블 Zone C nat gw 모든 트래픽
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

resource "aws_route_table" "db_a" {
  vpc_id = aws_vpc.web.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private_a.id
  }

  tags = {
    Name = "tf-db-a-rt"
  }
}

# 라우팅 테이블 Zone C nat gw 모든 트래픽
resource "aws_route_table" "db_c" {
  vpc_id = aws_vpc.web.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private_c.id
  }

  tags = {
    Name = "tf-db-c-rt"
  }
}

# 라우팅 테이블 - subnet 연결 Zone A
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

# 라우팅 테이블 - subnet 연결 Zone C
resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_c.id
}

# 라우팅 테이블 - subnet 연결 Zone A
resource "aws_route_table_association" "db_a" {
  subnet_id      = aws_subnet.db_a.id
  route_table_id = aws_route_table.db_a.id
}

# 라우팅 테이블 - subnet 연결 Zone C
resource "aws_route_table_association" "db_c" {
  subnet_id      = aws_subnet.db_c.id
  route_table_id = aws_route_table.db_c.id
}

# 퍼블릭 라우팅 테이블 인터넷 게이트 웨이 모든 트래픽
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

# 라우팅 테이블 - 서브넷 연결 (퍼블릭) Zone A,C
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

#############################
# launch template/ASG 설정
#############################

resource "aws_launch_template" "web" {

  name = "web-instance"

  image_id      = var.image_id
  instance_type = var.instance_type

  monitoring {
    enabled = true
  }
  vpc_security_group_ids = [aws_security_group.private.id]

  key_name = aws_key_pair.my-keypair.key_name

  user_data = base64encode(templatefile("lab-userdata.tftpl", {
    rds_endpoint = aws_db_instance.mariadb_multi_az.endpoint
    db_username  = var.db_username
    db_password  = var.db_password
  }))

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_db_instance.mariadb_multi_az]

  tags = {
    Name = "terraform-launch-template"
  }
}

resource "aws_autoscaling_group" "web" {
  #배포될 서브넷 multi az로 지정해야함(현재는 테스트로 단일 [2a,2c])
  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_c.id]

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  #rolling update (triggers 가 걸리면 update)
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }
  }

  target_group_arns = [aws_lb_target_group.target.arn]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "tf-asg-web"
    propagate_at_launch = true
  }

  desired_capacity = 2
  max_size         = 4
  min_size         = 2

}

#############################
# launch template/ASG 설정 종료
#############################

#############################
# RDS 생성
#############################

#서브넷 생성
resource "aws_db_subnet_group" "lab" {
  name       = "lab-db-subnet"
  subnet_ids = [aws_subnet.db_a.id, aws_subnet.db_c.id]

  tags = {
    Name = "lab-db-subnet"
  }
}

# RDS 인스턴스 (Multi-AZ 활성화)
resource "aws_db_instance" "mariadb_multi_az" {
  # 필수 및 기본 매개변수
  identifier        = "mariadb-multi-az-instance"
  allocated_storage = 20
  instance_class    = "db.t3.medium" # db.t3.micro는 Multi-AZ를 지원하지 않을 수 있습니다.
  engine            = "mariadb"
  engine_version    = "10.6.24"
  username          = var.db_username
  password          = var.db_password
  db_name           = "mydb"

  # ★ Multi-AZ 활성화 (Master/Standby 구조) ★
  multi_az = true

  # 추가 권장 매개변수
  parameter_group_name    = "default.mariadb10.6"
  skip_final_snapshot     = true
  publicly_accessible     = false
  backup_retention_period = 7

  # 서브넷 그룹 및 VPC 보안 그룹 설정
  db_subnet_group_name   = aws_db_subnet_group.lab.name
  vpc_security_group_ids = [aws_security_group.rds.id]
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
  port                 = var.httpd_port
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
  from_port                    = var.httpd_port
  to_port                      = var.httpd_port
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

