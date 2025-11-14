####################################################
# 2025.11.15 - LMK
# 네트워크 리소스 정의 
# 
####################################################

###
# 0.테라폼 Provider 설정
###
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }

  #처음에 로컬 백엔드 사용(추후 S3 backend로 분리 가능)
  # apply 후 실제 생성되는 리소스들의 메타데이터와 상태를 추적하는 tfstate 파일이 저장되는 위치
  backend "local" {
    path = "terraform.tfstate"
  }

}

provider "aws" {
  #어느 리전에 리소스를 만들지 지정
  region = var.aws_region
}

############################################
# 1. VPC생성
############################################

resource "aws_vpc" "this" {
  #VPC의 IP대역
  cidr_block = var.vpc_cidr

  #VPC 내부 인스턴스/노드 NDS를 쓸 수 있도록 하는 옵션들
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Project     = var.project_name
    Environment = "dev"
  }
}

############################################
# 2. Internet Gateway (IGW)
# - 퍼블릭 서브넷이 인터넷으로 나가게 해주는 관문
############################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

############################################
# 3. 퍼블릭 서브넷 (ALB/Jemp Host용)
############################################

#count를 사용해 AZ 개수만큼 반복 생성
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  #퍼블릭 서브넷: EC2/EKS 노드가 자동으로 퍼블릭 IP를 받도록 설정
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
    #EKS에서 이 서브넷을 "외부용 ELB(ALB.NLB) 배포 위치"로 인식하게 하는 태그
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}


############################################
# 4. 프라이빗 서브넷 (EKS 노드/내부 서비스용)
############################################

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  #프라이빗 서브넷: 퍼블릭 IP 자동할당 X
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"
    #EKS에서 이 서브넷을 "내부용 NLB/내부 ELB" 위치로 인식하는 태그
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

############################################
# 5. NAT Gateway (프라이빗 -> 아웃바운드 인터넷)
# - 프라이빗 서브넷의 노드들이 패키지 설치, 컨테이너 이미지 pull등을 위해
#   인터넷으로 나갈 때 사용(들어오는 트래픽은 차단됨)
############################################

#NAT 게이트웨이가 붙을 퍼블릭 IP(Elastic IP)
resource "aws_eip" "nat" {
  #VIP 안에서 사용하는 EIP
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip"
    Project = var.project_name
  }
}

# NAT Gateway는 퍼블릭 서브넷 중 하나에 위치
# (예제: 0번 인덱스 퍼블릭 서브넷에 생성)
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name    = "${var.project_name}-nat-gw"
    Project = var.project_name
  }

  #NAT 생성은 IGW보다 느려서 depends_on으로 의존성 명시(안전빵)
  depends_on = [aws_internet_gateway.this]
}

############################################
# 6. 퍼블릭 라우트 테이블 + 연관
# - 퍼블릭 서브넷: 0.0.0.0/0 -> IGW
############################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  #Default route: IGW로 향하게 설정
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

#각 퍼블릭 서브넷을 퍼블릭 라우트 테이블에 연결 
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

############################################
# 7. 프라이빗 라우트 테이블 + 연관
# - 프라이빗 서브넷: 0.0.0.0/0 -> NAT Gateway
############################################

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  #Default route: NAT Gateway로 향하게 설정
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name    = "${var.project_name}-private-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
