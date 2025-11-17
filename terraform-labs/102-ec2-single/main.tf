###########################################
#   2025-11-17 - LMK (강의)
#   강의 내용 실습
###########################################

provider "aws" {
  region = "ap-northeast-2" #Asia Pacific (Seoul) region
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}
resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "main"
  }
}

resource "aws_instance" "ubuntu" {
  ami           = "ami-0a71e3eb8b23101ed"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.main.id

  tags = {
    Name = "main" 
  }
}

resource "aws_instance" "web" {
  ami           = "ami-045293d19d738a663"
  instance_type = "t3.small"
  subnet_id = aws_subnet.main.id

  tags = {
    Name = "main" 
  }
}