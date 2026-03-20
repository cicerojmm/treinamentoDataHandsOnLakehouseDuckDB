from __future__ import annotations

import os
import logging
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.empty import EmptyOperator
from airflow.utils.trigger_rule import TriggerRule
from airflow.providers.docker.operators.docker import DockerOperator
from airflow.hooks.base import BaseHook

# ── Configurações ────────────────────────────────────────────
S3TABLES_ARN = os.environ.get("S3TABLES_ARN", "")
AWS_REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-2")
DBT_IMAGE = "datahandson/dbt-duckdb:latest"
DBT_DIR = "/dbt"

# Get AWS connection from Airflow
aws_conn = BaseHook.get_connection("aws_default")
AWS_ACCESS_KEY = aws_conn.login
AWS_SECRET_KEY = aws_conn.password

ENV_VARS = {
    "AWS_DEFAULT_REGION": AWS_REGION,
    "S3TABLES_ARN": S3TABLES_ARN,
    "AWS_ACCESS_KEY_ID": AWS_ACCESS_KEY,
    "AWS_SECRET_ACCESS_KEY": AWS_SECRET_KEY,
}

DOCKER_DEFAULTS = dict(
    image=DBT_IMAGE,
    docker_url="unix:///var/run/docker.sock",
    environment=ENV_VARS,
    network_mode="host",
    auto_remove=True,
    mount_tmp_dir=False,
    entrypoint=["dbt"],
)


def _on_failure(context):
    logging.error(
        "Task falhou: dag=%s task=%s execution_date=%s",
        context["dag"].dag_id,
        context["task"].task_id,
        context["execution_date"],
    )


def check_s3tables_connection():
    """Valida que o S3 Tables está acessível antes de rodar o dbt."""
    import boto3

    client = boto3.client("s3tables", region_name=AWS_REGION)
    arn = S3TABLES_ARN
    bucket = arn.split("/")[-1]
    account = arn.split(":")[4]

    try:
        client.get_table_bucket(tableBucketARN=arn)
        logging.info("S3 Tables acessível: %s", arn)
    except Exception as e:
        raise RuntimeError(f"S3 Tables inacessível: {e}")


# ── DAG ──────────────────────────────────────────────────────
with DAG(
    dag_id="dbt_s3tables_local",
    schedule_interval="0 6 * * *",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    default_args={
        "owner": "datahandson",
        "retries": 2,
        "retry_delay": timedelta(minutes=5),
        "on_failure_callback": _on_failure,
    },
    tags=["dbt", "duckdb", "s3tables", "layered"],
) as dag:

    dbt_silver = DockerOperator(
        task_id="dbt_run_staging",
        command="run --select silver --target dev --full-refresh",
        **DOCKER_DEFAULTS,
    )

    dbt_gold = DockerOperator(
        task_id="dbt_run_marts",
        command="run --select gold --target dev --full-refresh",
        **DOCKER_DEFAULTS,
    )

    done = EmptyOperator(
        task_id="pipeline_completo",
        trigger_rule=TriggerRule.ALL_SUCCESS,
    )

    (dbt_silver >> dbt_gold >> done)
