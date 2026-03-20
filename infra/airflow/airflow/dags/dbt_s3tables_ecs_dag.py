from airflow import DAG
from airflow.providers.amazon.aws.operators.ecs import EcsRunTaskOperator
from airflow.hooks.base import BaseHook
from datetime import timedelta, datetime
from airflow.models import Variable

# Get AWS connection
aws_conn = BaseHook.get_connection("aws_default")
AWS_ACCESS_KEY = aws_conn.login  # username
AWS_SECRET_KEY = aws_conn.password  # password

SUBNET_IDS = Variable.get("ecs_subnet_ids", default_var="").split(",")
SECURITY_GROUP = Variable.get("ecs_security_group_id_dbt", default_var="")
AWS_DEFAULT_REGION = Variable.get("aws_region", default_var="us-east-2")

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    "dbt_s3tables_ecs_dag",
    default_args=default_args,
    description="Run DBT project on ECS Fargate",
    schedule_interval="0 2 * * *",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["dbt", "ecs", "lakehouse"],
) as dag:

    dbt_run = EcsRunTaskOperator(
        task_id="dbt_run",
        cluster="data-handson-ecs-cluster-dev",
        task_definition="dbt-lakehouse-duckdb-dev",
        launch_type="FARGATE",
        overrides={
            "containerOverrides": [
                {
                    "name": "dbt-lakehouse-duckdb",
                    "command": [
                        "/usr/local/bin/dbt",
                        "run",
                        "--profiles-dir",
                        "/root/.dbt",
                    ],
                    "cpu": 2048,
                    "memory": 8192,
                    "environment": [
                        {"name": "AWS_ACCESS_KEY_ID", "value": AWS_ACCESS_KEY},
                        {"name": "AWS_SECRET_ACCESS_KEY", "value": AWS_SECRET_KEY},
                        {"name": "AWS_DEFAULT_REGION", "value": AWS_DEFAULT_REGION},
                    ],
                },
            ],
        },
        network_configuration={
            "awsvpcConfiguration": {
                "subnets": SUBNET_IDS,
                "securityGroups": [SECURITY_GROUP],
                "assignPublicIp": "ENABLED",
            },
        },
        awslogs_group="/ecs/dbt-lakehouse-duckdb-dev",
        awslogs_stream_prefix="ecs/dbt-lakehouse-duckdb",
    )

    dbt_run
