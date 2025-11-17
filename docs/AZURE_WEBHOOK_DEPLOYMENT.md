# Deploy Webhook Receiver to Azure - Testing Guide

This guide shows you how to deploy your blob event webhook receiver to Azure for real testing (not local development).

## 🎯 Quick Decision: Which Option?

| Option | Best For | Cost | Setup Time | Local Docker? | Difficulty |
|--------|----------|------|------------|---------------|------------|
| **Container Instances** | Quick testing, Ruby apps | ~$10/month | 5 min | ❌ No | ⭐ Easy |
| **App Service** | Production, managed hosting | Free tier available | 10 min | ❌ No | ⭐⭐ Medium |
| **Azure Functions** | Serverless, auto-scaling | Pay-per-use | 15 min | ❌ No | ⭐⭐⭐ Hard |

**✨ Great News:** None of these options require Docker on your local machine! Azure builds containers in the cloud.

**Recommendation for Testing: Use Container Instances** (Option 1) - It's the easiest and works great with Ruby.

---

## Option 1: Azure Container Instances (Easiest) ⭐

Azure Container Instances lets you run containers without managing servers. Perfect for testing!

**✨ No Docker Required:** Azure builds the container for you in the cloud using `az acr build`!

### Automated Deployment (Easiest)

```bash
cd /Users/jimfreeman/Applications-Local/AgentBuilder/UTS/scripts
ruby deploy_webhook_container.rb
```

This script does everything automatically:
- Creates Dockerfile
- Creates Azure Container Registry
- **Builds container in Azure** (no local Docker needed)
- Deploys to Container Instances
- Gives you the webhook URL

**Requirements:**
- Azure CLI (`brew install azure-cli`)
- Azure subscription
- That's it! No Docker needed on your machine.

### Manual Deployment (If You Prefer)

If you want to do it manually:

**Step 1: Create Dockerfile**

Navigate to the examples directory and create a `Dockerfile`:

```bash
cd /Users/jimfreeman/Applications-Local/AgentBuilder/UTS/examples
```

```dockerfile
FROM ruby:3.2-slim

WORKDIR /app

# Install dependencies
RUN gem install sinatra puma

# Copy webhook receiver
COPY webhook_receiver_example.rb .

# Expose port
EXPOSE 4567

# Run with Puma (production server)
CMD ["ruby", "webhook_receiver_example.rb"]
```

**Step 2: Build Container in Azure (No Local Docker Needed!)**

```bash
# Create container registry
az acr create \
  --resource-group YOUR_RG \
  --name yourwebhookreg \
  --sku Basic

# Build image IN AZURE (not locally!)
az acr build \
  --registry yourwebhookreg \
  --image webhook-receiver:v1 \
  --file Dockerfile .
```

The `az acr build` command uploads your files to Azure and builds the container there!

### Step 3: Deploy Container Instance

**Simple method (using the script):**

```bash
cd /Users/jimfreeman/Applications-Local/AgentBuilder/UTS/scripts
ruby deploy_webhook_container.rb
```

**Manual method (using Azure CLI):**

```bash
# Set variables
RG="webhook-test-rg"
LOCATION="centralus"
CONTAINER_NAME="blob-webhook-receiver"
DNS_NAME="blob-webhook-$(date +%s)"

# Create resource group
az group create --name $RG --location $LOCATION

# Deploy container (using public Docker Hub - we'll create this)
az container create \
  --resource-group $RG \
  --name $CONTAINER_NAME \
  --image yourregistryname.azurecr.io/webhook-receiver:v1 \
  --dns-name-label $DNS_NAME \
  --ports 4567 \
  --cpu 1 \
  --memory 1

# Or use local ACR image
az container create \
  --resource-group $RG \
  --name $CONTAINER_NAME \
  --image yourwebhookreg.azurecr.io/webhook-receiver:v1 \
  --registry-username yourwebhookreg \
  --registry-password $(az acr credential show --name yourwebhookreg --query "passwords[0].value" -o tsv) \
  --dns-name-label $DNS_NAME \
  --ports 4567 \
  --cpu 1 \
  --memory 1

# Get the webhook URL
az container show \
  --resource-group $RG \
  --name $CONTAINER_NAME \
  --query "ipAddress.fqdn" -o tsv
```

Your webhook URL will be:
```
http://YOUR-DNS-NAME.centralus.azurecontainer.io:4567/api/blob-upload-webhook
```

### Step 4: Test Your Webhook

