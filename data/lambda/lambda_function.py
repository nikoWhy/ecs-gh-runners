import json
import os
import boto3
from deps import verify_signature, get_secret, run_ecs_task

region = os.environ['AWS_REGION']

def lambda_handler(event, context):
    event_body = json.loads(event["body"])
    workflow_job_status = event_body["action"]
    workflow_job_id = event_body["workflow_job"]["id"]
    gh_owner, gh_repo = event_body["repository"]["full_name"].split("/") # Not sure if this will work for ORGs
    signature_header = event["headers"]["x-hub-signature-256"]
    
    boto3_session = boto3.session.Session()
    github_runner_name = f'ecs-runner-{workflow_job_id}'
    gh_secrets = get_secret(boto3_session,os.environ["GH_SECRETS_NAME"], region)

    if (
            workflow_job_status == 'queued' and
            verify_signature(event["body"], gh_secrets["GITHUB_SECRET_TOKEN"], signature_header) and
            run_ecs_task(boto3_session, gh_secrets['GITHUB_PAT'], github_runner_name, gh_owner, gh_repo, region)
        ):
        return {
            "statusCode": 201,
            "body": f"Starting Runner with name: {github_runner_name}!"
        }
    else:
        return {
            "statusCode": 200,
            "body": f"Will not start runner, as workflow job status is {workflow_job_status}!"
        }
