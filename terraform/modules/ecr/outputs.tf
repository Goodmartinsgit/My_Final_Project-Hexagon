output "app_repo_url" {
  description = "Full ECR URL for the app-tier (Flask backend) image."
  value       = aws_ecr_repository.app.repository_url
}

output "web_repo_url" {
  description = "Full ECR URL for the web-tier (Nginx frontend) image."
  value       = aws_ecr_repository.web.repository_url
}

output "app_repo_name" {
  description = "Repository name of the app-tier ECR repo (for use in docker push commands)."
  value       = aws_ecr_repository.app.name
}

output "web_repo_name" {
  description = "Repository name of the web-tier ECR repo (for use in docker push commands)."
  value       = aws_ecr_repository.web.name
}
