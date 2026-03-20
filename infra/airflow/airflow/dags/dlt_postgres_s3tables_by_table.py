from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.amazon.aws.operators.ecs import EcsRunTaskOperator
from airflow.models import Variable
from airflow.hooks.base import BaseHook

default_args = {
    "owner": "data-engineering",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

# Configurações do ECS
ECS_CLUSTER = "data-handson-ecs-cluster-dev"
TASK_DEFINITION = "dlt-postgres-s3tables-dev"
SUBNET_IDS = Variable.get("ecs_subnet_ids", default_var="").split(",")
SECURITY_GROUP = Variable.get("ecs_security_group_id", default_var="")

# Credenciais AWS da connection
aws_conn = BaseHook.get_connection("aws_default")
AWS_ACCESS_KEY_ID = aws_conn.login
AWS_SECRET_ACCESS_KEY = aws_conn.password
AWS_REGION = aws_conn.extra_dejson.get("region_name", "us-east-2")

# Credenciais PostgreSQL da connection
postgres_conn = BaseHook.get_connection("postgres_default")
POSTGRES_HOST = postgres_conn.host
POSTGRES_PORT = postgres_conn.port or 5432
POSTGRES_DATABASE = postgres_conn.schema or "movielens_database"
POSTGRES_USER = postgres_conn.login or "postgres"
POSTGRES_PASSWORD = postgres_conn.password or ""

# Lista de tabelas
TABLES = ["movies", "ratings", "tags", "links"]

with DAG(
    "dlt_postgres_s3tables_by_table",
    default_args=default_args,
    description="Extrai tabelas do Postgres para S3 Tables (uma por vez)",
    schedule_interval="0 2 * * *",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["dlt", "s3tables", "postgres"],
) as dag:

    previous_task = None

    for table in TABLES:
        task = EcsRunTaskOperator(
            task_id=f"extract_{table}",
            cluster=ECS_CLUSTER,
            task_definition=TASK_DEFINITION,
            launch_type="FARGATE",
            overrides={
                "cpu": "2048",
                "memory": "8192",
                "containerOverrides": [
                    {
                        "name": "dlt-postgres-s3tables",
                        "cpu": 2048,
                        "memory": 8192,
                        "command": ["--tables", table, "--full-refresh"],
                        "environment": [
                            # PostgreSQL via padrão dlt
                            {
                                "name": "SOURCES__SQL_DATABASE__CREDENTIALS__HOST",
                                "value": POSTGRES_HOST,
                            },
                            {
                                "name": "SOURCES__SQL_DATABASE__CREDENTIALS__PORT",
                                "value": str(POSTGRES_PORT),
                            },
                            {
                                "name": "SOURCES__SQL_DATABASE__CREDENTIALS__DATABASE",
                                "value": POSTGRES_DATABASE,
                            },
                            {
                                "name": "SOURCES__SQL_DATABASE__CREDENTIALS__USERNAME",
                                "value": POSTGRES_USER,
                            },
                            {
                                "name": "SOURCES__SQL_DATABASE__CREDENTIALS__PASSWORD",
                                "value": POSTGRES_PASSWORD,
                            },
                            # AWS via padrão dlt
                            {
                                "name": "DESTINATION__FILESYSTEM__CREDENTIALS__AWS_ACCESS_KEY_ID",
                                "value": AWS_ACCESS_KEY_ID,
                            },
                            {
                                "name": "DESTINATION__FILESYSTEM__CREDENTIALS__AWS_SECRET_ACCESS_KEY",
                                "value": AWS_SECRET_ACCESS_KEY,
                            },
                            {
                                "name": "DESTINATION__FILESYSTEM__CREDENTIALS__REGION_NAME",
                                "value": AWS_REGION,
                            },
                            # Iceberg catalog S3 config
                            {
                                "name": "ICEBERG_CATALOG__ICEBERG_CATALOG_CONFIG__S3__ACCESS_KEY_ID",
                                "value": AWS_ACCESS_KEY_ID,
                            },
                            {
                                "name": "ICEBERG_CATALOG__ICEBERG_CATALOG_CONFIG__S3__SECRET_ACCESS_KEY",
                                "value": AWS_SECRET_ACCESS_KEY,
                            },
                            {
                                "name": "ICEBERG_CATALOG__ICEBERG_CATALOG_CONFIG__S3__REGION",
                                "value": AWS_REGION,
                            },
                        ],
                    }
                ],
            },
            network_configuration={
                "awsvpcConfiguration": {
                    "subnets": SUBNET_IDS,
                    "securityGroups": [SECURITY_GROUP],
                    "assignPublicIp": "ENABLED",
                }
            },
            awslogs_group="/ecs/dlt-postgres-s3tables-dev",
            awslogs_stream_prefix="ecs/dlt-postgres-s3tables",
            region_name="us-east-2",
        )

        if previous_task:
            previous_task >> task

        previous_task = task
