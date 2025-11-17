# Quick Start: Cloud-Agnostic Blob Storage Events

## TL;DR

One webhook receiver handles blob uploads from **Azure**, **AWS S3**, and **Google Cloud Storage**.

## Setup (5 minutes)

### 1. Start Webhook Receiver

```bash
gem install sinatra
ruby cloud_agnostic_webhook_receiver.rb
```

### 2. Expose Publicly (Development)

```bash
# In another terminal
ngrok http 4567

# Copy the HTTPS URL: https://abc123.ngrok.io
```

### 3. Configure Cloud Provider(s)

**Azure:**
```bash
ruby setup_blob_event_trigger.rb
# Use webhook: https://abc123.ngrok.io/api/blob-webhook
```

**AWS S3:**
```bash
ruby setup_aws_s3_events.rb
# Use webhook: https://abc123.ngrok.io/api/blob-webhook
```

**Google Cloud:**
```bash
ruby setup_gcp_storage_events.rb
# Use webhook: https://abc123.ngrok.io/api/blob-webhook
```

### 4. Test Upload

**Azure:**
```bash
az storage blob upload --account-name ACCOUNT --container-name CONTAINER --name test.txt --file test.txt --auth-mode login
```

**AWS:**
```bash
aws s3 cp test.txt s3://BUCKET/test.txt
```

**GCP:**
```bash
gsutil cp test.txt gs://BUCKET/test.txt
```

## Your Application Logic

Edit `cloud_agnostic_webhook_receiver.rb`:

```ruby
def self.handle_blob_created(event)
  # event.provider    # :azure, :aws, or :gcp
  # event.blob_url    # Full URL to file
  # event.blob_name   # File name
  # event.bucket_name # Container/bucket
  # event.content_type
  # event.size
  
  # YOUR CODE HERE
  download_and_process(event.blob_url)
end
```

## Files Overview

| File | Purpose |
|------|---------|
| `cloud_agnostic_webhook_receiver.rb` | **Main webhook** - handles all providers |
| `setup_blob_event_trigger.rb` | Azure Event Grid setup |
| `setup_aws_s3_events.rb` | AWS S3 + SNS setup |
| `setup_gcp_storage_events.rb` | GCP Storage + Pub/Sub setup |
| `CLOUD_AGNOSTIC_GUIDE.md` | **Full documentation** |
| `QUICK_START.md` | This file |

## Architecture

```
Azure Blob → Event Grid ────┐
                            │
AWS S3 → SNS ───────────────┼──→ Unified Webhook → Your App
                            │
GCP Storage → Pub/Sub ──────┘
```

## Benefits

✅ **One webhook** for all cloud providers  
✅ **Automatic detection** - no manual routing  
✅ **Normalized events** - consistent data structure  
✅ **Easy migration** - switch providers without code changes  

## Production Deployment

Deploy webhook to:
- Azure App Service / Container Instances
- AWS EC2 / ECS / Lambda
- GCP Compute Engine / Cloud Run
- Any Kubernetes cluster
- Any VPS with Ruby

## Costs

All three providers have generous free tiers - typically **$0/month** for normal usage!

## Support

📖 Read `CLOUD_AGNOSTIC_GUIDE.md` for complete documentation  
🔍 Check example code in `cloud_agnostic_webhook_receiver.rb`

