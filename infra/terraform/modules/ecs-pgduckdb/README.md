# ECS pgDuckDB Module

Este módulo Terraform provisiona o pgDuckDB como um serviço no AWS ECS Fargate com acesso pela internet na porta 5432 através de um Network Load Balancer.

## Recursos Criados

- **ECS Task Definition**: Define a configuração da task do pgDuckDB
- **ECS Service**: Gerencia o ciclo de vida do container
- **Network Load Balancer (NLB)**: Expõe a porta 5432 para acesso externo
- **Target Group**: Roteia o tráfego para as tasks
- **Security Groups**: Controlam o acesso ao ALB e às tasks
- **IAM Roles**: Permitem que as tasks acessem recursos AWS (S3, S3 Tables, etc.)
- **CloudWatch Logs**: Armazena os logs das tasks
- **Auto Scaling**: Escalabilidade automática baseada em CPU e memória

## Pré-requisitos

1. ECR repository com a imagem do pgDuckDB já construída
2. AWS Secrets Manager com a senha do PostgreSQL configurada
3. VPC com subnets públicas e privadas já existentes
4. ECS Cluster já criado

## Exemplo de Uso

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
  postgres_password_secret_arn  = aws_secretsmanager_secret.pgduckdb_password.arn

  cpu                           = "512"
  memory                        = "1024"
  desired_count                 = 1
  min_capacity                  = 1
  max_capacity                  = 3

  s3tables_arn                  = var.s3tables_arn
}
```

## Variáveis Necessárias

| Variável | Tipo | Padrão | Descrição |
|----------|------|--------|-----------|
| `environment` | string | - | Ambiente (dev, staging, prod) |
| `vpc_id` | string | - | ID da VPC |
| `cluster_id` | string | - | ID do cluster ECS |
| `cluster_name` | string | - | Nome do cluster ECS |
| `public_subnet_ids` | list(string) | - | IDs das subnets públicas para o ALB |
| `private_subnet_ids` | list(string) | - | IDs das subnets privadas para as tasks |
| `aws_region` | string | - | Região AWS |
| `ecr_image_uri` | string | - | URI da imagem Docker no ECR |
| `postgres_password_secret_arn` | string | - | ARN do secret da senha do PostgreSQL |
| `cpu` | string | "512" | CPU da task (256, 512, 1024, 2048, 4096) |
| `memory` | string | "1024" | Memória da task em MB |
| `desired_count` | number | 1 | Número de tasks desejadas |
| `min_capacity` | number | 1 | Capacidade mínima para auto scaling |
| `max_capacity` | number | 3 | Capacidade máxima para auto scaling |
| `postgres_user` | string | "duckdb" | Usuário PostgreSQL |
| `postgres_db` | string | "warehouse" | Nome do banco de dados |
| `s3tables_arn` | string | "" | ARN dos S3 Tables |

## Outputs

- `task_definition_arn`: ARN da task definition
- `service_arn`: ARN do serviço ECS
- `load_balancer_dns_name`: DNS name do NLB (use para conectar)
- `connection_string`: String de conexão padrão para o pgDuckDB
- `log_group_name`: Nome do CloudWatch Log Group

## Como se Conectar

Após o deployment, você pode se conectar ao pgDuckDB usando:

```bash
psql -h <load_balancer_dns_name> -U duckdb -d warehouse
```

Ou com uma aplicação usando a connection string:

```
postgresql://duckdb:<password>@<load_balancer_dns_name>:5432/warehouse
```

## Observações Importantes

1. **Segurança**: O NLB expõe a porta 5432 para `0.0.0.0/0`. Para ambientes de produção, restrinja o CIDR nas rules de ingress.

2. **Health Check**: O ECS verificará a saúde das tasks a cada 30 segundos usando o comando `pg_isready`.

3. **Auto Scaling**: As tasks escalarem automaticamente quando CPU > 70% ou Memória > 80%.

4. **Custos**: Network Load Balancer tem custos associados. Verifique o orçamento antes de aplicar em produção.

5. **S3 Tables**: Se usar S3 Tables, a `s3tables_arn` deve estar configurada com as permissões corretas.
