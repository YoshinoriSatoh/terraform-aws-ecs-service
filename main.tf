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
  desired_count                     = var.desired_count
  platform_version                  = var.platform_version
  propagate_tags                    = "SERVICE"
  health_check_grace_period_seconds = var.load_balancer_enabled ? var.health_check_grace_period_seconds : null
  enable_execute_command            = var.enable_execute_command

  deployment_controller {
    type = "ECS"
  }

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_strategy.capacity_provider
    weight            = var.capacity_provider_strategy.weight
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each         = var.load_balancer_enabled ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.default[0].arn
      container_name   = var.load_balancer.container.name
      container_port   = var.load_balancer.container.port
    }
  }

  dynamic "service_registries" {
    for_each     = var.service_discovery_enabled ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.this[0].arn
    }
  }

  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition
    ]
  }
}

resource "aws_cloudwatch_log_group" "default" {
  name = "/aws/ecs/${var.tf.fullname}/${local.service.fullname}"
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

resource "aws_iam_role_policy_attachment" "additional_task_policy_attachment" {
  count      = var.additional_task_policy_arn == "" ? 0 : 1
  role       = aws_iam_role.task_role.name
  policy_arn = var.additional_task_policy_arn
}

### EXEC Command実行時に必要なポリシー
resource "aws_iam_policy" "task_policy_session_manager" {
  count       = var.enable_execute_command ? 1 : 0
  name        = "${local.fullname}-policy-session-manager"
  description = "${local.fullname} policy session-manager"

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
resource "aws_iam_role_policy_attachment" "task_policy_session_manager_attachment" {
  count      = var.enable_execute_command ? 1 : 0
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.task_policy_session_manager[0].arn
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

resource "aws_service_discovery_service" "this" {
  count = var.service_discovery_enabled ? 1 : 0
  name  = local.fullname

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
  count        = var.load_balancer_enabled ? 1 : 0
  listener_arn = var.load_balancer.listener.arn
  priority     = var.load_balancer.listener.rule.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default[0].arn
  }

  condition {
    host_header {
      values = [var.load_balancer.listener.rule.host_header]
    }
  }
}

resource "aws_lb_target_group" "default" {
  count       = var.load_balancer_enabled ? 1 : 0
  name        = "${local.service.fullshortname}-${substr(uuid(), 0, 6)}"
  port        = var.load_balancer.container.port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    path = var.load_balancer.container.health_check_path
    port = var.load_balancer.container.port
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
