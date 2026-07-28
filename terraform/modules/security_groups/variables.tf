variable "project_name" {
  description = "Short name prefix applied to every resource name and tag."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to create the security groups."
  type        = string
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR notation (e.g. 197.210.x.x/32) — restricts bastion SSH access."
  type        = string
}
