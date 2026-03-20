import json
import duckdb
import os
import logging
import shutil

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# Extensões pré-instaladas no build ficam aqui
PREINSTALLED_EXTENSIONS_DIR = '/opt/duckdb_extensions'

def lambda_handler(event, context):
    try:
       # 1. Preparar home_directory em /tmp (único diretório gravável no Lambda)
        temp_dir = '/tmp/duckdb_home'
        os.makedirs(temp_dir, exist_ok=True)

        # 2. Copiar extensões pré-instaladas para /tmp se ainda não estiver lá
        ext_dst = os.path.join(temp_dir, '.duckdb')
        if not os.path.exists(ext_dst) and os.path.exists(PREINSTALLED_EXTENSIONS_DIR):
            shutil.copytree(PREINSTALLED_EXTENSIONS_DIR, ext_dst)
            logger.info(f"Extensions copied from {PREINSTALLED_EXTENSIONS_DIR} to {ext_dst}")
        else:
            logger.info("Extensions already in place or not found in /opt")

        # 3. Conectar com home_directory configurado
        conn = duckdb.connect(':memory:', config={
            'home_directory': temp_dir
        })
        logger.info("DuckDB connected")

        # 4. Carregar extensões (sem INSTALL — já estão no disco)
        extensions = ['httpfs', 'parquet', 'avro', 'aws', 'iceberg']
        for ext in extensions:
            conn.execute(f"LOAD '{ext}';")
            logger.info(f"Loaded: {ext}")

        # 5. Credenciais AWS
        conn.execute("CALL load_aws_credentials();")
        conn.execute("""
            CREATE SECRET (
                TYPE s3,
                PROVIDER credential_chain
            );
        """)
        logger.info("AWS credentials configured")

        print(event)

        # 6. Parse dos parâmetros (suporta tanto HTTP quanto invocação direta)
        if 'queryStringParameters' in event:
            # Handle HTTP request from Function URL
            logger.info("Processing HTTP request from Function URL")
            query_params = event.get('queryStringParameters', {}) or {}

            # Extract parameters from query string
            catalog_arn = query_params.get('catalog_arn')
            query = query_params.get('query')

            # Validate required parameters
            if not catalog_arn or not query:
                return {
                    'statusCode': 400,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'error': 'Missing required parameters',
                        'required': ['catalog_arn', 'query']
                    })
                }
        else:
            # Handle direct Lambda invocation
            logger.info("Processing direct Lambda invocation")
            # Validate input parameters
            required_params = ['query', 'catalog_arn']
            if not all(param in event for param in required_params):
                return {
                    'statusCode': 400,
                    'body': json.dumps({
                        'error': 'Missing required parameters',
                        'required': required_params
                    })
                }

            catalog_arn = event['catalog_arn']
            query = event['query']

        logger.info(f"Using catalog ARN: {catalog_arn}")
        logger.info(f"Executing query: {query}")

        # Attach S3 Tables catalog using ARN
        try:
            conn.execute(f"""
            ATTACH '{catalog_arn}'
            AS s3_tables_db (
                TYPE iceberg,
                ENDPOINT_TYPE s3_tables
            );
            """)
            logger.info(f"Successfully attached S3 Tables catalog: {catalog_arn}")
        except Exception as e:
            logger.error(f"Catalog attachment failed: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'Catalog connection failed',
                    'details': str(e)
                })
            }

        # Execute query with enhanced error handling
        try:
            result = conn.execute(query).fetchall()
            columns = [desc[0] for desc in conn.description]

            formatted = [dict(zip(columns, row)) for row in result]
            logger.info(f"Query executed successfully. Returned {len(formatted)} rows.")
            response_body = json.dumps({
                'data': formatted,
                'metadata': {
                    'row_count': len(formatted),
                    'column_names': columns
                }
            }, default=str)

            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': response_body
            }

        except Exception as query_error:
            logger.error(f"Query execution failed: {str(query_error)}")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'Query execution error',
                    'details': str(query_error),
                    'suggestions': [
                        "Verify table exists in the attached database",
                        "Check your S3 Tables ARN format",
                        "Validate AWS permissions for the bucket"
                    ]
                })
            }

    except Exception as e:
        logger.error(f"Global error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Unexpected runtime error', 'details': str(e)})
        }
    finally:
        if 'conn' in locals():
            conn.close()