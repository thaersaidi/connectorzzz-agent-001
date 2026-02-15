# Azure Container App Deployment with Azure AI Foundry

This guide explains how to deploy OpenClaw to Azure Container Apps with Azure AI Foundry OpenAI GPT-5.2 integration.

## Prerequisites

- Docker installed locally
- Azure CLI (`az`) installed (optional, for automated deployment)
- Azure Container Registry credentials
- Azure AI Foundry project with API key

## Configuration

### 1. Environment Variables

The deployment uses `.env.azure` file for configuration. This file contains:

```bash
# Azure AI Foundry Configuration
AZURE_AI_ENDPOINT=https://aif-dev-fin-z123.services.ai.azure.com/api/projects/aifproj-dev-fin-z123
AZURE_AI_API_KEY=your-api-key
AZURE_AI_DEPLOYMENT=gpt-5.2  # or gpt-5.2-codex for coding tasks

# Azure Location
AZURE_LOCATION=swedencentral

# Azure Container Registry
ACR_NAME=acrgenesismesh
ACR_LOGIN_SERVER=acrgenesismesh.azurecr.io
ACR_PASSWORD=your-acr-password

# Container App Configuration
CONTAINER_APP_NAME=ca-genesis-mesh-node
CONTAINER_APP_ENV=env-genesis-mesh
CONTAINER_APP_INGRESS=true
AZURE_RESOURCE_GROUP=rg-genesis-mesh
```

### 2. Azure AI Foundry Models

OpenClaw supports Azure AI Foundry with the following configuration:

- **Provider:** `azure-ai`
- **Authentication:** `AZURE_AI_API_KEY` environment variable
- **Endpoint:** `AZURE_AI_ENDPOINT` (project URL including `/api/projects/...`)
- **Deployment:** `AZURE_AI_DEPLOYMENT` (e.g., `gpt-5.2` or `gpt-5.2-codex`)

#### Model References

- Standard GPT-5.2: `azure-ai/gpt-5.2`
- Codex variant: `azure-ai/gpt-5.2-codex`

The model reference format is `azure-ai/{deployment-name}`.

## Deployment Methods

### Method 1: Automated Deployment (Recommended)

Use the provided deployment script:

```bash
# Make sure .env.azure is configured
./scripts/deploy-azure-containerapp.sh
```

This script will:
1. Login to Azure Container Registry
2. Build the Docker image
3. Push to ACR
4. Update the Container App with new image and environment variables

### Method 2: Manual Deployment

#### Step 1: Build Docker Image

```bash
# Load environment variables
source .env.azure

# Build image
docker build -t $ACR_LOGIN_SERVER/openclaw:latest .
```

#### Step 2: Push to Azure Container Registry

```bash
# Login to ACR
echo $ACR_PASSWORD | docker login $ACR_LOGIN_SERVER -u $ACR_NAME --password-stdin

# Push image
docker push $ACR_LOGIN_SERVER/openclaw:latest
```

#### Step 3: Update Container App

```bash
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $AZURE_RESOURCE_GROUP \
  --image $ACR_LOGIN_SERVER/openclaw:latest \
  --set-env-vars \
    AZURE_AI_ENDPOINT="$AZURE_AI_ENDPOINT" \
    AZURE_AI_API_KEY="$AZURE_AI_API_KEY" \
    AZURE_AI_DEPLOYMENT="$AZURE_AI_DEPLOYMENT" \
    AZURE_LOCATION="$AZURE_LOCATION"
```

## OpenClaw Configuration

Once deployed, OpenClaw will automatically use Azure AI Foundry when configured with:

```json5
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "azure-ai/gpt-5.2"
      }
    }
  }
}
```

Or via environment variables:

```bash
# The AZURE_AI_* variables are already set in the Container App
# OpenClaw will automatically detect and use them
```

## Choosing Between GPT-5.2 and GPT-5.2-Codex

### Use `gpt-5.2` (default) when:
- General-purpose AI tasks
- Conversation and reasoning
- Mixed workloads (text, code, vision)

### Use `gpt-5.2-codex` when:
- Heavy code generation and editing
- Software development workflows
- Code analysis and refactoring

To switch deployments, update `AZURE_AI_DEPLOYMENT` in `.env.azure` and redeploy:

```bash
# Edit .env.azure
AZURE_AI_DEPLOYMENT=gpt-5.2-codex

# Redeploy
./scripts/deploy-azure-containerapp.sh
```

## Verification

### Check Container App Status

```bash
az containerapp show \
  --name ca-genesis-mesh-node \
  --resource-group rg-genesis-mesh
```

### View Logs

```bash
az containerapp logs show \
  --name ca-genesis-mesh-node \
  --resource-group rg-genesis-mesh \
  --follow
```

### Test Azure AI Connection

Once deployed, you can test the Azure AI connection:

```bash
# SSH into the container (if exec is enabled)
az containerapp exec \
  --name ca-genesis-mesh-node \
  --resource-group rg-genesis-mesh

# Inside the container, test the model
node openclaw.mjs models test azure-ai/gpt-5.2
```

## Troubleshooting

### Authentication Issues

If you see authentication errors:

1. Verify `AZURE_AI_API_KEY` is correct
2. Check that the API key has access to the project
3. Ensure `AZURE_AI_ENDPOINT` includes the full project path

### Deployment Issues

If the deployment model is not found:

1. Verify the deployment name in Azure AI Foundry
2. Check that `AZURE_AI_DEPLOYMENT` matches exactly
3. Confirm the deployment is active and ready

### Container App Not Starting

Check the logs for errors:

```bash
az containerapp logs show \
  --name ca-genesis-mesh-node \
  --resource-group rg-genesis-mesh \
  --tail 100
```

Common issues:
- Missing environment variables
- Image pull failures (check ACR credentials)
- Port binding conflicts (ensure health probes are configured)

## Security Notes

1. **Never commit `.env.azure`** - It contains sensitive credentials
2. Consider using Azure Key Vault for production secrets
3. The API key is passed as an environment variable at runtime
4. Container runs as non-root user (`node`) for security

## Additional Resources

- [Azure AI Foundry Documentation](https://learn.microsoft.com/azure/ai-services/openai/)
- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [OpenClaw Model Providers Guide](https://docs.openclaw.ai/concepts/model-providers)

## Support

For Azure AI Foundry configuration issues, refer to:
- OpenClaw docs: https://docs.openclaw.ai/concepts/model-providers#azure-ai-foundry
- Azure AI docs: https://learn.microsoft.com/azure/ai-services/
