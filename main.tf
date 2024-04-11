# We are going to use this log group to send logs from all services
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
      name      = var.ecs_container_name
      image     = var.ecs_container_image
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

################
# Lambda Setup #
################

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_secretsmanager_secret" "this" {
  name = var.gh_secrets_name
}

resource "aws_iam_policy" "lambda_permissions" {
  name        = var.lambda_iam_policy_name
  description = "This policy gives permission to Github Runners Lambda."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["ecs:RunTask"]
        Effect   = "Allow"
        Resource = "${aws_ecs_task_definition.this.arn_without_revision}:*"
      },
      {
        Action   = ["secretsmanager:GetSecretValue"]
        Effect   = "Allow"
        Resource = data.aws_secretsmanager_secret.this.arn
      },
      {
        Action   = ["iam:PassRole"]
        Effect   = "Allow"
        Resource = aws_iam_role.ecs_task_exec.arn
      }
    ]
  })
}

resource "aws_iam_role" "iam_for_lambda" {
  name                = var.lambda_name
  assume_role_policy  = data.aws_iam_policy_document.lambda_assume_role_policy.json
  managed_policy_arns = [aws_iam_policy.lambda_permissions.arn]
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.root}/data/lambda"
  output_path = "${path.root}/data/lambda_function_payload.zip"
}

resource "aws_lambda_function" "this" {
  filename         = "${path.root}/data/lambda_function_payload.zip"
  function_name    = var.lambda_name
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 15
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      ECS_CLUSTER_NAME    = var.ecs_cluster_name
      ECS_TASK_DEFINITION = aws_ecs_task_definition.this.arn_without_revision
      SUBNETS             = var.subnets
      SECURITY_GROUPS     = var.security_groups
      GH_SECRETS_NAME     = var.gh_secrets_name
    }
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.this.name
  }
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowGHRunnerstAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.this.execution_arn}/*"
}

resource "aws_apigatewayv2_api" "this" {
  name          = var.api_gateway_name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "this" {
  api_id                 = aws_apigatewayv2_api.this.id
  description            = "AWS Lambda integration"
  integration_type       = "AWS_PROXY"
  payload_format_version = "2.0"
  integration_uri        = aws_lambda_function.this.invoke_arn
}

resource "aws_apigatewayv2_route" "post_queued" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /queued"

  target = "integrations/${aws_apigatewayv2_integration.this.id}"
}