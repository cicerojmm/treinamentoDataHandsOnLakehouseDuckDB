FROM python:3.12-slim

RUN apt-get update && apt-get install -y curl git && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    #"dbt-duckdb==1.10.1" \
    "git+https://github.com/NikhilSuthar/dbt-duckdb.git@feature/s3-tables-support" \
    "duckdb==1.5.0"     \
    "boto3>=1.34"

WORKDIR /dbt

COPY . .
RUN mkdir -p /root/.dbt
COPY profiles/profiles.yml /root/.dbt/profiles.yml

ENV DBT_PROFILES_DIR=/root/.dbt

ENTRYPOINT []
CMD ["/usr/local/bin/dbt", "--help"]