output "service_name" {
  description = "ECS service name for Metabase"
  value       = aws_ecs_service.metabase_service.name
}

output "service_arn" {
  description = "ECS service ARN for Metabase"
  value       = aws_ecs_service.metabase_service.id
}

output "task_definition_arn" {
  description = "Task definition ARN"
  value       = try(aws_ecs_task_definition.metabase_task_efs[0].arn, aws_ecs_task_definition.metabase_task_noefs[0].arn)
}

output "alb_dns_name" {
  description = "ALB DNS name to access Metabase"
  value       = aws_lb.metabase_alb.dns_name
}

output "efs_id" {
  description = "EFS filesystem id used for persistence"
  value       = var.use_efs ? aws_efs_file_system.metabase_fs[0].id : ""
}

output "security_group_id" {
  description = "Security group id for Metabase"
  value       = aws_security_group.metabase_sg.id
}
