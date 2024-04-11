import json
import os
import hashlib
import hmac
import urllib3
from botocore.exceptions import ClientError


def verify_signature(payload_body, secret_token, signature_header):
    """Verify that the payload was sent from GitHub by validating SHA256.
    
    Raise error if signaures doesn't match.
    
    Args:
        payload_body: original request body to verify (request.body())
        secret_token: GitHub app webhook token (WEBHOOK_SECRET)
        signature_header: header received from GitHub (x-hub-signature-256)
    """
    hash_object = hmac.new(secret_token.encode('utf-8'), msg=payload_body.encode('utf-8'), digestmod=hashlib.sha256)
    expected_signature = "sha256=" + hash_object.hexdigest()
    if not hmac.compare_digest(expected_signature, signature_header):
        raise AssertionError("GitHub request signatures didn't match!")

    return True


def get_registration_token(github_owner, github_repo, github_pat):
    """Makes a POST request to GitHub runners/registration-token endpoint to get registration token.

    Raise error if it doesn't get 201 status code from GH

    Args:
        github_owner: Owner of the GitHub repo
        github_repo: Name of the GitHub repo
        github_pat: GitHub Personal Access Token
    """
    github_url = f'https://api.github.com/repos/{github_owner}/{github_repo}/actions/runners/registration-token'
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": "Bearer " + github_pat,
        "X-GitHub-Api-Version": "2022-11-28"
    }
    
    http = urllib3.PoolManager()
    
    resp = http.request(
        "POST",
        github_url,
        headers=headers
    )
    
    parsed_resp = json.loads(resp.data)
    
    if not resp.status == 201:
        raise ConnectionError(f'status_code={resp.status}, detail={parsed_resp}')
    
    return parsed_resp['token']


def get_secret(boto3_session, secret_name, region="eu-central-1"):
    """Get the value of an AWS Secret.

    Raise boto ClientError

    Args:
        boto3_sessions: Boto3 session that stores configuration state
        secret_name: Name of the AWS Secret
        region: AWS region
    """

    client = boto3_session.client(
        service_name="secretsmanager",
        region_name=region
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        raise e

    return json.loads(get_secret_value_response["SecretString"])


def run_ecs_task(boto3_session, github_pat, github_runner_name, github_owner, github_repo, region="eu-central-1"):
    """Starts a new ECS task using the specified task definition.

    Raise boto ClientError

    Args:
        boto3_sessions: Boto3 session that stores configuration state
        github_pat: GitHub Personal Access Token
        github_runner_name: The name of the GitHub Runner, that will be shown in GitHub
        github_owner: Owner of the GitHub repo
        github_repo: Name of the GitHub repo
        region: AWS region
    """

    github_reg_token = get_registration_token(github_owner, github_repo, github_pat)
    client = boto3_session.client(
        service_name="ecs",
        region_name=region
    )
    try:
        response = client.run_task(
            taskDefinition=os.environ["ECS_TASK_DEFINITION"],
            launchType="FARGATE",
            cluster=os.environ["ECS_CLUSTER_NAME"],
            platformVersion="LATEST",
            count=1,
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': os.environ["SUBNETS"].split(","),
                    'assignPublicIp': 'ENABLED',
                    'securityGroups': os.environ["SECURITY_GROUPS"].split(",")
                }
            },
            overrides={
                'containerOverrides': [
                    {
                        'name': 'runner',
                        'environment': [
                            {
                                'name': 'GITHUB_REGISTRATION_TOKEN',
                                'value': github_reg_token
                            },
                            {
                                'name': 'GITHUB_RUNNER_NAME',
                                'value': github_runner_name
                            },
                            {
                                'name': 'GITHUB_REPO',
                                'value': github_repo
                            },
                            {
                                'name': 'GITHUB_OWNER',
                                'value': github_owner
                            }
                        ]
                    }
                ]
            }
        )
    except ClientError as e:
        raise e

    # TODO: implement proper logging
    print(f"{response['tasks'][0]['createdAt']} ECS tasks has been started on Cluster: {response['tasks'][0]['clusterArn']}")

    return True