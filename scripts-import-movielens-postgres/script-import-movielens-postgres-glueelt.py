%idle_timeout 2880
%glue_version 5.0
%worker_type G.1X
%number_of_workers 5

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame

  
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

csv_files = [
    "movies",
    "tags",
    "ratings",
    "links"
]

def gravar_dados_rds(dynamic_frame, table_name, glueContext): 
    glueContext.write_dynamic_frame.from_options(
        frame=dynamic_frame,
        connection_type="postgresql",
        connection_options={
            "url": "jdbc:postgresql://datahandson-lakehouse-duckdb-dev-postgres.cnai0csqspw4.us-east-2.rds.amazonaws.com:5432/movielens_database",
            "user": "metabase",
            "password": "Mds20251",  # RECOMENDADO: use Secrets Manager no lugar
            "dbtable": f"public.{table_name}"
        },
        transformation_ctx="jdbc_output"
    )
    

s3_path_raw = 's3://cjmm-mds-lake-raw/movielens'

for table in csv_files:
    df = spark.read.csv(f"{s3_path_raw}/{table}.csv", header=True, inferSchema=True)
    dynamic_frame = DynamicFrame.fromDF(df, glueContext, "meu_dynamic_frame_exemplo")
    gravar_dados_rds(dynamic_frame, table, glueContext)