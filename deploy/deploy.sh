#!/usr/bin/env bash
# Run ON the EC2 instance. Pulls the SHA-tagged image from ECR and (re)starts the container.
# Usage: AWS_REGION=ap-south-1 ECR_REGISTRY=<acct>.dkr.ecr.ap-south-1.amazonaws.com \
#        IMAGE_TAG=<git-sha> DB_HOST=<rds-endpoint> DB_SECRET_ARN=<arn> ./deploy.sh
set -euo pipefail
: "${AWS_REGION:?}" "${ECR_REGISTRY:?}" "${IMAGE_TAG:?}" "${DB_HOST:?}" "${DB_SECRET_ARN:?}"
REPO=student-service
IMAGE="$ECR_REGISTRY/$REPO:$IMAGE_TAG"

SECRET=$(aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$DB_SECRET_ARN" --query SecretString --output text)
ENV_FILE=$(mktemp); chmod 600 "$ENV_FILE"; trap 'rm -f "$ENV_FILE"' EXIT
{
  echo "DB_HOST=$DB_HOST"
  echo "DB_NAME=students"
  echo "DB_USER=$(jq -r .username <<<"$SECRET")"
  echo "DB_PASSWORD=$(jq -r .password <<<"$SECRET")"
} > "$ENV_FILE"

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
docker pull "$IMAGE"
docker rm -f student-service 2>/dev/null || true
docker run -d --name student-service --restart unless-stopped \
  -p 8080:8080 --env-file "$ENV_FILE" \
  --read-only --tmpfs /tmp \
  --cap-drop ALL --security-opt no-new-privileges \
  --memory 512m --pids-limit 200 \
  "$IMAGE"
sleep 5; docker ps --filter name=student-service
