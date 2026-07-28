variable "project_name" {
  description = "Short name prefix applied to every resource name and tag."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC."
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets (bastion + external ALB)."
  type        = list(string)
}

variable "app_subnet_ids" {
  description = "IDs of the private app subnets (web + app ASGs)."
  type        = list(string)
}

variable "key_pair_name" {
  description = "EC2 key pair name for SSH access to bastion and ASG instances."
  type        = string
}

variable "bastion_sg_id" {
  description = "Security group ID for the bastion host."
  type        = string
}

variable "webserver_sg_id" {
  description = "Security group ID for the web-tier instances and external ALB."
  type        = string
}

variable "appserver_sg_id" {
  description = "Security group ID for the app-tier instances and internal ALB."
  type        = string
}

variable "web_instance_type" {
  description = "EC2 instance type for the web-tier ASG."
  type        = string
}

variable "app_instance_type" {
  description = "EC2 instance type for the app-tier ASG."
  type        = string
}

variable "app_ecr_repo_url" {
  description = "Full ECR URL for the app-tier (Flask backend) image."
  type        = string
}

variable "web_ecr_repo_url" {
  description = "Full ECR URL for the web-tier (Nginx frontend) image."
  type        = string
}

variable "app_image_tag" {
  description = "Docker image tag to pull for the app-tier container."
  type        = string
}

variable "web_image_tag" {
  description = "Docker image tag to pull for the web-tier container."
  type        = string
}
