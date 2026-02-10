#!/bin/bash
set -e

# ==================================================================================
# OpenClaw – Azure Container Apps Deployment Script
#
# Deploys the existing Dockerfile to Azure Container Apps.
# Prerequisites: az CLI installed & logged in (az login).
#
# Usage:
#   export ACR_PASSWORD='<your-acr-admin-password>'
#   ./scripts/deploy-azure.sh
# ==================================================================================

# --------------- Configuration (matches your Azure resources) ---------------
RESOURCE_GROUP="rg-genesis-mesh"
LOCATION="swedencentral"
ACR_NAME="acrgenesismesh"
ACR_SERVER="acrgenesismesh.azurecr.io"
ACR_USER="acrgenesismesh"
ACR_PASSWORD="${ACR_PASSWORD:?Set ACR_PASSWORD env var before running}"

CONTAINER_APP_NAME="ca-agent-001"
ENV_NAME="cae-agents001gf4gd"
ENV_RESOURCE_GROUP="rg-agents001"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_REF="${ACR_SERVER}/openclaw:${IMAGE_TAG}"

GATEWAY_PORT=3000
MIN_REPLICAS=1
MAX_REPLICAS=1
CPU="1.0"
MEMORY="2.0Gi"

# --------------- Preflight ---------------
command -v az &>/dev/null || { echo "Error: az CLI not found"; exit 1; }
az account show &>/dev/null || { echo "Error: not logged in – run 'az login'"; exit 1; }

echo "=== OpenClaw → Azure Container Apps ==="
echo "RG:    $RESOURCE_GROUP"
echo "ACR:   $ACR_SERVER"
echo "App:   $CONTAINER_APP_NAME"
echo "Image: $IMAGE_REF"
echo ""

# 1. Resource Group
echo "[1/5] Resource Group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" -o none

# 2. ACR (idempotent)
echo "[2/5] Container Registry..."
az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &>/dev/null \
  || az acr create -g "$RESOURCE_GROUP" -n "$ACR_NAME" --sku Basic --admin-enabled true -o none

# 3. Build & push via ACR Tasks (uses the repo Dockerfile as-is)
echo "[3/5] Building image in ACR..."
az acr build --registry "$ACR_NAME" --image "openclaw:${IMAGE_TAG}" --file Dockerfile .

# 4. Container Apps Environment (reusing existing)
echo "[4/5] Resolving Container Apps Environment..."
ENV_ID=$(az containerapp env show -n "$ENV_NAME" -g "$ENV_RESOURCE_GROUP" --query id -o tsv)
echo "  Using environment: $ENV_NAME ($ENV_RESOURCE_GROUP)"

# 5. Deploy / update Container App
echo "[5/5] Container App..."
if az containerapp show -n "$CONTAINER_APP_NAME" -g "$ENV_RESOURCE_GROUP" &>/dev/null; then
  # Write YAML for update (allows setting the startup command reliably)
  YAML_TMP=$(mktemp /tmp/ca-update-XXXXXX.yaml)
  cat > "$YAML_TMP" <<YAML
properties:
  template:
    containers:
      - image: ${IMAGE_REF}
        name: openclaw
        resources:
          cpu: ${CPU%.*}
          memory: ${MEMORY/\.0/}
        command:
          - node
          - dist/index.js
          - gateway
          - --allow-unconfigured
          - --bind
          - lan
          - --port
          - "${GATEWAY_PORT}"
        env:
          - name: NODE_ENV
            value: production
          - name: OPENCLAW_PREFER_PNPM
            value: "1"
          - name: OPENCLAW_STATE_DIR
            value: /data
          - name: NODE_OPTIONS
            value: --max-old-space-size=1536
YAML
  az containerapp update \
    -n "$CONTAINER_APP_NAME" \
    -g "$ENV_RESOURCE_GROUP" \
    --yaml "$YAML_TMP" \
    -o none
  rm -f "$YAML_TMP"
else
  # Initial creation (no command override – uses Dockerfile CMD)
  az containerapp create \
    -n "$CONTAINER_APP_NAME" \
    -g "$ENV_RESOURCE_GROUP" \
    --environment "$ENV_ID" \
    --image "$IMAGE_REF" \
    --target-port "$GATEWAY_PORT" \
    --ingress external \
    --transport auto \
    --registry-server "$ACR_SERVER" \
    --registry-username "$ACR_USER" \
    --registry-password "$ACR_PASSWORD" \
    --cpu "$CPU" --memory "$MEMORY" \
    --min-replicas "$MIN_REPLICAS" \
    --max-replicas "$MAX_REPLICAS" \
    --env-vars \
      "NODE_ENV=production" \
      "OPENCLAW_PREFER_PNPM=1" \
      "OPENCLAW_STATE_DIR=/data" \
      "NODE_OPTIONS=--max-old-space-size=1536" \
    -o none

  # Immediately update with correct startup command via YAML
  YAML_TMP=$(mktemp /tmp/ca-update-XXXXXX.yaml)
  cat > "$YAML_TMP" <<YAML
properties:
  template:
    containers:
      - image: ${IMAGE_REF}
        name: openclaw
        resources:
          cpu: ${CPU%.*}
          memory: ${MEMORY/\.0/}
        command:
          - node
          - dist/index.js
          - gateway
          - --allow-unconfigured
          - --bind
          - lan
          - --port
          - "${GATEWAY_PORT}"
        env:
          - name: NODE_ENV
            value: production
          - name: OPENCLAW_PREFER_PNPM
            value: "1"
          - name: OPENCLAW_STATE_DIR
            value: /data
          - name: NODE_OPTIONS
            value: --max-old-space-size=1536
YAML
  az containerapp update \
    -n "$CONTAINER_APP_NAME" \
    -g "$ENV_RESOURCE_GROUP" \
    --yaml "$YAML_TMP" \
    -o none
  rm -f "$YAML_TMP"
fi

# --------------- Done ---------------
FQDN=$(az containerapp show -n "$CONTAINER_APP_NAME" -g "$ENV_RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv 2>/dev/null || echo "<pending>")

echo ""
echo "=== Deployed ==="
echo "URL: https://${FQDN}"
echo ""
echo "Set secrets:"
echo "  az containerapp secret set -n $CONTAINER_APP_NAME -g $ENV_RESOURCE_GROUP --secrets gwtoken=<value>"
echo "  az containerapp update -n $CONTAINER_APP_NAME -g $ENV_RESOURCE_GROUP --set-env-vars OPENCLAW_GATEWAY_TOKEN=secretref:gwtoken"
echo ""
echo "Tail logs:"
echo "  az containerapp logs show -n $CONTAINER_APP_NAME -g $ENV_RESOURCE_GROUP --follow"
