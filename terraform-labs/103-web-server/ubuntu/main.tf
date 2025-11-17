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

resource "aws_vpc" "ubuntu" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "tf-ubuntu-web"
  }
}

resource "aws_subnet" "ubuntu" {
  vpc_id     = aws_vpc.ubuntu.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "tf-ubuntu-web"
  }
}

resource "aws_instance" "ubuntu" {
  ami                    = "ami-0a71e3eb8b23101ed" # Ubuntu 24.04 LTS
  instance_type          = "t3.micro"
  subnet_id = aws_subnet.ubuntu.id
  vpc_security_group_ids = [aws_security_group.ubuntu.id]
  associate_public_ip_address = true

  user_data                   = file("${path.module}/userdata-ubuntu.sh")
  user_data_replace_on_change = true
  tags = {
    Name = "tf-ubuntu-web"
  }
}

resource "aws_security_group" "ubuntu" {
  vpc_id      = aws_vpc.ubuntu.id
  name        = "allow http"
  description = "Allow HTTP inbound traffic"


  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
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
    Name = "tf-ubuntu-web"
  }
}

resource "aws_internet_gateway" "ubuntu" {
  vpc_id = aws_vpc.ubuntu.id

  tags = {
    Name = "tf-ubuntu-web"
  }
}

resource "aws_route_table" "ubuntu" {
  vpc_id = aws_vpc.ubuntu.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ubuntu.id
  }

  tags = {
    Name = "tf-ubuntu-web"
  }
}

resource "aws_route_table_association" "web" {
  subnet_id      = aws_subnet.ubuntu.id
  route_table_id = aws_route_table.ubuntu.id
}
