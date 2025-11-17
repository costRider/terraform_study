###########################################
#   2025-11-17 - LMK (강의)
#   심화 실습(Windows)
###########################################

provider "aws" {
  region = "ap-northeast-2" #Asia Pacific (Seoul) region
}

resource "aws_vpc" "windows" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "tf-windows-web"
  }
}
resource "aws_subnet" "windows" {
  vpc_id     = aws_vpc.windows.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "tf-windows-web"
  }
}

resource "aws_instance" "windows" {
  ami           = "ami-045293d19d738a663"
  instance_type = "t3.small"
  subnet_id     = aws_subnet.windows.id

  tags = {
    Name = "tf-windows-web"
  }
}