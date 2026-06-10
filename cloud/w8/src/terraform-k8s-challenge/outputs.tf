output "alb_dns" {
  value = aws_lb.alb.dns_name
  description = "Nhấn vào link này để mở App của bạn"
}

output "ec2_public_ip" {
  value = aws_instance.minikube.public_ip
}