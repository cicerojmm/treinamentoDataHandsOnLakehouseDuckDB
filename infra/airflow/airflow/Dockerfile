FROM apache/airflow:2.9.3-python3.12

USER root

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Adiciona o usuário airflow ao grupo docker do host
# O GID deve bater com o grupo docker da EC2:
#   getent group docker | cut -d: -f3
# Passe via build arg se diferente de 998:
#   docker build --build-arg DOCKER_GID=$(getent group docker | cut -d: -f3) .
ARG DOCKER_GID=998
RUN groupadd --gid ${DOCKER_GID} docker_host 2>/dev/null || groupmod -g ${DOCKER_GID} docker \
    && usermod -aG docker_host airflow 2>/dev/null || usermod -aG docker airflow

USER airflow

RUN pip install --no-cache-dir \
    "astronomer-cosmos==1.13.1" \
    "apache-airflow-providers-amazon[s3fs]>=8.0.0" \
    "apache-airflow-providers-docker>=3.8.0" \
    "s3fs>=2024.0.0" \
    "aiobotocore>=2.12.0" \
    "boto3>=1.34"