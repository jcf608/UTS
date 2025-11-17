# 🎯 Interactive CLI Demo

Visual walkthrough of the `rag_deploy` interactive CLI tool.

## 🌟 Features

- **No configuration files needed** - Everything is interactive
- **Browser-based authentication** - Secure OAuth flows
- **Progress indicators** - Know what's happening at each step
- **Beautiful UI** - Clean, easy-to-read interface
- **Multi-cloud support** - Azure now, AWS & GCP coming soon
- **Safe operations** - Confirmation required for destructive actions

## 📺 Visual Walkthrough

### 1. Welcome Screen

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    RAG INFRASTRUCTURE DEPLOYMENT CLI                          ║
║                  Interactive Setup for Azure, AWS & GCP                       ║
╚══════════════════════════════════════════════════════════════════════════════╝

  Welcome! This tool will help you deploy your RAG system infrastructure.
  We'll guide you through provider selection, authentication, and deployment.

  Press ENTER to continue...
```

### 2. Cloud Provider Selection

```
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                          SELECT CLOUD PROVIDER                             ║
  ╚════════════════════════════════════════════════════════════════════════════╝

  1. Azure           ✅
  2. AWS             🚧 Coming Soon
  3. GCP             🚧 Coming Soon

  Choose provider (1-3): _
```

### 3. Action Selection

```
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                    WHAT WOULD YOU LIKE TO DO? (Azure)                      ║
  ╚════════════════════════════════════════════════════════════════════════════╝

  1. 🚀 Deploy Infrastructure
  2. 📊 Check Status
  3. 🎯 Selective Delete
  4. 🗑️  Destroy All Infrastructure
  5. 👋 Exit

  Choose action (1-5): _
```

### 3a. Selective Delete (NEW!)

```
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                          SELECTIVE DELETE (Azure)                          ║
  ╚════════════════════════════════════════════════════════════════════════════╝

  📋 Loading your Azure resources...

  Loading resources in rg-rag-system...
  Loading resources in rg-test...
  Loading resources in NetworkWatcherRG...


  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                       SELECT RESOURCES TO DELETE                           ║
  ╚════════════════════════════════════════════════════════════════════════════╝

  🌳 Resource Tree (Type the numbers to select, separated by spaces)

  [1] 📁 Resource Group: rg-rag-system
      [2] 📦 ragstorageccde4da7 (storageAccounts)
      [3] 📦 rag-search-service (searchServices)
      [4] 📦 rag-openai-service (accounts)

  [5] 📁 Resource Group: rg-test
      [6] 📦 test-storage (storageAccounts)
      [7] 📦 test-vm (virtualMachines)

  [8] 📁 Resource Group: NetworkWatcherRG
      [9] 📦 NetworkWatcher_eastus (networkWatchers)

  ════════════════════════════════════════════════════════════════════════════

  Examples:
    - Type "1" to select first item
    - Type "1 3 5" to select multiple items
    - Type "all" to select everything (⚠️  dangerous!)
    - Press ENTER without typing to cancel

  Enter selection: 2 3 4

  ⚠️  The following will be DELETED:

    🗑️  Resource: ragstorageccde4da7 (in rg-rag-system)
    🗑️  Resource: rag-search-service (in rg-rag-system)
    🗑️  Resource: rag-openai-service (in rg-rag-system)

  ════════════════════════════════════════════════════════════════════════════

  ⚠️  Type "DELETE" to confirm: DELETE

  🗑️  Deleting selected resources...

  🗑️  Deleting ragstorageccde4da7...
     ✅ Deleted ragstorageccde4da7
  🗑️  Deleting rag-search-service...
     ✅ Deleted rag-search-service
  🗑️  Deleting rag-openai-service...
     ✅ Deleted rag-openai-service

  ✅ Deletion complete!

  Press ENTER to continue...
```

### 4. Authentication (Azure)

#### 4a. If Not Logged In

```
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                          AUTHENTICATION (Azure)                            ║
  ╚════════════════════════════════════════════════════════════════════════════╝

  We need your Azure credentials to proceed.

  📋 Please provide your Azure credentials:

  Enter Azure Tenant ID: 12345678-1234-1234-1234-123456789abc

  🔐 Opening Azure login in your browser...
     Please complete the authentication flow.

  [Browser opens for OAuth login]

  ✅ Successfully authenticated with Azure!
     Subscription: My Company Subscription
     ID: 87654321-4321-4321-4321-cba987654321
