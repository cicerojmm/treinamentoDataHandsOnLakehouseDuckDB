INSTALL httpfs;
LOAD httpfs;
INSTALL aws;
LOAD aws;
INSTALL iceberg;
LOAD iceberg;
INSTALL avro;
LOAD avro;

-- Credenciais AWS persistentes
CREATE PERSISTENT SECRET IF NOT EXISTS aws_credentials (
    TYPE   s3,
    KEY_ID    '${AWS_ACCESS_KEY_ID}',
    SECRET    '${AWS_SECRET_ACCESS_KEY}',
    REGION 'us-east-2'
);

-- Attach do S3 Tables
ATTACH IF NOT EXISTS 'arn:aws:s3tables:us-east-2:296735965303:bucket/datahandson-lakehouse-duckdb'
AS lakehouse (
    TYPE          iceberg,
    ENDPOINT_TYPE s3_tables
);