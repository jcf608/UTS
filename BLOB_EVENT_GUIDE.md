# Azure Blob Storage Event Trigger Guide

This guide explains how to trigger your application when files are uploaded to Azure Blob Storage.

## Overview

When a blob (file) is uploaded to Azure Blob Storage, you can automatically notify your application and pass it the blob's URI for processing.

## Solution: Azure Event Grid

**Azure Event Grid** is the recommended approach for receiving blob storage events. It provides:
- Real-time event notifications (typically < 1 second)
- Reliable delivery with retries
- Support for multiple subscribers
- Built-in filtering capabilities
- Pay-per-event pricing (very cost-effective)

## How It Works

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
│  routes event   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Your webhook    │
│ receives event  │
│ with blob URL   │
└─────────────────┘
```

## Quick Start

### 1. Set Up Event Grid Subscription

Run the setup script:

```bash
ruby setup_blob_event_trigger.rb
```

This interactive script will:
- Select your storage account
- Configure your webhook endpoint URL
- Choose which events to monitor (BlobCreated, BlobDeleted, etc.)
- Optionally filter by container or file type
- Create the Event Grid subscription

### 2. Create Your Webhook Endpoint

You need a publicly accessible HTTPS endpoint to receive events. Options:

#### Option A: Use the Example Sinatra Server

```bash
# Install dependencies
gem install sinatra

# Run the webhook receiver
ruby webhook_receiver_example.rb
```

#### Option B: Use ngrok for Local Development

```bash
# Start your local server on port 4567
ruby webhook_receiver_example.rb

# In another terminal, expose it publicly
ngrok http 4567

# Use the ngrok URL (e.g., https://abc123.ngrok.io/api/blob-upload-webhook)
# when setting up Event Grid
```

#### Option C: Deploy to Production

Deploy your webhook receiver to:
- Azure App Service
- Azure Functions
- Azure Container Instances
- Any web hosting service with HTTPS support

### 3. Test the Integration

Upload a test file:

```bash
az storage blob upload \
  --account-name YOUR_STORAGE_ACCOUNT \
  --container-name YOUR_CONTAINER \
  --name test.txt \
  --file test.txt \
  --auth-mode login
```

Your webhook should receive an event notification!

## Event Payload Structure

When a blob is uploaded, your webhook receives a JSON payload like this:

```json
[
  {
    "topic": "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Storage/storageAccounts/{storage-account}",
    "subject": "/blobServices/default/containers/{container}/blobs/{blob-name}",
    "eventType": "Microsoft.Storage.BlobCreated",
    "eventTime": "2025-11-17T12:34:56.789Z",
    "id": "unique-event-id",
    "data": {
      "api": "PutBlob",
      "clientRequestId": "request-id",
      "requestId": "request-id",
      "eTag": "0x8D...",
      "contentType": "image/jpeg",
      "contentLength": 524288,
      "blobType": "BlockBlob",
      "url": "https://youraccount.blob.core.windows.net/container/file.jpg",
      "sequencer": "000000000000000000000000000000000...",
      "storageDiagnostics": {
        "batchId": "batch-id"
      }
    }
  }
]
```

### Key Fields

- **`data.url`**: Complete blob URL (this is what you pass to your application!)
- **`subject`**: Path containing container and blob name
- **`eventType`**: Type of event (BlobCreated, BlobDeleted, etc.)
- **`data.contentType`**: MIME type of the uploaded file
- **`data.contentLength`**: File size in bytes
- **`eventTime`**: When the event occurred

## Webhook Validation

Event Grid requires webhook validation on first setup:

1. Event Grid sends a validation event to your endpoint
2. Your webhook must extract the `validationCode`
3. Return it in the response: `{ "validationResponse": "code" }`

The example webhook receiver handles this automatically!

## Event Types

Available blob storage events:

- **`Microsoft.Storage.BlobCreated`** - Blob uploaded or created
  - Triggered by: PutBlob, PutBlockList, CopyBlob, FlushWithClose
- **`Microsoft.Storage.BlobDeleted`** - Blob deleted
- **`Microsoft.Storage.BlobTierChanged`** - Blob access tier changed
- **`Microsoft.Storage.BlobInventoryPolicyCompleted`** - Inventory policy completed

Most applications only need `BlobCreated`.

## Filtering Events

You can filter events to reduce noise:

### By Container

Only receive events from specific container:

```bash
--subject-begins-with "/blobServices/default/containers/uploads/"
```

### By File Type

Only receive events for specific file types:

```bash
--subject-ends-with ".jpg"
```

### By Prefix

Only receive events for blobs with specific prefix:

```bash
--subject-begins-with "/blobServices/default/containers/uploads/blobs/images/"
```

The setup script helps you configure these filters interactively.

## Security Considerations

### 1. HTTPS Required

Event Grid only sends to HTTPS endpoints (except localhost for testing).

### 2. Validate Event Origin

Verify events come from Event Grid:

```ruby
def validate_event_grid_signature(request)
  # Check for Event Grid signature header
  signature = request.env['HTTP_AEG_EVENT_TYPE']
  # Validate it matches 'Notification' or 'SubscriptionValidation'
