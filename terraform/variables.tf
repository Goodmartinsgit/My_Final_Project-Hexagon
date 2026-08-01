# ── Project identity ──────────────────────────────────────────────────────────

variable "project_name" {
  description = <<-EOT
    Short name used to prefix ALL resource names and tags.
    Change this to reuse the same Terraform code for a different project.
    AWS ALB/ELB names do not allow underscores — use hyphens only.
    Example: "hexagon-final-project" (default), "my-webapp", "acme-api".
  EOT
  type    = string
  default = "hexagon-final-project"
}

variable "environment" {
  description = "Deployment environment label (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

# ── Ownership / tagging ───────────────────────────────────────────────────────

variable "owner" {
  description = "Owner tag applied to all resources — use your name or team name."
  type        = string
  default     = "martins"
}

# ── VPC ───────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across (must supply two)."
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets (bastion, web-tier ALB)."
  type        = list(string)
  default     = ["10.0.0.0/20", "10.0.16.0/20"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for the two private app subnets (web + app ASGs)."
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20"]
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for the two private DB subnets (RDS)."
  type        = list(string)
  default     = ["10.0.160.0/20", "10.0.176.0/20"]
}

# ── EC2 / Key pair ────────────────────────────────────────────────────────────

variable "key_pair_name" {
  description = "Existing EC2 key pair name for the bastion host (create in the AWS Console or import your public key first)."
  type        = string
  default     = "hexagon-key"
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR notation (e.g. 197.210.x.x/32) — locks down bastion SSH access."
  type        = string
}

variable "web_instance_type" {
  description = "EC2 instance type for the web-tier Auto Scaling Group."
  type        = string
  default     = "t3.micro"
}

variable "app_instance_type" {
  description = "EC2 instance type for the app-tier Auto Scaling Group."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum instances per ASG. Set to 1 on Free Tier (8 vCPU limit)."
  type        = number
  default     = 1
}

variable "asg_desired_capacity" {
  description = "Desired instances per ASG. Increase after requesting a vCPU limit increase."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum instances per ASG."
  type        = number
  default     = 4
}

variable "create_bastion" {
  description = "Set to true to create the bastion host. Disable on Free Tier to stay within the 8 vCPU limit while ASGs are running."
  type        = bool
  default     = false
}

variable "internal_alb_dns" {
  description = "DNS of the internal ALB — used by Nginx on web instances to proxy /api/ to the app tier. Set after first apply via: terraform output internal_alb_dns."
  type        = string
  default     = ""
}

# ── RDS ───────────────────────────────────────────────────────────────────────

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the PostgreSQL database to create."
  type        = string
  default     = "app_db"
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "app_admin"
}

variable "db_password" {
  description = "Master password for the RDS instance. Supply via TF_VAR_db_password env var or terraform.tfvars — never commit a real value."
  type        = string
  sensitive   = true
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS. Set true for production workloads."
  type        = bool
  default     = false
}

variable "db_allocated_storage" {
  description = "Allocated storage for the RDS instance in GB."
  type        = number
  default     = 20
}

# ── Container images ──────────────────────────────────────────────────────────

variable "app_image_tag" {
  description = "Docker image tag for the app-tier (backend Flask) container. CI/CD updates this after each push."
  type        = string
  default     = "latest"
}

variable "web_image_tag" {
  description = "Docker image tag for the web-tier (Nginx frontend) container. CI/CD updates this after each push."
  type        = string
  default     = "latest"
}

# ── GitHub / OIDC ─────────────────────────────────────────────────────────────

variable "github_org" {
  description = "GitHub organisation or username that owns this repository — used to scope the OIDC trust."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix) — used to scope the OIDC trust."
  type        = string
}
