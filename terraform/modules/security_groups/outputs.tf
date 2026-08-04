output "bastion_sg_id" {
  description = "Security group ID for the bastion host."
  value       = aws_security_group.bastion.id
}

output "external_alb_sg_id" {
  description = "Security group ID for the external (public) ALB."
  value       = aws_security_group.external_alb.id
}

output "webserver_sg_id" {
  description = "Security group ID for the web-tier EC2 instances."
  value       = aws_security_group.webserver.id
}

output "internal_alb_sg_id" {
  description = "Security group ID for the internal ALB."
  value       = aws_security_group.internal_alb.id
}

output "appserver_sg_id" {
  description = "Security group ID for the app-tier EC2 instances."
  value       = aws_security_group.appserver.id
}

output "database_sg_id" {
  description = "Security group ID for the RDS database tier."
  value       = aws_security_group.database.id
}
