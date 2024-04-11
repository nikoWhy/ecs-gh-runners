FROM ubuntu:22.04

ARG GH_RUNNER_VERSION

# TODO: Use regular user and not root
ENV RUNNER_ALLOW_RUNASROOT=1
ENV GH_RUNNER_VERSION=${GH_RUNNER_VERSION:-2.315.0}

WORKDIR /actions-runner

RUN apt-get update \
    && apt-get -qq -y install --no-install-recommends \
    curl \
    git \
    ca-certificates \
    gnupg \
    build-essential \
    wget \
    file \
    jq \
    unzip \
    && curl -OL https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
    && bash ./bin/installdependencies.sh \
    && rm ./actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
    && apt-get autoremove -y \
    && apt-get autoclean -y \ 
    && rm -rf /var/lib/apt/lists

COPY ./entrypoint.sh .

ENTRYPOINT ["./entrypoint.sh"]