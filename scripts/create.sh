#!/bin/bash

# Default variables
AWS_REGION="ap-south-1"
AMI_ID="ami-c2ee9dad"
LOGIN_USER=""
KEY_NAME="MyKeyPair"
SG_NAME="MySecurityGroup"
TAG_NAME="dummy"

AWS_CLI_REQUIRED_VERSION="1.11.25"

# Check if required parameter not specified.
if [ $# -lt 2 ] ; then
	echo "Required arguments not specified"
	echo "Usage: $0 num_servers server_size"
	exit 1
else
	_instance_count=$1
	_instance_type=$2
fi

# Check if required packages are installed
echo "Checking required packages..."
if ! which aws > /dev/null; then
	echo "AWS CLI is not installed"
	exit 1
else
	# For creating tag with run-instance api
	_aws_installed_verion=$(aws --version 2>&1 | cut -d'/' -f2 | cut -d' ' -f1)
	if [ $AWS_CLI_REQUIRED_VERSION != "`echo -e \"$AWS_CLI_REQUIRED_VERSION\n$_aws_installed_verion\" | sort -V | head -n1`" ]; then
		echo "AWS Cli verion $AWS_CLI_REQUIRED_VERSION or higher is required"
		exit 1
	fi
fi

if ! which jq > /dev/null; then
	echo "jq is not installed"
	exit 1	
fi

# Check status of last command
function check_status {
	_status=$1
	_msg="$2"
	if [ $_status -ne 0 ]; then
		echo "$_msg, exit code $_status"
		exit 1
	fi
}

# Create key pair
echo "Creating key pair..."
aws ec2 describe-key-pairs --key-name $KEY_NAME  --region $AWS_REGION --output json > /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo  "$KEY_NAME already exists"
	exit 1
fi
echo -e `aws ec2 create-key-pair --key-name $KEY_NAME --region $AWS_REGION --output json | jq '.KeyMaterial' | sed 's/\"//g'` > $HOME/${KEY_NAME}.pem
check_status $? "Key pair creation failed"
chmod 600 $HOME/${KEY_NAME}.pem
check_status $? "Changing permission of pem file failed"

# Create SG
echo "Creating SG..."
aws ec2 describe-security-groups --group-name $SG_NAME --region $AWS_REGION --output json > /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo  "$SG_NAME already exists"
	exit 1
fi
_sg_id=$(aws ec2 create-security-group --group-name $SG_NAME --description "$SG_NAME" --region $AWS_REGION --output json | jq '.GroupId' | sed 's/"//g')
check_status $? "SG creation failed"
aws ec2 authorize-security-group-ingress --group-id $_sg_id --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $AWS_REGION --output json
check_status $? "Whitelisting SSH port failed"
aws ec2 authorize-security-group-ingress --group-id $_sg_id --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $AWS_REGION --output json
check_status $? "Whitelisting HTTP port failed"


# Create instance
echo "Creating $_instance_count instance(s) with $_instance_type..."
_subnet_id=$(aws ec2 describe-subnets --region $AWS_REGION --output json| jq '.Subnets[1].SubnetId' | sed 's/"//g')
check_status $? "Getting subnet-id failed"
_instance_ids=$(aws ec2 run-instances --image-id $AMI_ID --count $_instance_count --instance-type $_instance_type --key-name $KEY_NAME --subnet-id $_subnet_id --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" --associate-public-ip-address --security-group-ids $_sg_id  --user-data file://userdata.sh --region $AWS_REGION --output json | jq '.Instances[].InstanceId' | sed 's/"//g' | tr '\n' ' ')
check_status $? "Instance creation failed"
echo "Waiting for instance to get up..."
aws ec2 wait instance-running --instance-ids $_instance_ids --region $AWS_REGION --output json
echo "Configuring basic packages..."
sleep 180 

# Deployement
bash deploy.sh

echo "Server(s) are ready. IP address(es)"
aws ec2 describe-instances --filters "Name=tag:Name,Values=$TAG_NAME" "Name=instance-state-name,Values=running"  --region $AWS_REGION --output json | jq '.Reservations[].Instances[].PublicIpAddress' | sed 's/"//g'