
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

variable "httpd_port" {
  description = "web port"
  type = number
  default = 80
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

variable "db_username" {
  description = "db_user"
  type        = string
}

variable "db_password" {
  description = "db_pass"
  type        = string
}
