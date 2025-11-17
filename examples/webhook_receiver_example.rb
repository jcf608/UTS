#!/usr/bin/env ruby
# frozen_string_literal: true

# Example webhook receiver for Azure Event Grid blob storage events
# This is a simple Sinatra web server that receives and processes blob upload notifications

require 'sinatra'
require 'json'

# Configure Sinatra
set :port, 4567
set :bind, '0.0.0.0'

# POST endpoint to receive Event Grid webhook notifications
post '/api/blob-upload-webhook' do
  request.body.rewind
  body = request.body.read
  
  begin
    events = JSON.parse(body)
    
    # Handle Event Grid validation (subscription validation handshake)
    if events.is_a?(Array) && events.first['eventType'] == 'Microsoft.EventGrid.SubscriptionValidationEvent'
      validation_code = events.first['data']['validationCode']
      
      puts "📝 Received Event Grid validation request"
      puts "Validation Code: #{validation_code}"
      
      # Return validation response
      content_type :json
      return { validationResponse: validation_code }.to_json
    end
    
    # Process blob storage events
    events.each do |event|
      process_blob_event(event)
    end
    
    status 200
    body 'Events processed successfully'
    
  rescue JSON::ParserError => e
    puts "❌ Error parsing JSON: #{e.message}"
    status 400
    body 'Invalid JSON'
  rescue StandardError => e
    puts "❌ Error processing event: #{e.message}"
    puts e.backtrace
    status 500
    body 'Internal server error'
  end
end

# GET endpoint for health check
get '/health' do
  content_type :json
  { status: 'ok', timestamp: Time.now.iso8601 }.to_json
end

def process_blob_event(event)
  event_type = event['eventType']
  event_time = event['eventTime']
  
  case event_type
  when 'Microsoft.Storage.BlobCreated'
    handle_blob_created(event)
  when 'Microsoft.Storage.BlobDeleted'
    handle_blob_deleted(event)
  else
    puts "ℹ️  Received event type: #{event_type}"
  end
end

def handle_blob_created(event)
  data = event['data']
  
  blob_url = data['url']
  blob_type = data['blobType']
  content_type = data['contentType']
  content_length = data['contentLength']
  
  # Extract container and blob name from subject or URL
  subject = event['subject']
  # Subject format: /blobServices/default/containers/{container}/blobs/{blob-name}
  parts = subject.split('/')
  container_name = parts[parts.index('containers') + 1] if parts.include?('containers')
  blob_name = parts[parts.index('blobs') + 1..-1].join('/') if parts.include?('blobs')
  
  puts
  puts "=" * 60
  puts "🎉 NEW BLOB UPLOADED!"
  puts "=" * 60
  puts "Time:           #{event['eventTime']}"
  puts "Blob URL:       #{blob_url}"
  puts "Container:      #{container_name}"
  puts "Blob Name:      #{blob_name}"
  puts "Blob Type:      #{blob_type}"
  puts "Content Type:   #{content_type}"
  puts "Size:           #{content_length} bytes"
  puts "=" * 60
  puts
  
  # ====================================
  # YOUR APPLICATION LOGIC GOES HERE
  # ====================================
  
  # Example: Load the blob and process it
  process_uploaded_asset(blob_url, container_name, blob_name, content_type)
  
  # Example: Store metadata in database
  # save_to_database(blob_url, container_name, blob_name, content_type, content_length)
  
  # Example: Trigger a processing pipeline
  # trigger_processing_pipeline(blob_url)
end

def handle_blob_deleted(event)
  data = event['data']
  blob_url = data['url']
  
  puts
  puts "🗑️  BLOB DELETED: #{blob_url}"
  puts
  
  # YOUR CLEANUP LOGIC GOES HERE
end

def process_uploaded_asset(blob_url, container, blob_name, content_type)
  puts "📦 Processing asset..."
  puts "   URL: #{blob_url}"
  
  # Example logic based on content type
  case content_type
  when /^image\//
    puts "   Type: Image file"
    # Process image (resize, generate thumbnails, etc.)
    # download_and_process_image(blob_url)
    
  when /^video\//
    puts "   Type: Video file"
    # Process video (transcode, generate preview, etc.)
    # download_and_process_video(blob_url)
    
  when 'application/pdf'
    puts "   Type: PDF document"
    # Process PDF (extract text, generate preview, etc.)
    # download_and_process_pdf(blob_url)
    
  else
    puts "   Type: Generic file (#{content_type})"
    # Generic processing
    # download_and_store(blob_url)
  end
  
  puts "✅ Asset processed successfully"
end

# Example: Download blob using Azure SDK
def download_blob_with_azure_sdk(blob_url)
  # Requires: gem install azure-storage-blob
  require 'azure/storage/blob'
  
  # Parse URL to extract account, container, blob
  uri = URI.parse(blob_url)
  storage_account = uri.host.split('.').first
  path_parts = uri.path.split('/')[1..-1]
  container = path_parts[0]
  blob_name = path_parts[1..-1].join('/')
  
  # Create blob client (uses Azure credentials from environment)
  client = Azure::Storage::Blob::BlobService.create(
    storage_account_name: storage_account
  )
  
  # Download blob
  blob, content = client.get_blob(container, blob_name)
  
  # Process content
  puts "Downloaded #{content.length} bytes"
  
  content
end

# Start server message
puts
puts "=" * 60
puts "🚀 Azure Blob Event Webhook Receiver"
puts "=" * 60
puts "Server starting on http://0.0.0.0:4567"
puts "Webhook endpoint: /api/blob-upload-webhook"
puts "Health check: /health"
puts
puts "To expose this locally with ngrok:"
puts "  ngrok http 4567"
puts
puts "Then use the ngrok URL in Event Grid subscription:"
puts "  https://your-ngrok-url.ngrok.io/api/blob-upload-webhook"
puts "=" * 60
puts

