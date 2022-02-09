<!-- BEGIN_TF_DOCS -->
# Terraform AWS ECS Service module

ECS Serviceと付随するロール群、セキュリティグループ、ターゲットグループ、メトリクスアラーム、サービスディカバりを作成します。

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.1.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=3.74.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >=3.74.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.cpu_utilization_too_high](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.memory_utilization_too_high](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_ecs_service.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_iam_policy.task_execution_policy_get_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.task_execution_policy_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.AmazonECSTaskExecutionRolePolicy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_execution_policy_get_parameter_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_execution_policy_kms_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb_listener_rule.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group.ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.ecs_service_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_service_discovery_service.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecs_task_definition.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_task_definition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container"></a> [container](#input\_container) | n/a | <pre>object({<br>    name              = string<br>    port              = number<br>    health_check_path = string<br>  })</pre> | n/a | yes |
| <a name="input_ecs_cluster"></a> [ecs\_cluster](#input\_ecs\_cluster) | n/a | <pre>object({<br>    arn  = string<br>    name = string<br>  })</pre> | n/a | yes |
| <a name="input_ecs_service"></a> [ecs\_service](#input\_ecs\_service) | n/a | <pre>object({<br>    desired_count                     = number<br>    platform_version                  = string<br>    health_check_grace_period_seconds = number<br>    capacity_provider_strategy = object({<br>      capacity_provider = string<br>      weight            = number<br>    })<br>  })</pre> | <pre>{<br>  "capacity_provider_strategy": {<br>    "capacity_provider": "FARGATE",<br>    "weight": 1<br>  },<br>  "desired_count": 1,<br>  "health_check_grace_period_seconds": 60,<br>  "platform_version": "1.4.0"<br>}</pre> | no |
| <a name="input_ecs_task_definition_name"></a> [ecs\_task\_definition\_name](#input\_ecs\_task\_definition\_name) | n/a | `string` | n/a | yes |
| <a name="input_ingresses"></a> [ingresses](#input\_ingresses) | n/a | <pre>list(object({<br>    description       = string<br>    from_port         = number<br>    to_port           = number<br>    protocol          = string<br>    security_group_id = string<br>  }))</pre> | n/a | yes |
| <a name="input_listener"></a> [listener](#input\_listener) | n/a | <pre>object({<br>    arn = string<br>    rule = object({<br>      priority    = number<br>      host_header = string<br>    })<br>  })</pre> | n/a | yes |
| <a name="input_metrics_alarm_thresholds"></a> [metrics\_alarm\_thresholds](#input\_metrics\_alarm\_thresholds) | n/a | <pre>object({<br>    cpu_utilization    = number<br>    memory_utilization = number<br>  })</pre> | <pre>{<br>  "cpu_utilization": 80,<br>  "memory_utilization": 80<br>}</pre> | no |
| <a name="input_metrics_notification_topic_arn"></a> [metrics\_notification\_topic\_arn](#input\_metrics\_notification\_topic\_arn) | n/a | `string` | n/a | yes |
| <a name="input_parameter_srote"></a> [parameter\_srote](#input\_parameter\_srote) | n/a | <pre>object({<br>    parameter_paths = list(string)<br>    kms_key_arn     = string<br>  })</pre> | <pre>{<br>  "kms_key_arn": "",<br>  "parameter_paths": []<br>}</pre> | no |
| <a name="input_service"></a> [service](#input\_service) | n/a | <pre>object({<br>    name      = string<br>    shortname = string<br>    env       = string<br>  })</pre> | n/a | yes |
| <a name="input_service_discovery"></a> [service\_discovery](#input\_service\_discovery) | n/a | <pre>object({<br>    private_dns_namespace_id = string<br>  })</pre> | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_task_policy_arn"></a> [task\_policy\_arn](#input\_task\_policy\_arn) | n/a | `string` | `""` | no |
| <a name="input_tf"></a> [tf](#input\_tf) | n/a | <pre>object({<br>    name          = string<br>    shortname     = string<br>    env           = string<br>    fullname      = string<br>    fullshortname = string<br>  })</pre> | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | n/a |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | n/a |
| <a name="output_task_execution_role"></a> [task\_execution\_role](#output\_task\_execution\_role) | n/a |
| <a name="output_task_role"></a> [task\_role](#output\_task\_role) | n/a |
<!-- END_TF_DOCS -->    