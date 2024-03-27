resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  retention_in_days = 30
}

resource "aws_ecs_cluster" "this" {
  count = var.create_cluster ? 1 : 0

  name = var.ecs_cluster_name
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  count = var.create_cluster ? 1 : 0

  cluster_name = aws_ecs_cluster.this[0].name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 0
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ecs_exec_managed_policy" {
  name = "AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_exec" {
  name                = var.ecs_task_execution_role_name
  assume_role_policy  = data.aws_iam_policy_document.ecs_assume_role_policy.json
  managed_policy_arns = [data.aws_iam_policy.ecs_exec_managed_policy.arn]
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.task_family_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "2048"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  execution_role_arn = aws_iam_role.ecs_task_exec.arn
  container_definitions = jsonencode([
    {
      name      = "runner"
      image     = "docker.io/ilniko/github-runner:latest"
      essential = true
      environment : [
        { "name" : "GITHUB_OWNER", "value" : "" },
        { "name" : "GITHUB_REPO", "value" : "" },
        { "name" : "GITHUB_RUNNER_NAME", "value" : "" },
        { "name" : "GITHUB_REGISTRATION_TOKEN", "value" : "" },
      ]
      logConfiguration : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : var.log_group_name
          "awslogs-region" : var.region
          "awslogs-stream-prefix" : "ecs"
        }
      }
    }
  ])
}