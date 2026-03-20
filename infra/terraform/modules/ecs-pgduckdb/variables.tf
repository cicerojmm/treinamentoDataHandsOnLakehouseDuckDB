variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "ecr_image_uri" {
  description = "URI da imagem Docker no ECR"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "cluster_id" {
  description = "ID do cluster ECS"
  type        = string
}

variable "cluster_name" {
  description = "Nome do cluster ECS"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs das subnets públicas para o ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas para as tasks"
  type        = list(string)
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
}

variable "cpu" {
  description = "CPU para a task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "512"
}

variable "memory" {
  description = "Memória para a task em MB"
  type        = string
  default     = "1024"
}

variable "desired_count" {
  description = "Número desejado de tasks"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Capacidade mínima para auto scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Capacidade máxima para auto scaling"
  type        = number
  default     = 3
}

variable "postgres_user" {
  description = "Usuário PostgreSQL"
  type        = string
  default     = "duckdb"
}

variable "postgres_db" {
  description = "Nome do banco de dados PostgreSQL"
  type        = string
  default     = "warehouse"
}

variable "postgres_password" {
  description = "Senha do PostgreSQL"
  type        = string
  sensitive   = true
}

variable "s3tables_arn" {
  description = "ARN dos S3 Tables"
  type        = string
  default     = ""
}
