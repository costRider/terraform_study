####################################################
# 2025.11.15 - LMK
# 네트워크 리소스 정의 
# 
####################################################


############################################
# 1. VPC생성
############################################

resource "aws_vpc" "this" {
  #VPC의 IP대역
  cidr_block = var.vpc_cidr

  #VPC 내부 인스턴스/노드 NDS를 쓸 수 있도록 하는 옵션들
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags,{
    Name        = "${var.project_name}-vpc"
  })
}

############################################
# 2. Internet Gateway (IGW)
# - 퍼블릭 서브넷이 인터넷으로 나가게 해주는 관문
############################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags,{
    Name    = "${var.project_name}-igw"
  })
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

  tags = merge(var.common_tags,{
    Name = "${var.project_name}-public-${count.index + 1}"
    #EKS에서 이 서브넷을 "외부용 ELB(ALB.NLB) 배포 위치"로 인식하게 하는 태그
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  })
}


############################################
# 4-1. 프라이빗 서브넷 (MGMT EC2 서비스용)
############################################

resource "aws_subnet" "mgmt" {
  count = length(var.mgmt_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.mgmt_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  #프라이빗 서브넷: 퍼블릭 IP 자동할당 X
  map_public_ip_on_launch = false

  tags = merge(var.common_tags,{
    Name = "${var.project_name}-mgmt-${count.index + 1}"
    #EKS에서 이 서브넷을 "내부용 NLB/내부 ELB" 위치로 인식하는 태그
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  })
}

############################################
# 4-2. 프라이빗 서브넷 (EKS 노드/내부 서비스용)
############################################

resource "aws_subnet" "worker" {
  count = length(var.worker_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.worker_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  #프라이빗 서브넷: 퍼블릭 IP 자동할당 X
  map_public_ip_on_launch = false

  tags = merge(var.common_tags,{
    Name = "${var.project_name}-worker-${count.index + 1}"
    #EKS에서 이 서브넷을 "내부용 NLB/내부 ELB" 위치로 인식하는 태그
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  })
}

############################################
# 4-3. 프라이빗 서브넷 (DB 내부 서비스용)
############################################
resource "aws_subnet" "db" {
  count = length(var.db_subnet_cidrs)

  vpc_id = aws_vpc.this.id
  cidr_block = var.db_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags,{
    Name = "${var.project_name}-db-${count.index+1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  })
}

############################################
# 5. NAT Gateway (프라이빗 -> 아웃바운드 인터넷)
# - 프라이빗 서브넷의 노드들이 패키지 설치, 컨테이너 이미지 pull등을 위해
#   인터넷으로 나갈 때 사용(들어오는 트래픽은 차단됨)
############################################

#NAT 게이트웨이가 붙을 퍼블릭 IP(Elastic IP)
resource "aws_eip" "nat" {
  #AZ별로 하나씩 NAT 
  count = length(var.azs)
  #VIP 안에서 사용하는 EIP
  domain = "vpc"

  tags = merge(var.common_tags,{
    Name    = "${var.project_name}-nat-eip-${count.index+1}"
  })
}

# NAT Gateway (AZ별 1개씩, 해당 AZ의 Public subnet에 위치)
resource "aws_nat_gateway" "this" {
  count = length(var.azs)

  #각 NAT는 해당 AZ의 public subnet & EIP와 1:1매칭
  allocation_id = aws_eip.nat[count.index].id

  subnet_id = aws_subnet.public[count.index].id

  tags = merge(var.common_tags,{
    Name = "${var.project_name}-nat-gw-${count.index+1}"
  })

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

  tags = merge(var.common_tags,{
    Name    = "${var.project_name}-public-rt"
  })
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
  count = length(var.azs)

  vpc_id = aws_vpc.this.id

  #Default route: NAT Gateway로 향하게 설정
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(var.common_tags,{
    Name    = "${var.project_name}-private-rt${count.index+1}"
  })
}

########################################
# MGMT Subnet ↔ Private RT (AZ별 매핑)
########################################
resource "aws_route_table_association" "mgmt" {
  count = length(aws_subnet.mgmt)

  subnet_id      = aws_subnet.mgmt[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

########################################
# Worker Subnet ↔ Private RT (AZ별 매핑)
########################################
resource "aws_route_table_association" "worker" {
  count = length(aws_subnet.worker)

  subnet_id      = aws_subnet.worker[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

########################################
# DB Subnet ↔ Private RT (AZ별 매핑)
########################################
resource "aws_route_table_association" "db" {
  count = length(aws_subnet.db)

  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
