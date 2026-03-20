#!/usr/bin/env bash
set -euo pipefail

# push-image.sh
# Build and push Metabase+DuckDB image to ECR from this project folder.
# Usage:
#   ./push-image.sh [image-name] [image-tag] [docker-context-dir] [aws-region]
# Example (from this script directory):
#   ./push-image.sh metabase latest .. us-east-2

IMAGE_NAME=${1:-metabase}
IMAGE_TAG=${2:-latest}
DOCKER_CONTEXT=${3:-..}
REGION=${4:-${AWS_REGION:-us-east-2}}

echo "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG} from context ${DOCKER_CONTEXT}"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" "${DOCKER_CONTEXT}"

echo "Detect AWS account ID"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$ACCOUNT_ID" ]; then
  echo "Failed to detect AWS account ID. Ensure AWS CLI is configured." >&2
  exit 1
fi

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
ECR_REPO="${ECR_REGISTRY}/${IMAGE_NAME}"

echo "Tagging image for ECR: ${ECR_REPO}:${IMAGE_TAG}"
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${ECR_REPO}:${IMAGE_TAG}"

echo "Logging into ECR (${REGION})"
aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "Creating ECR repository (if not exists): ${IMAGE_NAME}"
if ! aws ecr describe-repositories --repository-names "${IMAGE_NAME}" --region "${REGION}" >/dev/null 2>&1; then
  aws ecr create-repository --repository-name "${IMAGE_NAME}" --region "${REGION}" >/dev/null
  echo "Repository created: ${IMAGE_NAME}"
else
  echo "Repository already exists: ${IMAGE_NAME}"
fi

echo "Pushing image to ECR: ${ECR_REPO}:${IMAGE_TAG}"
docker push "${ECR_REPO}:${IMAGE_TAG}"

echo "Image pushed: ${ECR_REPO}:${IMAGE_TAG}"
echo
echo "Use this image URI in Terraform: ${ECR_REPO}:${IMAGE_TAG}"
