#!/usr/bin/env bash
# Zero-spend style budget: emails you as soon as actual cost exceeds $0.01. Budgets API lives in us-east-1.
# Usage: ALERT_EMAIL=you@example.com ./billing-alert.sh
set -euo pipefail
ALERT_EMAIL="${ALERT_EMAIL:?Set ALERT_EMAIL}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws budgets create-budget --region us-east-1 --account-id "$ACCOUNT_ID" \
  --budget '{"BudgetName":"zero-spend-lab","BudgetLimit":{"Amount":"1","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST"}' \
  --notifications-with-subscribers "[{\"Notification\":{\"NotificationType\":\"ACTUAL\",\"ComparisonOperator\":\"GREATER_THAN\",\"Threshold\":0.01,\"ThresholdType\":\"ABSOLUTE_VALUE\"},\"Subscribers\":[{\"SubscriptionType\":\"EMAIL\",\"Address\":\"$ALERT_EMAIL\"}]}]"
echo "Budget created. Confirm the subscription email if AWS sends one."
