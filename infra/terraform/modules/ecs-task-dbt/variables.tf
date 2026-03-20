variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

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

variable "aws_region" {
  description = "Região AWS"
  type        = string
}
