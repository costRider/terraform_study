#################################
#   2025-11-24 - LMK
#   Infra Outputs
#################################

output "out_lb" {
  description = "lb"
  value       = aws_lb.alb.dns_name
}

output "out_db" {
  description = "db endpoint"
  value       = aws_db_instance.mariadb_multi_az.endpoint
}