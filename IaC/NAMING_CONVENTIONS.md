# UTS RAG System - Naming Conventions

Following **DSi Aeris AI enterprise standards** with Azure naming restrictions.

## 🏢 Project Code
- **Project**: `UTS`
- **Environment**: `DEV` / `TEST` / `PROD`

---

## 📋 Naming Patterns

### Resource Group ✅ (Uppercase Allowed)
```
Format: UTS-{ENV}-RG
Examples:
  - UTS-DEV-RG
  - UTS-TEST-RG
  - UTS-PROD-RG
```

### Storage Account ⚠️ (MUST be lowercase - Azure limitation)
```
Format: uts{env}stg{region}{random}
Examples:
  - utsdevstgsea4a2f1c  (UTS DEV Storage Southeast Asia)
  - utstststgcus3b9e2a  (UTS TEST Storage Central US)
  - utsprdstgwu2f8c1d4  (UTS PROD Storage West US 2)

Note: 
  - No hyphens allowed (Azure restriction)
  - Lowercase only (Azure restriction)
  - 3-24 characters max
  - Must be globally unique
```

### Search Service ⚠️ (Must be lowercase - Azure limitation)
```
Format: uts-{env}-search-{region}-{id}
Examples:
  - uts-dev-search-sea-3f
  - uts-test-search-cus-9a
  - uts-prod-search-wu2-2b

Note:
  - Lowercase only (Azure restriction)
  - Hyphens allowed (can't start/end with hyphen)
  - Must be globally unique
```

### OpenAI Service ⚠️ (Must be lowercase - Azure limitation)
```
Format: uts-{env}-openai-{region}-{id}
Examples:
  - uts-dev-openai-sea-7c
  - uts-test-openai-cus-4d
  - uts-prod-openai-wu2-1a

Note:
  - Lowercase only (Azure restriction)
  - Must be globally unique
```

### Blob Container
```
Format: documents
Note: Standard name, lowercase
```

---

## 🌍 Region Codes

| Azure Region | Code | Example |
|--------------|------|---------|
| Central US | `cus` | utsdevstgcus |
| East US | `eus` | utsdevstgeus |
| West US 2 | `wu2` | utsdevstgwu2 |
| Southeast Asia | `sea` | utsdevstgsea |
| East Asia | `eas` | utsdevstgeas |
| North Europe | `neu` | utsdevstgneu |
| West Europe | `weu` | utsdevstgweu |
| UK South | `uks` | utsdevstguks |
| Japan East | `jpe` | utsdevstgjpe |
| Canada Central | `cac` | utsdevstgcac |

---

## 🎯 Default Configuration

**AI Provider**: OpenAI API (External) - **DEFAULT**
- Rationale: Most Azure for Students subscriptions lack Azure OpenAI quota
- Requires: `OPENAI_API_KEY` in `.env` file
- Cost: Pay-per-use to OpenAI directly

**To Use Azure OpenAI** (if you get quota access):
```bash
# In your .env file:
AI_PROVIDER=azure_openai
AZURE_OPENAI_API_KEY=your-key
AZURE_OPENAI_ENDPOINT=https://uts-dev-openai-sea.openai.azure.com
```

---

## 📝 Environment Variables

### Required
```bash
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_TENANT_ID=your-tenant-id
OPENAI_API_KEY=your-openai-api-key
```

### Optional
```bash
# Environment (default: DEV)
ENVIRONMENT=DEV

# AI Provider (default: openai)
AI_PROVIDER=openai

# Region (default: centralus)
AZURE_LOCATION=southeastasia

# Override auto-generated names
AZURE_RESOURCE_GROUP=UTS-DEV-RG
AZURE_STORAGE_ACCOUNT=utsdevstgsea4a2f1c
```

---

## 🚫 Azure Naming Restrictions

**Why not all uppercase?**

Azure enforces strict naming rules for certain resources:

| Resource | Uppercase? | Hyphens? | Max Length |
|----------|-----------|----------|------------|
| Resource Group | ✅ Yes | ✅ Yes | 90 chars |
| Storage Account | ❌ **NO** | ❌ **NO** | 24 chars |
| Search Service | ❌ **NO** | ✅ Yes | 60 chars |
| OpenAI Service | ❌ **NO** | ✅ Yes | 64 chars |
| Blob Container | ❌ **NO** | ✅ Yes | 63 chars |

**Official Azure Documentation:**
- Storage: https://learn.microsoft.com/azure/storage/common/storage-account-overview#storage-account-name
- Search: https://learn.microsoft.com/azure/search/search-limits-quotas-capacity#service-names

---

## ✅ Compliance Strategy

We follow DSi Aeris AI standards **where Azure permits**:

1. ✅ **Use UPPERCASE** for resource groups (UTS-DEV-RG)
2. ⚠️ **Use lowercase** for services with restrictions (utsdevstgsea)
3. ✅ **Include project code** in all names (UTS/uts)
4. ✅ **Include environment** in all names (DEV/dev)
5. ✅ **Include region code** for geo-identification
6. ✅ **Use consistent separators** (hyphens where allowed)

This ensures **maximum compliance** with DSi standards while respecting Azure's technical limitations.

---

## 📊 Example Full Deployment

```
🏢 Project: UTS
🌍 Environment: DEV
🤖 AI Provider: OPENAI (External API - DEFAULT)

Resources Created:
  ✅ Resource Group:    UTS-DEV-RG
  ✅ Location:          southeastasia
  ✅ Storage Account:   utsdevstgsea4a2f1c
  ✅ Blob Container:    documents
  ✅ Search Service:    uts-dev-search-sea-3f

External Services:
  🔗 OpenAI API:        api.openai.com
  🔑 API Key:           (from .env file)
```

---

**Last Updated**: 2025-11-17
**Azure Naming Rules**: https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules

