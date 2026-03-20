output "cluster_name" {
  description = "Nome do cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN do cluster ECS"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_id" {
  description = "ID do cluster ECS"
  value       = aws_ecs_cluster.main.id
}
