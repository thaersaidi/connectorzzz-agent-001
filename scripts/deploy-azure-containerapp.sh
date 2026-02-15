#!/usr/bin/env bash
# Azure Container App Deployment Script
# Builds and deploys OpenClaw to Azure Container Apps with Azure AI Foundry
#
# This script:
# 1. Builds the Docker image with Azure AI support
# 2. Pushes to Azure Container Registry
# 3. Updates the Container App with --bind lan for external access
# 4. Configures OPENCLAW_GATEWAY_TOKEN for authentication
#
# Prerequisites:
# - Docker installed and running
# - Azure CLI (az) installed and logged in
# - .env.azure file with required configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables from .env.azure
if [[ -f "$ROOT_DIR/.env.azure" ]]; then
  echo "Loading configuration from .env.azure..."
  source "$ROOT_DIR/.env.azure"
else
  echo "Error: .env.azure file not found"
  echo "Please create .env.azure file with your Azure configuration"
  exit 1
fi

# Validate required variables
REQUIRED_VARS=(
  "AZURE_AI_ENDPOINT"
  "AZURE_AI_API_KEY"
  "AZURE_AI_DEPLOYMENT"
  "ACR_NAME"
  "ACR_LOGIN_SERVER"
  "ACR_PASSWORD"
  "CONTAINER_APP_NAME"
  "CONTAINER_APP_ENV"
  "AZURE_RESOURCE_GROUP"
)

for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR:-}" ]]; then
    echo "Error: $VAR is not set in .env.azure"
    exit 1
  fi
done

IMAGE_NAME="openclaw"
IMAGE_TAG="${IMAGE_TAG:-$(date +%Y%m%d-%H%M%S)}"
FULL_IMAGE_NAME="$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"
LATEST_IMAGE_NAME="$ACR_LOGIN_SERVER/$IMAGE_NAME:latest"

echo "================================"
echo "Azure Container App Deployment"
echo "================================"
echo "Image: $FULL_IMAGE_NAME"
echo "Container App: $CONTAINER_APP_NAME"
echo "Environment: $CONTAINER_APP_ENV"
echo "Azure AI Endpoint: $AZURE_AI_ENDPOINT"
echo "Azure AI Deployment: $AZURE_AI_DEPLOYMENT"
echo "================================"
echo ""

# Step 1: Login to ACR
echo "Step 1: Logging into Azure Container Registry..."
echo "$ACR_PASSWORD" | docker login "$ACR_LOGIN_SERVER" -u "$ACR_NAME" --password-stdin

# Step 2: Build Docker image
echo ""
echo "Step 2: Building Docker image..."
docker build \
  -t "$FULL_IMAGE_NAME" \
  -t "$LATEST_IMAGE_NAME" \
  -f "$ROOT_DIR/Dockerfile" \
  "$ROOT_DIR"

# Step 3: Push to ACR
echo ""
echo "Step 3: Pushing image to Azure Container Registry..."
docker push "$FULL_IMAGE_NAME"
docker push "$LATEST_IMAGE_NAME"

# Step 4: Generate Gateway Token (if not set)
echo ""
echo "Step 4: Generating Gateway Token..."
if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  # Generate a secure random token
  OPENCLAW_GATEWAY_TOKEN=$(openssl rand -base64 32 | tr -d '/+=' | head -c 43)
  echo "Generated new gateway token: ${OPENCLAW_GATEWAY_TOKEN:0:10}..."
  echo ""
  echo "⚠️  IMPORTANT: Save this token to .env.azure for future deployments:"
  echo "OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN"
else
  echo "Using existing OPENCLAW_GATEWAY_TOKEN from .env.azure"
fi

# Step 5: Update Container App
echo ""
echo "Step 5: Updating Azure Container App..."

# Check if az CLI is installed
if ! command -v az &> /dev/null; then
  echo "Warning: Azure CLI (az) not found. Skipping container app update."
  echo "Install Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli"
  echo "Then re-run this script."
  exit 1
fi

# Build a YAML file for the update.
# az containerapp update --command cannot handle flags like --allow-unconfigured
# because the Azure CLI parser confuses them with its own flags, so we use --yaml.
YAML_FILE="$(mktemp /tmp/containerapp-update-XXXXXX.yaml)"
trap 'rm -f "$YAML_FILE"' EXIT

cat > "$YAML_FILE" <<YAML
properties:
  template:
    containers:
    - name: $CONTAINER_APP_NAME
      image: $FULL_IMAGE_NAME
      command:
      - /bin/sh
      - -c
      - |
        mkdir -p /home/node/.openclaw &&
        cat > /home/node/.openclaw/config.json5 << 'CFGEOF'
        {
          agents: { defaults: { model: { primary: "azure-ai/${AZURE_AI_DEPLOYMENT}" } } }
        }
        CFGEOF
        exec node openclaw.mjs gateway --allow-unconfigured --bind lan --port 18789
      env:
      - name: AZURE_AI_ENDPOINT
        value: "$AZURE_AI_ENDPOINT"
      - name: AZURE_AI_API_KEY
        value: "$AZURE_AI_API_KEY"
      - name: AZURE_AI_DEPLOYMENT
        value: "$AZURE_AI_DEPLOYMENT"
      - name: AZURE_LOCATION
        value: "$AZURE_LOCATION"
      - name: OPENCLAW_GATEWAY_TOKEN
        value: "$OPENCLAW_GATEWAY_TOKEN"
      resources:
        cpu: 2
        memory: 4Gi
YAML

az containerapp update \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --yaml "$YAML_FILE" \
  --output table

echo ""
echo "================================"
echo "Deployment completed successfully!"
echo "================================"
echo "Image: $FULL_IMAGE_NAME"
echo "Container App: $CONTAINER_APP_NAME"
echo "Gateway Token: ${OPENCLAW_GATEWAY_TOKEN:0:10}... (masked)"
echo ""
echo "To get the app URL:"
echo "az containerapp show --name $CONTAINER_APP_NAME --resource-group $AZURE_RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv"
echo ""
echo "To view logs:"
echo "az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $AZURE_RESOURCE_GROUP --follow"
echo ""
echo "To view app details:"
echo "az containerapp show --name $CONTAINER_APP_NAME --resource-group $AZURE_RESOURCE_GROUP"
