output "external_alb_dns" {
  description = "DNS name of the public (external) ALB serving the web tier."
  value       = aws_lb.external.dns_name
}

output "internal_alb_dns" {
  description = "DNS name of the internal ALB serving the app tier."
  value       = aws_lb.internal.dns_name
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host."
  value       = aws_instance.bastion.public_ip
}

output "web_asg_name" {
  description = "Name of the web-tier Auto Scaling Group — used by CI/CD to trigger instance refresh."
  value       = aws_autoscaling_group.web.name
}

output "app_asg_name" {
  description = "Name of the app-tier Auto Scaling Group — used by CI/CD to trigger instance refresh."
  value       = aws_autoscaling_group.app.name
}
