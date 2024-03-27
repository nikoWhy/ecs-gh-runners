variable "region" {
  description = "Region Name"
  type        = string
}
variable "create_cluster" {
  description = "Trigger whether to create an ECS cluster"
  type        = bool
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "log_group_name" {
  description = "Name of the CloudWatch log group"
  type        = string
}

variable "task_family_name" {
  description = "Name of the task family"
  type        = string
}

variable "ecs_task_execution_role_name" {
  description = "ECS task execution role name"
  type        = string
}