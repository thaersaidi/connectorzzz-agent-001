# OpenClaw Azure Dashboard Setup

If your dashboard shows **"disconnected (1008): pairing required"** or hangs while thinking, follow these steps to activate it.

## 1. Get Your Gateway Token

You need this token to authenticate in the dashboard settings.

**Option A: From local file (if you deployed from this machine)**
```bash
grep OPENCLAW_GATEWAY_TOKEN .env.azure
```

**Option B: From Azure CLI**
```bash
az containerapp show \
  --name ca-genesis-mesh-node \
  --resource-group rg-genesis-mesh \
  --query "properties.template.containers[0].env[?name=='OPENCLAW_GATEWAY_TOKEN'].value"
```

*Copy the token value.*

## 2. Approve Your Browser (Pairing)

OpenClaw running in Azure (remote mode) blocks all new browser connections by default until approved.

1.  **Open the Dashboard** in your browser and attempt to connect (it will fail with "pairing required").
2.  **List Pending Requests** in your terminal:
    ```bash
    az containerapp exec \
      --name ca-genesis-mesh-node \
      --resource-group rg-genesis-mesh \
      --command "node openclaw.mjs devices list"
    ```
3.  **Approve the Request**:
    Copy the Request ID from the "Pending" list (e.g., `req_abc123` or a UUID) and run:
    ```bash
    az containerapp exec \
      --name ca-genesis-mesh-node \
      --resource-group rg-genesis-mesh \
      --command "node openclaw.mjs devices approve <REQUEST_ID>"
    ```

4.  **Connect**: Go back to the dashboard and click **Connect**.

## 3. Fix "Thinking Forever" (Model Config)

If the chat hangs indefinitely, the gateway is likely trying to use the default Anthropic model instead of your Azure AI model.

Run this command to force the Azure AI model as the default:

```bash
az containerapp update \
  --name ca-genesis-mesh-node \
  --resource-group rg-genesis-mesh \
  --set-env-vars OPENCLAW_AGENTS_DEFAULTS_MODEL_PRIMARY=azure-ai/gpt-5.2
```

*Note: This will restart the container, so you may need to repeat the **Device Pairing** step (Step 2) after the restart completes.*
