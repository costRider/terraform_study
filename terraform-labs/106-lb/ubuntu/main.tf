########################################
#   2025-11-20 - LMK
#   강의 실습
#   LB 만들기
########################################

#프로바이더 설정 테라폼 버전과 aws 의 provider 버전을 설정
terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2" # Asia Pacific (Seoul) region
}

resource "aws_vpc" "web" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "tf-web"
  }
}

# NAT용 탄력 IP
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "tf-nat-eip"
  }
}

# NAT Gateway (public subnet 하나에 올림: ap-northeast-2a)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.web_a.id # public subnet (2a)

  tags = {
    Name = "tf-nat"
  }

  depends_on = [aws_internet_gateway.web]
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

# 새로 추가: Private Subnet (ASG/EC2용)
resource "aws_subnet" "web_priv_a" {
  vpc_id                  = aws_vpc.web.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "tf-web-a-private"
  }
}

resource "aws_subnet" "web_priv_c" {
  vpc_id                  = aws_vpc.web.id
  cidr_block              = "10.0.12.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = false

  tags = {
    Name = "tf-web-c-private"
  }
}

# Public RT (ALB / Public Subnets용)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.web.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web.id
  }

  tags = {
    Name = "tf-web-public-rt"
  }
}

# Public Subnet ↔ Public RT 연결
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.web_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.web_c.id
  route_table_id = aws_route_table.public.id
}
/*
resource "aws_instance" "web" {
  ami                         = var.image_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.web.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  key_name = "academyKey"

  user_data = <<-EOF
 #!/bin/bash
 yum -y install httpd
 sed -i 's/Listen 80/Listen ${var.server_port}/' /etc/httpd/conf/httpd.conf
 systemctl enable httpd
 systemctl start httpd
 echo '<html><h1>Hello From My Linux Web Server! ${var.server_port} </h1></html>' > /var/www/html/index.html
EOF

  //user_data = file("${path.module}/userdata.sh")

 #user_data 를 사용하는데 templatefile의 내용을 불러올거고
 # 쓰는 방법은 templatefile("파일",파일에 선언한 변수에 값 할당)
  //user_data = templatefile("${path.module}/userdata.tpl",{server_port=var.server_port})

#user data를 update 후 적용하기 위해 instance를 삭제 후 재생성 한다.
  user_data_replace_on_change = true

  tags = {
    Name = "tf-web"
  }
}
*/
/*
data "aws_vpc" "test" {
  filter {
    name   = "tag:Name"
    values = ["tf-web"]
  }
}

data "aws_subnet" "test" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.test.id]
  }
}
*/

#################################
# ami 선택
#################################

data "aws_ami" "ubuntu2404" {
  most_recent = true

  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/*ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}


data "aws_ami" "amzLinux" {
  #최신 버전을 가져온다. 
  most_recent = true

  #아마존 리눅스 공식계정
  owners = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] # Amazon Linux 2023 이름 규칙
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

#################################
# ami 선택 종료
#################################

#################################
# launch template 생성
#################################

resource "aws_launch_template" "web" {

  name = "lt-web"

  image_id      = coalesce(data.aws_ami.ubuntu2404.id, var.user_specified_ami) //"${var.user_specified_ami == "" ? data.aws_ami.ubuntu_2024.id : var.user_specified_ami}" //data.aws_ami.amzLinux.image_id //var.image_id
  instance_type = var.instance_type
  monitoring {
    enabled = true
  }

  /*
  network_interfaces {
    security_groups = [aws_security_group.web.id]
    associate_public_ip_address = false
  }
*/
  # ENI 블록 대신 이 한 줄로 SG만 지정
  vpc_security_group_ids = [aws_security_group.web.id]

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
  /*
  vpc_zone_identifier = [
    aws_subnet.web_a.id,
    aws_subnet.web_c.id,
  ]
*/
  # 변경: 이제 private subnet 위에서만 인스턴스 뜨게
  vpc_zone_identifier = [
    aws_subnet.web_priv_a.id,
    aws_subnet.web_priv_c.id,
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
  /*
    lifecycle {
    create_before_destroy = true
  }
*/
  tag {
    key                 = "Name"
    value               = "tf-asg-web"
    propagate_at_launch = true
  }

  desired_capacity = 4
  max_size         = 8
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

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.lb-security.id]
  }

  ingress {
    description = "SSH Port"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "tf-web"
  }
}

resource "aws_security_group" "lb-security" {
  vpc_id      = aws_vpc.web.id
  name        = var.lb_security_group_name
  description = "Allow HTTP inbound traffic"

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = var.lb_port
    to_port     = var.lb_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH Port"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "tf-lb-sg"
  }
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

# Private RT (ASG/EC2 → NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.web.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "tf-web-private-rt"
  }
}

# Private Subnet ↔ Private RT 연결
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.web_priv_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.web_priv_c.id
  route_table_id = aws_route_table.private.id
}


/*
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
}*/

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


##################################
#
# 변수 선언 라인
#
##################################

variable "lb_name" {
  description = "LB-Name"
  type        = string
  default     = "lb"
}

variable "user_specified_ami" {
  description = "user ami(amazonLinux)"
  type        = string
  default     = "ami-0ad90ede5f7a6f599"
}

variable "server_port" {
  description = "server_port"
  type        = number
  default     = 80
}

variable "ssh_port" {
  description = "ssh_port"
  type        = number
  default     = 22
}

variable "lb_port" {
  description = "lb_port"
  type        = number
  default     = 80
}

variable "web_security_group_name" {
  description = "web security group name"
  type        = string
  default     = "allow_http"
}

variable "lb_security_group_name" {
  description = "lb security group name"
  type        = string
  default     = "lb security"
}

variable "image_id" {
  description = "image AMI"
  type        = string
  default     = "ami-0ad90ede5f7a6f599" # Amazon Linux 2023 k-6.12
}

variable "instance_type" {
  description = "instance type"
  type        = string
  default     = "t3.micro"
}
