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

variable "ecs_container_name" {
  description = "The name of the container"
  type        = string
}

variable "ecs_container_image" {
  description = "Container image URI to be used"
  type        = string
}

variable "gh_secrets_name" {
  description = "The name of the AWS Secrets where secrets are stored"
  type        = string
}

variable "lambda_iam_policy_name" {
  description = "The name of the policy that will be attached to the role which will be used by AWS Lambda"
  type        = string
}

variable "lambda_name" {
  description = "The name of the lambda fuction"
  type        = string
}

variable "api_gateway_name" {
  description = "The name of the API Gateway"
  type        = string
}

variable "subnets" {
  description = "Comma separated subnet ids of where the ecs task to run"
  type        = string
}

variable "security_groups" {
  description = "Comma separated security group ids to be applied to the ecs tasks"
  type        = string
}