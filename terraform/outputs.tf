# ── VPC ───────────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

# ── Compute — DNS names for the load balancers ────────────────────────────────
output "external_alb_dns" {
  description = "DNS name of the public (external) ALB. Point your domain here or use directly in a browser."
  value       = module.compute.external_alb_dns
}

output "internal_alb_dns" {
  description = "DNS name of the internal ALB used by the web tier to reach the app tier."
  value       = module.compute.internal_alb_dns
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host. Use for SSH tunnelling into private subnets."
  value       = module.compute.bastion_public_ip
}

# ── ECR — image repository URLs ───────────────────────────────────────────────
output "ecr_app_repo_url" {
  description = "Full ECR URL for the app-tier (backend Flask) image. Use in docker push and GitHub Actions."
  value       = module.ecr.app_repo_url
}

output "ecr_web_repo_url" {
  description = "Full ECR URL for the web-tier (Nginx frontend) image. Use in docker push and GitHub Actions."
  value       = module.ecr.web_repo_url
}

# ── RDS ───────────────────────────────────────────────────────────────────────
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (host:port). Set as DB_HOST in backend configuration."
  value       = module.rds.db_endpoint
  sensitive   = true
}

# ── Auto Scaling Group names (used by CI/CD to trigger instance refresh) ──────
output "web_asg_name" {
  description = "Name of the web-tier Auto Scaling Group. Set as WEB_ASG_NAME in GitHub Secrets."
  value       = module.compute.web_asg_name
}

output "app_asg_name" {
  description = "Name of the app-tier Auto Scaling Group. Set as APP_ASG_NAME in GitHub Secrets."
  value       = module.compute.app_asg_name
}
