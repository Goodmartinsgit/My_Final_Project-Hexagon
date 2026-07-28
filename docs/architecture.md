# Architecture — Hexagon Final Project

## Overview

A production-grade three-tier web application deployed on AWS using
Terraform (IaC), Docker (containers), and GitHub Actions (CI/CD).
All infrastructure is parameterised by a single `project_name` variable —
no hardcoded strings exist in any Terraform file.

## Three-Tier Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Internet                                    │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ HTTP :80
                    ┌────────────────▼────────────────┐
                    │       External ALB               │  Public subnets
                    │  {project_name}-external-alb     │  (eu-west-1a/b)
                    └────────────────┬────────────────┘
                                     │
          ┌──────────────────────────▼──────────────────────────┐
          │                 Web-tier ASG                         │
          │     {project_name}-web-asg  (t2.micro × 2–4)        │
          │     Nginx container from ECR ({project_name}/frontend│
          │     Private app subnets (eu-west-1a/b)              │
          └──────────────────────────┬──────────────────────────┘
                                     │ HTTP :5000
                    ┌────────────────▼────────────────┐
                    │       Internal ALB               │  Private app subnets
                    │  {project_name}-internal-alb     │
                    └────────────────┬────────────────┘
                                     │
          ┌──────────────────────────▼──────────────────────────┐
          │                 App-tier ASG                         │
          │     {project_name}-app-asg  (t2.micro × 2–4)        │
          │     Flask API container from ECR                     │
          │       ({project_name}/backend)                       │
          │     Private app subnets (eu-west-1a/b)              │
          └──────────────────────────┬──────────────────────────┘
                                     │ PostgreSQL :5432
          ┌──────────────────────────▼──────────────────────────┐
          │              RDS PostgreSQL                          │
          │    {project_name}-postgres  (db.t3.micro)            │
          │    Private DB subnets (eu-west-1a/b)                │
          └─────────────────────────────────────────────────────┘
```

### Bastion host
A single `t2.micro` instance in a public subnet provides SSH access
to the private tiers for debugging. Access is locked to `var.my_ip_cidr`.

### NAT Gateway
A managed NAT Gateway in the first public subnet gives the private app
subnets outbound internet access (for ECR pulls, package updates).

## VPC Layout

| Subnet type        | CIDR (default)         | AZs               | Purpose              |
|--------------------|------------------------|-------------------|----------------------|
| Public             | 10.0.0.0/20            | eu-west-1a        | Bastion, External ALB|
| Public             | 10.0.16.0/20           | eu-west-1b        | External ALB         |
| Private app        | 10.0.128.0/20          | eu-west-1a        | Web + App ASG        |
| Private app        | 10.0.144.0/20          | eu-west-1b        | Web + App ASG        |
| Private DB         | 10.0.160.0/20          | eu-west-1a        | RDS                  |
| Private DB         | 10.0.176.0/20          | eu-west-1b        | RDS (subnet group)   |

## Security Groups

| Group name                      | Inbound                          | Outbound        |
|---------------------------------|----------------------------------|-----------------|
| `{project_name}-bastion-sg`     | SSH from `my_ip_cidr` only       | All             |
| `{project_name}-webserver-sg`   | HTTP/HTTPS (0.0.0.0/0), SSH from bastion | All      |
| `{project_name}-appserver-sg`   | :5000 from webserver-sg, SSH from bastion | HTTPS (NAT), :5432 (DB) |
| `{project_name}-database-sg`    | :5432 from appserver-sg only     | All             |

## Naming Convention

**Every AWS resource name is derived from `var.project_name`:**

```hcl
# Example — same pattern used in all modules:
resource "aws_vpc" "main" {
  tags = { Name = "${var.project_name}-vpc" }
}
```

Changing `project_name` in `terraform/terraform.tfvars` renames every
resource in the stack in one place. No hardcoded strings exist in any module.

## ECR Repositories

| Repository name              | Contains                        |
|------------------------------|---------------------------------|
| `{project_name}/backend`     | Flask API (built from backend/) |
| `{project_name}/frontend`    | Nginx serving static HTML/CSS   |

Lifecycle policy: keep the 10 most recent images, expire older ones.

## CI/CD Pipelines

| Workflow              | Trigger                            | What it does                               |
|-----------------------|------------------------------------|--------------------------------------------|
| `backend-ci.yml`      | PR touching `backend/`             | Lint, format check, pytest, Trivy scan     |
| `backend-deploy.yml`  | Push to `main` touching `backend/` | Build + push backend to ECR, ASG refresh   |
| `frontend-ci.yml`     | PR touching `frontend/`            | HTML validation, URL check, Trivy scan     |
| `frontend-deploy.yml` | Push to `main` touching `frontend/`| Build + push Nginx to ECR, ASG refresh     |
| `terraform.yml`       | PR/dispatch on `terraform/`        | Plan (PR comment), Apply, Destroy          |

All workflows authenticate to AWS via **OIDC** — no static access keys stored.

## GitHub Actions Secrets Required

| Secret                   | Description                                          |
|--------------------------|------------------------------------------------------|
| `AWS_REGION`             | Target AWS region (e.g. `eu-west-1`)                 |
| `AWS_DEPLOY_ROLE_ARN`    | IAM role ARN for GitHub Actions OIDC authentication  |
| `ECR_REPOSITORY_BACKEND` | ECR repository name for the backend image            |
| `ECR_REPOSITORY_FRONTEND`| ECR repository name for the frontend image           |
| `APP_ASG_NAME`           | App-tier ASG name (from `terraform output app_asg_name`) |
| `WEB_ASG_NAME`           | Web-tier ASG name (from `terraform output web_asg_name`) |
| `ADMIN_IP_CIDR`          | Your IP in x.x.x.x/32 form                          |
| `TF_VAR_DB_PASSWORD`     | RDS master password                                  |
| `GITHUB_OWNER`           | GitHub username/org                                  |

## Cost Notes (development environment)

- Single-AZ RDS (`db_multi_az = false`) saves ~50 % of database costs.
- `t2.micro` instances stay within AWS Free Tier limits where eligible.
- NAT Gateway charges are the main cost driver (~$32/month). Consider
  replacing with a NAT instance (t2.micro) for non-production environments.

## Teardown

```bash
cd terraform
terraform destroy \
  -var="github_org=<your-org>" \
  -var="github_repo=<your-repo>" \
  -var="my_ip_cidr=<your-ip>/32" \
  -var="db_password=<your-password>"
```

Destroy the state bucket **only** once you are fully done (deletes state history):
```bash
# From the AWS Console or CLI — NOT managed by Terraform to prevent accidents
aws s3 rb s3://<your-bucket-name> --force
aws dynamodb delete-table --table-name <project_name>-tf-locks
```
