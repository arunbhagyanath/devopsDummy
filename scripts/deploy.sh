#!/bin/bash

# Default variables
DEFAULT_AWS_REGION="ap-south-1"
DEFAULT_LOGIN_USER="ubuntu"
DEFAULT_KEY_NAME="MyKeyPair"
DEFAULT_TAG_NAME="dummy"

DEFAULT_GIT_URL="https://github.com/arunbhagyanath/devopsDummy.git"
DEFAULT_TMP_DIR="/tmp/deploy_$$"

echo "Starting deployment"
# Getting instance IPs
_instance_ips=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$DEFAULT_TAG_NAME" "Name=instance-state-name,Values=running" | jq '.Reservations[].Instances[].PublicIpAddress' | sed 's/"//g' | tr '\n' ' ')