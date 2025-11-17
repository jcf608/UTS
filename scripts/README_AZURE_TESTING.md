# Quick Start: Test Blob Events in Azure

You want to test your blob event webhook **in Azure** (not locally). Here's how:

## 🚀 Fastest Method (5 minutes)

**No Docker required!** Just Azure CLI.

### Step 1: Deploy Webhook to Azure Container

```bash
cd /Users/jimfreeman/Applications-Local/AgentBuilder/UTS/scripts

# Run the automated deployment script
ruby deploy_webhook_container.rb
```

This will:
- ✅ Build container **in Azure** (no local Docker needed!)
- ✅ Create Azure Container Registry
- ✅ Deploy to Azure Container Instances
- ✅ Give you a webhook URL

**Requirements:**
- ✅ Azure CLI installed (`brew install azure-cli`)
- ✅ Azure subscription
- ❌ **NO Docker needed** on your machine!

**What you'll get:**
- Webhook URL: `http://webhook-xxxxx.centralus.azurecontainer.io:4567/api/blob-upload-webhook`
- Health check: `http://webhook-xxxxx.centralus.azurecontainer.io:4567/health`

### Step 2: Configure Event Grid

```bash
# Run Event Grid setup
ruby setup_blob_event_trigger.rb
```

When prompted for webhook URL, paste the URL from Step 1.

### Step 3: Test It!

Upload a file to blob storage:

```bash
az storage blob upload \
  --account-name YOUR_STORAGE_ACCOUNT \
  --container-name YOUR_CONTAINER \
  --name test.txt \
  --file test.txt \
  --auth-mode login
```

Watch the logs to see your webhook receive the event:

```bash
az container logs \
  --resource-group webhook-test-rg \
  --name blob-webhook-receiver \
  --follow
```

You should see:
```
🎉 NEW BLOB UPLOADED!
Blob URL: https://...
Container: YOUR_CONTAINER
Blob Name: test.txt
```

## 🎯 That's It!

Your webhook is now running in Azure and processing blob upload events!

---

## Alternative Methods

### Method 2: Azure App Service (with HTTPS)

For production or if you need HTTPS:

```bash
ruby deploy_webhook_to_azure.rb
```

This deploys to Azure App Service with automatic HTTPS support.

---

## Troubleshooting

### Container not receiving events?

**Check Event Grid subscription:**
```bash
az eventgrid event-subscription list \
  --source-resource-id $(az storage account show \
    --name YOUR_STORAGE --resource-group YOUR_RG --query id -o tsv)
```

**Check container is running:**
```bash
az container show \
  --resource-group webhook-test-rg \
  --name blob-webhook-receiver
```

**Test webhook directly:**
```bash
curl http://YOUR-WEBHOOK-URL/health
```

### Event Grid requires HTTPS?

For testing, Azure Container Instances uses HTTP. If Event Grid requires HTTPS:

**Option 1:** Deploy to App Service instead (has built-in HTTPS)
```bash
ruby deploy_webhook_to_azure.rb
```

**Option 2:** Use ngrok with your container
```bash
# In a separate terminal
ngrok http YOUR-CONTAINER-URL:4567

# Use the ngrok HTTPS URL with Event Grid
```

---

## Cost

- **Container Instances**: ~$0.01/hour (~$7/month)
- **Container Registry (Basic)**: ~$5/month
- **Event Grid**: Free (first 100K operations/month)

**Total for testing**: ~$12/month

---

## Cleanup

When you're done testing:

```bash
# Delete the container
az container delete \
  --resource-group webhook-test-rg \
  --name blob-webhook-receiver \
  --yes

# Delete entire resource group (including registry)
az group delete \
  --name webhook-test-rg \
  --yes
```

---

## Full Documentation

See detailed guide: `/docs/AZURE_WEBHOOK_DEPLOYMENT.md`

---

**Questions?** Check Azure Portal for resource status and logs.