```bash
# Test health endpoint
curl http://YOUR-DNS-NAME.centralus.azurecontainer.io:4567/health

# Should return: {"status":"ok","timestamp":"..."}
```

### Step 5: Configure Event Grid

Now run the Event Grid setup:

```bash
cd /Users/jimfreeman/Applications-Local/AgentBuilder/UTS/scripts
ruby setup_blob_event_trigger.rb
```

When prompted for webhook URL, use:
```
http://YOUR-DNS-NAME.centralus.azurecontainer.io:4567/api/blob-upload-webhook
```

⚠️ **Note**: Container Instances use HTTP by default. Event Grid requires HTTPS for production. For testing, you can use the ngrok workaround or add an Application Gateway (see Option 3 below).

---

## Option 2: Azure App Service ⭐⭐

Azure App Service provides managed hosting for web applications with built-in HTTPS.

### Prerequisites

```bash
# Ensure you have Azure CLI installed
which az

# Login to Azure
az login

# Set your subscription
export AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

### Deploy Using Script

```bash
cd /Users/jimfreeman/Applications-Local/AgentBuilder/UTS/scripts
ruby deploy_webhook_to_azure.rb
```

The script will:
1. ✅ Authenticate with Azure
2. ✅ Select or create a Resource Group
3. ✅ Create an App Service Plan
4. ✅ Create a Web App with Ruby runtime
5. ✅ Configure deployment settings
6. ✅ Provide your webhook URL with HTTPS

### Manual Deployment to App Service

If you prefer manual control:

```bash
# Variables
RG="webhook-receiver-rg"
LOCATION="centralus"
APP_NAME="blob-webhook-$(date +%s)"
PLAN="${APP_NAME}-plan"

# Create resource group
az group create --name $RG --location $LOCATION

# Create App Service Plan (Free tier)
az appservice plan create \
  --name $PLAN \
  --resource-group $RG \
  --location $LOCATION \
  --sku F1 \
  --is-linux

# Create Web App with Ruby runtime
az webapp create \
  --name $APP_NAME \
  --resource-group $RG \
  --plan $PLAN \
  --runtime "RUBY:3.2"

# Configure port
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RG \
  --settings PORT=8080 RACK_ENV=production
```

### Prepare Application for Deployment

Create these files in your `examples` directory:

**1. Gemfile**
```ruby
source 'https://rubygems.org'

gem 'sinatra'
gem 'puma'
gem 'json'
```

**2. config.ru** (Rack configuration)
```ruby
require './webhook_receiver_example'
run Sinatra::Application
```

**3. Startup command** (tell Azure how to run your app)

```bash
# Configure startup command
az webapp config set \
  --name $APP_NAME \
  --resource-group $RG \
  --startup-file "bundle exec puma -t 5:5 -p 8080 -e production config.ru"
```

### Deploy Your Code

**Option A: ZIP Deployment (Easiest)**

```bash
cd examples

# Create deployment package
zip -r webhook.zip . \
  -x "*.git*" \
  -x "node_modules/*" \
  -x ".DS_Store"

# Deploy
az webapp deployment source config-zip \
  --resource-group $RG \
  --name $APP_NAME \
  --src webhook.zip
```

**Option B: Git Deployment**

```bash
# Get deployment credentials
az webapp deployment list-publishing-credentials \
  --name $APP_NAME \
  --resource-group $RG

# Initialize git (if not already)
cd examples
git init
git add .
git commit -m "Initial webhook deployment"

# Add Azure remote
git remote add azure <git-url-from-credentials>

# Push to deploy
git push azure main
```

### Get Your Webhook URL

```bash
echo "https://${APP_NAME}.azurewebsites.net/api/blob-upload-webhook"
```

### Test Deployment

```bash
# Test health endpoint
curl https://${APP_NAME}.azurewebsites.net/health

# View logs
az webapp log tail --name $APP_NAME --resource-group $RG
```

---

## Option 3: Add HTTPS to Container Instances (Advanced)

If you're using Container Instances and need HTTPS for Event Grid:

### Method 1: Use Application Gateway

```bash
# This adds an Application Gateway in front of your container
# Provides SSL termination and HTTPS endpoint
# Cost: ~$125/month (not recommended for simple testing)

# Better for testing: Use ngrok or cloudflared tunnel
```

### Method 2: Use Cloudflare Tunnel (Free HTTPS)

```bash
# Install cloudflared
brew install cloudflare/cloudflare/cloudflared

# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create blob-webhook

# Run tunnel to your container
cloudflared tunnel --url http://YOUR-CONTAINER-FQDN:4567
```

### Method 3: Use Azure Front Door (Microsoft's CDN)

```bash
# Create Front Door profile
az afd profile create \
  --profile-name webhook-frontdoor \
  --resource-group $RG \
  --sku Standard_AzureFrontDoor

# Add your container as origin
# Provides HTTPS automatically
```

---

## Testing Your Deployment

### 1. Verify Webhook is Running

```bash
# Test health endpoint
curl https://YOUR-APP.azurewebsites.net/health

# Expected response:
# {"status":"ok","timestamp":"2025-11-17T..."}
```

### 2. Configure Event Grid

```bash
cd scripts
ruby setup_blob_event_trigger.rb
```

Use your Azure webhook URL:
- **App Service**: `https://YOUR-APP.azurewebsites.net/api/blob-upload-webhook`
- **Container**: `http://YOUR-CONTAINER.region.azurecontainer.io:4567/api/blob-upload-webhook`

### 3. Upload Test File

```bash
az storage blob upload \
  --account-name YOUR_STORAGE \
  --container-name YOUR_CONTAINER \
  --name test.txt \
  --file test.txt \
  --auth-mode login
```

### 4. Check Logs

**App Service Logs:**
```bash
az webapp log tail \
  --name YOUR_APP \
  --resource-group YOUR_RG
```

**Container Instance Logs:**
```bash
az container logs \
  --resource-group YOUR_RG \
  --name YOUR_CONTAINER
```

---

## Troubleshooting

### Webhook Not Receiving Events

**Check Event Grid subscription status:**
```bash
az eventgrid event-subscription show \
  --name YOUR_SUBSCRIPTION \
  --source-resource-id $(az storage account show \
    --name YOUR_STORAGE --resource-group YOUR_RG --query id -o tsv)
```

**Check webhook validation:**
```bash
# Event Grid sends validation request first
# Check your app logs for "Received Event Grid validation request"
```

### App Service Issues

**App not starting:**
```bash
# Check deployment status
az webapp deployment source show \
  --name YOUR_APP \
  --resource-group YOUR_RG

# Check application logs
az webapp log tail --name YOUR_APP --resource-group YOUR_RG
```

**Port issues:**
```bash
# Ensure PORT is configured correctly
az webapp config appsettings set \
  --name YOUR_APP \
  --resource-group YOUR_RG \
  --settings PORT=8080
```

### Container Instance Issues

**Container not running:**
```bash
# Check container status
az container show \
  --resource-group YOUR_RG \
  --name YOUR_CONTAINER

# View logs
az container logs \
  --resource-group YOUR_RG \
  --name YOUR_CONTAINER --follow
```

---

## Cost Estimates

| Option | Development | Production |
|--------|------------|------------|
| **Container Instances** | ~$10/month | ~$30/month |
| **App Service (Free)** | $0 | - |
| **App Service (Basic)** | ~$13/month | ~$55/month |
| **App Service + Front Door** | - | ~$35/month + $35/month |

---

## Production Recommendations

For production use:

1. ✅ **Use App Service (B1 or higher)** - Managed, auto-scaling, integrated
2. ✅ **Enable HTTPS** - Required by Event Grid (App Service has it built-in)
3. ✅ **Add custom domain** - Professional appearance
4. ✅ **Enable Application Insights** - Monitoring and diagnostics
5. ✅ **Configure auto-scaling** - Handle traffic spikes
6. ✅ **Add authentication** - Validate Event Grid signature
7. ✅ **Use Azure Key Vault** - Store secrets securely

---

## Cleanup

### Delete Container Instance

```bash
az container delete \
  --resource-group YOUR_RG \
  --name YOUR_CONTAINER \
  --yes
```

### Delete App Service

```bash
# Delete just the app
az webapp delete \
  --name YOUR_APP \
  --resource-group YOUR_RG

# Delete entire resource group (including plan)
az group delete \
  --name YOUR_RG \
  --yes
```

---

## Next Steps

1. ✅ Deploy webhook receiver to Azure (Option 1 or 2)
2. ✅ Test webhook endpoint health check
3. ✅ Configure Event Grid subscription
4. ✅ Upload test file to blob storage
5. ✅ Verify webhook receives events
6. ✅ Customize processing logic
7. ✅ Deploy to production!

**Need help?** Check Azure portal for resource status and logs.

