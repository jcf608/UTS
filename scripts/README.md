# 🔧 Utility Scripts

Helper scripts for setting up and configuring cloud storage events.

## 🚀 Quick Start: Test Blob Events in Azure

**Want to test blob event processing in Azure?** See: [README_AZURE_TESTING.md](README_AZURE_TESTING.md)

### Deploy Webhook to Azure (5 minutes)

```bash
# Deploy webhook receiver to Azure Container Instances
ruby deploy_webhook_container.rb

# OR deploy to App Service (with HTTPS)
ruby deploy_webhook_to_azure.rb
```

Then configure Event Grid to send events to your webhook.

---

## 📦 Storage Creation

**[create_blob_storage.rb](create_blob_storage.rb)** - Create Azure Blob Storage
```bash
ruby create_blob_storage.rb
```
Creates an Azure Blob Storage account with containers and access policies.

## 🐳 Webhook Deployment

**[deploy_webhook_container.rb](deploy_webhook_container.rb)** - Deploy to Azure Container Instances
```bash
ruby deploy_webhook_container.rb
```
Deploys webhook receiver to Azure Container Instances for testing (easiest method).

**[deploy_webhook_to_azure.rb](deploy_webhook_to_azure.rb)** - Deploy to Azure App Service
```bash
ruby deploy_webhook_to_azure.rb
```
Deploys webhook receiver to Azure App Service with HTTPS support.

## 🔔 Event Triggers Setup

### Azure
**[setup_blob_event_trigger.rb](setup_blob_event_trigger.rb)** - Setup Azure Blob Events
```bash
ruby setup_blob_event_trigger.rb
```
Configures Azure Event Grid triggers for blob storage events.

### AWS
**[setup_aws_s3_events.rb](setup_aws_s3_events.rb)** - Setup AWS S3 Events
```bash
ruby setup_aws_s3_events.rb
```
Configures AWS S3 event notifications with Lambda or webhooks.

### GCP
**[setup_gcp_storage_events.rb](setup_gcp_storage_events.rb)** - Setup GCP Storage Events
```bash
ruby setup_gcp_storage_events.rb
```
Configures Google Cloud Storage event notifications with Cloud Functions.

## 💡 When to Use

These scripts are useful when you need to:
- Set up storage manually (outside of IaC)
- Configure event triggers for document processing
- Test event handling before full deployment
- Debug storage event issues

## 🚀 Recommended Workflow

1. **Deploy infrastructure first** using `IaC/rag_deploy`
2. **Then configure events** using these scripts if needed
3. **Test with examples** from the `examples/` directory

## 📚 Related Documentation

- [Quick Start: Azure Testing](README_AZURE_TESTING.md) - **Start here for testing in Azure**
- [Azure Webhook Deployment Guide](../docs/AZURE_WEBHOOK_DEPLOYMENT.md) - Detailed deployment options
- [Blob Event Guide](../docs/BLOB_EVENT_GUIDE.md) - How blob events work
- [Infrastructure Deployment](../IaC/README.md) - Deploy full infrastructure
- [Examples](../examples/README.md) - Example webhook receivers

