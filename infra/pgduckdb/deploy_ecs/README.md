# pgDuckDB ECS Deployment

Este diretório contém os arquivos necessários para fazer deploy do pgDuckDB no AWS ECS.

## Estrutura

- `Dockerfile`: Dockerfile para construir a imagem do pgDuckDB
- `build_and_push.sh`: Script para fazer build e push da imagem para o ECR
- `init.sql`: Script de inicialização do banco de dados

## Pré-requisitos

1. AWS CLI configurado
2. Docker instalado
3. Credenciais AWS com permissões para ECR e ECS

## Passos para Deploy

### 1. Construir e fazer push da imagem Docker

```bash
cd infra/pgduckdb/deploy_ecs

# Tornar o script executável
chmod +x build_and_push.sh

# Executar o script de build e push
# Você pode passar variáveis de ambiente opcionais:
# - AWS_ACCOUNT_ID: Seu ID da conta AWS (default: obtido via AWS CLI)
# - AWS_REGION: Região AWS (default: us-east-2)
# - ECR_REPOSITORY_NAME: Nome do repositório ECR (default: pgduckdb)
# - IMAGE_TAG: Tag da imagem (default: latest)

./build_and_push.sh

# Ou com variáveis customizadas:
AWS_REGION=us-west-2 ECR_REPOSITORY_NAME=my-pgduckdb IMAGE_TAG=v1.0 ./build_and_push.sh
```

### 2. Criar secret para a senha do PostgreSQL

```bash
# Criar o secret no AWS Secrets Manager
aws secretsmanager create-secret \
  --name pgduckdb-password \
  --secret-string "sua-senha-segura" \
  --region us-east-2
```

### 3. Aplicar o Terraform

No arquivo `infra/terraform/main.tf`, adicione o módulo do pgDuckDB:

```hcl
module "ecs_pgduckdb" {
  source = "./modules/ecs-pgduckdb"

  environment                   = var.environment
  vpc_id                        = module.vpc_public.vpc_id
  cluster_id                    = module.ecs_cluster.cluster_id
  cluster_name                  = module.ecs_cluster.cluster_name
  public_subnet_ids             = module.vpc_public.public_subnet_ids
  private_subnet_ids            = module.vpc_public.private_subnet_ids
  aws_region                    = var.region

  ecr_image_uri                 = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/pgduckdb:latest"
  postgres_password_secret_arn  = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:pgduckdb-password"

  cpu                           = "512"
  memory                        = "1024"
  desired_count                 = 1
  min_capacity                  = 1
  max_capacity                  = 3

  s3tables_arn                  = var.s3tables_arn
}
```

Depois execute:

```bash
cd infra/terraform

# Inicializar o Terraform
terraform init -backend-config="backends/dev.hcl"

# Planejar as mudanças
terraform plan -var-file="envs/dev.tfvars"

# Aplicar as mudanças
terraform apply -var-file="envs/dev.tfvars" -auto-approve
```

## Conectando ao pgDuckDB

Após o deployment bem-sucedido, obtenha o DNS do Network Load Balancer:

```bash
terraform output ecs_pgduckdb_load_balancer_dns_name
```

Então conecte usando:

```bash
psql -h <dns-name> -U duckdb -d warehouse
```

Ou com uma string de conexão:

```
postgresql://duckdb:<password>@<dns-name>:5432/warehouse
```

## Monitorando os Logs

Veja os logs das tasks no CloudWatch:

```bash
# Listar os log streams
aws logs describe-log-streams \
  --log-group-name /ecs/pgduckdb-dev \
  --region us-east-2

# Ver os logs
aws logs tail /ecs/pgduckdb-dev --follow --region us-east-2
```

## Troubleshooting

### A task não inicia

1. Verifique os logs no CloudWatch
2. Verifique se a imagem ECR existe e está acessível
3. Verifique se o secret da senha foi criado corretamente

### Não consigo conectar

1. Verifique se o NLB foi criado: `aws elbv2 describe-load-balancers --region us-east-2`
2. Verifique se a task está em estado RUNNING: `aws ecs list-tasks --cluster data-handson-ecs-cluster-dev`
3. Verifique o security group do ALB permite conexões na porta 5432

## Limpeza

Para remover todos os recursos:

```bash
terraform destroy -var-file="envs/dev.tfvars" -auto-approve
```

## Notas de Segurança

- A senha do PostgreSQL está no AWS Secrets Manager. Nunca comente ou versione a senha real
- O NLB está exposto para `0.0.0.0/0`. Para produção, restrinja o acesso
- Considere usar VPN ou bastion host para acessar o banco de dados
