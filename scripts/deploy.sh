#!/usr/bin/env bash
# Despliega (o actualiza) el stack. ESTO PUEDE GENERAR COBROS por hora.
#
#   ./scripts/deploy.sh --preview   -> crea solo el change set, NO ejecuta nada (gratis)
#   ./scripts/deploy.sh             -> despliega de verdad (pide confirmacion)
#
# Variables opcionales:
#   IMAGE_TAG    tag de la imagen en ECR (por defecto: SHA del commit actual)
#   APP_VERSION  version que expone GET /version   (por defecto: 1.0.0)
#   DEPLOY_COLOR blue | green                      (por defecto: blue)
set -euo pipefail
export AWS_PAGER=""

STACK_NAME="${STACK_NAME:-ecs-fargate-bluegreen}"
REGION="${AWS_REGION:-us-east-1}"
REPO="ecs-fargate-bluegreen"
APP_VERSION="${APP_VERSION:-1.0.0}"
DEPLOY_COLOR="${DEPLOY_COLOR:-blue}"
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse HEAD)}"
PREVIEW=0
[ "${1:-}" = "--preview" ] && PREVIEW=1

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

# La imagen tiene que existir ya en ECR (la sube GitHub Actions).
if ! aws ecr describe-images --repository-name "$REPO" --region "$REGION" \
      --image-ids imageTag="$IMAGE_TAG" >/dev/null 2>&1; then
  echo "No encuentro la imagen con tag $IMAGE_TAG en ECR."
  echo "Revisa que el workflow de GitHub Actions haya terminado en verde, o usa IMAGE_TAG=<sha>."
  exit 1
fi
IMAGE_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO:$IMAGE_TAG"

# VPC por defecto y dos de sus subnets (una por AZ).
VPC_ID="$(aws ec2 describe-vpcs --region "$REGION" \
  --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)"
SUBNETS="$(aws ec2 describe-subnets --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=default-for-az,Values=true \
  --query 'Subnets[0:2].SubnetId' --output text)"
SUBNET1="$(echo "$SUBNETS" | awk '{print $1}')"
SUBNET2="$(echo "$SUBNETS" | awk '{print $2}')"
if [ "$VPC_ID" = "None" ] || [ -z "$SUBNET1" ] || [ -z "$SUBNET2" ]; then
  echo "No pude encontrar la VPC por defecto con dos subnets."
  exit 1
fi

echo "Stack:   $STACK_NAME ($REGION)"
echo "Imagen:  $IMAGE_URI"
echo "VPC:     $VPC_ID  Subnets: $SUBNET1 $SUBNET2"
echo "Version: $APP_VERSION ($DEPLOY_COLOR)"
echo

EXTRA=()
if [ "$PREVIEW" -eq 1 ]; then
  EXTRA=(--no-execute-changeset)
  echo "Modo PREVIEW: solo se crea el change set. No se crea ningun recurso."
else
  echo "AVISO DE COSTO: el ALB, las tareas Fargate y las IPs publicas cobran POR HORA"
  echo "mientras el stack exista (del orden de centavos de dolar por hora)."
  echo "Cuando termines, ejecuta ./scripts/teardown.sh"
  echo
  read -r -p "Escribe SI para desplegar: " ANSWER
  [ "$ANSWER" = "SI" ] || { echo "Cancelado. No se creo nada."; exit 1; }
fi

aws cloudformation deploy \
  --region "$REGION" \
  --stack-name "$STACK_NAME" \
  --template-file infra/template.yaml \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides \
      Vpc="$VPC_ID" Subnet1="$SUBNET1" Subnet2="$SUBNET2" \
      ImageUri="$IMAGE_URI" AppVersion="$APP_VERSION" DeployColor="$DEPLOY_COLOR" \
  ${EXTRA[@]+"${EXTRA[@]}"}

if [ "$PREVIEW" -eq 0 ]; then
  echo
  aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'Stacks[0].Outputs' --output table
  echo "Recuerda: ./scripts/teardown.sh al terminar."
fi
