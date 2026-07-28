variable "project_name" {
  description = "Short name prefix applied to every resource name and tag."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

variable "db_subnet_ids" {
  description = "IDs of the private DB subnets (RDS requires subnets in at least two AZs)."
  type        = list(string)
}

variable "database_sg_id" {
  description = "Security group ID restricting access to the DB instance."
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class (e.g. db.t3.micro)."
  type        = string
}

variable "db_name" {
  description = "Name of the PostgreSQL database to create."
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
}

variable "db_password" {
  description = "Master password for the RDS instance. Always supply via TF_VAR env var or terraform.tfvars — never commit a real value."
  type        = string
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "Initial storage allocation in GB."
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Enable Multi-AZ standby replica. Set true for production workloads."
  type        = bool
  default     = false
}
