# Infrastructure as Code (IaC) for RAG System

Automated deployment scripts for cloud-agnostic RAG (Retrieval Augmented Generation) infrastructure.

## 📁 Directory Structure

```
IaC/
├── README.md                           # This file
├── QUICKSTART.md                       # Quick start guide
├── Gemfile                             # Ruby dependencies
├── .gitignore                          # Ignore sensitive files
├── env.template                        # Environment variables template
├── rag_deploy                          # 🌟 Interactive CLI (RECOMMENDED)
├── deploy.rb                           # Scripted deployment tool
├── common/
│   └── base_infrastructure.rb          # Base class for all providers
├── azure/
│   ├── azure_rag_infrastructure.rb     # Azure deployment script
│   └── azure_app_service_deploy.rb     # Azure app deployment (coming soon)
├── aws/
│   └── aws_rag_infrastructure.rb       # AWS deployment script (coming soon)
└── gcp/
    └── gcp_rag_infrastructure.rb       # GCP deployment script (coming soon)
```

## 🚀 Quick Start (Interactive CLI - Recommended!)

### The Easiest Way - Interactive CLI

```bash
# Navigate to IaC directory
cd IaC

# Run the interactive deployment tool
./rag_deploy
```

That's it! The interactive CLI will:
1. ✅ Let you choose your cloud provider (Azure/AWS/GCP)
2. ✅ Guide you through authentication
3. ✅ Let you select what to do (Deploy/Status/Destroy)
4. ✅ Execute the deployment with progress indicators

**No configuration files needed!** Everything is interactive and guided.

### Prerequisites

1. **Ruby 3.0+** (preferably Ruby 3.3.3 with rbenv)
2. **Cloud CLI tools**:
   - Azure: `az` CLI
   - AWS: `aws` CLI (coming soon)
   - GCP: `gcloud` CLI (coming soon)
3. **Cloud account** with appropriate permissions

### Alternative: Manual Configuration

If you prefer to configure manually or script deployments:

```bash
# Navigate to IaC directory
cd IaC

# Copy environment template
cp env.template .env

# Edit .env with your credentials
vim .env

# Deploy using the deployment script
ruby deploy.rb deploy
```

## ☁️ Azure Deployment

### Configuration

Set the following environment variables in `.env`:

```bash
# Required
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_TENANT_ID=your-tenant-id

# Optional (defaults provided)
AZURE_RESOURCE_GROUP=rg-rag-system
AZURE_LOCATION=eastus
AZURE_STORAGE_ACCOUNT=ragstorageXXXX
AZURE_STORAGE_CONTAINER=documents
AZURE_SEARCH_SERVICE=rag-search-service
AZURE_OPENAI_SERVICE=rag-openai-service
```

### Deploy Infrastructure

```bash
# Deploy all Azure resources
ruby azure/azure_rag_infrastructure.rb deploy

# Or simply (deploy is default)
ruby azure/azure_rag_infrastructure.rb
```

This will create:
- ✅ Resource Group
- ✅ Storage Account (General Purpose v2)
- ✅ Blob Container for documents
- ✅ Azure AI Search service (Basic tier)
- ✅ Azure OpenAI service
- ✅ Embedding model deployment (text-embedding-ada-002)
- ✅ GPT-4 model deployment

**Deployment Time:** ~5-10 minutes

### Check Status

```bash
# Check if resources are deployed
ruby azure/azure_rag_infrastructure.rb status
```

### Destroy Infrastructure

```bash
# Delete all resources (requires confirmation)
ruby azure/azure_rag_infrastructure.rb destroy
```

⚠️ **Warning:** This will permanently delete all resources. Type 'destroy' to confirm.

## 📝 What Gets Deployed

### Azure Landing Zone Components

#### 1. Resource Group
- Container for all RAG system resources
- Default location: East US (configurable)

#### 2. Storage Layer
- **Storage Account**: General Purpose v2, LRS redundancy
- **Blob Container**: For PDF, TXT, DOCX documents
- **Access Tier**: Hot (for frequently accessed data)

#### 3. Vector Database
- **Azure AI Search**: Basic tier
- **Features**: Vector search, semantic ranking, full-text search
- **Index**: Created programmatically (not by IaC script)

#### 4. AI Services
- **Azure OpenAI**: S0 tier
- **Models Deployed**:
  - `text-embedding-ada-002`: 1536-dimensional embeddings
  - `gpt-4`: Latest stable version for response generation