```

#### 4b. If Already Logged In

```
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                          AUTHENTICATION (Azure)                            ║
  ╚════════════════════════════════════════════════════════════════════════════╝

  We need your Azure credentials to proceed.

  ℹ️  You are already logged in to Azure:
     Subscription: My Company Subscription
     Account: user@example.com

  Use this account? (Y/n): _
```

### 5. Deployment Execution

```
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                     EXECUTING: Deploy Infrastructure                       ║
  ╚════════════════════════════════════════════════════════════════════════════╝

  📦 Provider: Azure
  🎯 Action: Deploy Infrastructure
  📄 Script: azure/azure_rag_infrastructure.rb

  ════════════════════════════════════════════════════════════════════════════

  [Execution continues with the deployment script...]
```

### 6. Deployment Progress (from azure_rag_infrastructure.rb)

```
================================================================================
🚀 Starting Azure Infrastructure Deployment
================================================================================

────────────────────────────────────────────────────────────────────────────
  Configuration Validation
────────────────────────────────────────────────────────────────────────────
✅ Configuration valid

Deployment Configuration:
  resource_group: rg-rag-system
  location: eastus
  storage_account: ragstoragea1b2c3d4
  storage_container: documents
  search_service: rag-search-service
  openai_service: rag-openai-service

────────────────────────────────────────────────────────────────────────────
  Authentication
────────────────────────────────────────────────────────────────────────────
▶️  Azure CLI login
   ✅ Success
✅ Authenticated successfully

Setting subscription context...
▶️  Set subscription
   ✅ Success
✅ Subscription set

────────────────────────────────────────────────────────────────────────────
  Resource Group Creation
────────────────────────────────────────────────────────────────────────────
▶️  Creating resource group 'rg-rag-system'
   ✅ Success
✅ Resource group 'rg-rag-system' created in eastus

────────────────────────────────────────────────────────────────────────────
  Storage Account & Container Creation
────────────────────────────────────────────────────────────────────────────
Creating storage account 'ragstoragea1b2c3d4'...
▶️  Creating storage account
   ✅ Success
✅ Storage account 'ragstoragea1b2c3d4' created

Creating blob container 'documents'...
✅ Container 'documents' created

────────────────────────────────────────────────────────────────────────────
  Azure AI Search Service Creation
────────────────────────────────────────────────────────────────────────────
Creating AI Search service 'rag-search-service'...
⏳ This may take 2-3 minutes...
▶️  Creating Azure AI Search service
   ✅ Success
✅ Search service 'rag-search-service' created

────────────────────────────────────────────────────────────────────────────
  Azure OpenAI Service Creation
────────────────────────────────────────────────────────────────────────────
Creating Azure OpenAI service 'rag-openai-service'...
⏳ This may take 1-2 minutes...
▶️  Creating Azure OpenAI service
   ✅ Success
✅ OpenAI service 'rag-openai-service' created

Deploying AI models...
  📦 Deploying text-embedding-ada-002...
     ✅ Deployed text-embedding-ada-002
  📦 Deploying gpt-4...
     ✅ Deployed gpt-4
✅ AI models deployed

────────────────────────────────────────────────────────────────────────────
  Security Configuration
────────────────────────────────────────────────────────────────────────────
Retrieving access keys...
▶️  Getting storage connection string
   ✅ Success
▶️  Getting OpenAI keys
   ✅ Success
▶️  Getting Search admin key
   ✅ Success
✅ Access keys retrieved

⚠️  IMPORTANT: Save these credentials to your .env file:

# Azure Storage
AZURE_STORAGE_CONNECTION_STRING='DefaultEndpointsProtocol=https;...'

# Azure OpenAI
AZURE_OPENAI_API_KEY='abc123...xyz789'
AZURE_OPENAI_ENDPOINT='https://rag-openai-service.openai.azure.com/'

# Azure AI Search
AZURE_SEARCH_ENDPOINT='https://rag-search-service.search.windows.net'
AZURE_SEARCH_ADMIN_KEY='def456...uvw012'

================================================================================
📋 Deployment Summary
================================================================================

  ✅ Resource Group: rg-rag-system
     ID: /subscriptions/.../resourceGroups/rg-rag-system

  ✅ Storage Account: ragstoragea1b2c3d4
     ID: ragstoragea1b2c3d4

  ✅ Blob Container: documents
     ID: ragstoragea1b2c3d4/documents

  ✅ AI Search Service: rag-search-service
     ID: /subscriptions/.../searchServices/rag-search-service
     Endpoint: https://rag-search-service.search.windows.net

  ✅ OpenAI Service: rag-openai-service
     ID: /subscriptions/.../accounts/rag-openai-service
     Endpoint: https://rag-openai-service.openai.azure.com/

  ✅ AI Model Deployment: text-embedding-ada-002
     ID: rag-openai-service/deployments/text-embedding-ada-002

  ✅ AI Model Deployment: gpt-4
     ID: rag-openai-service/deployments/gpt-4

