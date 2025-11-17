###########################################
#   2025-11-17 - LMK (강의)
#   심화 실습(Ubuntu)
###########################################

provider "aws" {
  region = "ap-northeast-2" #Asia Pacific (Seoul) region
}

resource "aws_vpc" "ubuntu" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

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
  ami           = "ami-0a71e3eb8b23101ed"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.ubuntu.id

  tags = {
    Name = "tf-ubuntu-web"
  }
}
