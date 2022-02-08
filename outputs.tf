output "security_group_id" {
  value = aws_security_group.ecs_service.id
}

output "task_role" {
  value = aws_iam_role.task-role
}

output "task_execution_role" {
  value = aws_iam_role.task-execution-role
}

output "ecs_service_name" {
  value = local.service.fullname
}