#### 5. Security
- Access keys retrieved and displayed
- Connection strings generated
- Managed identities (manual setup for production)

## 🏗️ Architecture Pattern

All deployment scripts follow the **Template Method Pattern**:

```ruby
class BaseInfrastructure
  def deploy
    authenticate              # Provider-specific
    create_resource_group     # Provider-specific
    create_storage           # Provider-specific
    create_vector_database   # Provider-specific
    create_ai_services       # Provider-specific
    configure_security       # Provider-specific
    output_summary           # Common
  end
end
```

### Benefits
- ✅ **Consistent workflow** across all cloud providers
- ✅ **Easy to extend** for new providers
- ✅ **DRY principle** - common logic in base class
- ✅ **OOP design** - clean inheritance hierarchy

## 🔐 Security Best Practices

### For Development
- ✅ Use service principals or managed identities
- ✅ Store credentials in `.env` (gitignored)
- ✅ Rotate keys regularly

### For Production
- ✅ Use Azure Key Vault for secrets
- ✅ Enable private endpoints for services
- ✅ Implement RBAC (Role-Based Access Control)
- ✅ Use virtual networks and NSGs
- ✅ Enable diagnostic logging
- ✅ Implement automated backup

## 💰 Cost Estimation

### Azure (Basic Tier)
| Component | Estimated Monthly Cost |
|-----------|----------------------|
| Storage Account (100GB) | ~$2 |
| AI Search (Basic) | ~$75 |
| OpenAI - Embeddings (1M tokens) | ~$0.10 |
| OpenAI - GPT-4 (1M tokens) | ~$30-60 |
| **Total** | **~$107-137/month** |

### Cost Optimization Tips
- Use commitment discounts for predictable usage
- Archive old documents to cool/archive tiers
- Use GPT-3.5 for simple queries
- Implement caching for frequent queries
- Scale down search service during off-hours

## 🔧 Customization

### Change Azure Region

```bash
# In .env
AZURE_LOCATION=westus2

# Or via environment variable
AZURE_LOCATION=westus2 ruby azure/azure_rag_infrastructure.rb deploy
```

### Use Existing Resource Group

```bash
# In .env
AZURE_RESOURCE_GROUP=my-existing-rg

# The script will use existing RG instead of creating new one
ruby azure/azure_rag_infrastructure.rb deploy
```

### Custom Storage Account Name

```bash
# In .env
AZURE_STORAGE_ACCOUNT=myragstorageacct

# Must be 3-24 chars, lowercase letters and numbers only
```

## 🐛 Troubleshooting

### Azure CLI Not Authenticated
```bash
# Login to Azure
az login --tenant YOUR_TENANT_ID

# Set subscription
az account set --subscription YOUR_SUBSCRIPTION_ID
```

### Resource Already Exists
The scripts are **idempotent** - they check if resources exist before creating. Safe to run multiple times.

### Quota Exceeded
Some Azure OpenAI regions have limited quota. Try different regions:
- East US
- West Europe
- South Central US

### Permission Denied
Ensure your Azure account has:
- `Contributor` role on subscription
- `OpenAI Contributor` role for AI services

## 📚 Additional Resources

### Azure Documentation
- [Azure CLI Reference](https://learn.microsoft.com/en-us/cli/azure/)
- [Azure OpenAI Service](https://learn.microsoft.com/en-us/azure/ai-services/openai/)
- [Azure AI Search](https://learn.microsoft.com/en-us/azure/search/)
- [Azure Storage](https://learn.microsoft.com/en-us/azure/storage/)

### Ruby Best Practices
- [Ruby Style Guide](https://rubystyle.guide/)
- [RuboCop](https://github.com/rubocop/rubocop)
- [Ruby OOP Patterns](https://refactoring.guru/design-patterns/ruby)

## 🚦 Roadmap

- [ ] AWS infrastructure deployment script
- [ ] GCP infrastructure deployment script
- [ ] Application deployment automation
- [ ] CI/CD pipeline integration
- [ ] Terraform/ARM template generation
- [ ] Monitoring and alerting setup
- [ ] Automated backup configuration
- [ ] Multi-region deployment support

## 🤝 Contributing

When adding new cloud providers:

1. Inherit from `BaseInfrastructure`
2. Implement all abstract methods
3. Follow the template method pattern
4. Add provider to README
5. Include cost estimates
6. Document prerequisites

## 📄 License

Part of the UTS RAG System project.

---

**Built with ❤️ for cloud-agnostic infrastructure automation**

