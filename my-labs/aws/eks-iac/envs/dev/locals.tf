#############################################
#   2025-11-17 - LMK
#   공통 태그 묶기 - 기본적으로 가져다 쓸 Tag
#############################################

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner

    ManagedBy  = "Terraform"
    CostCenter = var.cost_center
  }
}