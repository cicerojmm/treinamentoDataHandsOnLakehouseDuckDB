terraform {
  backend "s3" {
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = {
      "Application"    = "datahandson-lakehouse-duckdb"
      "Project"        = "datahandson-lakehouse-duckdb"
      "Environment"    = var.environment
      "Owner"          = "LakehouseDuckDB Team"
      "CostCenter"     = "LakehouseDuckDB"
      "ManagedBy"      = "Terraform"
    }
  }
}
