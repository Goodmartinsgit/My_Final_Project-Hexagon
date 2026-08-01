# DB Subnet Group — RDS requires subnets in at least two AZs
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# RDS PostgreSQL instance
# multi_az defaults to false to keep dev costs low.
# Set to true in terraform.tfvars for production workloads.
resource "aws_db_instance" "postgres" {
  identifier     = "${var.project_name}-postgres"
  engine         = "postgres"
  engine_version = "15"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 100
  storage_type          = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.database_sg_id]
  publicly_accessible    = false

  multi_az                = var.multi_az
  backup_retention_period = 0
  # Note: backup_retention_period = 0 disables automated backups.
  # Free Tier accounts cannot set this above 0 without upgrading.
  # For production, upgrade your account and set this to 7 or higher.

  # skip_final_snapshot = true is acceptable for dev environments that are
  # torn down regularly. Set to false and provide final_snapshot_identifier
  # for any environment where data must survive a terraform destroy.
  skip_final_snapshot = true

  tags = {
    Name = "${var.project_name}-postgres"
  }
}
