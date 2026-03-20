#terraform init -backend-config="backends/dev.hcl"
#terraform apply -var-file=envs/dev.tfvars -auto-approve

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}


###############################################################################
#########             VPC E SUBNETS                               #############
###############################################################################
module "vpc_public" {
  source               = "./modules/vpc"
  project_name         = "data-handson-mds"
  vpc_name             = "data-handson-mds-vpc-${var.environment}"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones   = ["us-east-2a", "us-east-2b"]
}


###############################################################################
#########             RDS POSTGRESQL                              #############
###############################################################################
module "rds_postgres" {
  source = "./modules/rds"

  environment       = var.environment
  vpc_id            = module.vpc_public.vpc_id
  public_subnet_ids = module.vpc_public.public_subnet_ids

  # Use 'metabase' DB/user to match local docker-compose setup
  db_name     = "metabase"
  db_username = "metabase"
  db_password = var.rds_password

  instance_class    = "db.t3.large"
  allocated_storage = 50
}


##############################################################################
########             INSTANCIAS EC2                              #############
##############################################################################
# data "aws_ami" "ubuntu" {
#   most_recent = true
#   owners      = ["099720109477"] # Canonical

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

# module "ec2_instance" {
#   source              = "./modules/ec2"
#   ami_id              = data.aws_ami.ubuntu.id
#   instance_type       = "t3a.2xlarge"
#   subnet_id           = module.vpc_public.public_subnet_ids[0]
#   vpc_id              = module.vpc_public.vpc_id
#   key_name            = "cjmm-mds-dq"
#   associate_public_ip = true
#   instance_name       = "data-handson-mds-ec2-${var.environment}"

#   user_data = templatefile("${path.module}/scripts/bootstrap/ec2_bootstrap.sh", {
#     AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
#   })

#   ingress_rules = [
#     {
#       from_port   = 22
#       to_port     = 22
#       protocol    = "tcp"
#       cidr_blocks = ["0.0.0.0/0"]
#     },
#     {
#       from_port   = 80
#       to_port     = 80
#       protocol    = "tcp"
#       cidr_blocks = ["0.0.0.0/0"]
#     },
#     {
#       from_port   = 443
#       to_port     = 443
#       protocol    = "tcp"
#       cidr_blocks = ["0.0.0.0/0"]
#     },
#     {
#       from_port   = 3000
#       to_port     = 3000
#       protocol    = "tcp"
#       cidr_blocks = ["0.0.0.0/0"]
#     },
#     {
#       from_port   = 8080
#       to_port     = 8080
#       protocol    = "tcp"
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#   ]
# }


###############################################################################
#########            LAMBDA FUNCTION WITH DOCKER - Bedrock        #############
###############################################################################
module "lambda_function_duckdb" {
  source = "./modules/lambda_ecr"

  function_name = "datahandson-lakehouse-duckdb-s3tables-duckdb"
  description   = "Python Lambda function for querying S3 tables with DuckDB"

  # Docker image URI (replace with your actual ECR URI after running build_and_push.sh)
  image_uri = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/lambda-lakehouseduckdb-duckdb:latest"

  # Optional parameters
  timeout                = 900
  memory_size            = 2048
  ephemeral_storage_size = 2048

  # Function URL configuration
  create_function_url    = true
  function_url_auth_type = "AWS_IAM" # Use AWS IAM for authentication

  environment_variables = {
    ENV_VAR_1 = "value1"
  }
}


###############################################################################
#########            LAMBDA FUNCTION WITH DOCKER - API            #############
###############################################################################
module "lambda_function_duckdb_api" {
  source = "./modules/lambda_ecr"

  function_name = "datahandson-lakehouse-duckdb-s3tables-duckdb-api"
  description   = "Python Lambda function for querying S3 tables with DuckDB"

  # Docker image URI (replace with your actual ECR URI after running build_and_push.sh)
  image_uri = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/lambda-lakehouseduckdb-duckdb-api:latest"

  # Optional parameters
  timeout                = 900
  memory_size            = 2048
  ephemeral_storage_size = 2048

  # Function URL configuration
  create_function_url    = true
  function_url_auth_type = "AWS_IAM" # Use AWS IAM for authentication

  environment_variables = {
    ENV_VAR_1 = "value1"
  }
}


