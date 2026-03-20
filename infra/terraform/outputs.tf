###############################################################################
#########            ECS OUTPUTS                                  #############
###############################################################################
output "ecs_cluster_name" {
  description = "Nome do cluster ECS compartilhado"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN do cluster ECS compartilhado"
  value       = module.ecs_cluster.cluster_arn
}

###############################################################################
#########            ECS DLT OUTPUTS                              #############
###############################################################################
output "ecs_dlt_task_definition_family" {
  description = "Family da task definition DLT"
  value       = module.ecs_task_dlt.task_definition_family
}

output "ecs_dlt_security_group_id" {
  description = "ID do security group das tasks ECS DLT"
  value       = module.ecs_task_dlt.security_group_id
}

output "ecs_dlt_log_group_name" {
  description = "Nome do CloudWatch Log Group do DLT"
  value       = module.ecs_task_dlt.log_group_name
}


###############################################################################
#########            ECS DBT OUTPUTS                              #############
###############################################################################
output "dbt_task_definition_arn" {
  description = "ARN da task definition do DBT"
  value       = module.ecs_task_dbt.task_definition_arn
}

output "dbt_security_group_id" {
  description = "ID do security group do DBT"
  value       = module.ecs_task_dbt.security_group_id
}

###############################################################################
#########            ECS pgDuckDB OUTPUTS                         #############
###############################################################################
# output "ecs_pgduckdb_task_definition_arn" {
#   description = "ARN da task definition do pgDuckDB"
#   value       = module.ecs_pgduckdb.task_definition_arn
# }

# output "ecs_pgduckdb_service_arn" {
#   description = "ARN do serviço ECS do pgDuckDB"
#   value       = module.ecs_pgduckdb.service_arn
# }

# output "ecs_pgduckdb_security_group_id" {
#   description = "ID do security group das tasks do pgDuckDB"
#   value       = module.ecs_pgduckdb.security_group_id
# }

# output "ecs_pgduckdb_log_group_name" {
#   description = "Nome do CloudWatch Log Group do pgDuckDB"
#   value       = module.ecs_pgduckdb.log_group_name
# }

# output "ecs_pgduckdb_load_balancer_dns_name" {
#   description = "DNS name do Network Load Balancer do pgDuckDB"
#   value       = module.ecs_pgduckdb.load_balancer_dns_name
# }

# output "ecs_pgduckdb_connection_string" {
#   description = "String de conexão para o pgDuckDB"
#   value       = module.ecs_pgduckdb.connection_string
#   sensitive   = true
# }
