# UTS RAG System - Multi-Cloud Infrastructure

Enterprise-grade Retrieval-Augmented Generation (RAG) system infrastructure for the **UTS** project, following **DSi Aeris AI** naming standards.

## 🚀 Quick Start

### 1. Deploy Infrastructure

```bash
cd IaC
./rag_deploy
```

Choose your cloud provider (Azure, AWS, or GCP) and follow prompts.

### 2. Run the Application

```bash
./start_dev.rb
```

The browser will open automatically to http://localhost:8080!

## 📁 Project Structure

```
UTS/
├── start_dev.rb            # 🎯 Start both servers + open browser
├── stop_dev.rb             # 🛑 Stop all servers
├── app/                    # 🚀 Full-Stack RAG Application
│   ├── backend/           # Sinatra API (port 4000)
│   │   ├── app.rb         # Main Sinatra app
│   │   ├── models/        # ActiveRecord models
│   │   ├── routes/        # API routes
│   │   └── db/            # Database & migrations
│   └── frontend/          # React/Vite (port 8080)
│       ├── src/           # React components
│       └── package.json   # Node dependencies
│
├── IaC/                    # Infrastructure as Code
│   ├── rag_deploy         # 🎯 Infrastructure CLI
│   ├── azure/             # Azure-specific infrastructure
│   ├── aws/               # AWS-specific infrastructure
│   ├── gcp/               # GCP-specific infrastructure
│   └── common/            # Shared base classes
│
├── docs/                   # 📚 Documentation & Guides
│   ├── QUICK_START.md     # Getting started guide
│   ├── PRINCIPLES.md      # Design principles
│   ├── BLOB_EVENT_GUIDE.md
│   ├── CLOUD_AGNOSTIC_GUIDE.md
│   └── azure_rag_guide.html
│
├── examples/               # 💡 Example Code
│   ├── azure_auth_simple.rb
│   ├── azure_auth_oop.rb
│   ├── webhook_receiver_example.rb
│   └── cloud_agnostic_webhook_receiver.rb
│
├── scripts/                # 🔧 Utility Scripts
│   ├── create_blob_storage.rb
│   ├── setup_blob_event_trigger.rb
│   ├── setup_aws_s3_events.rb
│   └── setup_gcp_storage_events.rb
│
└── .env                    # 🔐 Configuration (git-ignored)
```

## 🏢 Naming Convention

Following **DSi Aeris AI Standards**:

- **Resource Group**: `UTS-{ENV}-RG` (e.g., `UTS-DEV-RG`)
- **Storage Account**: `uts{env}stg{region}{random}` (e.g., `utsdevstgsea4a2f1c`)
- **Search Service**: `uts-{env}-search-{region}-{id}` (e.g., `uts-dev-search-sea-3f`)

See [`IaC/NAMING_CONVENTIONS.md`](IaC/NAMING_CONVENTIONS.md) for complete details.

## 🤖 AI Provider

**Default: OpenAI API** (External)
- Works with Azure for Students (no special quota needed)
- Requires `OPENAI_API_KEY` in `.env`

**Alternative: Azure OpenAI**
- Requires quota approval (request at https://aka.ms/oai/access)
- Set `AI_PROVIDER=azure_openai` in `.env`

## 🌍 Multi-Cloud Support

Deploy to any cloud provider:
- ✅ **Azure** - Fully implemented
- 🚧 **AWS** - Coming soon
- 🚧 **GCP** - Coming soon

## 📖 Documentation

- **[Quick Start](docs/QUICK_START.md)** - Get started in 5 minutes
- **[IaC Guide](IaC/README.md)** - Infrastructure deployment details
- **[Naming Conventions](IaC/NAMING_CONVENTIONS.md)** - UTS naming standards
- **[Region Guide](IaC/REGIONS_FOR_STUDENTS.md)** - Azure for Students regions

## 🛠️ Prerequisites

- Ruby 3.0+
- Azure CLI (for Azure deployments)
- AWS CLI (for AWS deployments)
- GCP CLI (for GCP deployments)
- OpenAI API account

## 📝 Configuration

Create `.env` in the project root:

```bash
# Azure
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_TENANT_ID=your-tenant-id

# OpenAI (Default)
OPENAI_API_KEY=your-openai-api-key

# Environment
ENVIRONMENT=DEV
AI_PROVIDER=openai
```

## 🎯 Core Features

- ✅ Multi-cloud infrastructure deployment
- ✅ Enterprise naming standards (UTS/DSi Aeris AI)
- ✅ Automatic region validation and qualification
- ✅ OpenAI API integration (default)
- ✅ Azure OpenAI support (optional)
- ✅ Complete resource group JSON export
- ✅ Intelligent error handling and recovery

## 📊 Deployment Output

After deployment, you'll receive:
- ✅ Complete `.env` configuration
- ✅ Full resource group JSON export
- ✅ Connection strings and API keys
- ✅ Endpoint URLs

## 🗑️ Cleanup

```bash
cd IaC
./rag_deploy
# Choose: Destroy All Infrastructure
```

---

**Project**: UTS  
**Standards**: DSi Aeris AI  
**Author**: James Freeman (JamesCurrie.Freeman@uts.edu.au)  
**Last Updated**: November 2025

