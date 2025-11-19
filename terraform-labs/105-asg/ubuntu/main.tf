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

data "aws_ami" "ubuntu2404" {
  most_recent = true

  owners = ["099720109477"]  # Canonical

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

resource "aws_launch_template" "web" {

  name = "ubuntu"

  image_id      =  coalesce(data.aws_ami.ubuntu2404.id,var.user_specified_ami)//"${var.user_specified_ami == "" ? data.aws_ami.ubuntu_2024.id : var.user_specified_ami}" //data.aws_ami.amzLinux.image_id //var.image_id
  instance_type = var.instance_type

  monitoring {
    enabled = true
  }

  network_interfaces {
    security_groups             = [aws_security_group.web.id]
    associate_public_ip_address = true
  }

  key_name = aws_key_pair.my-keypair.key_name //"academyKey"

  user_data = base64encode(templatefile("${path.module}/userdata.tftpl", { server_port = var.server_port }))

  tags = {
    Name = "terraform-launch-template"
  }
}

resource "aws_autoscaling_group" "web" {
  #배포될 서브넷 multi az로 지정해야함(현재는 테스트로 단일 [2a,2c])
  vpc_zone_identifier = [aws_subnet.web.id]

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
  /*
    lifecycle {
    create_before_destroy = true
  }
*/
  tag {
    key                 = "Name"
    value               = "tf-asg-ubuntu-web"
    propagate_at_launch = true
  }

  desired_capacity = 2
  max_size         = 4
  min_size         = 2

}

resource "aws_security_group" "web" {
  vpc_id      = aws_vpc.web.id
  name        = var.security_group_name
  description = "Allow HTTP inbound traffic"

  lifecycle {
    create_before_destroy = true
  }

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

variable "user_specified_ami" {
  description = "user ami(amazonLinux)"
  type = string
  default = "ami-0ad90ede5f7a6f599"
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

variable "security_group_name" {
  description = "security group name"
  type        = string
  default     = "allow_http"
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
