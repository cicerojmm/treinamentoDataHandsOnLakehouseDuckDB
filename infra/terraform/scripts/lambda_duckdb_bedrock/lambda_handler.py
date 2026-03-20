import json
import duckdb
import os
import logging
import tempfile
import shutil

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# Extensões pré-instaladas no build ficam aqui
PREINSTALLED_EXTENSIONS_DIR = '/opt/duckdb_extensions'

def lambda_handler(event, context):

    def query_duck_db(event):
        conn = None
        try:
            catalog_arn = "arn:aws:s3tables:us-east-2:296735965303:bucket/datahandson-lakehouse-duckdb"
            query = event["requestBody"]["content"]["application/json"]["properties"][
                0
            ]["value"]

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


            logger.info(f"Catalog ARN: {catalog_arn}")
            logger.info(f"Query: {query}")

            # 6. Attach S3 Tables
            try:
                conn.execute(f"""
                    ATTACH '{catalog_arn}'
                    AS s3_tables_db (
                        TYPE iceberg,
                        ENDPOINT_TYPE s3_tables
                    );
                """)
                logger.info("S3 Tables catalog attached")
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

            # 7. Executar query
            try:
                result = conn.execute(query).fetchall()
                columns = [desc[0] for desc in conn.description]
                formatted = [dict(zip(columns, row)) for row in result]

                logger.info(
                    f"Query executed successfully. Returned {len(formatted)} rows."
                )
                response_body = json.dumps(formatted)

                return response_body
            except Exception as e:
                logger.error(f"Query error: {str(e)}")
                return {
                    'statusCode': 400,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'error': 'Query execution error',
                        'details': str(e)
                    })
                }

        except Exception as e:
            logger.error(f"Global error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'Unexpected runtime error',
                    'details': str(e)
                })
            }
        finally:
            if conn:
                conn.close()

    action_group = event.get("actionGroup")
    api_path = event.get("apiPath")

    print("api_path: ", api_path)

    result = ""
    response_code = 200

    if api_path == "/duckQuery":
        result = query_duck_db(event)
    else:
        response_code = 404
        result = {"error": f"Unrecognized api path: {action_group}::{api_path}"}

    response_body = {"application/json": {"body": result}}

    action_response = {
        "actionGroup": action_group,
        "apiPath": api_path,
        "httpMethod": event.get("httpMethod"),
        "httpStatusCode": response_code,
        "responseBody": response_body,
    }

    api_response = {"messageVersion": "1.0", "response": action_response}
    return api_response