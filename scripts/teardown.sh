#!/usr/bin/env bash
# Elimina TODO lo que cobra por hora (ALB, tareas Fargate, etc.) borrando el stack.
# Uso:  ./scripts/teardown.sh
set -euo pipefail
export AWS_PAGER=""

STACK_NAME="${STACK_NAME:-ecs-fargate-bluegreen}"
REGION="${AWS_REGION:-us-east-1}"

echo "Eliminando el stack '$STACK_NAME' en $REGION ..."
aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
echo "Stack eliminado."
echo

"$(dirname "$0")/check-costs.sh"
