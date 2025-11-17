# 🚀 Quick Start Guide - Deploy RAG Infrastructure

Get your RAG system running in under 10 minutes!

## ⚡ The Easiest Way - Interactive CLI

### Step 1: Run the Interactive Tool

```bash
# Navigate to IaC folder
cd IaC

# Run the interactive deployment CLI
./rag_deploy
```

### Step 2: Follow the Prompts

The CLI will guide you through:
1. **Choose Cloud Provider** → Select Azure, AWS, or GCP
2. **Authenticate** → Login to your cloud account (opens browser)
3. **Select Action** → Deploy, Check Status, or Destroy
4. **Watch Progress** → Automated deployment with status updates

### Step 3: Save Access Keys

The deployment will output access keys. **Save these to your application .env file:**

```bash
AZURE_STORAGE_CONNECTION_STRING='...'
AZURE_OPENAI_API_KEY='...'
AZURE_OPENAI_ENDPOINT='...'
AZURE_SEARCH_ENDPOINT='...'
AZURE_SEARCH_ADMIN_KEY='...'
```

**That's it!** No configuration files needed. Everything is interactive.

---

## 🔧 Alternative: Manual Configuration (Advanced)

If you prefer to configure manually or need automated scripts:

### Step 1: Configure Credentials

```bash
# Navigate to IaC folder
cd IaC

# Copy environment template
cp env.template .env

# Edit with your cloud credentials
vim .env
```

**For Azure, get your credentials:**
```bash
# Get subscription ID
az account show --query id --output tsv

# Get tenant ID
az account show --query tenantId --output tsv
```

### Step 2: Deploy Infrastructure

```bash
# Deploy using the deployment script
ruby deploy.rb deploy

# Or use provider-specific script directly
ruby azure/azure_rag_infrastructure.rb deploy
```

## ✅ What Gets Created

| Resource | Purpose | Tier |
|----------|---------|------|
| Resource Group | Container for all resources | - |
| Storage Account | Document storage (PDFs, TXT, etc.) | Standard_LRS |
| Blob Container | Named "documents" | - |
| AI Search | Vector database for embeddings | Basic |
| OpenAI Service | GPT-4 and embeddings | S0 |
| Embedding Model | text-embedding-ada-002 | Deployed |
| GPT-4 Model | gpt-4 | Deployed |

**Total Cost:** ~$107-137/month

## 📊 Check Deployment Status

```bash
# Check if all resources are deployed
ruby deploy.rb status
```

## 🎯 Selective Delete (Cherry-Pick Resources)

```bash
# Interactive tree view - select specific resources to delete
./rag_deploy
# Choose: 3. Selective Delete
# See all resource groups and resources
# Type numbers to select (e.g., "2 3 4")
# Type "DELETE" to confirm
```

**Perfect for:**
- Removing expensive AI services while keeping data
- Deleting test resources without touching production
- Cleaning up specific resource groups

## 🗑️ Delete Everything

```bash
# Destroy all resources (requires typing 'destroy' to confirm)
ruby deploy.rb destroy

# Or use interactive CLI
./rag_deploy
# Choose: 4. Destroy All Infrastructure
```

## 🛠️ Customize Deployment

Edit `.env` to customize resource names and locations:

```bash
# Use different region
AZURE_LOCATION=westus2

# Use existing resource group
AZURE_RESOURCE_GROUP=my-existing-rg

# Custom storage account name
AZURE_STORAGE_ACCOUNT=mycompanystorageacct
```

## 🐛 Troubleshooting

### "Azure CLI not found"
```bash
# Install Azure CLI
brew install azure-cli  # macOS
# Or: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
```

### "Not logged in to Azure"
```bash
az login
az account set --subscription YOUR_SUBSCRIPTION_ID
```

### "Resource already exists"
That's okay! The scripts are idempotent. They'll skip existing resources.

### "OpenAI quota exceeded"
Try a different region:
```bash
AZURE_LOCATION=westeurope ruby deploy.rb deploy
```

## 📖 Next Steps

After deployment:

1. ✅ **Test storage**: Upload a document to blob container
2. ✅ **Test embeddings**: Generate embeddings with OpenAI
3. ✅ **Create search index**: Setup vector search index
4. ✅ **Deploy application**: Deploy your RAG API

## 💡 Pro Tips

- **Cost Savings**: Use Basic tier for AI Search in development
- **Security**: Use private endpoints in production
- **Monitoring**: Enable diagnostic logs for all services
- **Backup**: Enable blob versioning and soft delete
- **Scale**: Upgrade to Standard tier when you need more capacity

## 📚 Full Documentation

See [README.md](README.md) for comprehensive documentation.

## 🆘 Getting Help

- Check Azure portal for resource status
- Review deployment logs (saved in `logs/` folder)
- Run `ruby deploy.rb status` to diagnose issues
- Check [Azure status page](https://status.azure.com/) for service issues

---

**Ready to deploy? Run `ruby deploy.rb deploy` now!** 🚀

