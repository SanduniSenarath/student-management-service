#!/usr/bin/env bash
# One-time setup: ECR repository + GitHub OIDC provider + least-privilege push role.
# Usage: GITHUB_REPO=my-org/my-repo ./ci-bootstrap.sh
set -euo pipefail
REGION="${REGION:-ap-south-1}"
GITHUB_REPO="${GITHUB_REPO:?Set GITHUB_REPO as owner/repo}"
REPO_NAME=student-service
export AWS_DEFAULT_REGION="$REGION"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws ecr create-repository --repository-name "$REPO_NAME" \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 >/dev/null

# Skip this call if the provider already exists in the account
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com --client-id-list sts.amazonaws.com >/dev/null || true

cat > /tmp/gh-trust.json <<JSON
{"Version":"2012-10-17","Statement":[{
  "Effect":"Allow",
  "Principal":{"Federated":"arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"},
  "Action":"sts:AssumeRoleWithWebIdentity",
  "Condition":{
    "StringEquals":{"token.actions.githubusercontent.com:aud":"sts.amazonaws.com"},
    "StringLike":{"token.actions.githubusercontent.com:sub":"repo:${GITHUB_REPO}:ref:refs/heads/main"}}}]}
JSON
aws iam create-role --role-name github-sms-ecr-push --assume-role-policy-document file:///tmp/gh-trust.json >/dev/null

cat > /tmp/gh-ecr.json <<JSON
{"Version":"2012-10-17","Statement":[
 {"Effect":"Allow","Action":"ecr:GetAuthorizationToken","Resource":"*"},
 {"Effect":"Allow","Action":["ecr:BatchCheckLayerAvailability","ecr:InitiateLayerUpload","ecr:UploadLayerPart","ecr:CompleteLayerUpload","ecr:PutImage","ecr:BatchGetImage"],
  "Resource":"arn:aws:ecr:${REGION}:${ACCOUNT_ID}:repository/${REPO_NAME}"}]}
JSON
aws iam put-role-policy --role-name github-sms-ecr-push --policy-name ecr-push --policy-document file:///tmp/gh-ecr.json

echo "ECR registry : ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
echo "Role ARN     : arn:aws:iam::${ACCOUNT_ID}:role/github-sms-ecr-push   <- save as GitHub secret AWS_ROLE_ARN"
