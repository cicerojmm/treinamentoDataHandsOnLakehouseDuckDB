output "task_definition_arn" {
  description = "ARN da task definition"
  value       = aws_ecs_task_definition.main.arn
}

output "task_definition_family" {
  description = "Family da task definition"
  value       = aws_ecs_task_definition.main.family
}

output "security_group_id" {
  description = "ID do security group das tasks ECS"
  value       = aws_security_group.ecs_tasks.id
}

output "task_execution_role_arn" {
  description = "ARN da role de execução da task"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  description = "ARN da role da task"
  value       = aws_iam_role.ecs_task.arn
}

output "log_group_name" {
  description = "Nome do CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.ecs.name
}
