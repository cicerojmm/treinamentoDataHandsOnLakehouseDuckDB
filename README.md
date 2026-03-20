**Workshop Lakehouse Moderno — Data HandsON (DuckDB + S3 Tables)**

Resumo
------
Este repositório contém o material do workshop "Lakehouse Moderno na AWS com DuckDB" (Data HandsON). O objetivo é demonstrar um pipeline completo: extração de dados de PostgreSQL → carregamento com `dlt` para S3 Tables (Iceberg) → transformação com `dbt` (DuckDB) → exploração com Metabase (DuckDB). A orquestração local e de produção é feita com Airflow (DAGs), e a infraestrutura é criada com Terraform (ECS, EFS, RDS, ALB, etc.).

Tecnologias utilizadas (breve)
--------------------------------
- AWS (ECR, ECS, EFS, RDS, ALB, CloudWatch, IAM)
- Terraform: IaC para criar VPC, RDS, ECS cluster, Task Definitions, EFS e ALB
- Docker: Imagens para `dlt`, `dbt`, `metabase+duckdb` e utilitários
- Airflow: orquestração de DAGs local (docker-compose) e para execução em ECS
- dlt: extração/ingestão de dados (Postgres → S3 Tables / Iceberg)
- dbt (with DuckDB): modelos SQL para transformar dados e gerar manifests
- DuckDB + S3 Tables (Iceberg): armazenamento e consulta de tabelas em S3
- Metabase + DuckDB: exploração de dados via DuckDB (arquivo persistente `.duckdb`)
- Cosmos: integração dbt → Airflow (usa manifest na execução)

Estrutura principal do repositório
----------------------------------
- `infra/terraform/` — módulos e root Terraform para criar infra na AWS
- `infra/airflow/` — docker-compose, Dockerfiles e DAGs para rodar Airflow localmente
- `dlt-postgres-s3tables/` — projeto `dlt` para extrair de Postgres e enviar para S3 Tables
- `dbt/` ou `dbt_s3_iceberg/` — projetos `dbt` e macros (modelos OLAP)
- `infra/metabase-duckdb/` — Dockerfile, init SQL e docker-compose para Metabase+DuckDB local

Dados utilizados
----------------
- Fonte: MovieLens (GroupLens) — conjunto de dados utilizado no workshop:
  https://grouplens.org/datasets/movielens/
- Arquivos usados (exemplos presentes no fluxo de ingestão):
  - `links.csv`
  - `tags.csv`
  - `movies.csv`
  - `ratings.csv`

Pastas adicionais importantes
----------------------------
- `lambda_duckdb_api` — código e Dockerfile para a Lambda/API que expõe consultas DuckDB (via container/ECR).
- `lambda_duckdb_bedrock` — funções Lambda e helpers para integração com Bedrock (se aplicável ao workshop).
- `scripts-import-movielens-postgres` — scripts para importar os arquivos MovieLens para o Postgres (ex.: Glue job, scripts ETL). Contém:
  - `script-import-movielens-postgres-glueelt.py` — exemplo de job Glue que lê CSVs do S3 e grava no Postgres (use Secrets Manager para credenciais em vez de hardcoding).

Segurança importante — nunca commite chaves
-----------------------------------------
Os exemplos do workshop podem conter snippets com variáveis de ambiente — NUNCA deixe chaves AWS, senhas ou credenciais em arquivos versionados. Use Airflow Connections, AWS IAM Roles (ECS Task Role, Instance Role) e AWS Secrets Manager quando possível.

1) Build & push das imagens Docker para ECR
------------------------------------------
O Airflow/ECS executará containers (`dlt`, `dbt`, `metabase`) — antes de rodar em ECS você precisa construir e enviar as imagens para o ECR.

- dlt (exemplo):
  - Há um script já presente em `dlt-postgres-s3tables/deploy/push-image.sh` para build & push dessa imagem.
  - Exemplo:
    ```bash
    cd dlt-postgres-s3tables
    ./deploy/push-image.sh
    ```

- dbt (exemplo):
  - Há scripts de build em `infra/airflow/dbt/` e `infra/dbt/` (veja `build_and_push.sh` nos módulos dbt).
  - Exemplo (genérico):
    ```bash
    cd infra/airflow/dbt
    ./build_and_push.sh
    ```

- Metabase + DuckDB:
  - Script criado: `infra/metabase-duckdb/deploy/push-image.sh` (constrói a imagem a partir do Dockerfile em `infra/metabase-duckdb/` e envia para ECR).
  - Também existe um helper genérico: `infra/terraform/deploy/push-metabase-image.sh`.
  - Uso exemplo:
    ```bash
    cd infra/metabase-duckdb/deploy
    ./push-image.sh metabase latest .. us-east-2
    ```

Nota: os scripts usam `aws sts get-caller-identity` para detectar o Account ID e `aws ecr` para criar repositório quando necessário.

2) Configuração do DuckDB
-------------------------
O projeto usa DuckDB para consultas locais e também o driver DuckDB para Metabase.

- Local (docker-compose): o `docker-compose.yml` em `infra/metabase_duckdb/` monta a pasta `./duckdb` para persistir arquivos:
  - `./duckdb` → `/duckdb` no container
  - `duckdb/init.sql` contém instruções `ATTACH` para S3 Tables e (atualmente) exemplos de `CREATE PERSISTENT SECRET` — remova chaves sensíveis do arquivo e prefira usar roles/secret manager.

- Em ECS: o módulo Terraform `modules/ecs-metabase-duckdb` monta um `EFS` em `/duckdb` dentro do container. Assim o `.duckdb` persiste entre reinícios de tarefa.

