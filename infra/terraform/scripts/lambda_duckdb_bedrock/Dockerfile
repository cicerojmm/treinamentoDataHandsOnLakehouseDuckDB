FROM public.ecr.aws/lambda/python:3.12

COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Pré-instala extensões DuckDB durante o build
RUN python3 -c "\
import duckdb; \
import tempfile; \
import os; \
import shutil; \
temp_dir = tempfile.mkdtemp(); \
conn = duckdb.connect(':memory:', config={'home_directory': temp_dir}); \
[conn.execute(f'INSTALL {ext}') for ext in ['httpfs', 'parquet', 'avro', 'aws', 'iceberg']]; \
conn.close(); \
src = os.path.join(temp_dir, '.duckdb'); \
shutil.copytree(src, '/opt/duckdb_extensions') if os.path.exists(src) else None; \
print('Extensions installed successfully'); \
"

COPY . ${LAMBDA_TASK_ROOT}/

CMD [ "lambda_handler.lambda_handler" ]