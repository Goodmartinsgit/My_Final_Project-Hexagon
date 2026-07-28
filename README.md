# Hexagon Final Project — Three-Tier Web Application on AWS

A production-grade three-tier web architecture provisioned as code and deployed
through CI/CD — no manual clicking in the console. Read this top-to-bottom before
running anything; the order matters.

**Key principle:** Every AWS resource name is prefixed with `var.project_name`.
No string is hardcoded in any Terraform file. Renaming the project means
changing one variable.

## Architecture Overview

```
Presentation tier  — Nginx container (ECR) on web-tier ASG behind a public ALB
Application tier   — Flask REST API container (ECR) on app-tier ASG behind an internal ALB
Data tier          — PostgreSQL on RDS in private subnets
```

Full architecture diagram, VPC layout, and security group rules: [docs/architecture.md](docs/architecture.md)

## Repository Layout

```
.
├── backend/                   Flask API (Python)
│   ├── app.py                 Application factory
│   ├── config.py              Environment-based configuration
│   ├── models.py              SQLAlchemy models
│   ├── routes.py              API route handlers
│   ├── requirements.txt       Production dependencies (includes Gunicorn)
│   ├── requirements-dev.txt   Development / test dependencies
│   ├── .env.example           Required environment variables (no real values)
│   ├── tests/                 Pytest test suite
│   └── Dockerfile             Production image (Gunicorn + Flask, non-root user)
│
├── frontend/                  Static HTML/CSS site
│   ├── index.html
│   ├── features.html
│   ├── docs.html
│   ├── css/
│   ├── images/
│   └── Dockerfile             Nginx image for local dev and web-tier ECR
│
├── terraform/                 Terraform — provisions all AWS infrastructure
│   ├── main.tf                Backend config, provider, and all module wiring
│   ├── variables.tf           All variables — project_name is the naming prefix
│   ├── outputs.tf             Key values output after apply
│   ├── terraform.tfvars.example  Copy to terraform.tfvars and fill in real values
│   └── modules/
│       ├── vpc/               VPC, subnets (public/private-app/private-db), IGW, NAT, route tables
│       ├── security_groups/   Bastion, web, app, and database security groups
│       ├── ecr/               ECR repos: {project_name}/backend and {project_name}/frontend
│       ├── compute/           Bastion, IAM, launch templates, ALBs, target groups, ASGs
│       └── rds/               RDS PostgreSQL instance and subnet group
│
├── .github/workflows/         GitHub Actions CI/CD pipelines
│   ├── backend-ci.yml         Lint, test, and security-scan on pull request
│   ├── backend-deploy.yml     Build backend/ image, push to ECR, trigger app ASG refresh
│   ├── frontend-ci.yml        Validate frontend on pull request
│   ├── frontend-deploy.yml    Build frontend/ image, push to ECR, trigger web ASG refresh
│   └── terraform.yml          Plan on PR (comments output), apply/destroy via workflow_dispatch
│
├── docs/
│   └── architecture.md        Full architecture diagram and design decisions
│
├── docker-compose.yml          Local development — spins up db, api, webapp, and pgadmin
├── bootstrap.sh                One-time setup: creates S3 state bucket + DynamoDB lock table
└── README.md
```

## Local Development

### Prerequisites

- Docker and Docker Compose
- Python 3.11 or later (for running tests outside containers)

### Start all services

```bash
docker compose up --build
```

This starts four containers:

```
hexagon_db       PostgreSQL 16 on port 5433
hexagon_api      Flask API on port 5000
hexagon_webapp   Nginx serving the static frontend on port 80
hexagon_pgadmin  pgAdmin on port 5050 (optional, for DB inspection)
```

Open http://localhost in your browser.
The demo form submits to http://localhost:5000/api/demo.

### Run backend tests

```bash
cd backend
pip install -r requirements.txt -r requirements-dev.txt
pytest tests/ -v --cov=. --cov-report=term-missing
```