3) Metabase + DuckDB (local vs ECS)
-----------------------------------
- Local: `infra/metabase_duckdb/docker-compose.yml` traz uma configuração simples com Postgres auxiliar (metabase metadata) e montagem `./duckdb:/duckdb`.

- ECS: o módulo `ecs-metabase-duckdb` (em `infra/terraform/modules/`) cria:
  - EFS filesystem e mount targets
  - ALB público (porta 80)
  - ECS Task Definition Fargate com volume EFS montado em `/duckdb`
  - Variáveis de ambiente `MB_DB_FILE=/duckdb/metabase.db` (onde Metabase guarda seu DB H2/arquivo) e `MB_DUCKDB_DIR=/duckdb` para o driver DuckDB

4) Airflow — executar DAGs localmente com Docker
-----------------------------------------------
Há um `docker-compose.yml` para Airflow em `infra/airflow/`. Para rodar localmente:

```bash
cd infra/airflow
docker-compose up -d
# aguarde até que 'airflow-init' finalize e que scheduler/webserver estejam prontos
docker-compose logs -f airflow-webserver
```

Configurar conexões no UI do Airflow (http://localhost:8080):
- `aws_default` — credenciais ou role para acessar S3/ECR
- `postgres_default` — credenciais do Postgres de origem (se for testar local, use o Postgres que o docker-compose pode criar)

Trigger de DAGs (exemplos):
- `dlt_postgres_s3tables_by_table` — extrai uma tabela do Postgres usando dlt
- `dlt_postgres_s3tables_full_load` — full load

5) Terraform — criar tudo na AWS
--------------------------------
O núcleo da infraestrutura é definido em `infra/terraform`.

Passos para criar na AWS:

```bash
cd infra/terraform
terraform init
terraform plan -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars -auto-approve
```

Principais recursos criados (por módulos):
- `vpc` — VPC, subnets
- `rds` — RDS PostgreSQL (o projeto cria DB `metabase` por conveniência)
- `ecs-cluster` — Cluster ECS
- `ecs-task-dlt` / `ecs-task-dbt` — Task definitions para executar dlt/dbt no ECS
- `ecs-metabase-duckdb` — ALB + ECS Service + EFS para Metabase + DuckDB

6) dbt parse → subir manifest para S3 (Cosmos integration)
-----------------------------------------------------------
Para que o Cosmos (Airflow provider) execute dbt dentro de um container e utilize o manifest, execute o parse e disponibilize o `target/` no S3.

Exemplo (remova as credenciais reais antes de usar — abaixo são variáveis de ambiente):

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
  -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
  -e AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-2}" \
  -v $(pwd)/target:/dbt/target \
  datahandson/dbt:latest \
  parse
```

Depois gere o `target/manifest.json` e envie para S3 (exemplo):

```bash
aws s3 cp target/manifest.json s3://<bucket-deploy>/dbt/manifest.json
```

7) Observabilidade e logs
-------------------------
- Para tarefas ECS: logs no CloudWatch (os módulos criam CloudWatch Log Groups para tasks)
- Para execução local com Docker: `docker-compose logs -f <service>` e Airflow UI logs

8) Boas práticas e próximos ajustes
---------------------------------
- Remover credenciais do repositório: mova chaves para AWS Secrets Manager ou configure Roles (ECS Task Role / IAM).
- Habilitar HTTPS no ALB (ACM) antes de expor Metabase publicamente.
- Usar EFS Access Points para controlar UID/GID de arquivos no volume montado.
- Fazer provisionamento inicial do EFS (copiar `init.sql` e `.duckdb`) com um job separado ou script que monte EFS temporariamente.

Arquivos importantes para referência rápida
------------------------------------------
- `dlt-postgres-s3tables/pipeline.py` — lógica do pipeline dlt
- `dlt-postgres-s3tables/deploy/push-image.sh` — script para push da imagem dlt
- `infra/metabase-duckdb/Dockerfile` — Dockerfile Metabase+DuckDB
- `infra/metabase-duckdb/docker-compose.yml` — configuração local do Metabase com DuckDB
- `infra/airflow/docker-compose.yml` — Airflow local (webserver + scheduler + postgres)
- `infra/terraform/modules/ecs-metabase-duckdb` — módulo ECS Metabase + EFS + ALB
- `infra/terraform/deploy/push-metabase-image.sh` — helper para build/push da imagem Metabase

Contato / Autor
---------------
Material criado para o Workshop Lakehouse Moderno — Data HandsON

Destruir todo o ambiente
-----------------------
Siga estas etapas para remover os recursos criados localmente e na AWS. CUIDADO: `terraform destroy` apagará recursos na sua conta AWS.

1) Parar e remover os serviços locais (Docker Compose)

```bash
# Airflow local
cd infra/airflow
docker-compose down --volumes --remove-orphans

# Metabase DuckDB local (se estiver rodando via docker-compose)
cd infra/metabase-duckdb
docker-compose down --volumes --remove-orphans
```

2) Remover imagens locais (opcional)

```bash
docker image rm <image_id_or_name>
```

3) Destruir recursos provisionados pela Terraform (AWS)

```bash
cd infra/terraform
terraform plan -destroy -var-file=envs/dev.tfvars
terraform destroy -var-file=envs/dev.tfvars -auto-approve
```

Observações e limpeza adicional
- ECR: `terraform destroy` não remove imagens automaticamente do ECR; para limpar imagens use `aws ecr batch-delete-image` ou delete repository via console.
- EFS: se o EFS estiver sendo usado por outros recursos, confirme dependências antes de excluir.
- RDS: a destruição removerá a instância (dados serão perdidos se não houver snapshot). Se quiser preservar dados, crie snapshots antes.

Se quiser, posso automatizar a limpeza de ECR e fornecer scripts adicionais para snapshot/backup antes da destruição — diga se deseja que eu adicione isso ao repo.
