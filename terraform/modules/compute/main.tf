data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_region" "current" {}

# ── Bastion host ──────────────────────────────────────────────────────────────
resource "aws_instance" "bastion" {
  count                       = var.create_bastion ? 1 : 0
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.web_instance_type
  subnet_id                   = var.public_subnet_ids[0]
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [var.bastion_sg_id]
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-bastion"
    Tier = "management"
  }
}

# ── IAM role — EC2 instances pull images from ECR ────────────────────────────
resource "aws_iam_role" "ec2_instance_role" {
  name = "${var.project_name}-ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.project_name}-ec2-instance-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.project_name}-ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name

  tags = {
    Name = "${var.project_name}-ec2-instance-profile"
  }
}

# ── Web-tier launch template ──────────────────────────────────────────────────
# Nginx acts as a reverse proxy:
#   /       → serves the static frontend from the ECR image
#   /api/   → proxies to the internal ALB (app tier) on port 5000
#   /health → local health stub for the external ALB health check
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.web_instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [var.webserver_sg_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
yum update -y
yum install -y docker
systemctl enable docker
systemctl start docker

# Write the Nginx config with the real internal ALB DNS baked in at apply time.
# This config is volume-mounted over the image's default, so it always wins
# regardless of which image tag is pulled from ECR.
cat > /tmp/default.conf <<'NGINX'
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Serve static frontend files
    location / {
        try_files $$uri $$uri/ /index.html;
    }

    # Proxy /api/ requests to the internal ALB → app tier
    location /api/ {
        proxy_pass http://${aws_lb.internal.dns_name}:5000/api/;
        proxy_set_header Host $$host;
        proxy_set_header X-Real-IP $$remote_addr;
        proxy_set_header X-Forwarded-For $$proxy_add_x_forwarded_for;
        proxy_connect_timeout 10s;
        proxy_read_timeout 60s;
    }

    # Health endpoint for the external ALB health check
    location /health {
        default_type application/json;
        return 200 '{"status":"ok","tier":"web"}';
    }
}
NGINX

# Authenticate against ECR and pull the web image.
# Falls back to plain nginx:alpine if the pull fails (e.g. image not yet pushed).
IMAGE=nginx:alpine
if aws ecr get-login-password --region ${data.aws_region.current.name} | \
     docker login --username AWS --password-stdin ${var.web_ecr_repo_url} 2>/dev/null; then
  docker pull ${var.web_ecr_repo_url}:${var.web_image_tag} 2>/dev/null && \
    IMAGE=${var.web_ecr_repo_url}:${var.web_image_tag}
fi

docker run -d --restart unless-stopped -p 80:80 \
  -v /tmp/default.conf:/etc/nginx/conf.d/default.conf:ro \
  --name ${var.project_name}-web \
  "$IMAGE"
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-web-instance"
      Tier = "web"
    }
  }

  tags = {
    Name = "${var.project_name}-web-lt"
  }
}

# ── App-tier launch template ──────────────────────────────────────────────────
# Flask backend container. DB connection details are injected at runtime so
# no credentials are stored in the image or in source control.
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-app-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.app_instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [var.appserver_sg_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
yum update -y
yum install -y docker
systemctl enable docker
systemctl start docker

if aws ecr get-login-password --region ${data.aws_region.current.name} | \
     docker login --username AWS --password-stdin ${var.app_ecr_repo_url} 2>/dev/null && \
   docker pull ${var.app_ecr_repo_url}:${var.app_image_tag} 2>/dev/null; then
  docker run -d --restart unless-stopped -p 5000:5000 \
    -e SERVICE_NAME=${var.project_name}-app \
    -e ENV_MODE=production \
    -e DATABASE_URL="postgresql://${var.db_username}:${var.db_password}@${var.db_address}:5432/${var.db_name}" \
    -e DB_HOST="${var.db_address}" \
    -e SECRET_KEY="$(openssl rand -hex 32)" \
    -e ALLOWED_ORIGIN="http://${aws_lb.external.dns_name}" \
    --name ${var.project_name}-app \
    ${var.app_ecr_repo_url}:${var.app_image_tag}
else
  echo "ECR pull failed — no app container started. Push the image and trigger an ASG refresh."
fi
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-app-instance"
      Tier = "app"
    }
  }

  tags = {
    Name = "${var.project_name}-app-lt"
  }
}

# ── Target groups ─────────────────────────────────────────────────────────────
resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Name = "${var.project_name}-web-tg"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-app-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/api/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Name = "${var.project_name}-app-tg"
  }
}

# ── Application Load Balancers ────────────────────────────────────────────────
# External ALB — internet-facing, serves the web tier.
# Uses its own dedicated security group (not shared with EC2 instances).
resource "aws_lb" "external" {
  name               = "${var.project_name}-ext-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.external_alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.project_name}-ext-alb"
  }
}

resource "aws_lb_listener" "external_http" {
  load_balancer_arn = aws_lb.external.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Internal ALB — private, only reachable from web-tier Nginx.
# Uses its own dedicated security group (not shared with app EC2 instances).
resource "aws_lb" "internal" {
  name               = "${var.project_name}-int-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.internal_alb_sg_id]
  subnets            = var.app_subnet_ids

  tags = {
    Name = "${var.project_name}-int-alb"
  }
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 5000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ── Auto Scaling Groups ───────────────────────────────────────────────────────
resource "aws_autoscaling_group" "web" {
  name                = "${var.project_name}-web-asg"
  vpc_zone_identifier = var.public_subnet_ids
  desired_capacity    = var.asg_desired_capacity
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web-asg-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-app-asg"
  vpc_zone_identifier = var.app_subnet_ids
  desired_capacity    = var.asg_desired_capacity
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-asg-instance"
    propagate_at_launch = true
  }
}
