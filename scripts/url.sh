#!/usr/bin/env bash
# Imprime la URL publica del ALB del stack (la plantilla no puede declarar Outputs).
set -euo pipefail
export AWS_PAGER=""

STACK_NAME="${STACK_NAME:-ecs-fargate-bluegreen}"
REGION="${AWS_REGION:-us-east-1}"

ALB_ARN="$(aws cloudformation describe-stack-resources \
  --stack-name "$STACK_NAME" --region "$REGION" \
  --logical-resource-id LoadBalancer \
  --query 'StackResources[0].PhysicalResourceId' --output text)"

ALB_DNS="$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" --region "$REGION" \
  --query 'LoadBalancers[0].DNSName' --output text)"

echo "URL de la API: http://$ALB_DNS"