================================================================================

================================================================================
✅ Deployment Complete!
================================================================================
```

## 🎮 Command Examples

### Deploy Infrastructure

```bash
./rag_deploy
# Select: 1 (Azure)
# Select: 1 (Deploy Infrastructure)
# Authenticate when prompted
# Watch the magic happen!
```

### Check Status

```bash
./rag_deploy
# Select: 1 (Azure)
# Select: 2 (Check Status)
# Authenticate when prompted
# See what's deployed
```

### Selective Delete (Cherry-pick Resources)

```bash
./rag_deploy
# Select: 1 (Azure)
# Select: 3 (Selective Delete)
# Authenticate when prompted
# See tree of all resource groups and resources
# Type numbers to select (e.g., "2 3 4" or "1" or "all")
# Type "DELETE" to confirm
# Only selected resources deleted
```

### Destroy All Infrastructure

```bash
./rag_deploy
# Select: 1 (Azure)
# Select: 4 (Destroy All Infrastructure)
# Authenticate when prompted
# Type 'destroy' to confirm
# Everything deleted
```

## 💡 Tips

### Already Authenticated?
If you're already logged in to Azure CLI, the tool will detect it and ask if you want to use your existing session. No need to login again!

### Cancel Anytime
Press `Ctrl+C` to cancel the operation at any time.

### Debug Mode
Set `DEBUG=true` environment variable to see detailed command output:

```bash
DEBUG=true ./rag_deploy
```

### Help
Get help anytime:

```bash
./rag_deploy --help
```

## 🛡️ Safety Features

1. **Confirmation Required**: Destructive actions (destroy) require typing 'destroy' to confirm
2. **Existing Resources**: Script checks for existing resources and won't fail if they exist
3. **Clear Feedback**: Every step shows success/failure status
4. **Graceful Errors**: Clear error messages with suggestions

## 🚀 What Makes This CLI Special?

- ✅ **Zero Configuration** - No .env files to edit
- ✅ **Browser Authentication** - Secure OAuth flows
- ✅ **Beautiful UI** - Clean, professional interface
- ✅ **Progress Tracking** - Know what's happening
- ✅ **Multi-Cloud Ready** - Same UX for Azure, AWS, GCP
- ✅ **Error Handling** - Clear messages with solutions
- ✅ **Idempotent** - Safe to run multiple times

## 📚 Technical Details

The CLI uses:
- Ruby's `IO.console` for password input (hidden characters)
- ANSI escape codes for screen clearing
- Child process execution for cloud CLI tools
- JSON parsing for API responses
- Error handling with helpful messages

## 🎯 Selective Delete Use Cases

### 1. Clean Up After Testing
You deployed some test resources and want to remove them without deleting the entire resource group:
```bash
./rag_deploy
# Choose: Selective Delete
# Select individual test resources (e.g., "6 7")
# Keep production resources intact
```

### 2. Remove Expensive Services
You want to keep your resource group but remove costly AI services:
```bash
./rag_deploy
# Choose: Selective Delete
# Select only AI Search and OpenAI (e.g., "3 4")
# Keep storage account with your data
```

### 3. Delete Entire Resource Groups
You have multiple resource groups and want to delete specific ones:
```bash
./rag_deploy
# Choose: Selective Delete
# Select resource group numbers (e.g., "5" to delete rg-test)
# This deletes the RG and all resources inside it
```

### 4. Granular Control
Mix and match - delete some resources from one group, entire other groups:
```bash
./rag_deploy
# Choose: Selective Delete
# Type: "2 3 5 9" to delete:
#   - Resources 2 & 3 from first group
#   - Entire resource group 5
#   - Resource 9 from another group
```

## 🎯 Future Enhancements

- [x] Selective resource deletion with tree view
- [ ] Progress bars during long operations
- [ ] Color-coded output (requires gem)
- [ ] Configuration presets (save/load common configs)
- [ ] Dry-run mode (show what would be deployed)
- [ ] Cost estimation before deployment
- [ ] Resource tagging options
- [ ] Multi-region deployment wizard
- [ ] Export resource list to CSV/JSON

---

**Try it now:** `./rag_deploy` 🚀

