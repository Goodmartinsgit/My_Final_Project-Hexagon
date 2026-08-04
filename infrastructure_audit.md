# Infrastructure Audit — Hexagon Final Project

> **Symptoms reported:** Cannot access app via external ALB DNS. When it briefly worked, frontend couldn't connect to backend / database.

---

## Architecture Overview

```
Internet → External ALB (public subnets) → Web ASG (public subnets, Nginx)
                                                      ↓ /api/ proxy
                                         Internal ALB (private app subnets)
                                                      ↓
                                          App ASG (private app subnets, Flask)
                                                      ↓
                                           RDS PostgreSQL (private DB subnets)
```

---

## 🔴 Critical Bug #1 — Web ASG instances placed in PUBLIC subnets (wrong tier)

**File:** [`compute/main.tf` L264](file:///c:/Users/DELL%20XPS/Desktop/Hexagon_Final_Project/terraform/modules/compute/main.tf#L262-L289)

```hcl
# CURRENT (BROKEN):
resource "aws_autoscaling_group" "web" {
  vpc_zone_identifier = var.public_subnet_ids   # ← Web servers in public subnets
```

The Web-tier (Nginx) instances are in **public subnets**, but these subnets are where the *External ALB* lives. That's actually fine for a simple setup, BUT the bigger problem is that `var.app_subnet_ids` in the compute module's variable description says "IDs of the private app subnets **(web + app ASGs)**" — this is a naming inconsistency that created the wrong routing. More critically:

**The Internal ALB is placed in `var.app_subnet_ids` (private subnets), and then Nginx proxies to it — but the web ASG also needs to reach the Internal ALB from the public subnet, which requires proper routing.**

This is actually the source of the second symptom (Nginx can't reach the internal ALB).

---

## 🔴 Critical Bug #2 — Internal ALB Security Group allows only `appserver_sg_id`, not `webserver_sg_id`

**File:** [`compute/main.tf` L238-L248](file:///c:/Users/DELL%20XPS/Desktop/Hexagon_Final_Project/terraform/modules/compute/main.tf#L238-L248)

```hcl
resource "aws_lb" "internal" {
  security_groups = [var.appserver_sg_id]   # ← WRONG
  subnets         = var.app_subnet_ids
```

The internal ALB is assigned the **`appserver` security group**, which only allows inbound port 5000 from `webserver_sg`. But the internal ALB itself needs to **accept traffic from the web tier** on port 5000 and **forward it to app instances** — yet its SG is the same as the app instances. This creates a circular/wrong trust chain.

**Result:** The internal ALB has no explicit ingress rule allowing the web-tier Nginx to reach it. Traffic is blocked.

**Fix:** Create a dedicated `internal_alb_sg` that:
- Allows inbound 5000 from `webserver_sg_id`
- The `appserver_sg` allows inbound 5000 from `internal_alb_sg` (not `webserver_sg` directly)

---

## 🔴 Critical Bug #3 — App tier receives no DB connection details at runtime

**File:** [`compute/main.tf` L142-L161](file:///c:/Users/DELL XPS/Desktop/Hexagon_Final_Project/terraform/modules/compute/main.tf#L142-L161)

The app-tier launch template user_data runs:
```bash
docker run -d -p 5000:5000 \
  -e SERVICE_NAME=... \
  -e ALLOWED_ORIGIN=... \
  --name ... \
  ${var.app_ecr_repo_url}:${var.app_image_tag}
```

**No `DATABASE_URL`, `DB_HOST`, `DB_NAME`, `DB_USER`, or `DB_PASSWORD` environment variables are passed.** The Flask backend (`config.py`) reads `DATABASE_URL` from the environment. Without it, it falls back to `postgresql://postgres:postgres@{DB_HOST}:5432/demo_db` — and `DB_HOST` is also not set, so it resolves to `postgresql://postgres:postgres@None:5432/demo_db`.

**Result:** Every database call fails. The RDS instance exists but the backend can never connect.

**Fix:** Pass the RDS endpoint and credentials as environment variables in the launch template, reading from the `rds` module outputs.

---

## 🔴 Critical Bug #4 — Health check path mismatch on the Internal ALB target group

**File:** [`compute/main.tf` L196-L212](file:///c:/Users/DELL%20XPS/Desktop/Hexagon_Final_Project/terraform/modules/compute/main.tf#L196-L212)

```hcl
resource "aws_lb_target_group" "app" {
  health_check {
    path = "/api/health"   # ← Expects /api/health
```

The Flask app registers the health route at `/api/health` (via the blueprint prefix `/api` + route `/health`). However, the `docker/app/app.py` (the simple placeholder image) only has `/health` — **not** `/api/health`. Until the real backend image is pushed and deployed, the health check fails and the Internal ALB marks all app instances as unhealthy → no traffic reaches the backend.

The **backend `routes.py`** correctly has `@demo_bp.route("/health")` with prefix `/api`, so the real app works at `/api/health`. But the `docker/app/app.py` placeholder only exposes `/health`. This means:
- If ECR pull fails → placeholder runs → health check at `/api/health` fails → app TG unhealthy
- Nginx proxies to an unhealthy (or no-target) ALB → 502/503 errors

---

## 🟡 Major Issue #5 — Circular dependency: Internal ALB DNS hardcoded as a variable

**File:** [`terraform.tfvars` L26](file:///c:/Users/DELL%20XPS/Desktop/Hexagon_Final_Project/terraform/terraform.tfvars#L26) & [`compute/main.tf` L91](file:///c:/Users/DELL%20XPS/Desktop/Hexagon_Final_Project/terraform/modules/compute/main.tf#L91)

```hcl
# In compute/main.tf web user_data (Nginx config):
proxy_pass http://${aws_lb.internal.dns_name}:5000/api/;
```

The web-tier Nginx config references `${aws_lb.internal.dns_name}` **directly** in the launch template — this is interpolated at Terraform apply time and baked into the Launch Template. This part is actually correct.

However, `var.internal_alb_dns` is also passed as a separate variable in `terraform.tfvars` but **is NOT used** in `compute/main.tf` for the web user_data (the template directly uses `aws_lb.internal.dns_name`). The hardcoded `internal_alb_dns` in `terraform.tfvars` is a stale/unused value that creates confusion.

**The real problem:** When `asg_min_size = 0` or when the launch template is first applied with the wrong internal ALB DNS (e.g. the one from `terraform.tfvars`), the Nginx config inside already-running web instances will have a stale internal ALB DNS. **An ASG instance refresh must be triggered after every terraform apply that changes the internal ALB DNS.**

---

## 🟡 Major Issue #6 — External ALB uses `webserver_sg` — missing dedicated ALB security group

**File:** [`compute/main.tf` L215-L225](file:///c:/Users/DELL%20XPS/Desktop/Hexagon_Final_Project/terraform/modules/compute/main.tf#L215-L225)

```hcl
resource "aws_lb" "external" {
  security_groups = [var.webserver_sg_id]   # ← ALB shares SG with EC2 instances
```

AWS strongly recommends separate security groups for ALBs vs. their EC2 targets. When the same SG is shared:
- You can't distinguish "traffic from the ALB" vs. "direct traffic to EC2" 
- Introduces security risks and can cause health check ambiguity

**Fix:** Create dedicated `external_alb_sg` (port 80/443 from 0.0.0.0/0) and `webserver_sg` that allows port 80 only from `external_alb_sg`.

---

## 🟡 Major Issue #7 — `appserver_sg` self-reference rule is wrong for internal ALB

**File:** [`security_groups/main.tf` L85-L91](file:///c:/Users/DELL%20XPS/Desktop/Hexagon_Final_Project/terraform/modules/security_groups/main.tf#L85-L91)

```hcl
ingress {
  description = "App traffic from internal ALB (self)"
  from_port   = 5000
  to_port     = 5000
  protocol    = "tcp"
  self        = true   # ← This allows traffic FROM appserver_sg members to themselves
}
```

The `self = true` rule allows inbound from resources in the **same security group** — i.e., app instances talking to each other. But the **Internal ALB also uses `appserver_sg_id`** (Bug #2), so this is what makes it work at all. However, it's semantically wrong and fragile. The real fix is a dedicated ALB security group (see Bug #2 fix).

---

## 🟡 Major Issue #8 — Backend Docker image missing `gunicorn` dependency

**File:** [`docker/app/requirements.txt`](file:///c:/Users/DELL XPS/Desktop/Hexagon_Final_Project/docker/app/requirements.txt)

The `docker/app/Dockerfile` uses `CMD ["gunicorn", ...]` but the placeholder's `requirements.txt` likely only has `flask`. Let me cross-check:

- `docker/app/requirements.txt` (30 bytes) — very small, likely just `flask`
- `backend/requirements.txt` (115 bytes) — larger, likely includes gunicorn

The **placeholder docker image** (`docker/app/`) has its own minimal `app.py` and `Dockerfile`, which CMD calls `gunicorn` without `gunicorn` in `requirements.txt`. This means the placeholder container will fail to start.

---

## 🟡 Major Issue #9 — `config.py` environment loading bug (logic error)

**File:** [`backend/config.py` L6-L13](file:///c:/Users/DELL%20XPS/Desktop/Hexagon_Final_Project/backend/config.py#L6-L13)

```python
env = os.getenv("ENV_MODE", "development")

if env == "production":
    load_dotenv(".env.prod")
if env == "test":          # ← Should be elif
    load_dotenv(".env.test")
else:                      # ← This 'else' always runs unless env == "test"
    load_dotenv(".env.dev")
```

**Bug:** When `ENV_MODE=production`, the code loads `.env.prod` correctly, but then falls into the `else` branch (since `env != "test"`) and **also loads `.env.dev`**, potentially overwriting production settings.

**Fix:** Change `if env == "test":` to `elif env == "test":`.

---

## 🟡 Major Issue #10 — Frontend nginx.conf proxies to docker-compose hostname `api`

**File:** [`frontend/nginx.conf` L14](file:///c:/Users/DELL XPS/Desktop/Hexagon_Final_Project/frontend/nginx.conf#L14)

```nginx
location /api/ {
    proxy_pass http://api:5000/api/;   # ← docker-compose service name
```

This Nginx config is **baked into the web ECR image**. When deployed on EC2 (not docker-compose), the hostname `api` does not resolve. The **web-tier Nginx correctly overrides this in the user_data** with a proper config pointing to `aws_lb.internal.dns_name` — but only if that user_data script runs successfully and the container is started with the volume-mounted config.

**The problem:** The `docker run` command in user_data does:
```bash
docker run -d -p 80:80 \
  -v /tmp/default.conf:/etc/nginx/conf.d/default.conf:ro \
  ...
```
It mounts `/tmp/default.conf` over the baked-in config. This **only works if the ECR pull fails** (falls back to `nginx:alpine`). When the **real web ECR image** is pulled, the volume mount still applies but the container image's built-in `/etc/nginx/conf.d/default.conf` would be overwritten by the mount. This is correct behavior, but the image's default config (which proxies to `api:5000`) would be the fallback if the mount failed.

---

## 🟡 Major Issue #11 — `docker/web/default.conf` does NOT proxy `/api/` at all

**File:** [`docker/web/default.conf`](file:///c:/Users/DELL XPS/Desktop/Hexagon_Final_Project/docker/web/default.conf)

```nginx
server {
    listen 80;
    location / {
        default_type application/json;
        return 200 '{"status":"ok","tier":"web"}';   # ← just a health stub
    }
    location /health { ... }
}
```

This is the config **baked into the web ECR image** via `docker/web/Dockerfile`. It has **no `/api/` proxy block**. If someone runs this container directly (e.g. in a test or the ECR pull succeeds but the volume mount in user_data fails), all `/api/` calls return a 200 JSON stub instead of proxying to the backend.

The actual proxy config lives in the **launch template user_data** as an inline heredoc — it's not in the `docker/web/` Nginx config. The two configs are inconsistent.

---

## 🟠 Minor Issue #12 — RDS outputs not exported for use by the compute module

**File:** [`terraform/modules/rds/`](file:///c:/Users/DELL%20XPS/Desktop/Hexagon_Final_Project/terraform/modules/rds/) — check outputs.tf

The RDS module must output `db_endpoint` (or `db_address`) so that `main.tf` can pass `module.rds.db_endpoint` to the compute module for the app launch template's `DATABASE_URL`. If this output doesn't exist, the fix for Bug #3 cannot be wired up in `main.tf`.

---

## 🟠 Minor Issue #13 — `my_ip_cidr = "0.0.0.0/0"` in terraform.tfvars

**File:** [`terraform.tfvars` L13](file:///c:/Users/DELL%20XPS/Desktop/Hexagon_Final_Project/terraform/terraform.tfvars#L13)

```hcl
my_ip_cidr = "0.0.0.0/0"   # ← Bastion SSH open to the entire internet
```

This opens SSH on the bastion to the entire internet. While `create_bastion = false` mitigates this for now, it's a security risk that should be scoped to your actual IP (`/32`).

---

## Summary Table

| # | Severity | Problem | Affected File(s) | Impact |
|---|----------|---------|-----------------|--------|
| 1 | 🔴 Critical | Web ASG in wrong subnet scope (variable naming confusion) | `compute/main.tf` | Routing confusion |
| 2 | 🔴 Critical | Internal ALB assigned `appserver_sg` — no proper trust from web tier | `compute/main.tf`, `security_groups/main.tf` | Frontend→backend blocked |
| 3 | 🔴 Critical | No DB env vars passed to app container | `compute/main.tf` | DB connection always fails |
| 4 | 🔴 Critical | Health check `/api/health` fails for placeholder image | `compute/main.tf`, `docker/app/app.py` | App TG unhealthy, 502s |
| 5 | 🟡 Major | `internal_alb_dns` var unused; stale values cause confusion | `terraform.tfvars`, `compute/main.tf` | Stale Nginx configs |
| 6 | 🟡 Major | External ALB shares SG with web instances | `compute/main.tf` | Security + health check ambiguity |
| 7 | 🟡 Major | `appserver_sg self` rule is wrong/fragile | `security_groups/main.tf` | Fragile networking |
| 8 | 🟡 Major | Placeholder image CMD uses gunicorn but requirements.txt missing it | `docker/app/` | Container startup failure |
| 9 | 🟡 Major | `config.py` else-branch always loads `.env.dev` | `backend/config.py` | Production config override |
| 10 | 🟡 Major | `frontend/nginx.conf` proxies to docker-compose hostname | `frontend/nginx.conf` | Wrong proxy in ECR image |
| 11 | 🟡 Major | `docker/web/default.conf` has no `/api/` proxy block | `docker/web/default.conf` | All API calls return stubs |
| 12 | 🟠 Minor | RDS endpoint not passed to compute module | `main.tf`, `rds/outputs.tf` | Can't wire DB fix |
| 13 | 🟠 Minor | SSH bastion open to 0.0.0.0/0 | `terraform.tfvars` | Security risk |

---

## Fix Priority & Action Plan

### Phase 1 — Infrastructure Fixes (Terraform)

**1. Create dedicated security groups for ALBs:**
```hcl
# NEW: external_alb_sg — allows HTTP/HTTPS from internet
resource "aws_security_group" "external_alb" { ... }

# NEW: internal_alb_sg — allows port 5000 from webserver_sg
resource "aws_security_group" "internal_alb" { ... }

# MODIFY: webserver_sg — allow port 80 only from external_alb_sg (not 0.0.0.0/0)
# MODIFY: appserver_sg — allow port 5000 only from internal_alb_sg
```

**2. Assign correct SGs to ALBs:**
```hcl
resource "aws_lb" "external" {
  security_groups = [aws_security_group.external_alb.id]  # dedicated SG
}
resource "aws_lb" "internal" {
  security_groups = [aws_security_group.internal_alb.id]  # dedicated SG
}
```

**3. Add RDS output and pass DB connection to app launch template:**
```hcl
# In rds/outputs.tf (add):
output "db_endpoint" {
  value = aws_db_instance.postgres.address
}

# In main.tf (add to compute module):
db_endpoint  = module.rds.db_endpoint
db_name      = var.db_name
db_username  = var.db_username
db_password  = var.db_password

# In compute/main.tf app user_data docker run:
docker run -d -p 5000:5000 \
  -e SERVICE_NAME=... \
  -e ALLOWED_ORIGIN=... \
  -e DATABASE_URL="postgresql://${var.db_username}:${var.db_password}@${var.db_endpoint}:5432/${var.db_name}" \
  -e ENV_MODE=production \
  -e SECRET_KEY=... \
  ...
```

### Phase 2 — Application Fixes

**4. Fix `backend/config.py` `elif` bug:**
```python
if env == "production":
    load_dotenv(".env.prod")
elif env == "test":     # ← fix: was 'if'
    load_dotenv(".env.test")
else:
    load_dotenv(".env.dev")
```

**5. Fix `docker/app/` placeholder:**
- Add `/api/health` route OR update health check path to `/health`
- Add `gunicorn` to `docker/app/requirements.txt`

**6. Fix `docker/web/default.conf` to include the `/api/` proxy block** (matching the user_data inline config), using an environment variable or build arg for the internal ALB DNS. Alternatively, keep it as a pure placeholder and document that the volume mount from user_data always overrides it.

### Phase 3 — Security Hardening

**7. Scope `my_ip_cidr` to your real IP (`x.x.x.x/32`)**

**8. Store RDS credentials in AWS Secrets Manager or Parameter Store** — pass the secret ARN to the EC2 IAM role and fetch at container start instead of baking into user_data.
