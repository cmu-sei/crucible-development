#!/usr/bin/env bash

# start clean
rm -f /home/vscode/.aws/cli/cache/*
# login
aws sso login --sso-session crucible-sso
# create a file with the aws credentials needed for moodle or other docker-in-docker containers
aws configure export-credentials --profile default > /home/vscode/.aws/sso-credentials
