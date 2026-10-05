#!/usr/bin/env bash
# Revisa si queda algo encendido que cobre por hora. No modifica nada.
# Uso:  ./scripts/check-costs.sh
set -uo pipefail
export AWS_PAGER=""

STACK_NAME="${STACK_NAME:-ecs-fargate-bluegreen}"
REGION="${AWS_REGION:-us-east-1}"
FOUND=0

report() {  # $1 = etiqueta, $2 = salida del comando
  if [ -n "$2" ] && [ "$2" != "None" ]; then
    echo "ATENCION - $1:"
    echo "$2" | tr '\t' '\n' | sed 's/^/     /'
    FOUND=1
  else
    echo "OK       - $1: ninguno"
  fi
}

report "Load balancers (ALB/NLB)" \
  "$(aws elbv2 describe-load-balancers --region "$REGION" \
      --query 'LoadBalancers[].LoadBalancerName' --output text 2>&1)"

CLUSTERS="$(aws ecs list-clusters --region "$REGION" \
      --query 'clusterArns[]' --output text 2>&1)"

TASKS=""
for c in $CLUSTERS; do
  t="$(aws ecs list-tasks --cluster "$c" --region "$REGION" \
        --query 'taskArns[]' --output text 2>&1)"
  if [ -n "$t" ] && [ "$t" != "None" ]; then
    TASKS="$TASKS $t"
  fi
done
report "Tareas Fargate en ejecucion" "$TASKS"

report "NAT gateways activos" \
  "$(aws ec2 describe-nat-gateways --region "$REGION" \
      --filter Name=state,Values=pending,available \
      --query 'NatGateways[].NatGatewayId' --output text 2>&1)"

report "Elastic IPs (cobran si no se usan)" \
  "$(aws ec2 describe-addresses --region "$REGION" \
      --query 'Addresses[].PublicIp' --output text 2>&1)"

report "Stack '$STACK_NAME'" \
  "$(aws cloudformation list-stacks --region "$REGION" \
      --stack-status-filter CREATE_IN_PROGRESS CREATE_COMPLETE ROLLBACK_COMPLETE \
        UPDATE_IN_PROGRESS UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE DELETE_FAILED \
      --query "StackSummaries[?StackName=='$STACK_NAME'].StackName" --output text 2>&1)"

echo
if [ "$FOUND" -eq 0 ]; then
  echo "Todo limpio: no hay nada facturable encendido."
else
  echo "Hay recursos listados arriba. (Un cluster ECS vacio no cobra.)"
  exit 1
fi
