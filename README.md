# Hexagon Final Project — Three-Tier Web Architecture on AWS

A production-grade, highly available three-tier web application provisioned using **Terraform (IaC)**, containerized with **Docker**, and deployed across AWS infrastructure (VPC, ALBs, EC2 Auto Scaling Groups, ECR, and RDS PostgreSQL).

---

## Architecture Overview

```
Presentation Tier  — Nginx web server container on Web ASG behind External ALB
Application Tier   — Flask REST API container on App ASG behind Internal ALB
Data Tier          — PostgreSQL Database on RDS in Private DB Subnets
```

For full architecture diagrams, security group rules, and subnet layouts, see [docs/architecture_report.md](docs/architecture_report.md).

---

## Repository Layout

```
.
├── backend/                   Flask REST API (Python 3.11 + Gunicorn)
│   ├── app.py                 Application factory & entrypoint
│   ├── config.py              Database & environment configuration
│   ├── models.py              SQLAlchemy models (DemoRequest schema)
│   ├── routes.py              API route handlers (/health, /api/demo)
│   ├── requirements.txt       Production dependencies
│   ├── tests/                 Pytest suite
│   └── Dockerfile             Production Gunicorn container image
│
├── frontend/                  Loruki Static HTML/CSS Web Application
│   ├── index.html             Home page with "Request a Demo" form
│   ├── features.html          Platform features overview
│   ├── docs.html              Technical documentation page
│   ├── submissions.html       Submissions dashboard (Card / Table views & live search)
│   ├── css/                   Stylesheets (style.css, utilities.css)
│   ├── nginx.conf             Nginx reverse proxy configuration & cache-control headers
│   └── Dockerfile             Nginx production image
│
├── terraform/                 Terraform Infrastructure Code
│   ├── main.tf                Backend provider & module wiring
│   ├── variables.tf           Input variables (project_name prefix)
│   ├── outputs.tf             ALB DNS, ECR URLs, and ASG names
│   ├── terraform.tfvars.example  Configuration template
│   └── modules/               VPC, Security Groups, ECR, Compute, RDS
│
├── .github/workflows/         GitHub Actions CI/CD pipelines
│   ├── backend-deploy.yml     Build & push backend container to ECR
│   └── frontend-deploy.yml    Build & push frontend container to ECR
│
├── docs/
│   ├── architecture.md        Detailed network layout & design decisions
│   ├── architecture_report.md Full Capstone Architecture Report & Reflection Answers (Tasks 1-6)
│   └── demo_guide.md          10-Minute Live Demo Presentation Guide & Script
│
├── docker-compose.yml          Local development environment
├── bootstrap.sh                One-time S3 state bucket & DynamoDB lock setup script
└── README.md                   Project lifecycle & operation guide
```

---

## Complete Application Lifecycle

Follow these steps in order to **Initialize**, **Deploy**, **Start**, and **Teardown** the infrastructure.

---

### Step 0: Prerequisites & Tool Setup

Ensure the following tools are installed on your machine:
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (configured with credentials: `aws configure`)
- [Terraform v1.7+](https://developer.hashicorp.com/terraform/downloads)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (running)
- Git / Bash environment

---

### Step 1: Initialize Infrastructure & Remote State Backend

1. **Bootstrap S3 Remote State Bucket and DynamoDB Lock Table**:
   Run the setup script from the project root:
   ```bash
   bash bootstrap.sh
   ```
   *Note the created S3 bucket name printed in the script output.*

2. **Configure Remote State in Terraform**:
   Open `terraform/main.tf` and ensure the `backend "s3"` block contains your bucket name and region:
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "hexagon-final-project-tf-state-xxxx"
       key            = "hexagon/terraform.tfstate"
       region         = "eu-west-1"
       dynamodb_table = "hexagon-final-project-tf-locks"
       encrypt        = true
     }
   }
   ```

3. **Initialize Terraform Workspace**:
   ```bash
   cd terraform
   terraform init
   ```

---

### Step 2: Configure & Provision AWS Infrastructure (Deploy)

1. **Create Variable File**:
   Copy the template and specify your deployment parameters:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`**:
   ```hcl
   project_name = "hexagon-final-project"
   aws_region   = "eu-west-1"
   my_ip_cidr   = "YOUR_PUBLIC_IP/32"  # e.g., 203.0.113.25/32
   db_password  = "YOUR_SECURE_DB_PASSWORD"
   github_org   = "your-github-username"
   github_repo  = "your-repo-name"
   ```

3. **Review & Apply Terraform Configuration**:
   ```bash
   terraform plan
   terraform apply -auto-approve
   ```

4. **Capture Infrastructure Outputs**:
   After `terraform apply` finishes successfully, display the outputs:
   ```bash
   terraform output
   ```
   Take note of:
   - `external_alb_dns`: Public ALB domain name
   - `ecr_web_repo_url`: ECR repository URL for Frontend
   - `ecr_app_repo_url`: ECR repository URL for Backend
   - `web_asg_name`: Web Auto Scaling Group name
   - `app_asg_name`: App Auto Scaling Group name

