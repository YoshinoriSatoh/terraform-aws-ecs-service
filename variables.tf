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
    fullname      = var.service.env == "" ? var.service.name : "${var.service.name}-${var.service.env}"
    fullshortname = var.service.env == "" ? var.service.name : "${var.service.shortname}-${var.service.env}"
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

variable "ecs_service" {
  type = object({
    desired_count                     = number
    platform_version                  = string
    health_check_grace_period_seconds = number
    capacity_provider_strategy = object({
      capacity_provider = string
      weight            = number
    })
  })
  default = {
    capacity_provider_strategy = {
      capacity_provider = "FARGATE"
      weight            = 1
    }
    desired_count                     = 1
    health_check_grace_period_seconds = 60
    platform_version                  = "1.4.0"
  }
}

variable "load_balancer" {
  type = object({
    target_group_arn = string
    container = object({
      name = string
      port = number
    })
  })
}

variable "ingresses" {
  type = list(object({
    description     = string
    from_port       = number
    to_port         = number
    protocol        = string
    security_group_id  = string
  }))
}

variable "ecs_task_definition_name" {
  type = string
}

variable "task_policy_arn" {
  type = string
  default = ""
}

variable "service_discovery" {
  type = object({
    private_dns_namespace_id = string
  })
}

variable "parameter_srote" {
  type = object({
    parameter_paths = list(string)
    kms_key_arn      = string
  })
  default = {
    parameter_paths = []
    kms_key_arn = ""
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

