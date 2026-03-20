-- ── 1. Habilita DuckDB como engine padrão ────────────────────
SET duckdb.force_execution = true;

-- ── 2. Instala e carrega extensões ───────────────────────────
SELECT duckdb.install_extension('httpfs');
SELECT duckdb.load_extension('httpfs');

SELECT duckdb.install_extension('aws');
SELECT duckdb.load_extension('aws');

SELECT duckdb.install_extension('iceberg');
SELECT duckdb.load_extension('iceberg');

-- ── 3. Anexa o S3 Tables ───────────────────────────
SELECT duckdb.raw_query($$
    CREATE PERSISTENT SECRET IF NOT EXISTS aws_credentials(
        TYPE      s3,
        KEY_ID    '${AWS_ACCESS_KEY_ID}',
        SECRET    '${AWS_SECRET_ACCESS_KEY}',
        REGION    'us-east-2'
    )
$$);

-- ATTACH
SELECT duckdb.raw_query($$
    ATTACH 'arn:aws:s3tables:us-east-2:296735965303:bucket/datahandson-lakehouse-duckdb'
    AS lakehouse (
        TYPE          iceberg,
        ENDPOINT_TYPE s3_tables
    )
$$);


-- SELECT * FROM duckdb.query($$ SHOW DATABASES $$);

-- SELECT * FROM duckdb.query($$ SHOW ALL TABLES $$);

-- SELECT * FROM duckdb.query($$
--     SELECT * FROM lakehouse.bronze.tags
--     LIMIT 10
-- $$);