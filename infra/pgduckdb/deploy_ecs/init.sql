-- ── 1. Habilita DuckDB como engine padrão ────────────────────
SET duckdb.force_execution = true;

-- ── 2. Instala e carrega extensões ───────────────────────────
SELECT duckdb.install_extension('httpfs');
SELECT duckdb.load_extension('httpfs');

SELECT duckdb.install_extension('aws');
SELECT duckdb.load_extension('aws');

SELECT duckdb.install_extension('iceberg');
SELECT duckdb.load_extension('iceberg');

-- ── 3. Anexa o S3 Tables (configurar com valores reais) ───────
-- Nota: Substitua os valores de KEY_ID, SECRET e ARN pelos valores reais
-- Você pode passar essas variáveis através de variáveis de ambiente no ECS

-- SELECT duckdb.raw_query($$
--     CREATE PERSISTENT SECRET IF NOT EXISTS aws_credentials(
--         TYPE      s3,
--         KEY_ID    'YOUR_AWS_ACCESS_KEY_ID',
--         SECRET    'YOUR_AWS_SECRET_ACCESS_KEY',
--         REGION    'us-east-2'
--     )
-- $$);
--
-- SELECT duckdb.raw_query($$
--     ATTACH 'arn:aws:s3tables:us-east-2:YOUR_ACCOUNT_ID:bucket/YOUR_BUCKET_NAME'
--     AS lakehouse (
--         TYPE          iceberg,
--         ENDPOINT_TYPE s3_tables
--     )
-- $$);
