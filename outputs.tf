output "security_group" {
  value = aws_security_group.ecs_service
}

output "ecs_service" {
  value = aws_ecs_service.default
}

output "task_role" {
  value = aws_iam_role.task_role
}

output "task_execution_role" {
  value = aws_iam_role.task_execution_role
}

output "ecs_service_name" {
  value = local.service.fullname
}