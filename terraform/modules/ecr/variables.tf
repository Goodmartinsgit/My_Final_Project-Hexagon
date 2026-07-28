variable "project_name" {
  description = "Short name prefix applied to every ECR repository name and tag."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}
