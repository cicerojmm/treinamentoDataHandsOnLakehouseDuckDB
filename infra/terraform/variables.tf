variable "environment" {
  description = "Ambiente de implantação (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-2"
}

variable "s3_bucket_raw" {
  description = "Nome do bucket S3 para armazenar dados brutos"
  type        = string
}

variable "s3_bucket_scripts" {
  description = "Nome do bucket S3 para armazenar scripts"
  type        = string
}

variable "s3_bucket_curated" {
  description = "Nome do bucket S3 para armazenar dados processados"
  type        = string
  default     = ""
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for data quality alerts"
  type        = string
  default     = "https://discord.com/api/webhooks/1354503644946628769/bjvMnt1ZpcsMTt67nAe_vFwK6A1yVq6p0sUNRxNJNK1TJz8Gd4WgSxCAQHRToCf1itIj"
  sensitive   = true
}

variable "data_quality_alerts_sns_topic_arn" {
  description = "ARN of the SNS topic for data quality alerts"
  type        = string
  default     = ""
}

variable "rds_password" {
  description = "Password for RDS PostgreSQL instance"
  type        = string
  default     = "Mds20251"
  sensitive   = true
}

variable "dlt_ecr_image_uri" {
  description = "URI da imagem Docker do DLT no ECR"
  type        = string
  default     = ""
}

variable "dbt_ecr_image_uri" {
  description = "URI da imagem Docker do DBT no ECR"
  type        = string
  default     = ""
}

variable "pgduckdb_password" {
  description = "Password for pgDuckDB PostgreSQL instance"
  type        = string
  default     = "duckdb2024"
  sensitive   = true
}

variable "pgduckdb_user" {
  description = "Username for pgDuckDB"
  type        = string
  default     = "duckdb"
}

variable "pgduckdb_db" {
  description = "Database name for pgDuckDB"
  type        = string
  default     = "warehouse"
}

variable "pgduckdb_ecr_image_uri" {
  description = "URI da imagem Docker do pgDuckDB no ECR"
  type        = string
  default     = ""
}

variable "s3tables_arn" {
  description = "ARN dos S3 Tables para o pgDuckDB"
  type        = string
  default     = ""
}

variable "metabase_use_efs" {
  description = "Whether to enable EFS for Metabase /duckdb persistence"
  type        = bool
  default     = false
}

variable "metabase_ecr_image_uri" {
  description = "Optional ECR image URI for Metabase container. If empty, a default pattern will be used."
  type        = string
  default     = ""
}
