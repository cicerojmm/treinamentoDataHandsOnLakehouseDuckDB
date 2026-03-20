from airflow.decorators import dag
from airflow.models import Variable
from datetime import datetime, timedelta
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig, RenderConfig
from cosmos.constants import ExecutionMode, LoadMode
from cosmos.profiles import BaseProfileMapping
from airflow.hooks.base import BaseHook


# Get AWS connection
aws_conn = BaseHook.get_connection("aws_default")
AWS_ACCESS_KEY = aws_conn.login  # username
AWS_SECRET_KEY = aws_conn.password  # password

SUBNET_IDS     = Variable.get('ecs_subnet_ids', default_var='').split(',')
SECURITY_GROUP = Variable.get('ecs_security_group_id_dbt', default_var='')
AWS_DEFAULT_REGION = "us-east-2"


profile_config = ProfileConfig(
    profile_name="datahandson",
    target_name="dev",
    profiles_yml_filepath="/root/.dbt/profiles.yml"
)

ECS_OPERATOR_ARGS = {
    "task_definition": "dbt-lakehouse-duckdb-dev",
    "container_name":  "dbt-lakehouse-duckdb",
    "cluster":         "data-handson-ecs-cluster-dev",
    "launch_type":     "FARGATE",
    "overrides": {
        "containerOverrides": [
            {
                "name": "dbt-lakehouse-duckdb",
                "cpu": 2048,
                "memory": 8192,
            }
        ]
    },
    "network_configuration": {
        "awsvpcConfiguration": {
            "subnets":        SUBNET_IDS,
            "securityGroups": [SECURITY_GROUP],
            "assignPublicIp": "ENABLED",
        }
    },
    "awslogs_group":         "/ecs/dbt-lakehouse-duckdb-dev",
    "awslogs_stream_prefix": "ecs/dbt-lakehouse-duckdb",
    "awslogs_region":        "us-east-2",
}


@dag(
    dag_id="dbt_s3tables_cosmos_ecs_dag",
    schedule_interval=None,
    start_date=datetime(2024, 1, 1),
    catchup=False
)
def dbt_s3tables_cosmos_ecs_dag():
    dbt_group = DbtTaskGroup(
        group_id="dbt_transformations",
        project_config=ProjectConfig(
            project_name="datahandson",
            manifest_path="s3://cjmm-datalake-mds-configs/datahandson-lakehouse-duckdb-dbt/manifest.json",
            env_vars={
                "AWS_ACCESS_KEY_ID": AWS_ACCESS_KEY,
                "AWS_SECRET_ACCESS_KEY": AWS_SECRET_KEY,
                "AWS_DEFAULT_REGION": AWS_DEFAULT_REGION,
            }
        ),
        profile_config=profile_config,
        execution_config=ExecutionConfig(
            execution_mode=ExecutionMode.AWS_ECS,
            dbt_executable_path="/usr/local/bin/dbt",
            dbt_project_path="/dbt",
        ),
        render_config=RenderConfig(
            load_method=LoadMode.DBT_MANIFEST,
        ),
        operator_args=ECS_OPERATOR_ARGS,
    )

    dbt_group


dbt_s3tables_cosmos_ecs_dag()