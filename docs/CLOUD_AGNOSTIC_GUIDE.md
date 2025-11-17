# Cloud-Agnostic Blob Storage Event Trigger Guide

This guide explains how to set up blob storage event triggers that work across **Azure**, **AWS**, and **Google Cloud Platform** with a single, unified webhook receiver.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    Cloud Providers                            │
│                                                               │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐       │
│  │   Azure     │   │     AWS     │   │     GCP     │       │
│  │    Blob     │   │     S3      │   │   Storage   │       │
│  │  Storage    │   │             │   │             │       │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘       │
│         │                 │                  │               │
│         ▼                 ▼                  ▼               │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐       │
│  │   Event     │   │     SNS     │   │   Pub/Sub   │       │
│  │    Grid     │   │             │   │             │       │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘       │
│         │                 │                  │               │
└─────────┼─────────────────┼──────────────────┼───────────────┘
          │                 │                  │
          │                 │                  │
          └────────┬────────┴────────┬─────────┘
                   │                 │
                   ▼                 ▼
          ┌────────────────────────────────┐
          │  Cloud-Agnostic Webhook        │
          │  (Unified Receiver)            │
          │                                │
          │  - Detects provider            │
          │  - Normalizes event format     │
          │  - Routes to your app logic    │
          └────────────────────────────────┘
                         │
                         ▼
          ┌────────────────────────────────┐
          │  Your Application Logic        │
          │                                │
          │  - Process uploaded files      │
          │  - Generate thumbnails         │
          │  - Store metadata              │
          │  - Trigger pipelines           │
          └────────────────────────────────┘
```

## Key Features

✅ **Single Webhook** - One endpoint handles all three cloud providers  
✅ **Automatic Detection** - Identifies cloud provider from request  
✅ **Normalized Events** - Converts provider-specific formats to common structure  
✅ **Type Safety** - Unified `BlobEvent` class with consistent fields  
✅ **Easy Migration** - Switch providers without changing application logic  

## Quick Start

### 1. Start the Unified Webhook Receiver

```bash
# Install dependencies
gem install sinatra

# Run the cloud-agnostic webhook receiver
ruby cloud_agnostic_webhook_receiver.rb
```

The server will start on `http://0.0.0.0:4567` with endpoint `/api/blob-webhook`

### 2. Expose Locally with ngrok (Development)

```bash
# In another terminal
ngrok http 4567

# Copy the HTTPS URL (e.g., https://abc123.ngrok.io)
# Use: https://abc123.ngrok.io/api/blob-webhook
```

### 3. Configure Your Cloud Provider(s)

#### Azure Setup

```bash
ruby setup_blob_event_trigger.rb
```

- Select your storage account
- Enter webhook URL: `https://your-domain.com/api/blob-webhook`
- Choose events to monitor (BlobCreated recommended)
- Optionally add filters

#### AWS S3 Setup

```bash
ruby setup_aws_s3_events.rb
```

- Select your S3 bucket
- Create/select SNS topic
- Enter webhook URL: `https://your-domain.com/api/blob-webhook`
- Configure S3 notification

#### Google Cloud Storage Setup

```bash
ruby setup_gcp_storage_events.rb
```

- Select your GCS bucket
- Create/select Pub/Sub topic
- Enter webhook URL: `https://your-domain.com/api/blob-webhook`
- Create push subscription

### 4. Test Each Provider

**Azure:**
```bash
az storage blob upload \
  --account-name YOUR_ACCOUNT \
  --container-name YOUR_CONTAINER \
  --name test.txt \
  --file test.txt \
  --auth-mode login
```

**AWS:**
```bash
aws s3 cp test.txt s3://YOUR_BUCKET/test.txt
```

**Google Cloud:**
```bash
gsutil cp test.txt gs://YOUR_BUCKET/test.txt
```

## Unified Event Structure

All events are normalized to this structure:

```ruby
class BlobEvent
  attr_reader :provider      # :azure, :aws, or :gcp
  attr_reader :event_type    # :created, :deleted, or :updated
  attr_reader :blob_url      # Full URL to the blob
  attr_reader :bucket_name   # Container/bucket name
  attr_reader :blob_name     # Object/blob name (key)
  attr_reader :content_type  # MIME type (if available)
  attr_reader :size          # Size in bytes (if available)
  attr_reader :timestamp     # Event timestamp
  attr_reader :metadata      # Provider-specific extra data
end
```

