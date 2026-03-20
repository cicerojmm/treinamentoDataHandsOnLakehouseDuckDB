#!/bin/bash

set -e

# Configuration
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}
AWS_REGION=${AWS_REGION:-us-east-2}
ECR_REPOSITORY_NAME=${ECR_REPOSITORY_NAME:-pgduckdb}
IMAGE_TAG=${IMAGE_TAG:-latest}

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPOSITORY_URI="${ECR_REGISTRY}/${ECR_REPOSITORY_NAME}"

echo "Building and pushing pgDuckDB Docker image..."
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "ECR Repository: $ECR_REPOSITORY_URI"
echo "Image Tag: $IMAGE_TAG"

# Create ECR repository if it doesn't exist
echo "Checking/Creating ECR repository..."
aws ecr describe-repositories --repository-names $ECR_REPOSITORY_NAME --region $AWS_REGION > /dev/null 2>&1 || \
  aws ecr create-repository --repository-name $ECR_REPOSITORY_NAME --region $AWS_REGION

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build Docker image
echo "Building Docker image..."
docker build -t ${ECR_REPOSITORY_URI}:${IMAGE_TAG} .
docker tag ${ECR_REPOSITORY_URI}:${IMAGE_TAG} ${ECR_REPOSITORY_URI}:latest

# Push Docker image
echo "Pushing Docker image to ECR..."
docker push ${ECR_REPOSITORY_URI}:${IMAGE_TAG}
docker push ${ECR_REPOSITORY_URI}:latest

echo "Successfully pushed image: ${ECR_REPOSITORY_URI}:${IMAGE_TAG}"
