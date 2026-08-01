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

variable "create_bastion" {
  description = "Set to false on Free Tier to avoid vCPU limit errors."
  type        = bool
  default     = false
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

variable "internal_alb_dns" {
  description = "DNS name of the internal ALB — used by the web-tier Nginx to proxy /api/ requests to the app tier."
  type        = string
  default     = ""
}

variable "asg_min_size" {
  description = "Minimum number of instances in each Auto Scaling Group."
  type        = number
  default     = 1
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in each Auto Scaling Group."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances each Auto Scaling Group can scale to."
  type        = number
  default     = 4
}