### Example: Processing Any Provider's Event

```ruby
def process_blob_event(event)
  puts "Provider: #{event.provider}"        # :azure, :aws, or :gcp
  puts "Type: #{event.event_type}"         # :created, :deleted, etc.
  puts "URL: #{event.blob_url}"
  puts "Bucket: #{event.bucket_name}"
  puts "Name: #{event.blob_name}"
  
  # Download and process - same code for all providers!
  download_and_process(event.blob_url, event.provider)
end
```

## Provider-Specific Details

### Azure Blob Storage (Event Grid)

**Event Types:**
- `Microsoft.Storage.BlobCreated` → `:created`
- `Microsoft.Storage.BlobDeleted` → `:deleted`
- `Microsoft.Storage.BlobTierChanged` → `:updated`

**URL Format:**
```
https://youraccount.blob.core.windows.net/container/blob-name
```

**Metadata Includes:**
- `blob_type`: BlockBlob, PageBlob, AppendBlob
- `etag`: Entity tag
- `api`: Operation that triggered event (PutBlob, CopyBlob, etc.)

### AWS S3 (SNS)

**Event Types:**
- `s3:ObjectCreated:*` → `:created`
- `s3:ObjectRemoved:*` → `:deleted`
- `s3:ObjectRestore:*` → `:updated`

**URL Format:**
```
https://bucket-name.s3.region.amazonaws.com/object-key
```

**Metadata Includes:**
- `etag`: Entity tag
- `version_id`: Object version (if versioning enabled)
- `sequencer`: Unique sequence number
- `event_name`: Specific S3 event name

**Note:** S3 events don't include `content_type` - fetch separately if needed

### Google Cloud Storage (Pub/Sub)

**Event Types:**
- `OBJECT_FINALIZE` → `:created`
- `OBJECT_DELETE` → `:deleted`
- `OBJECT_ARCHIVE` → `:updated`

**URL Format:**
```
https://storage.googleapis.com/bucket-name/object-name
```

**Metadata Includes:**
- `generation`: Object generation number
- `metageneration`: Metadata generation number
- `md5_hash`: MD5 hash of object

## Customizing Application Logic

Edit the `BlobEventProcessor` class in `cloud_agnostic_webhook_receiver.rb`:

```ruby
class BlobEventProcessor
  def self.handle_blob_created(event)
    # YOUR CUSTOM LOGIC HERE
    
    case event.provider
    when :azure
      # Azure-specific handling if needed
      download_from_azure(event.blob_url)
    when :aws
      # AWS-specific handling if needed
      download_from_s3(event.blob_url)
    when :gcp
      # GCP-specific handling if needed
      download_from_gcs(event.blob_url)
    end
    
    # Or use provider-agnostic logic
    process_file(event.blob_url, event.content_type)
  end
end
```

## Downloading Blobs

### Azure

```ruby
require 'azure/storage/blob'

client = Azure::Storage::Blob::BlobService.create
blob, content = client.get_blob(container, blob_name)
```

### AWS S3

```ruby
require 'aws-sdk-s3'

s3 = Aws::S3::Client.new
response = s3.get_object(bucket: bucket, key: key)
content = response.body.read
```

### Google Cloud Storage

```ruby
require 'google/cloud/storage'

storage = Google::Cloud::Storage.new
bucket = storage.bucket(bucket_name)
file = bucket.file(object_name)
content = file.download.read
```

### Universal (HTTP)

Works for all providers if blobs are publicly accessible:

```ruby
require 'net/http'
require 'uri'

uri = URI.parse(blob_url)
response = Net::HTTP.get_response(uri)
content = response.body
```

## Security Best Practices

### 1. Validate Event Sources

Each adapter should validate that events come from the legitimate cloud provider.

### 2. Use Managed Identities / IAM Roles

Don't store credentials in code:

- **Azure:** Use Managed Identity
- **AWS:** Use IAM roles for EC2/Lambda/ECS
- **GCP:** Use service accounts with Workload Identity

### 3. HTTPS Only

All cloud providers require HTTPS endpoints for production.

### 4. Implement Authentication

Add authentication to your webhook:

