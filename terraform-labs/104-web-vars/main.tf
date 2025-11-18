########################################
#   2025-11-17 - LMK
#   강의 실습
#   WebServer 만들기
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

resource "aws_subnet" "web" {
  vpc_id     = aws_vpc.web.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "tf-web"
  }
}

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

  user_data_replace_on_change = true

  tags = {
    Name = "tf-web"
  }
}

resource "aws_security_group" "web" {
  vpc_id      = aws_vpc.web.id
  name        = "${var.security_group_name}"
  description = "Allow HTTP inbound traffic"

  ingress {
    description = "HTTP from VPC"
    from_port   = var.server_port
    to_port     = var.server_port
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
    Name = "tf-web"
  }
}

resource "aws_internet_gateway" "web" {
  vpc_id = aws_vpc.web.id

  tags = {
    Name = "tf-web"
  }
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

resource "aws_route_table_association" "web" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.web.id
}

variable "server_port" {
  description = "server_port"
  type        = number
  default = 80
}

variable "ssh_port" {
  description = "ssh_port"
  type        = number
  default     = 22
}

variable "security_group_name" {
  description = "security group name"
  type        = string
  default     = "allow_http"
}

variable "image_id" {
  description = "image AMI"
  type        = string
  default     = "ami-0aa02302a11ea5190"
}

variable "instance_type" {
  description = "instance type"
  type        = string
  default     = "t3.micro"
}
