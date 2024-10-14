# ecs-gh-runners

## !This is not production ready, it is just for practicing purposes!

It was inspired from https://github.com/philips-labs/terraform-aws-github-runner, but instead of ec2 instances use ECS.

The architecture is pretty simple. There is an API Gateway that is listening for Github events and triggers a Lambda function on workflow_job webhook event that are in status `queued`. And finally the AWS Lambda function starts ECS task, that registers the Github runner. 