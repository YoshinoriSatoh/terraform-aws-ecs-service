/**
 * # Terraform AWS ECS Service module
 *
 * ECS Serviceと付随するロール群、セキュリティグループ、ターゲットグループ、メトリクスアラーム、サービスディカバりを作成します。
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ecs_task_definition" "default" {
  task_definition = var.ecs_task_definition_name
}

resource "aws_ecs_service" "default" {
  name                              = local.service.fullname
  cluster                           = var.ecs_cluster.arn
  task_definition                   = "${data.aws_ecs_task_definition.default.family}:${data.aws_ecs_task_definition.default.revision}"
  desired_count                     = var.ecs_service.desired_count
  platform_version                  = var.ecs_service.platform_version
  propagate_tags                    = "SERVICE"
  health_check_grace_period_seconds = var.ecs_service.health_check_grace_period_seconds
  enable_execute_command            = true

  deployment_controller {
    type = "ECS"
  }

  capacity_provider_strategy {
    capacity_provider = var.ecs_service.capacity_provider_strategy.capacity_provider
    weight            = var.ecs_service.capacity_provider_strategy.weight
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.default.arn
    container_name   = var.container.name
    container_port   = var.container.port
  }

  service_registries {
    registry_arn = aws_service_discovery_service.api.arn
  }

  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition
    ]
  }
}

resource "aws_cloudwatch_log_group" "default" {
  name = "/aws/ecs/${local.fullname}"
}

resource "aws_security_group" "ecs_service" {
  name        = local.fullname
  description = local.fullname
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ecs_service_ingress" {
  for_each = {
    for key, ingress in var.ingresses : key => {
      description       = ingress.description
      from_port         = ingress.from_port
      to_port           = ingress.to_port
      protocol          = ingress.protocol
      security_group_id = ingress.security_group_id
    }
  }
  type                     = "ingress"
  description              = each.value.description
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.security_group_id
  security_group_id        = aws_security_group.ecs_service.id
}

## Task Role
resource "aws_iam_role" "task_role" {
  name               = "${local.fullname}-task-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task_policy_attachment" {
  count      = var.task_policy_arn == "" ? 0 : 1
  role       = aws_iam_role.task_role.name
  policy_arn = var.task_policy_arn
}

## Task Ececution Role
resource "aws_iam_role" "task_execution_role" {
  name = "${local.fullname}-task-execution-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Effect" : "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicy_attachment" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "task_execution_policy_session_manager" {
  name        = "${local.fullname}-execution-policy-session-manager"
  description = "${local.fullname} execution policy session-manager"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_policy_session_manager_attachment" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.task_execution_policy_session_manager.arn
}

resource "aws_iam_policy" "task_execution_policy_kms" {
  count       = var.parameter_srote.kms_key_arn != "" ? 1 : 0
  name        = "${local.fullname}-execution-policy-kms"
  description = "${local.fullname} execution policy kms"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "kms:Decrypt"
        ],
        "Effect" : "Allow",
        "Resource" : var.parameter_srote.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_policy_kms_attachment" {
  count      = var.parameter_srote.kms_key_arn != "" ? 1 : 0
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.task_execution_policy_kms[0].arn
}

resource "aws_iam_policy" "task_execution_policy_get_parameter" {
  count       = length(var.parameter_srote.parameter_paths) > 0 ? 1 : 0
  name        = "${local.fullname}-execution-policy-get-parameter"
  description = "${local.fullname} execution policy get parameter"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowParameterStores",
        "Action" : [
          "ssm:GetParameter",
          "ssm:GetParameters",
        ],
        "Effect" : "Allow",
        "Resource" : var.parameter_srote.parameter_paths
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_policy_get_parameter_attachment" {
  count      = length(var.parameter_srote.parameter_paths) > 0 ? 1 : 0
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.task_execution_policy_get_parameter[0].arn
}

resource "aws_service_discovery_service" "api" {
  name = "api"

  dns_config {
    namespace_id = var.service_discovery.private_dns_namespace_id

    dns_records {
      ttl  = 5
      type = "A"
    }

    routing_policy = "WEIGHTED"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_lb_listener_rule" "default" {
  listener_arn = var.listener.arn
  priority     = var.listener.rule.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }

  condition {
    host_header {
      values = [var.listener.rule.host_header]
    }
  }
}

resource "aws_lb_target_group" "default" {
  name        = "${local.service.fullshortname}-${substr(uuid(), 0, 6)}"
  port        = var.container.port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    path = var.container.health_check_path
    port = var.container.port
  }
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }
}

# Cloudwatch Metric Alerms
resource "aws_cloudwatch_metric_alarm" "cpu_utilization_too_high" {
  alarm_name                = "${local.fullname}_cpu_utilization_too_high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "3"
  datapoints_to_alarm       = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECS"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = var.metrics_alarm_thresholds.cpu_utilization
  alarm_description         = "Average CPU utilization too high"
  alarm_actions             = [var.metrics_notification_topic_arn]
  ok_actions                = [var.metrics_notification_topic_arn]
  insufficient_data_actions = []
  treat_missing_data        = "ignore"
  dimensions = {
    ClusterName = var.ecs_cluster.name
    ServiceName = local.service.fullname
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization_too_high" {
  alarm_name                = "${local.fullname}_memory_utilization_too_high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "3"
  datapoints_to_alarm       = "2"
  metric_name               = "MemoryUtilization"
  namespace                 = "AWS/ECS"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = var.metrics_alarm_thresholds.memory_utilization
  alarm_description         = "Average Memory utilization too high"
  alarm_actions             = [var.metrics_notification_topic_arn]
  ok_actions                = [var.metrics_notification_topic_arn]
  insufficient_data_actions = []
  treat_missing_data        = "ignore"
  dimensions = {
    ClusterName = var.ecs_cluster.name
    ServiceName = local.service.fullname
  }
}
