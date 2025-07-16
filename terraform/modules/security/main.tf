# modules/security/main.tf

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-alb-sg"
    Environment = var.environment
    Project     = var.project
  }
}

# Additional ingress rules for internal service ports (conditional)
resource "aws_security_group_rule" "alb_internal_ports" {
  for_each = var.expose_internal_services ? toset(["8003", "8065", "8080", "8085", "8095"]) : []
  
  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Internal service port ${each.value}"
}

# ECS Service Security Group
resource "aws_security_group" "ecs_service" {
  name        = "${var.project}-ecs-service-sg"
  description = "Security group for ECS services"
  vpc_id      = var.vpc_id

  # Allow traffic from ALB
  ingress {
    description     = "Traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow inter-service communication
  ingress {
    description = "Inter-service communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # Allow specific ports from VPC CIDR for internal communication
  dynamic "ingress" {
    for_each = var.service_ports
    content {
      description = "Port ${ingress.value} from VPC"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-ecs-service-sg"
    Environment = var.environment
    Project     = var.project
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  # Allow PostgreSQL from ECS services
  ingress {
    description     = "PostgreSQL from ECS services"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service.id]
  }

  # Allow PostgreSQL from VPC (for public access as required)
  ingress {
    description = "PostgreSQL from anywhere (public access)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # As per requirement for public access
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-rds-sg"
    Environment = var.environment
    Project     = var.project
  }
}
