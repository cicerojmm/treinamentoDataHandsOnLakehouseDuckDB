variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name (dev/prod)"
}

variable "cluster_id" {
  type        = string
  description = "ECS cluster id"
}

variable "cluster_name" {
  type        = string
  description = "ECS cluster name"
}

variable "vpc_id" {
  type        = string
  description = "VPC id where resources will be created"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet ids for ALB and mount targets"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet ids used by ECS tasks (EFS mount targets still require subnets)"
}

variable "ecr_image_uri" {
  type        = string
  description = "ECR image URI for Metabase container"
}

variable "desired_count" {
  type        = number
  default     = 1
}

variable "cpu" {
  type    = string
  default = "1024"
}

variable "memory" {
  type    = string
  default = "2048"
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "use_efs" {
  description = "Whether to create and mount EFS for persistent storage. Set false to use S3/other approaches."
  type        = bool
  default     = false
}


variable "db_host" {
  type        = string
  description = "Postgres host for Metabase (optional)"
  default     = ""
}

variable "db_port" {
  type        = number
  description = "Postgres port for Metabase"
  default     = 5432
}

variable "db_name" {
  type        = string
  description = "Postgres database name for Metabase"
  default     = "metabase"
}

variable "db_user" {
  type        = string
  description = "Postgres user for Metabase"
  default     = "metabase"
}

variable "db_password" {
  type        = string
  description = "Postgres password for Metabase"
  default     = "metabase"
  sensitive   = true
}

variable "aws_region" {
  type        = string
  description = "AWS region for log group and resources"
  default     = "us-east-2"
}