---

### Step 3: Build, Push Container Images & Start Application Services

1. **Log into AWS ECR**:
   Get your AWS Account ID and authenticate Docker against ECR:
   ```bash
   AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   AWS_REGION="eu-west-1"

   aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
   ```

2. **Build and Push Backend Image**:
   ```bash
   cd ../backend
   docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/hexagon-final-project/backend:latest .
   docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/hexagon-final-project/backend:latest
   ```

3. **Build and Push Frontend Image**:
   ```bash
   cd ../frontend
   docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/hexagon-final-project/frontend:latest .
   docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/hexagon-final-project/frontend:latest
   ```

4. **Trigger Auto Scaling Instance Refreshes (Start Services)**:
   Trigger rolling instance refreshes so EC2 instances pull and run the latest Docker containers:
   ```bash
   aws autoscaling start-instance-refresh --auto-scaling-group-name hexagon-final-project-app-asg --region eu-west-1
   aws autoscaling start-instance-refresh --auto-scaling-group-name hexagon-final-project-web-asg --region eu-west-1
   ```

---

### Step 4: Access & Verify Live Application

1. **Web Tier Health Check**:
   ```bash
   curl -i http://<EXTERNAL_ALB_DNS>/health
   # Response: HTTP 200 OK {"status":"ok","tier":"web"}
   ```

2. **App Tier & End-to-End Routing Check**:
   ```bash
   curl -i http://<EXTERNAL_ALB_DNS>/api/health
   # Response: HTTP 200 OK {"status":"ok"}
   ```

3. **Open Web Pages in Browser**:
   - **Home Page**: `http://<EXTERNAL_ALB_DNS>/index.html`
   - **Submissions Page**: `http://<EXTERNAL_ALB_DNS>/submissions.html`

4. **Test Data Flow (Frontend → Backend → RDS PostgreSQL)**:
   Submit a test request via curl or using the web form:
   ```bash
   curl -i -X POST http://<EXTERNAL_ALB_DNS>/api/demo \
     -H "Content-Type: application/json" \
     -d '{"name":"Hexagon User","company":"Hexagon Global","email":"user@hexagon.com"}'
   ```
   Then view the saved record on the Submissions dashboard (`http://<EXTERNAL_ALB_DNS>/submissions.html`).

---

### Step 5: Teardown & Clean Up Infrastructure

To completely destroy all created resources and stop incurring charges:

1. **Delete Images from ECR Repositories**:
   ECR repositories cannot be destroyed by Terraform if they contain images. Clear them using AWS CLI:
   ```bash
   aws ecr batch-delete-image --repository-name hexagon-final-project/backend --image-ids imageTag=latest --region eu-west-1
   aws ecr batch-delete-image --repository-name hexagon-final-project/frontend --image-ids imageTag=latest --region eu-west-1
   ```

2. **Run Terraform Destroy**:
   ```bash
   cd terraform
   terraform destroy -auto-approve
   ```

3. **Delete Remote State S3 Bucket and DynamoDB Lock Table (Optional Final Cleanup)**:
   ```bash
   S3_BUCKET=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'hexagon-final-project-tf-state')].Name" --output text)
   aws s3 rb s3://$S3_BUCKET --force
   aws dynamodb delete-table --table-name hexagon-final-project-tf-locks --region eu-west-1
   ```

---

## Local Development (Docker Compose)

To run the entire 4-container stack locally without deploying to AWS:

```bash
docker compose up --build
```

Services started:
- `hexagon_db`: PostgreSQL on port `5433`
- `hexagon_api`: Flask API on port `5000`
- `hexagon_webapp`: Nginx Frontend on port `80`
- `hexagon_pgadmin`: DB administration UI on port `5050`

---

## Capstone Architecture Report & Technical Documentation

For a comprehensive, production-grade architectural analysis and reflection documentation, refer to the full [AWS Cloud Engineering Capstone Architecture Report](docs/architecture_report.md).

### Key Report Highlights:
- **End-to-End Architecture & Network Topology**: Complete request routing analysis from external ingress to multi-AZ Web/App Auto Scaling Groups and private RDS PostgreSQL.
- **VPC Subnet & Security Group Specifications**: Least-privilege firewall rules (`bastion-sg`, `webserver-sg`, `appserver-sg`, `database-sg`) and subnet IP calculations.
- **CI/CD & Container Orchestration**: Automated GitHub Actions pipelines using AWS OIDC authentication, ECR registries, and rolling ASG instance refreshes.
- **Capstone Reflections (Tasks 1–6)**: Detailed theoretical and operational reflection answers covering VPC design, stateful firewalls, EC2 Auto Scaling, ALBs, RDS storage, and Terraform IaC advantages.
- **Cost Analysis & Production Hardening**: Monthly AWS expenditure breakdowns and roadmap recommendations for WAF, HTTPS/TLS termination, Multi-AZ database failover, and KMS encryption.

