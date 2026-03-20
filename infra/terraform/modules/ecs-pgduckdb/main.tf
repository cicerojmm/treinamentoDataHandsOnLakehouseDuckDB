# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "pgduckdb" {
  name              = "/ecs/pgduckdb-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "pgduckdb-logs-${var.environment}"
    Environment = var.environment
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "pgduckdb_tasks" {
  name        = "pgduckdb-ecs-tasks-${var.environment}"
  description = "Security group for pgDuckDB ECS tasks"
  vpc_id      = var.vpc_id

  # Allow PostgreSQL inbound on port 5432
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.pgduckdb_alb.id]
    description = "PostgreSQL from ALB"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "pgduckdb-ecs-tasks-${var.environment}"
    Environment = var.environment
  }
}

# Security Group for ALB
resource "aws_security_group" "pgduckdb_alb" {
  name        = "pgduckdb-alb-${var.environment}"
  description = "Security group for pgDuckDB ALB (Network Load Balancer)"
  vpc_id      = var.vpc_id

  # Allow PostgreSQL inbound from internet
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "PostgreSQL from internet"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "pgduckdb-alb-${var.environment}"
    Environment = var.environment
  }
}

# Network Load Balancer for PostgreSQL
resource "aws_lb" "pgduckdb" {
  name               = "pgduckdb-nlb-${var.environment}"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.pgduckdb_alb.id]

  enable_deletion_protection = false

  tags = {
    Name        = "pgduckdb-nlb-${var.environment}"
    Environment = var.environment
  }
}

# Target Group for PostgreSQL
resource "aws_lb_target_group" "pgduckdb" {
  name        = "pgduckdb-tg-${var.environment}"
  port        = 5432
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    port                = "5432"
    protocol            = "TCP"
  }

  tags = {
    Name        = "pgduckdb-tg-${var.environment}"
    Environment = var.environment
  }
}

# ALB Listener
resource "aws_lb_listener" "pgduckdb" {
  load_balancer_arn = aws_lb.pgduckdb.arn
  port              = "5432"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pgduckdb.arn
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "pgduckdb_task_execution" {
  name = "pgduckdb-ecs-task-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "pgduckdb-ecs-task-execution-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "pgduckdb_task_execution" {
  role       = aws_iam_role.pgduckdb_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task
resource "aws_iam_role" "pgduckdb_task" {
  name = "pgduckdb-ecs-task-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "pgduckdb-ecs-task-${var.environment}"
    Environment = var.environment
  }
}

# IAM Policy for S3Tables and S3 access
resource "aws_iam_role_policy" "pgduckdb_task_s3" {
  name = "pgduckdb-s3-access-${var.environment}"
  role = aws_iam_role.pgduckdb_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3tables:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "pgduckdb" {
  family                   = "pgduckdb-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.pgduckdb_task_execution.arn
  task_role_arn            = aws_iam_role.pgduckdb_task.arn

  container_definitions = jsonencode([
    {
      name      = "pgduckdb"
      image     = var.ecr_image_uri
      essential = true
      portMappings = [
        {
          containerPort = 5432
          hostPort      = 5432
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "POSTGRES_USER"
          value = var.postgres_user
        },
        {
          name  = "POSTGRES_PASSWORD"
          value = var.postgres_password
        },
        {
          name  = "POSTGRES_DB"
          value = var.postgres_db
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        },
        {
          name  = "S3TABLES_ARN"
          value = var.s3tables_arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.pgduckdb.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "pg_isready -U ${var.postgres_user} -d ${var.postgres_db}"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "pgduckdb-${var.environment}"
    Environment = var.environment
  }
}

# ECS Service
resource "aws_ecs_service" "pgduckdb" {
  name            = "pgduckdb-service-${var.environment}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.pgduckdb.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.pgduckdb_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.pgduckdb.arn
    container_name   = "pgduckdb"
    container_port   = 5432
  }

  depends_on = [
    aws_lb_listener.pgduckdb
  ]

  tags = {
    Name        = "pgduckdb-service-${var.environment}"
    Environment = var.environment
  }
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "pgduckdb_target" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.cluster_name}/pgduckdb-service-${var.environment}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.pgduckdb]
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "pgduckdb_cpu" {
  name               = "pgduckdb-cpu-autoscaling-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.pgduckdb_target.resource_id
  scalable_dimension = aws_appautoscaling_target.pgduckdb_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.pgduckdb_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "pgduckdb_memory" {
  name               = "pgduckdb-memory-autoscaling-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.pgduckdb_target.resource_id
  scalable_dimension = aws_appautoscaling_target.pgduckdb_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.pgduckdb_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}
