#!/usr/bin/env bash
# FinOps clean-up. Reads infra/infra.env written by provision.sh. Safe to re-run (errors are tolerated).
set -uo pipefail
cd "$(dirname "$0")"; source ./infra.env
export AWS_DEFAULT_REGION="$REGION"
run() { echo "+ $*"; "$@" || echo "  (skipped/failed: continue)"; }

run aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" || true

run aws rds delete-db-instance --db-instance-identifier sms-db --skip-final-snapshot --delete-automated-backups
aws rds wait db-instance-deleted --db-instance-identifier sms-db || true
run aws rds delete-db-subnet-group --db-subnet-group-name sms-db-subnets
run aws rds delete-db-parameter-group --db-parameter-group-name sms-pg16

run aws iam remove-role-from-instance-profile --instance-profile-name sms-ec2-profile --role-name sms-ec2-role
run aws iam delete-instance-profile --instance-profile-name sms-ec2-profile
run aws iam detach-role-policy --role-name sms-ec2-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
run aws iam detach-role-policy --role-name sms-ec2-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
run aws iam delete-role-policy --role-name sms-ec2-role --policy-name read-db-secret
run aws iam delete-role --role-name sms-ec2-role

run aws ec2 delete-security-group --group-id "$DB_SG"
run aws ec2 delete-security-group --group-id "$APP_SG"

for RT in "$PUB_RT" "$PRIV_RT"; do
  for ASSOC in $(aws ec2 describe-route-tables --route-table-ids "$RT" --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' --output text); do
    run aws ec2 disassociate-route-table --association-id "$ASSOC"
  done
  run aws ec2 delete-route-table --route-table-id "$RT"
done
run aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
run aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"
for SN in "$PUB_SN" "$DB_SN_A" "$DB_SN_B"; do run aws ec2 delete-subnet --subnet-id "$SN"; done
run aws ec2 delete-vpc --vpc-id "$VPC_ID"

run aws ecr delete-repository --repository-name student-service --force

echo; echo "===== VERIFICATION (screenshot this for the report) ====="
echo "EC2 instances not terminated:"; aws ec2 describe-instances --filters "Name=tag:Project,Values=student-three-tier" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query 'Reservations[].Instances[].InstanceId' --output text
echo "RDS instances:";            aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output text
echo "VPCs tagged for project:";  aws ec2 describe-vpcs --filters "Name=tag:Project,Values=student-three-tier" --query 'Vpcs[].VpcId' --output text
echo "ECR repositories:";         aws ecr describe-repositories --query 'repositories[].repositoryName' --output text 2>/dev/null
echo "Elastic/public IPs still allocated:"; aws ec2 describe-addresses --query 'Addresses[].PublicIp' --output text
echo "(Empty lists above = clean. Also check Billing > Bills the next day.)"
