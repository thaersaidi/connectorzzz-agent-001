# Azure AI Foundry Configuration - Quick Start

## What's Been Set Up

Your repository is now configured for Azure Container App deployment with Azure AI Foundry OpenAI GPT-5.2.

### Files Created

1. **`.env.azure`** - Environment configuration (⚠️ contains secrets, never commit!)
2. **`scripts/deploy-azure-containerapp.sh`** - Automated deployment script
3. **`docs/platforms/azure-containerapp.md`** - Full deployment documentation

### Your Azure AI Configuration

```
Endpoint: https://aif-dev-fin-z123.services.ai.azure.com/api/projects/aifproj-dev-fin-z123
Location: swedencentral
Model: gpt-5.2
Codex Model: gpt-5.2-codex
```

### Container App Configuration

```
Container App: ca-genesis-mesh-node
Environment: env-genesis-mesh
ACR: acrgenesismesh.azurecr.io
```

## Quick Deploy

```bash
# 1. Review and update .env.azure if needed
nano .env.azure

# 2. Run deployment
./scripts/deploy-azure-containerapp.sh
```

## Model Selection: GPT-5.2 vs GPT-5.2-Codex

### Current Setup: GPT-5.2 (Default)

The codebase is configured to use `gpt-5.2` (standard model) by default.

**✅ When to use `gpt-5.2`:**
- General AI tasks
- Conversation, reasoning, analysis
- Mixed workloads (text + code + vision)
- Most production workloads

**🔧 When to use `gpt-5.2-codex`:**
- Heavy code generation
- Code review and refactoring
- Software development workflows
- Specialized coding tasks

### Switching to Codex

To switch to the codex deployment:

```bash
# Edit .env.azure
sed -i 's/AZURE_AI_DEPLOYMENT=gpt-5.2/AZURE_AI_DEPLOYMENT=gpt-5.2-codex/' .env.azure

# Redeploy
./scripts/deploy-azure-containerapp.sh
```

## Environment Variables

The deployment automatically sets these environment variables in your Container App:

```bash
AZURE_AI_ENDPOINT     # Your Azure AI project endpoint
AZURE_AI_API_KEY      # Your API key
AZURE_AI_DEPLOYMENT   # Model deployment (gpt-5.2 or gpt-5.2-codex)
AZURE_LOCATION        # Azure region (swedencentral)
```

OpenClaw will automatically detect and use these variables.

## Verification

```bash
# Check deployment status
az containerapp show --name ca-genesis-mesh-node --resource-group rg-genesis-mesh

# View logs
az containerapp logs show --name ca-genesis-mesh-node --resource-group rg-genesis-mesh --follow
```

## Model Usage in OpenClaw

Once deployed, the agent will use Azure AI Foundry automatically. The model reference format is:

```
azure-ai/gpt-5.2       # Standard model
azure-ai/gpt-5.2-codex # Codex variant
```

## Security

- ✅ `.env.azure` is in `.gitignore` - never commit secrets
- ✅ Container runs as non-root user
- ✅ API keys passed via environment variables at runtime

## Full Documentation

See [docs/platforms/azure-containerapp.md](docs/platforms/azure-containerapp.md) for:
- Detailed deployment steps
- Troubleshooting guide
- Manual deployment methods
- Advanced configuration options

## Support

- OpenClaw Model Providers: https://docs.openclaw.ai/concepts/model-providers#azure-ai-foundry
- Azure AI Foundry: https://learn.microsoft.com/azure/ai-services/openai/