###############################################################################
#########            ECS DLT POSTGRES TO S3 TABLES                #############
###############################################################################
# ECS Cluster compartilhado
module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  cluster_name              = "data-handson-ecs-cluster-${var.environment}"
  environment               = var.environment
  enable_container_insights = true
}


###############################################################################
#########            ECS pgDuckDB SERVICE                          #############
###############################################################################
# module "ecs_pgduckdb" {
#   source = "./modules/ecs-pgduckdb"

#   environment                   = var.environment
#   vpc_id                        = module.vpc_public.vpc_id
#   cluster_id                    = module.ecs_cluster.cluster_id
#   cluster_name                  = module.ecs_cluster.cluster_name
#   public_subnet_ids             = module.vpc_public.public_subnet_ids
#   private_subnet_ids            = module.vpc_public.private_subnet_ids
#   aws_region                    = var.region

#   ecr_image_uri                 = var.pgduckdb_ecr_image_uri != "" ? var.pgduckdb_ecr_image_uri : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/pgduckdb:latest"
#   postgres_password             = var.pgduckdb_password

#   cpu                           = "512"
#   memory                        = "1024"
#   desired_count                 = 1
#   min_capacity                  = 1
#   max_capacity                  = 3

#   postgres_user                 = var.pgduckdb_user
#   postgres_db                   = var.pgduckdb_db
#   s3tables_arn                  = var.s3tables_arn

#   depends_on = [
#     module.ecs_cluster
#   ]
# }

###############################################################################
#########            dlthub LAKEHOUSE DUCKDB                      #############
###############################################################################
module "ecs_task_dlt" {
  source = "./modules/ecs-task-dlt"

  project_name = "dlt-postgres-s3tables"
  environment  = var.environment

  ecr_image_uri = var.dlt_ecr_image_uri != "" ? var.dlt_ecr_image_uri : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/dlt-postgres-s3tables:latest"

  vpc_id = module.vpc_public.vpc_id

  cpu        = "512"
  memory     = "1024"
  aws_region = var.region
}


###############################################################################
#########            ECS DBT LAKEHOUSE DUCKDB                     #############
###############################################################################
module "ecs_task_dbt" {
  source = "./modules/ecs-task-dbt"

  project_name = "dbt-lakehouse-duckdb"
  environment  = var.environment

  ecr_image_uri = var.dbt_ecr_image_uri != "" ? var.dbt_ecr_image_uri : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/dbt-lakehouse-duckdb:latest"

  vpc_id = module.vpc_public.vpc_id

  cpu        = "8192"
  memory     = "16384"
  aws_region = var.region
}

module "ecs_task_dbt_s3_iceberg" {
  source = "./modules/ecs-task-dbt"

  project_name = "dbt-lakehouse-duckdb-s3-iceberg"
  environment  = var.environment

  ecr_image_uri = var.dbt_ecr_image_uri != "" ? var.dbt_ecr_image_uri : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/dbt-lakehouse-duckdb-s3-iceberg:latest"

  vpc_id = module.vpc_public.vpc_id

  cpu        = "8192"
  memory     = "16384"
  aws_region = var.region
}

###############################################################################
#########            ECS METABASE DUCKDB                          #############
###############################################################################
module "ecs_metabase_duckdb" {
  source = "./modules/ecs-metabase-duckdb"

  project_name       = "metabase-duckdb"
  environment        = var.environment

  cluster_id         = module.ecs_cluster.cluster_id
  cluster_name       = module.ecs_cluster.cluster_name

  vpc_id             = module.vpc_public.vpc_id
  public_subnet_ids  = module.vpc_public.public_subnet_ids
  private_subnet_ids = module.vpc_public.private_subnet_ids

  ecr_image_uri = var.metabase_ecr_image_uri != "" ? var.metabase_ecr_image_uri : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/metabase:latest"

  aws_region = var.region

  desired_count = 1
  cpu           = "2048"
  memory        = "8192"
  container_port = 3000
  use_efs       = var.metabase_use_efs
  
  # Database connection (point to RDS created above)
  # Ensure we pass only the hostname (strip any trailing :port if present)
  db_host     = "datahandson-lakehouse-duckdb-dev-postgres.cnai0csqspw4.us-east-2.rds.amazonaws.com"
  db_port     = module.rds_postgres.db_instance_port
  db_name     = "metabase"
  db_user     = "metabase"
  db_password = var.rds_password

  tags = {
    project = "metabase-duckdb"
  }
}
