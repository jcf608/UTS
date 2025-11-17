# 🚀 Quick Start: Test Ruby Blob Processing in Azure

You asked: **"How would I launch a Ruby program to process a file posted to blob storage?"**

**Answer:** Deploy your webhook to Azure, configure Event Grid, and it will automatically trigger your Ruby program when files are uploaded!

---

## 🎯 Choose Your Path

### Path 1: Container Instances (⭐ Easiest - 5 minutes)

```bash
cd scripts
ruby deploy_webhook_container.rb
```

**What it does:**
- Builds container **in Azure** (no local Docker needed!)
- Deploys to Azure Container Instances
- Gives you a public URL: `http://webhook-xxxxx.centralus.azurecontainer.io:4567`

**Requirements:** Just Azure CLI (no Docker on your machine!)

**Best for:** Quick testing, Ruby apps, minimal setup

---

### Path 2: App Service (Production-ready with HTTPS)

```bash
cd scripts
ruby deploy_webhook_to_azure.rb
```

**What it does:**
- Deploys to Azure App Service
- Automatic HTTPS support
- Gives you a URL: `https://your-app.azurewebsites.net`

**Requirements:** Just Azure CLI (no Docker needed!)

**Best for:** Production use, requires HTTPS, managed hosting

---

## 📋 Complete Workflow

### Step 1: Deploy Your Webhook

Choose **Path 1** (easiest) or **Path 2** (production):

```bash
cd /Users/jimfreeman/Applications-Local/AgentBuilder/UTS/scripts

# Path 1: Container Instances (recommended for testing)
ruby deploy_webhook_container.rb

# OR Path 2: App Service
ruby deploy_webhook_to_azure.rb
```

**What you get:**
- A running webhook in Azure
- Public URL to receive events
- Logs you can monitor

### Step 2: Configure Event Grid

Now tell Azure to send blob events to your webhook:

```bash
ruby setup_blob_event_trigger.rb
```

**The script will:**
1. List your storage accounts
2. Ask for your webhook URL (from Step 1)
3. Let you choose which events to monitor (BlobCreated, etc.)
4. Create the Event Grid subscription

### Step 3: Test It!

Upload a file to test:

```bash
az storage blob upload \
  --account-name YOUR_STORAGE \
  --container-name YOUR_CONTAINER \
  --name test.pdf \
  --file test.pdf \
  --auth-mode login
```

**Watch the magic happen:**

```bash
# For Container Instances:
az container logs \
  --resource-group webhook-test-rg \
  --name blob-webhook-receiver \
  --follow

# For App Service:
az webapp log tail \
  --resource-group YOUR_RG \
  --name YOUR_APP
```

**You should see:**
```
🎉 NEW BLOB UPLOADED!
============================================================
Time:           2025-11-17T12:34:56.789Z
Blob URL:       https://youraccount.blob.core.windows.net/container/test.pdf
Container:      YOUR_CONTAINER
Blob Name:      test.pdf
Content Type:   application/pdf
Size:           524288 bytes
============================================================
```

### Step 4: Customize Processing

Edit the webhook to add your custom logic:

```bash
code examples/webhook_receiver_example.rb
```

Find this function and add your processing logic:

```ruby
def process_uploaded_asset(blob_url, container, blob_name, content_type)
  case content_type
  when /^image\//
    # YOUR IMAGE PROCESSING CODE
    # download_and_resize(blob_url)
    # generate_thumbnails(blob_url)
    
  when 'application/pdf'
    # YOUR PDF PROCESSING CODE
    # extract_text(blob_url)
    # generate_preview(blob_url)
    
  else
    # YOUR GENERIC PROCESSING CODE
    # store_metadata(blob_url)
  end
end
```

Then redeploy:
```bash
# Redeploy your changes
ruby deploy_webhook_container.rb
```

---

## 🎓 How It Works

```
┌─────────────────┐
│  User uploads   │
│  file to Blob   │
│    Storage      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Blob Storage    │
│ emits event     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Event Grid     │
│  routes event   │  ← You configured this with setup_blob_event_trigger.rb
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Your Ruby       │
│ Webhook in      │  ← You deployed this with deploy_webhook_container.rb
│ Azure           │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Your custom     │
│ Ruby code       │  ← You customize this in webhook_receiver_example.rb
│ processes file  │
└─────────────────┘
```

**Event Payload:** When a file is uploaded, your Ruby program receives:

```json
{
  "eventType": "Microsoft.Storage.BlobCreated",
  "data": {
    "url": "https://account.blob.core.windows.net/container/file.pdf",
    "contentType": "application/pdf",
    "contentLength": 524288
  }
}
```

Your Ruby code extracts the URL and processes the file!

---

## 💰 Cost

**For testing:**
- Container Instances: ~$0.01/hour (~$7/month)
- Container Registry: ~$5/month
- Event Grid: FREE (first 100K events/month)
- **Total: ~$12/month**

**For production:**
- App Service (Basic B1): ~$13/month
- Event Grid: Still FREE for most usage
- **Total: ~$13/month**

---

## 🧹 Cleanup

When done testing:

```bash
# Delete container deployment
az container delete \
  --resource-group webhook-test-rg \
  --name blob-webhook-receiver \
  --yes

# OR delete entire resource group
az group delete --name webhook-test-rg --yes
```

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [scripts/README_AZURE_TESTING.md](scripts/README_AZURE_TESTING.md) | Quick start guide |
| [docs/AZURE_WEBHOOK_DEPLOYMENT.md](docs/AZURE_WEBHOOK_DEPLOYMENT.md) | Detailed deployment options |
| [docs/BLOB_EVENT_GUIDE.md](docs/BLOB_EVENT_GUIDE.md) | How blob events work |
| [examples/webhook_receiver_example.rb](examples/webhook_receiver_example.rb) | Example webhook code |

---

## 🆘 Troubleshooting

### Webhook not receiving events?

**1. Check Event Grid subscription:**
```bash
az eventgrid event-subscription list --output table
```

**2. Test webhook directly:**
```bash
curl http://YOUR-WEBHOOK-URL/health
# Should return: {"status":"ok"}
```

**3. Check container/app logs:**
```bash
# Container:
az container logs --resource-group webhook-test-rg --name blob-webhook-receiver --follow

# App Service:
az webapp log tail --resource-group YOUR_RG --name YOUR_APP
```

**4. Verify blob upload triggered event:**
```bash
# Upload test file
az storage blob upload \
  --account-name YOUR_STORAGE \
  --container-name YOUR_CONTAINER \
  --name test.txt \
  --file test.txt \
  --auth-mode login

# Check Event Grid metrics in Azure Portal
```

### Event Grid requires HTTPS?

**Option 1:** Use App Service (has HTTPS built-in)
```bash
ruby deploy_webhook_to_azure.rb
```

**Option 2:** Use ngrok with Container Instances
```bash
ngrok http YOUR-CONTAINER-URL:4567
# Use the ngrok HTTPS URL with Event Grid
```

---

## ✅ Next Steps

1. ✅ Deploy webhook to Azure (5 minutes)
2. ✅ Configure Event Grid (3 minutes)
3. ✅ Upload test file (1 minute)
4. ✅ Verify webhook receives event
5. ✅ Customize processing logic
6. ✅ Deploy to production!

---

**Ready to start?**

```bash
cd scripts
ruby deploy_webhook_container.rb
```

That's it! Your Ruby program will now automatically process every file uploaded to blob storage! 🎉