```ruby
post '/api/blob-webhook' do
  # Verify authorization header
  auth_header = request.env['HTTP_AUTHORIZATION']
  halt 401 unless valid_token?(auth_header)
  
  # Process event...
end
```

### 5. Rate Limiting

Protect against event storms:

```ruby
require 'rack/attack'

Rack::Attack.throttle('blob-webhook', limit: 100, period: 60) do |req|
  req.ip if req.path == '/api/blob-webhook'
end
```

## Deployment Options

### Option 1: Cloud VMs

Deploy to a VM on any provider:
- Azure: App Service or VM
- AWS: EC2 or Elastic Beanstalk
- GCP: Compute Engine or App Engine

### Option 2: Containers

Run in a container:

```dockerfile
FROM ruby:3.2
WORKDIR /app
COPY . .
RUN gem install sinatra
EXPOSE 4567
CMD ["ruby", "cloud_agnostic_webhook_receiver.rb"]
```

Deploy to:
- Azure Container Instances
- AWS ECS/Fargate
- GCP Cloud Run

### Option 3: Kubernetes

Deploy to any Kubernetes cluster (AKS, EKS, GKE).

### Option 4: Serverless Functions

Convert to serverless:
- Azure Functions (HTTP trigger)
- AWS Lambda (via API Gateway)
- GCP Cloud Functions (HTTP trigger)

## Troubleshooting

### Events Not Received

1. **Check webhook accessibility:**
   ```bash
   curl https://your-webhook/health
   ```

2. **Verify provider-specific setup:**
   - Azure: Check Event Grid subscription in portal
   - AWS: Verify SNS subscription confirmed
   - GCP: Check Pub/Sub push subscription

3. **Check logs:**
   ```bash
   # Your webhook should log incoming requests
   tail -f webhook.log
   ```

### Provider Not Detected

The webhook logs which adapter it selects. If none match:

1. Check request headers
2. Verify JSON structure
3. Add debug logging to `detect_and_create_adapter`

### Webhook Validation Fails

Each provider has different validation:

- **Azure:** Returns validation code
- **AWS:** Must visit SNS confirmation URL
- **GCP:** No validation required (uses auth)

## Cost Comparison

All three providers offer generous free tiers:

| Provider | Free Tier | After Free Tier |
|----------|-----------|-----------------|
| **Azure Event Grid** | 100K ops/month | $0.60 per million |
| **AWS SNS** | 1M requests/month | $0.50 per million |
| **GCP Pub/Sub** | 10GB/month | $40 per TB |

For typical usage (< 10K events/month): **All are essentially free!** 🎉

## Migration Between Providers

Because events are normalized, migrating is easy:

1. Set up new provider using appropriate setup script
2. Point to same webhook URL
3. Test with new provider
4. Gradually migrate data
5. Decommission old provider

Your application logic doesn't need to change!

## Advanced: Multi-Cloud Strategy

You can use multiple providers simultaneously:

```ruby
def process_blob_event(event)
  # Log which provider sent the event
  log_event_source(event.provider)
  
  # Use provider-aware logic if needed
  if event.provider == :azure
    # Azure-specific optimization
  else
    # Standard processing
  end
  
  # Most logic is provider-agnostic!
  process_file(event.blob_url, event.content_type)
end
```

**Use cases:**
- **High availability:** Replicate across providers
- **Cost optimization:** Use cheapest provider per region
- **Data residency:** Keep data in specific regions/providers
- **Testing:** Test with one provider, production with another

## Next Steps

1. ✅ Start unified webhook: `ruby cloud_agnostic_webhook_receiver.rb`
2. ✅ Expose with ngrok (dev) or deploy (production)
3. ✅ Configure provider(s) using setup scripts
4. ✅ Test with file uploads
5. ✅ Customize `BlobEventProcessor` for your needs
6. ✅ Deploy to production
7. ✅ Add monitoring and alerting

## Additional Resources

- [Azure Event Grid Docs](https://docs.microsoft.com/azure/event-grid/)
- [AWS S3 Event Notifications](https://docs.aws.amazon.com/AmazonS3/latest/userguide/NotificationHowTo.html)
- [GCP Cloud Storage Notifications](https://cloud.google.com/storage/docs/pubsub-notifications)

## Support

Questions? Check the example code in `cloud_agnostic_webhook_receiver.rb` for detailed implementation.

