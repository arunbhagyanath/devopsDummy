#!/bin/bash

# Default variables
AWS_REGION="ap-south-1"
LOGIN_USER="ubuntu"
KEY_NAME="MyKeyPair"
TAG_NAME="dummy"
GIT_PROJECT="devopsDummy"
GIT_REVISION="HEAD"
GIT_URL="https://github.com/arunbhagyanath/devopsDummy.git"
TMP_DIR="/tmp/deploy_$$"
APP_NAME="dumbapp"
APP_USER="appuser"


echo "Starting deployment"
echo "Preparing deployment package"
mkdir $TMP_DIR
cd $TMP_DIR
git clone $GIT_URL
cd $GIT_PROJECT
if [ $GIT_REVISION != "HEAD" ]; then
	git checkout $GIT_REVISION
fi
tar -czf $TMP_DIR/${GIT_PROJECT}_${GIT_REVISION}.tar.gz app configuration
# Getting instance IPs
_instance_ips=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$TAG_NAME" "Name=instance-state-name,Values=running" | jq '.Reservations[].Instances[].PublicIpAddress' | sed 's/"//g' | tr '\n' ' ')
for _instance_ip in $_instance_ips; do
	ssh -i $HOME/${KEY_NAME}.pem -o StrictHostKeyChecking=no $LOGIN_USER@$_instance_ip "sudo service nginx stop; sudo service uwsgi stop; mkdir $TMP_DIR"
	scp -i $HOME/${KEY_NAME}.pem -o StrictHostKeyChecking=no $TMP_DIR/${GIT_PROJECT}_${GIT_REVISION}.tar.gz $LOGIN_USER@$_instance_ip:$TMP_DIR
	ssh -i $HOME/${KEY_NAME}.pem -o StrictHostKeyChecking=no $LOGIN_USER@$_instance_ip "cd $TMP_DIR && tar xzf ${GIT_PROJECT}_${GIT_REVISION}.tar.gz && sudo cp -af app/$APP_NAME /opt/apphome/ && sudo cp -af configuration/etc/* /etc/ && sudo -H -u $APP_USER bash -c \"pip install -r /opt/apphome/$APP_NAME/requirements.txt\" && sudo ln -f -s /etc/nginx/sites-available/dumbapp /etc/nginx/sites-enabled/ && sudo service nginx start; sudo service uwsgi start && rm -rf $TMP_DIR"
done
rm -rf $TMP_DIR
echo "Application deployment sucessfull"

