########################################
# 2025.11.15 - LMK
# Test EC2 Instance (퍼블릭 서브넷)
# - 네트워크/라우팅/SG 확인용
########################################

resource "aws_instance" "bastion" {
  ami           = var.bastion_ami_id              #이미지 ID AMI에서 사용하는 이미지의 ID 설정
  instance_type = var.instance_type_bastion            #  aws에서 사용하는 인스턴스 type을 결정 
  subnet_id     = aws_subnet.public[0].id # 어느 서브넷에 EC2를 배치할지 결정

  key_name = var.ssh_key_name #설정할 접근용 키페어명

  vpc_security_group_ids = [aws_security_group.bastion.id] # 보안그룹 설정

  associate_public_ip_address = true #퍼블릭 접근 가능하도록 설정
  
  tags = merge(var.common_tags,{
    Name = "${var.project_name}-bastion" # 태그명 설정
  })
}

resource "aws_instance" "mgmt" {
  ami           = var.mgmt_ami_id
  instance_type = var.instance_type_mgmt
  subnet_id     = aws_subnet.mgmt[0].id

  key_name = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.mgmt.id]

  tags = merge(var.common_tags,{
    Name = "${var.project_name}-mgmt"
  })

}