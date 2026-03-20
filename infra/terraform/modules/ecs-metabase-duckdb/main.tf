locals {
  name_prefix = "${var.project_name}-${var.environment}-metabase"
}

# Security group for metabase
resource "aws_security_group" "metabase_sg" {
  name        = "${local.name_prefix}-sg"
  description = "Allow HTTP access to Metabase"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP from the internet to the ALB (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({ Name = local.name_prefix }, var.tags)
}

# Allow NFS (EFS) mount from tasks (allow SG-to-SG on port 2049)
resource "aws_security_group_rule" "allow_nfs_from_sg" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.metabase_sg.id
  source_security_group_id = aws_security_group.metabase_sg.id
  description              = "Allow NFS (EFS) mount from tasks in same SG"
  count                    = var.use_efs ? 1 : 0
}

# EFS filesystem for persistent .duckdb file
# EFS filesystem for persistent .duckdb file (created only when use_efs = true)
resource "aws_efs_file_system" "metabase_fs" {
  count          = var.use_efs ? 1 : 0
  creation_token = local.name_prefix
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = merge({ Name = local.name_prefix }, var.tags)
}

# Mount targets for each subnet where tasks run; ensure they exist in the same subnets as tasks
# If tasks run in public subnets, create mount targets in `public_subnet_ids` so Fargate ENIs can reach them
resource "aws_efs_mount_target" "mount_targets" {
  for_each = var.use_efs ? toset(var.public_subnet_ids) : toset([])
  file_system_id  = aws_efs_file_system.metabase_fs[0].id
  subnet_id       = each.value
  security_groups = [aws_security_group.metabase_sg.id]
}
  # Resolve subnet AZs and select one subnet per AZ to create mount targets (one mount target per AZ)
  data "aws_subnet" "public_subs" {
    for_each = toset(var.public_subnet_ids)
    id       = each.value
  }

  locals {
    # map availability_zone -> subnet_id (select one subnet per AZ)
    mount_subnet_by_az = { for k, s in data.aws_subnet.public_subs : s.availability_zone => s.id }
  }

# (Mount targets are created per AZ below; one mount target per AZ is used)

# EFS access point to ensure correct ownership/permissions for /duckdb
resource "aws_efs_access_point" "metabase_ap" {
  count          = var.use_efs ? 1 : 0
  file_system_id = aws_efs_file_system.metabase_fs[0].id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/metabase"
    creation_info {
      owner_uid = 1000
      owner_gid = 1000
      permissions = "0755"
    }
  }
}

# ALB
resource "aws_lb" "metabase_alb" {
  name               = local.name_prefix
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.metabase_sg.id]
  tags = merge({ Name = local.name_prefix }, var.tags)
}

resource "aws_lb_target_group" "metabase_tg" {
  name     = local.name_prefix
  port     = var.container_port
  protocol = "HTTP"
  target_type = "ip"
  vpc_id   = var.vpc_id
  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
  tags = merge({ Name = local.name_prefix }, var.tags)
}

resource "aws_lb_listener" "metabase_listener" {
  load_balancer_arn = aws_lb.metabase_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.metabase_tg.arn
  }
}

# CloudWatch Log Group for ECS tasks
resource "aws_cloudwatch_log_group" "metabase" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 14
  tags              = merge({ Name = local.name_prefix }, var.tags)
}

# IAM roles for ECS task
resource "aws_iam_role" "task_execution_role" {
  name = "${local.name_prefix}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_iam_role_policy_attachment" "exec_role_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Task definition with EFS volume
resource "aws_ecs_task_definition" "metabase_task_efs" {
  count                    = var.use_efs ? 1 : 0
  family                   = local.name_prefix
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution_role.arn

  volume {
    name = "metabase-data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.metabase_fs[0].id
      transit_encryption = "ENABLED"
      root_directory = "/"
      authorization_config {
        access_point_id = aws_efs_access_point.metabase_ap[0].id
        iam             = "DISABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "metabase"
      image     = var.ecr_image_uri
      cpu       = tonumber(var.cpu)
      memory    = tonumber(var.memory)
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "metabase-data"
          containerPath = "/duckdb"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.metabase.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "metabase"
        }
      }
      environment = [
        { name = "MB_DB_FILE" , value = "/duckdb/metabase.db" },
        { name = "MB_DUCKDB_DIR", value = "/duckdb" },
        { name = "MB_DB_TYPE", value = "postgres" },
        { name = "MB_DB_HOST", value = var.db_host },
        { name = "MB_DB_PORT", value = tostring(var.db_port) },
        { name = "MB_DB_DBNAME", value = var.db_name },
        { name = "MB_DB_USER", value = var.db_user },
        { name = "MB_DB_PASS", value = var.db_password }
      ]
    }
  ])
  tags = merge({ Name = local.name_prefix }, var.tags)
}

# Task definition without EFS (use S3 or DB for persistence)
resource "aws_ecs_task_definition" "metabase_task_noefs" {
  count                    = var.use_efs ? 0 : 1
  family                   = local.name_prefix
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "metabase"
      image     = var.ecr_image_uri
      cpu       = tonumber(var.cpu)
      memory    = tonumber(var.memory)
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      mountPoints = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.metabase.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "metabase"
        }
      }
      environment = [
        # When not using EFS, prefer Metabase metadata in Postgres
        { name = "MB_DB_TYPE", value = "postgres" },
        { name = "MB_DB_HOST", value = var.db_host },
        { name = "MB_DB_PORT", value = tostring(var.db_port) },
        { name = "MB_DB_DBNAME", value = var.db_name },
        { name = "MB_DB_USER", value = var.db_user },
        { name = "MB_DB_PASS", value = var.db_password }
      ]
    }
  ])
  tags = merge({ Name = local.name_prefix }, var.tags)
}

# Use the appropriate task definition ARN depending on use_efs
resource "aws_ecs_service" "metabase_service" {
  name            = local.name_prefix
  cluster         = var.cluster_id
  task_definition = var.use_efs ? aws_ecs_task_definition.metabase_task_efs[0].arn : aws_ecs_task_definition.metabase_task_noefs[0].arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    # place tasks in public subnets as requested
    subnets         = var.public_subnet_ids
    security_groups = [aws_security_group.metabase_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.metabase_tg.arn
    container_name   = "metabase"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.metabase_listener]
  tags = merge({ Name = local.name_prefix }, var.tags)
}


