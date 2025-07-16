# modules/alb/main.tf

# Application Load Balancer
resource "aws_lb" "main" {
  name               = var.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection = false
  enable_http2               = true

  tags = {
    Name        = var.name
    Environment = var.environment
    Project     = var.project
  }
}

# Target Group for Frontend (always exists)
resource "aws_lb_target_group" "frontend" {
  name        = "${var.name}-frontend-tg"
  port        = 8075
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # For Fargate

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.name}-frontend-tg"
    Environment = var.environment
    Project     = var.project
  }
}

# Conditional Target Groups for Internal Services
resource "aws_lb_target_group" "langgraph" {
  count = var.expose_internal_services ? 1 : 0

  name        = "${var.name}-langgraph-tg"
  port        = 8065
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.name}-langgraph-tg"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_lb_target_group" "intent" {
  count = var.expose_internal_services ? 1 : 0

  name        = "${var.name}-intent-tg"
  port        = 8085
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.name}-intent-tg"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_lb_target_group" "sentiment" {
  count = var.expose_internal_services ? 1 : 0

  name        = "${var.name}-sentiment-tg"
  port        = 8095
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.name}-sentiment-tg"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_lb_target_group" "non_ai" {
  count = var.expose_internal_services ? 1 : 0

  name        = "${var.name}-non-ai-tg"
  port        = 8003
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health-deep"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.name}-non-ai-tg"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_lb_target_group" "rag" {
  count = var.expose_internal_services ? 1 : 0

  name        = "${var.name}-rag-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 15
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.name}-rag-tg"
    Environment = var.environment
    Project     = var.project
  }
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action forwards to frontend
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Additional Port-Based Listeners for Internal Services
resource "aws_lb_listener" "langgraph" {
  count             = var.expose_internal_services ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "8065"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.langgraph[0].arn
  }
}

resource "aws_lb_listener" "intent" {
  count             = var.expose_internal_services ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "8085"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.intent[0].arn
  }
}

resource "aws_lb_listener" "sentiment" {
  count             = var.expose_internal_services ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "8095"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sentiment[0].arn
  }
}

resource "aws_lb_listener" "non_ai" {
  count             = var.expose_internal_services ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "8003"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.non_ai[0].arn
  }
}

resource "aws_lb_listener" "rag" {
  count             = var.expose_internal_services ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rag[0].arn
  }
}
