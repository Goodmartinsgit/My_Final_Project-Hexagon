# ── Bastion ───────────────────────────────────────────────────────────────────
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Bastion host - SSH from your IP only"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    description = "All outbound allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# ── External ALB ──────────────────────────────────────────────────────────────
resource "aws_security_group" "external_alb" {
  name        = "${var.project_name}-external-alb-sg"
  description = "External ALB - HTTP/HTTPS from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Forward to web tier"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-external-alb-sg"
  }
}

# ── Web tier ──────────────────────────────────────────────────────────────────
resource "aws_security_group" "webserver" {
  name        = "${var.project_name}-webserver-sg"
  description = "Web tier - HTTP from external ALB only, SSH from bastion"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "SSH from bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "All outbound allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-webserver-sg"
  }
}

# ── Internal ALB ──────────────────────────────────────────────────────────────
resource "aws_security_group" "internal_alb" {
  name        = "${var.project_name}-internal-alb-sg"
  description = "Internal ALB - accepts /api/ traffic from web tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App traffic from web tier"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.webserver.id]
  }

  ingress {
    description = "App traffic from VPC"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Forward to app tier"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-internal-alb-sg"
  }
}

# ── App tier ──────────────────────────────────────────────────────────────────
resource "aws_security_group" "appserver" {
  name        = "${var.project_name}-appserver-sg"
  description = "App tier - reachable from internal ALB only, no direct internet inbound"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App traffic from internal ALB only"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb.id]
  }

  ingress {
    description = "App traffic from VPC"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description     = "SSH from bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "All outbound allowed for package and container pulls"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-appserver-sg"
  }
}

# appserver → database egress added separately to avoid a dependency cycle
resource "aws_security_group_rule" "appserver_to_db" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.appserver.id
  source_security_group_id = aws_security_group.database.id
  description              = "PostgreSQL to DB tier"
}

# ── Database tier ─────────────────────────────────────────────────────────────
resource "aws_security_group" "database" {
  name        = "${var.project_name}-database-sg"
  description = "DB tier - PostgreSQL from app tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from app tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.appserver.id]
  }

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "All outbound allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-database-sg"
  }
}