## Infrastructure Deployment

### 1. Prerequisites (local machine)

```bash
# Git Bash on Windows (or WSL / Linux / macOS)
aws configure   # configure your IAM user credentials for the one-time bootstrap only
```

Ensure `terraform` v1.7+ is in your PATH.

### 2. Bootstrap the remote state backend (once, ever)

```bash
bash bootstrap.sh
```

This creates the S3 bucket and DynamoDB table used to store Terraform state.
Copy the bucket name printed at the end into `terraform/main.tf`'s `backend "s3"` block, then:

```bash
cd terraform && terraform init
```

### 3. Set up GitHub OIDC (once, manual step)

GitHub Actions authenticates to AWS via OIDC — no static access keys stored.

In the AWS Console:

1. **IAM → Identity providers → Add provider → OpenID Connect**
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
2. **IAM → Roles → Create role → Web identity**
   - Select the OIDC provider above
   - Condition: `token.actions.githubusercontent.com:sub` = `repo:<org>/<repo>:ref:refs/heads/main`
3. Attach a policy granting EC2, VPC, ELB, RDS, ECR, IAM, S3, and DynamoDB permissions
4. Copy the role ARN → **GitHub Repo → Settings → Secrets → `AWS_DEPLOY_ROLE_ARN`**

### 4. Configure GitHub Secrets

| Secret                    | Where to get the value                                  |
|---------------------------|---------------------------------------------------------|
| `AWS_REGION`              | Your target region (e.g. `eu-west-1`)                  |
| `AWS_DEPLOY_ROLE_ARN`     | IAM role ARN from step 3 above                          |
| `ECR_REPOSITORY_BACKEND`  | `terraform output ecr_app_repo_url` (after apply)       |
| `ECR_REPOSITORY_FRONTEND` | `terraform output ecr_web_repo_url` (after apply)       |
| `APP_ASG_NAME`            | `terraform output app_asg_name` (after apply)           |
| `WEB_ASG_NAME`            | `terraform output web_asg_name` (after apply)           |
| `ADMIN_IP_CIDR`           | Your public IP in `x.x.x.x/32` form                    |
| `TF_VAR_DB_PASSWORD`      | Strong RDS master password                              |
| `GITHUB_OWNER`            | Your GitHub username or organisation                    |

### 5. First infrastructure deploy

```bash
# Copy the example file and fill in real values:
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit terraform/terraform.tfvars — set project_name, my_ip_cidr, db_password, github_org/repo

cd terraform
terraform plan   # review the plan
terraform apply  # provision VPC, security groups, ECR, compute, RDS
```

Or open a pull request — `terraform.yml` runs automatically and comments the plan on the PR.
Merging to `main` and triggering `workflow_dispatch → apply` provisions real infrastructure.

### 6. Push the first images

After `terraform apply` creates the ECR repos (instances will be unhealthy until images exist):

```bash
# Push to main — backend-deploy.yml and frontend-deploy.yml run automatically.
# Or trigger workflow_dispatch manually in the GitHub Actions tab.
```

### 7. Refresh the ASGs

The GitHub Actions deploy workflows trigger a rolling instance refresh automatically.
You can also do it manually:

```bash
aws autoscaling start-instance-refresh --auto-scaling-group-name <app_asg_name>
aws autoscaling start-instance-refresh --auto-scaling-group-name <web_asg_name>
```

## Naming Convention

All AWS resource names are prefixed with `var.project_name` (default: `hexagon-final-project`).
To rename the entire stack, change `project_name` in `terraform/terraform.tfvars` and run `terraform apply`.

## Teardown

```bash
cd terraform
terraform destroy \
  -var="github_org=<your-org>" \
  -var="github_repo=<your-repo>" \
  -var="my_ip_cidr=<your-ip>/32" \
  -var="db_password=<your-password>"
```

See [docs/architecture.md](docs/architecture.md) for instructions on destroying the
state bucket once you are completely finished.
