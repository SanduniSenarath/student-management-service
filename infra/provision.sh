#!/usr/bin/env bash
# Provisions: VPC, subnets, IGW, route tables, security groups, RDS PostgreSQL, IAM role, EC2.
# Usage: ADMIN_CIDR=203.0.113.10/32 KEY_NAME=sms-key ./provision.sh
set -euo pipefail

REGION="${REGION:-ap-south-1}"
ADMIN_CIDR="${ADMIN_CIDR:?Set ADMIN_CIDR to your public IP, e.g. 203.0.113.10/32}"
KEY_NAME="${KEY_NAME:?Set KEY_NAME to an existing EC2 key pair name}"
AZ_A="${REGION}a"; AZ_B="${REGION}b"
export AWS_DEFAULT_REGION="$REGION"
TAGS="Key=Project,Value=student-three-tier"

name() { aws ec2 create-tags --resources "$1" --tags "Key=Name,Value=$2" "$TAGS"; }

echo "==> VPC"
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query Vpc.VpcId --output text)
name "$VPC_ID" sms-vpc
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support '{"Value":true}'
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'

echo "==> Subnets"
PUB_SN=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 --availability-zone "$AZ_A" --query Subnet.SubnetId --output text)
DB_SN_A=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.2.0/24 --availability-zone "$AZ_A" --query Subnet.SubnetId --output text)
DB_SN_B=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.3.0/24 --availability-zone "$AZ_B" --query Subnet.SubnetId --output text)
name "$PUB_SN" sms-public-a; name "$DB_SN_A" sms-private-db-a; name "$DB_SN_B" sms-private-db-b
aws ec2 modify-subnet-attribute --subnet-id "$PUB_SN" --map-public-ip-on-launch

echo "==> Internet gateway + public route table"
IGW_ID=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
name "$IGW_ID" sms-igw
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
PUB_RT=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query RouteTable.RouteTableId --output text)
name "$PUB_RT" sms-public-rt
aws ec2 create-route --route-table-id "$PUB_RT" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null
aws ec2 associate-route-table --route-table-id "$PUB_RT" --subnet-id "$PUB_SN" >/dev/null

echo "==> Private route table (local route only, no IGW)"
PRIV_RT=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query RouteTable.RouteTableId --output text)
name "$PRIV_RT" sms-private-rt
aws ec2 associate-route-table --route-table-id "$PRIV_RT" --subnet-id "$DB_SN_A" >/dev/null
aws ec2 associate-route-table --route-table-id "$PRIV_RT" --subnet-id "$DB_SN_B" >/dev/null

echo "==> Security groups"
APP_SG=$(aws ec2 create-security-group --group-name App-SG --description "Application tier" --vpc-id "$VPC_ID" --query GroupId --output text)
DB_SG=$(aws ec2 create-security-group --group-name DB-SG --description "Database tier" --vpc-id "$VPC_ID" --query GroupId --output text)
name "$APP_SG" App-SG; name "$DB_SG" DB-SG
aws ec2 authorize-security-group-ingress --group-id "$APP_SG" --protocol tcp --port 22   --cidr "$ADMIN_CIDR" >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$APP_SG" --protocol tcp --port 8080 --cidr 0.0.0.0/0     >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$DB_SG"  --protocol tcp --port 5432 --source-group "$APP_SG" >/dev/null

echo "==> RDS subnet group, parameter group (force SSL), instance"
aws rds create-db-subnet-group --db-subnet-group-name sms-db-subnets \
  --db-subnet-group-description "Private DB subnets across two AZs" \
  --subnet-ids "$DB_SN_A" "$DB_SN_B" --tags "$TAGS" >/dev/null
aws rds create-db-parameter-group --db-parameter-group-name sms-pg16 \
  --db-parameter-group-family postgres16 --description "Force SSL" >/dev/null
aws rds modify-db-parameter-group --db-parameter-group-name sms-pg16 \
  --parameters "ParameterName=rds.force_ssl,ParameterValue=1,ApplyMethod=immediate" >/dev/null

# Master password is generated and stored in AWS Secrets Manager (never appears in this script).
aws rds create-db-instance \
  --db-instance-identifier sms-db \
  --engine postgres --engine-version 16 \
  --db-instance-class db.t4g.micro \
  --allocated-storage 20 --storage-type gp2 --storage-encrypted \
  --db-name students \
  --master-username dbadmin --manage-master-user-password \
  --db-subnet-group-name sms-db-subnets \
  --vpc-security-group-ids "$DB_SG" \
  --db-parameter-group-name sms-pg16 \
  --availability-zone "$AZ_A" --no-multi-az \
  --no-publicly-accessible \
  --backup-retention-period 1 \
  --copy-tags-to-snapshot --tags "$TAGS" >/dev/null
echo "    waiting for RDS (about 5-10 minutes)..."
aws rds wait db-instance-available --db-instance-identifier sms-db
DB_HOST=$(aws rds describe-db-instances --db-instance-identifier sms-db --query 'DBInstances[0].Endpoint.Address' --output text)
DB_SECRET_ARN=$(aws rds describe-db-instances --db-instance-identifier sms-db --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)

echo "==> IAM role / instance profile for EC2 (ECR pull + read DB secret + SSM)"
cat > /tmp/ec2-trust.json <<JSON
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}
JSON
aws iam create-role --role-name sms-ec2-role --assume-role-policy-document file:///tmp/ec2-trust.json >/dev/null
aws iam attach-role-policy --role-name sms-ec2-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam attach-role-policy --role-name sms-ec2-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
cat > /tmp/ec2-secret.json <<JSON
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"secretsmanager:GetSecretValue","Resource":"$DB_SECRET_ARN"}]}
JSON
aws iam put-role-policy --role-name sms-ec2-role --policy-name read-db-secret --policy-document file:///tmp/ec2-secret.json
aws iam create-instance-profile --instance-profile-name sms-ec2-profile >/dev/null
aws iam add-role-to-instance-profile --instance-profile-name sms-ec2-profile --role-name sms-ec2-role
sleep 15   # IAM eventual consistency

echo "==> EC2 instance in public subnet"
AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
cat > /tmp/user-data.sh <<'UD'
#!/bin/bash
set -eux
dnf install -y docker jq
systemctl enable --now docker
usermod -aG docker ec2-user
UD
INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type t3.micro --key-name "$KEY_NAME" \
  --subnet-id "$PUB_SN" --security-group-ids "$APP_SG" --associate-public-ip-address \
  --iam-instance-profile Name=sms-ec2-profile \
  --metadata-options HttpTokens=required,HttpEndpoint=enabled \
  --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=8,VolumeType=gp3,Encrypted=true}' \
  --user-data file:///tmp/user-data.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=sms-app},$TAGS]" \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

cat > "$(dirname "$0")/infra.env" <<ENV
REGION=$REGION
VPC_ID=$VPC_ID
PUB_SN=$PUB_SN
DB_SN_A=$DB_SN_A
DB_SN_B=$DB_SN_B
IGW_ID=$IGW_ID
PUB_RT=$PUB_RT
PRIV_RT=$PRIV_RT
APP_SG=$APP_SG
DB_SG=$DB_SG
INSTANCE_ID=$INSTANCE_ID
PUBLIC_IP=$PUBLIC_IP
DB_HOST=$DB_HOST
DB_SECRET_ARN=$DB_SECRET_ARN
ENV
echo "==> Done. Values saved to infra/infra.env"; cat "$(dirname "$0")/infra.env"
