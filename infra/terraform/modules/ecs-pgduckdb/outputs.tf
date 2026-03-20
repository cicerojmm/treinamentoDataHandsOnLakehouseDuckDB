output "task_definition_arn" {
  description = "ARN da task definition"
  value       = aws_ecs_task_definition.pgduckdb.arn
}

output "task_definition_family" {
  description = "Family da task definition"
  value       = aws_ecs_task_definition.pgduckdb.family
}

output "service_name" {
  description = "Nome do serviço ECS"
  value       = aws_ecs_service.pgduckdb.name
}

# output "service_arn" {
#   description = "ARN do serviço ECS"
#   value       = aws_ecs_service.pgduckdb.arn
# }

output "security_group_id" {
  description = "ID do security group das tasks ECS"
  value       = aws_security_group.pgduckdb_tasks.id
}

output "alb_security_group_id" {
  description = "ID do security group do ALB"
  value       = aws_security_group.pgduckdb_alb.id
}

output "task_execution_role_arn" {
  description = "ARN da role de execução da task"
  value       = aws_iam_role.pgduckdb_task_execution.arn
}

output "task_role_arn" {
  description = "ARN da role da task"
  value       = aws_iam_role.pgduckdb_task.arn
}

output "log_group_name" {
  description = "Nome do CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.pgduckdb.name
}

output "load_balancer_dns_name" {
  description = "DNS name do Network Load Balancer"
  value       = aws_lb.pgduckdb.dns_name
}

output "load_balancer_arn" {
  description = "ARN do Network Load Balancer"
  value       = aws_lb.pgduckdb.arn
}

output "target_group_arn" {
  description = "ARN do target group"
  value       = aws_lb_target_group.pgduckdb.arn
}

output "connection_string" {
  description = "String de conexão para o pgDuckDB"
  value       = "postgresql://${var.postgres_user}:<password>@${aws_lb.pgduckdb.dns_name}:5432/${var.postgres_db}"
}
