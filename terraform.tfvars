region                       = "eu-central-1"
create_cluster               = true
ecs_cluster_name             = "github-runners"
log_group_name               = "/github-runners"
task_family_name             = "gh-runner"
ecs_task_execution_role_name = "gh-runners-ecs-task"
ecs_task_role_name           = "gh-runners-ecs-task-admin"
ecs_container_name           = "runner"
ecs_container_image          = "docker.io/ilniko/github-runner:latest"

gh_secrets_name        = "gh-runner-secrets"
lambda_iam_policy_name = "GitHubRunners-permissions"
lambda_name            = "gh-runners"
api_gateway_name       = "gh_runners_api"
security_groups        = "sg-063b3160f0ea41e4f"