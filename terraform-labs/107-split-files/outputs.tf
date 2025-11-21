#################################
#   2025-11-20 - LMK
#   리스너 실습 Output
#################################

output "out_lb" {
  description = "lb"
  value       = aws_lb.alb.dns_name
}