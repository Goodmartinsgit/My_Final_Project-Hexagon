terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Fill in after running bootstrap.sh (or terraform/bootstrap/):
    #   bucket         = "<output of bootstrap: state_bucket_name>"
    #   key            = "hexagon-final-project/terraform.tfstate"
    #   region         = "eu-west-1"
    #   dynamodb_table = "<project_name>-tf-locks"
    #   encrypt        = true
    #
    # Then run: terraform init -reconfigure
    bucket         = "hexagon-final-project-tfstate-CHANGEME"
    key            = "hexagon-final-project/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "hexagon-final-project-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "Terraform"
    }
  }
}

# ── VPC — network foundation ──────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name             = var.project_name
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  azs                      = var.azs
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
}

# ── Security groups ───────────────────────────────────────────────────────────
module "security_groups" {
  source = "./modules/security_groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  my_ip_cidr   = var.my_ip_cidr
}

# ── ECR — container registries for web and app images ────────────────────────
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

# ── Compute — bastion, ALBs, launch templates, ASGs ──────────────────────────
module "compute" {
  source = "./modules/compute"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  app_subnet_ids      = module.vpc.private_app_subnet_ids
  key_pair_name       = var.key_pair_name
  bastion_sg_id       = module.security_groups.bastion_sg_id
  webserver_sg_id     = module.security_groups.webserver_sg_id
  appserver_sg_id     = module.security_groups.appserver_sg_id
  web_instance_type   = var.web_instance_type
  app_instance_type   = var.app_instance_type
  app_ecr_repo_url    = module.ecr.app_repo_url
  web_ecr_repo_url    = module.ecr.web_repo_url
  app_image_tag       = var.app_image_tag
  web_image_tag       = var.web_image_tag
}

# ── RDS — managed PostgreSQL ──────────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  project_name       = var.project_name
  environment        = var.environment
  db_subnet_ids      = module.vpc.private_db_subnet_ids
  database_sg_id     = module.security_groups.database_sg_id
  db_instance_class  = var.db_instance_class
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  db_allocated_storage = var.db_allocated_storage
  multi_az           = var.db_multi_az
}
