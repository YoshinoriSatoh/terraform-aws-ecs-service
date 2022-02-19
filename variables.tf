variable "tf" {
  type = object({
    name          = string
    shortname     = string
    env           = string
    fullname      = string
    fullshortname = string
  })
}

variable "service" {
  type = object({
    name      = string
    shortname = string
    env       = string
  })
}

locals {
  service = {
    fullname      = var.service.env == "" ? replace(var.service.name, "_", "-") : replace("${var.service.name}-${var.service.env}", "_", "-")
    fullshortname = var.service.env == "" ? replace(var.service.shortname, "_", "-") : replace("${var.service.shortname}-${var.service.env}", "_", "-")
  }
}

locals {
  fullname  = "${var.tf.fullname}-${local.service.fullname}"
  shortname = "${var.tf.shortname}-${local.service.fullshortname}"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "ecs_cluster" {
  type = object({
    arn  = string
    name = string
  })
}

variable "capacity_provider_strategy" {
  type = object({
    capacity_provider = string
    weight            = number
  })
  default = {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "platform_version" {
  type    = string
  default = "1.4.0"
}

variable "health_check_grace_period_seconds" {
  type    = number
  default = 60
}

variable "enable_execute_command" {
  type    = bool
  default = false
}

variable "load_balancer_enabled" {
  type    = bool
  default = false
}

variable "load_balancer" {
  type = object({
    listener = object({
      arn = string
      rule = object({
        priority     = number
        host_header  = string
        path_pattern = string
      })
    })
    container = object({
      name              = string
      port              = number
      health_check_path = string
    })
  })
  default = {
    container = {
      health_check_path = ""
      name = ""
      port = 0
    }
    listener = {
      arn = ""
      rule = {
        host_header = ""
        priority = 0
        path_pattern = "*"
      }
    }
  }
}

variable "ingresses" {
  type = list(object({
    description       = string
    from_port         = number
    to_port           = number
    protocol          = string
    security_group_id = string
  }))
  default = []
}

variable "ecs_task_definition_name" {
  type = string
}

variable "additional_task_policy_arn" {
  type    = string
  default = ""
}

variable "service_discovery_enabled" {
  type    = bool
  default = false
}

variable "service_discovery" {
  type = object({
    private_dns_namespace_id = string
  })
  default = {
    private_dns_namespace_id = ""
  }
}

variable "parameter_srote" {
  type = object({
    parameter_paths = list(string)
    kms_key_arn     = string
  })
  default = {
    parameter_paths = []
    kms_key_arn     = ""
  }
}

variable "metrics_alarm_thresholds" {
  type = object({
    cpu_utilization    = number
    memory_utilization = number
  })
  default = {
    cpu_utilization    = 80
    memory_utilization = 80
  }
}

variable "metrics_notification_topic_arn" {
  type = string
}

