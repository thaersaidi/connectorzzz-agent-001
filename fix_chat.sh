#!/bin/bash
set -e

# 1. Force the global default config
echo "Setting global default model to Azure AI..."
az containerapp exec \
  --name ca-genesis-mesh-node \
  --resource-group rg-genesis-mesh \
  --command "node openclaw.mjs config set agents.defaults.model.primary azure-ai/gpt-5.2"

# 2. Force the 'main' agent configuration (by overwriting the specific agent config file if possible, 
# or by explicitly attempting to update the agent configuration if the CLI supports it in this version)
# Since 'agents update' isn't available, we rely on the global default update. 
# We'll also try to delete the main agent's persistent config file so it regenerates from defaults on next load.
# Note: This might fail if the file doesn't exist, which is fine.

echo "Attempting to reset 'main' agent configuration..."
# We try to remove the specific agent.json so it falls back to global defaults
az containerapp exec \
  --name ca-genesis-mesh-node \
  --resource-group rg-genesis-mesh \
  --command "rm -f /home/node/.openclaw/agents/main/agent/agent.json" || true

echo "Done. Please refresh your dashboard and try chatting again."
