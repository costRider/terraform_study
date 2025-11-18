###################################
#   2025-11-18 - LMK
#   output - 내보낼 값
###################################

output "public_ip" {
  description = "The public IP address of the web server"
  value = "${aws_instance.ubuntu.public_ip}:${var.server_port}"
}

output "private_ip" {
    description = "The Private IP address of the web server"
    value = "${aws_instance.ubuntu.private_ip}"
}