end
```

### 3. Use Managed Identity

For downloading blobs, use managed identity instead of storage keys:

```ruby
# Set up managed identity for your app in Azure Portal
# Then authenticate without storing secrets
require 'azure/storage/blob'
credential = Azure::Storage::Common::Core::TokenCredential.new(
  Azure::Core::TokenProvider.new
)
```

### 4. Network Security

Consider using:
- Event Grid system topics with private endpoints
- VNet integration for your webhook receiver
- Azure Key Vault for storing credentials

## Troubleshooting

### Events Not Received

1. **Check webhook is accessible**:
   ```bash
   curl https://your-webhook-url/health
   ```

2. **Verify Event Grid subscription status**:
   ```bash
   az eventgrid event-subscription show \
     --name YOUR_SUBSCRIPTION_NAME \
     --source-resource-id $(az storage account show \
       --name YOUR_STORAGE --resource-group YOUR_RG --query id -o tsv)
   ```

3. **Check Event Grid delivery metrics**:
   - Go to Azure Portal → Event Grid Subscriptions
   - View delivery success/failure metrics
   - Check dead-letter events

### Webhook Validation Fails

Ensure your endpoint:
- Returns HTTP 200
- Returns JSON: `{ "validationResponse": "the-code" }`
- Responds within 30 seconds

### Events Delayed

Event Grid is usually sub-second, but delays can occur due to:
- Webhook endpoint slow response (timeout is 60 seconds)
- Retry logic if webhook fails
- Azure service issues (check Azure status)

## Alternative Approaches

### Azure Functions (Serverless)

Create a function with blob trigger:

```bash
# Create function app
az functionapp create \
  --resource-group YOUR_RG \
  --name your-function-app \
  --storage-account YOUR_STORAGE \
  --runtime ruby \
  --functions-version 4

# Function is triggered automatically on blob upload
# No need for Event Grid subscription
```

**Pros**: Fully managed, auto-scaling, integrated with storage
**Cons**: Cold start delays, Ruby support limited (use Python/Node.js instead)

### Azure Logic Apps

Visual workflow designer for no-code solutions.

**Pros**: No coding required, many built-in connectors
**Cons**: Less flexible, higher cost for high volume

### Polling

Your application periodically checks for new blobs:

```ruby
# Not recommended - use Event Grid instead!
loop do
  new_blobs = list_blobs_since(last_check)
  new_blobs.each { |blob| process(blob) }
  sleep 60
end
```

**Pros**: Simple, no infrastructure setup
**Cons**: Not real-time, inefficient, higher API costs

## Cost Estimates

Event Grid pricing (as of 2025):
- First 100,000 operations/month: **FREE**
- After that: $0.60 per million operations

For typical usage (100 uploads/day):
- ~3,000 operations/month
- **Cost: $0** (within free tier)

Very cost-effective! 🎉

## Best Practices

1. **Idempotency**: Events may be delivered multiple times - design your handler to be idempotent
2. **Async Processing**: Return HTTP 200 quickly, process blob asynchronously
3. **Error Handling**: Handle blob download failures gracefully
4. **Monitoring**: Log all events and processing results
5. **Dead Letter Queue**: Configure dead-letter destination for failed events
6. **Rate Limiting**: Handle bursts of uploads appropriately

## Next Steps

1. Run `ruby setup_blob_event_trigger.rb` to create Event Grid subscription
2. Start your webhook receiver: `ruby webhook_receiver_example.rb`
3. Test with a blob upload
4. Customize `process_uploaded_asset()` function for your needs
5. Deploy to production!

## Additional Resources

- [Azure Event Grid Documentation](https://docs.microsoft.com/azure/event-grid/)
- [Blob Storage Events Schema](https://docs.microsoft.com/azure/event-grid/event-schema-blob-storage)
- [Event Grid Security](https://docs.microsoft.com/azure/event-grid/security-authentication)

## Support

Questions? Check the Azure documentation or the example code in `webhook_receiver_example.rb`.

