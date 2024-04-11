#!/bin/bash
set -ex

./config.sh \
    --url "https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}" \
    --token "$GITHUB_REGISTRATION_TOKEN" \
    --name "$GITHUB_RUNNER_NAME" \
    --disableupdate \
    --unattended \
    --ephemeral

./run.sh