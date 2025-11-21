########################################
#   2025-11-20 - LMK
#   강의 실습
#   LB 만들기
########################################
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

#################################
# launch template 생성
#################################

resource "aws_launch_template" "web" {

  name = "lt-web"

  image_id      = coalesce(var.user_specified_ami, data.aws_ami.ubuntu2404.id) //"${var.user_specified_ami == "" ? data.aws_ami.ubuntu_2024.id : var.user_specified_ami}" //data.aws_ami.amzLinux.image_id //var.image_id
  instance_type = var.instance_type

  monitoring {
    enabled = true
  }

  network_interfaces {
    security_groups = [aws_security_group.web.id]
  }

  key_name = aws_key_pair.my-keypair.key_name //"academyKey"

  user_data = base64encode(templatefile("${path.module}/userdata.tftpl", { server_port = var.server_port }))

  tags = {
    Name = "terraform-launch-template"
  }
}

#################################
# launch template 생성 종료
#################################

#################################
# Auto Scaling 그룹 생성
#################################

resource "aws_autoscaling_group" "web" {
  #배포될 서브넷 multi az로 지정해야함(현재는 테스트로 단일 [2a,2c])
  vpc_zone_identifier = [
    aws_subnet.private_a.id,
    aws_subnet.private_c.id,
  ]

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  target_group_arns = [aws_lb_target_group.target.arn]
  health_check_type = "ELB"

  #rolling update (triggers 가 걸리면 update)
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }
  }

  tag {
    key                 = "Name"
    value               = "tf-asg-web"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [
      target_group_arns,
      desired_capacity
    ]
  }

  desired_capacity = 2
  max_size         = 4
  min_size         = 2

}

#################################
# Auto Scaling 그룹 생성 종료
#################################

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
  security_groups = [aws_security_group.lb-security.id]
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
  port                 = var.server_port
  protocol             = "HTTP"
  vpc_id               = aws_vpc.web.id
  deregistration_delay = 60 #기본 300초 (빠른 테스트를 위한 시간 줄임)

  health_check {
    path                = "/"
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

resource "aws_security_group" "web" {
  vpc_id      = aws_vpc.web.id
  name        = var.web_security_group_name
  description = "Allow HTTP inbound traffic"

  tags = {
    Name = "tf-web"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http-web" {

  description = "HTTP from VPC"
  from_port   = var.server_port
  to_port     = var.server_port
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_egress_rule" "egress-web" {

  from_port   = 0
  to_port     = 0
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_ingress_rule" "ssh-web" {

  description = "SSH Port"
  from_port   = var.ssh_port
  to_port     = var.ssh_port
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  security_group_id = aws_security_group.web.id
}

resource "aws_security_group" "lb-security" {
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

  security_group_id = aws_security_group.lb-security.id
}

resource "aws_vpc_security_group_ingress_rule" "ssh-lb-security" {

  description = "SSH Port"
  from_port   = var.ssh_port
  to_port     = var.ssh_port
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  security_group_id = aws_security_group.lb-security.id
}

resource "aws_vpc_security_group_egress_rule" "egress-lb-security" {

  from_port   = 0
  to_port     = 0
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  security_group_id = aws_security_group.lb-security.id
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
  allocation_id = aws_eip.eip.id
  subnet_id         = aws_subnet.web_a.id
  depends_on        = [aws_internet_gateway.web]
  tags = {
    Name = "tf-nat-private-a"
  }
}

resource "aws_nat_gateway" "private_c" {
  allocation_id = aws_eip.eip.id
  connectivity_type = "public"
  subnet_id         = aws_subnet.web_c.id
  depends_on        = [aws_internet_gateway.web]
  tags = {
    Name = "tf-nat-private-c"
  }
}

resource "aws_eip" "eip" {
  domain = "vpc"

  tags = {
    Name = "tf-eip"
  }
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.web.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.private_a.id
  }

  tags = {
    Name = "tf-web"
  }
}

resource "aws_route_table" "private_c" {
  vpc_id = aws_vpc.web.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.private_c.id
  }

  tags = {
    Name = "tf-web"
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

