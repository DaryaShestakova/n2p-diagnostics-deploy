# syntax=docker/dockerfile:experimental
FROM python:3.7 as base

RUN apt-get update && apt-get install -y git

COPY .ci/requirements.txt /tmp/

RUN pip install -r /tmp/requirements.txt

WORKDIR /app

COPY . /app

FROM base as ci

RUN .ci/syntax_check.py

RUN \
    --mount=type=secret,id=jfrog-credentials \
    --mount=type=secret,id=redis-credentials \
    while read line; do export $line; done < /run/secrets/jfrog-credentials && \
    while read line; do export $line; done < /run/secrets/redis-credentials && \
    .ci/requirements_check.py $ARTIFACTORY_PASSWORD $REDIS_HOST $REDIS_PORT $REDIS_PWD

RUN \
    --mount=type=secret,id=jfrog-credentials \
    while read line; do export $line; done < /run/secrets/jfrog-credentials && \
    git diff --name-only --diff-filter=d master | xargs -I {} .ci/persistence_check.py $ARTIFACTORY_PASSWORD {}

FROM base as report_success

ARG IMAGE
ARG TAG
ARG ENV

RUN \
    --mount=type=secret,id=redis-credentials \
    while read line; do export $line; done < /run/secrets/redis-credentials && \
    .ci/report_success.py $REDIS_HOST $REDIS_PORT $REDIS_PWD $IMAGE $TAG $ENV
