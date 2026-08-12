# PayBridge Live Demo Guide & Presentation Cheat Sheet

---

**Project Name:** PayBridge 3-Tier Microservice Infrastructure  
**Presenter:** Martins Goodluck Balogun (Cloud Engineer)  
**Duration:** 10 Minutes  
**AWS Region:** `eu-west-1`  
**AWS Account ID:** `790139457082`  

---

## Demo Agenda & Timeline

| Time | Topic | Action & Demonstration |
|---|---|---|
| **0:00 - 2:00** | **VPC & Network Layout** | AWS Console walkthrough of VPC, 6 Subnets, Route Tables, IGW, and NAT GW. |
| **2:00 - 4:00** | **Security Groups & Firewalls** | Walk through `bastion-sg`, `webserver-sg`, `appserver-sg`, and `database-sg` rules. |
| **4:00 - 6:00** | **Target Groups & ASGs** | Show Target Group health state (`healthy`) and Auto Scaling Group capacity. |
| **6:00 - 8:00** | **GitHub Actions & Docker ECR** | Demonstrate GitHub Actions workflow runs and ECR Docker repositories. |
| **8:00 - 10:00** | **Terraform & Architecture Q&A** | Run `terraform plan` (0 changes) and answer questions on RPO/RTO & scaling. |

---

## Step-by-Step Execution Script

### Step 1: Network & VPC Infrastructure (Console Walkthrough)
1. Open AWS Console → Navigate to **VPC Service** (`eu-west-1`).
2. Show `hexagon-final-project-vpc` (`10.0.0.0/16`).
3. Click **Subnets** and highlight the 6 subnets:
   - `public-eu-west-1a` (`10.0.0.0/20`) & `public-eu-west-1b` (`10.0.16.0/20`)
   - `app-private-eu-west-1a` (`10.0.128.0/20`) & `app-private-eu-west-1b` (`10.0.144.0/20`)
   - `db-private-eu-west-1a` (`10.0.160.0/20`) & `db-private-eu-west-1b` (`10.0.176.0/20`)
4. Point out **Internet Gateway** (`hexagon-final-project-igw`) attached to public subnets.
5. Point out **NAT Gateway** (`hexagon-final-project-nat-gw`) providing outbound access to private subnets.

### Step 2: Security Group Least Privilege Demonstration
1. Go to **EC2 → Security Groups**.
2. Select `hexagon-final-project-webserver-sg`: Show inbound HTTP:80 from `0.0.0.0/0` and SSH:22 from `bastion-sg` ID.
3. Select `hexagon-final-project-appserver-sg`: Show inbound TCP:5000 from `webserver-sg` ID only.
4. Select `hexagon-final-project-database-sg`: Show inbound PostgreSQL:5432 from `appserver-sg` ID only.

### Step 3: Target Group & Load Balancer Health Verification
1. Go to **EC2 → Target Groups**.
2. Select `hexagon-final-project-web-tg`: Show Target State = `healthy` (Nginx instances).
3. Select `hexagon-final-project-app-tg`: Show Target State = `healthy` (Flask API instances).

### Step 4: GitHub Actions CI/CD & ECR Container Inspection
1. Go to **AWS ECR → Repositories**.
2. Show `hexagon-final-project/frontend` and `hexagon-final-project/backend` repositories with `latest` image tags.
3. Open GitHub repository → **Actions** tab: Show successful automated CI/CD workflow runs (`frontend-deploy.yml` and `backend-deploy.yml`).

### Step 5: Terminal Verification Commands
Run the following commands in terminal during presentation:

```bash
# 1. Test Web Tier Health
curl -i http://hexagon-final-project-ext-alb-633462384.eu-west-1.elb.amazonaws.com/health

# 2. Test App Tier Health via Proxy
curl -i http://hexagon-final-project-ext-alb-633462384.eu-west-1.elb.amazonaws.com/api/health
```
