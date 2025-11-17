#!/usr/bin/env ruby
# frozen_string_literal: true

# Cloud-agnostic webhook receiver for blob storage events
# Supports: Azure Blob Storage, AWS S3, Google Cloud Storage

require 'sinatra'
require 'json'
require 'base64'

# Configure Sinatra
set :port, 4567
set :bind, '0.0.0.0'

# =============================================================================
# CLOUD PROVIDER ADAPTERS
# =============================================================================

# Base class for cloud storage event adapters
class CloudStorageEventAdapter
  def self.can_handle?(request, body)
    raise NotImplementedError, "Subclass must implement can_handle?"
  end

  def initialize(event_data)
    @raw_event = event_data
  end

  def extract_events
    raise NotImplementedError, "Subclass must implement extract_events"
  end

  def validate_and_respond(request)
    # Optional: Handle provider-specific validation
    # Returns [status_code, response_body] or nil to continue normal processing
    nil
  end
end

# Normalized event structure (cloud-agnostic)
class BlobEvent
  attr_reader :provider, :event_type, :blob_url, :bucket_name, :blob_name,
              :content_type, :size, :timestamp, :metadata

  def initialize(provider:, event_type:, blob_url:, bucket_name:, blob_name:,
                 content_type: nil, size: nil, timestamp: nil, metadata: {})
    @provider = provider        # :azure, :aws, :gcp
    @event_type = event_type    # :created, :deleted, :updated
    @blob_url = blob_url
    @bucket_name = bucket_name  # container/bucket name
    @blob_name = blob_name
    @content_type = content_type
    @size = size
    @timestamp = timestamp
    @metadata = metadata
  end

  def to_s
    <<~INFO
      Provider:      #{@provider.to_s.upcase}
      Event Type:    #{@event_type}
      Blob URL:      #{@blob_url}
      Bucket:        #{@bucket_name}
      Blob Name:     #{@blob_name}
      Content Type:  #{@content_type || 'N/A'}
      Size:          #{@size ? "#{@size} bytes" : 'N/A'}
      Timestamp:     #{@timestamp || 'N/A'}
    INFO
  end
end

# =============================================================================
# AZURE BLOB STORAGE ADAPTER
# =============================================================================

class AzureEventGridAdapter < CloudStorageEventAdapter
  def self.can_handle?(request, body)
    # Azure Event Grid sends specific headers
    request.env['HTTP_AEG_EVENT_TYPE'] ||
    (body.is_a?(Array) && body.first&.dig('eventType')&.start_with?('Microsoft.'))
  end

  def extract_events
    events = []

    @raw_event.each do |event|
      next unless event['eventType']&.include?('Storage.Blob')

      event_type = case event['eventType']
      when /BlobCreated/ then :created
      when /BlobDeleted/ then :deleted
      when /BlobTierChanged/ then :updated
      else :unknown
      end

      next if event_type == :unknown

      data = event['data']
      subject = event['subject']

      # Parse subject: /blobServices/default/containers/{container}/blobs/{blob-name}
      parts = subject.split('/')
      container_idx = parts.index('containers')
      blob_idx = parts.index('blobs')

      container_name = container_idx ? parts[container_idx + 1] : nil
      blob_name = blob_idx ? parts[blob_idx + 1..-1].join('/') : nil

      events << BlobEvent.new(
        provider: :azure,
        event_type: event_type,
        blob_url: data['url'],
        bucket_name: container_name,
        blob_name: blob_name,
        content_type: data['contentType'],
        size: data['contentLength'],
        timestamp: event['eventTime'],
        metadata: {
          blob_type: data['blobType'],
          etag: data['eTag'],
          api: data['api']
        }
      )
    end

    events
  end

  def validate_and_respond(request)
    # Handle Event Grid subscription validation
    if @raw_event.is_a?(Array) &&
       @raw_event.first&.dig('eventType') == 'Microsoft.EventGrid.SubscriptionValidationEvent'

      validation_code = @raw_event.first['data']['validationCode']

      puts "📝 Azure Event Grid validation request received"
      puts "Validation Code: #{validation_code}"

      return [200, { validationResponse: validation_code }.to_json]
    end

    nil
  end
end

# =============================================================================
# AWS S3 ADAPTER (via SNS)
# =============================================================================

class AwsS3Adapter < CloudStorageEventAdapter
  def self.can_handle?(request, body)
    # AWS SNS sends specific headers
    request.env['HTTP_X_AMZ_SNS_MESSAGE_TYPE'] ||
    body.is_a?(Hash) && (body['Type'] || body['Records']&.first&.dig('eventSource') == 'aws:s3')
  end

  def extract_events
    events = []

    # Handle SNS wrapper
    if @raw_event['Type'] == 'Notification' && @raw_event['Message']
      message = JSON.parse(@raw_event['Message'])
    else
      message = @raw_event
    end

    # Handle S3 event records
    records = message['Records'] || []

    records.each do |record|
      next unless record['eventSource'] == 'aws:s3'

      event_name = record['eventName']
      event_type = case event_name
      when /ObjectCreated/ then :created
      when /ObjectRemoved/ then :deleted
      when /ObjectRestore/ then :updated
      else :unknown
      end

      next if event_type == :unknown

      s3 = record['s3']
      bucket = s3['bucket']['name']
      object = s3['object']
      key = URI.decode_www_form_component(object['key'])

      # Construct S3 URL
      region = record['awsRegion']
      blob_url = "https://#{bucket}.s3.#{region}.amazonaws.com/#{key}"

      events << BlobEvent.new(
        provider: :aws,
        event_type: event_type,
        blob_url: blob_url,
        bucket_name: bucket,
        blob_name: key,
        content_type: nil, # S3 events don't include content type
        size: object['size'],
        timestamp: record['eventTime'],
        metadata: {
          etag: object['eTag'],
          version_id: object['versionId'],
          sequencer: object['sequencer'],
          event_name: event_name
        }
      )
    end

    events
  end

  def validate_and_respond(request)
    # Handle SNS subscription confirmation
    if @raw_event['Type'] == 'SubscriptionConfirmation'
      subscribe_url = @raw_event['SubscribeURL']

      puts "📝 AWS SNS subscription confirmation received"
      puts "Subscribe URL: #{subscribe_url}"
      puts "⚠️  You need to visit this URL to confirm the subscription:"
      puts subscribe_url

      # Auto-confirm by visiting the URL
      require 'net/http'
      begin
        uri = URI(subscribe_url)
        response = Net::HTTP.get_response(uri)
        if response.is_a?(Net::HTTPSuccess)
          puts "✅ Subscription confirmed automatically"
        else
          puts "❌ Auto-confirmation failed - please visit URL manually"
        end
      rescue => e
        puts "❌ Error confirming subscription: #{e.message}"
        puts "Please visit the URL manually to confirm"
      end

      return [200, 'Subscription confirmation processed']
    end

    nil
  end
end

# =============================================================================
# GOOGLE CLOUD STORAGE ADAPTER (via Pub/Sub)
# =============================================================================

class GcpStorageAdapter < CloudStorageEventAdapter
  def self.can_handle?(request, body)
    # GCP Pub/Sub sends messages with specific structure
    body.is_a?(Hash) && body['message'] && body['subscription']
  end

  def extract_events
    events = []

    # Decode Pub/Sub message
    message_data = @raw_event.dig('message', 'data')
    attributes = @raw_event.dig('message', 'attributes') || {}

    if message_data
      # Data is base64 encoded
      decoded = Base64.decode64(message_data)
      event_data = JSON.parse(decoded)
    else
      # Attributes contain the event data
      event_data = attributes
    end

    # GCS event format
    event_type_str = attributes['eventType'] || event_data['eventType']
    event_type = case event_type_str
    when /OBJECT_FINALIZE/ then :created
    when /OBJECT_DELETE/ then :deleted
    when /OBJECT_ARCHIVE/ then :updated
    else :unknown
    end

    return events if event_type == :unknown

    bucket = attributes['bucketId'] || event_data['bucket']
    object_name = attributes['objectId'] || event_data['name']

    # Construct GCS URL
    blob_url = "https://storage.googleapis.com/#{bucket}/#{object_name}"

    events << BlobEvent.new(
      provider: :gcp,
      event_type: event_type,
      blob_url: blob_url,
      bucket_name: bucket,
      blob_name: object_name,
      content_type: event_data['contentType'],
      size: event_data['size']&.to_i,
      timestamp: event_data['timeCreated'] || @raw_event.dig('message', 'publishTime'),
      metadata: {
        generation: event_data['generation'],
        metageneration: event_data['metageneration'],
        md5_hash: event_data['md5Hash']
      }
    )

    events
  end

  def validate_and_respond(request)
    # GCP Pub/Sub doesn't require special validation
    nil
  end
end

# =============================================================================
# EVENT PROCESSOR - YOUR APPLICATION LOGIC
# =============================================================================

class BlobEventProcessor
  def self.process(blob_event)
    puts
    puts "=" * 70
    puts "🎉 NEW BLOB STORAGE EVENT"
    puts "=" * 70
    puts blob_event.to_s
    puts "=" * 70
    puts

    # Route to specific handler based on event type
    case blob_event.event_type
    when :created
      handle_blob_created(blob_event)
    when :deleted
      handle_blob_deleted(blob_event)
    when :updated
      handle_blob_updated(blob_event)
    end
  end

  def self.handle_blob_created(event)
    puts "📦 Processing new blob..."

    # YOUR APPLICATION LOGIC GOES HERE
    # Examples:
    # - Download and process the file
    # - Store metadata in database
    # - Trigger processing pipeline
    # - Send notifications
    # - Generate thumbnails/previews

    case event.content_type
    when /^image\//
      process_image(event)
    when /^video\//
      process_video(event)
    when 'application/pdf'
      process_pdf(event)
    else
      process_generic_file(event)
    end

    puts "✅ Blob processed successfully"
  end

  def self.handle_blob_deleted(event)
    puts "🗑️  Processing blob deletion..."

    # YOUR CLEANUP LOGIC GOES HERE
    # Examples:
    # - Remove from database
    # - Delete related files
    # - Update indexes

    puts "✅ Deletion processed"
  end

  def self.handle_blob_updated(event)
    puts "🔄 Processing blob update..."

    # YOUR UPDATE LOGIC GOES HERE

    puts "✅ Update processed"
  end

  # Example processing methods
  def self.process_image(event)
    puts "   Type: Image file"
    puts "   Provider: #{event.provider.to_s.upcase}"
    puts "   URL: #{event.blob_url}"
    # download_and_resize(event.blob_url, event.provider)
    # generate_thumbnails(event.blob_url, event.provider)
  end

  def self.process_video(event)
    puts "   Type: Video file"
    puts "   Provider: #{event.provider.to_s.upcase}"
    puts "   URL: #{event.blob_url}"
    # transcode_video(event.blob_url, event.provider)
    # generate_preview(event.blob_url, event.provider)
  end

  def self.process_pdf(event)
    puts "   Type: PDF document"
    puts "   Provider: #{event.provider.to_s.upcase}"
    puts "   URL: #{event.blob_url}"
    # extract_text(event.blob_url, event.provider)
    # generate_preview(event.blob_url, event.provider)
  end

  def self.process_generic_file(event)
    puts "   Type: Generic file (#{event.content_type})"
    puts "   Provider: #{event.provider.to_s.upcase}"
    puts "   URL: #{event.blob_url}"
    # store_metadata(event)
  end
end

# =============================================================================
# SINATRA WEB SERVER
# =============================================================================

# Unified webhook endpoint for all cloud providers
post '/api/blob-webhook' do
  request.body.rewind
  raw_body = request.body.read

  begin
    # Try to parse as JSON
    parsed_body = JSON.parse(raw_body)
  rescue JSON::ParserError => e
    puts "❌ Error parsing JSON: #{e.message}"
    status 400
    return 'Invalid JSON'
  end

  # Detect cloud provider and create appropriate adapter
  adapter = detect_and_create_adapter(request, parsed_body)

  unless adapter
    puts "⚠️  Unknown cloud provider or event format"
    status 400
    return 'Unsupported event format'
  end

  # Handle provider-specific validation
  validation_response = adapter.validate_and_respond(request)
  if validation_response
    status validation_response[0]
    content_type :json if validation_response[1].is_a?(String) && validation_response[1].start_with?('{')
    return validation_response[1]
  end

  # Extract normalized events
  begin
    events = adapter.extract_events

    # Process each event
    events.each do |event|
      BlobEventProcessor.process(event)
    end

    status 200
    body "Processed #{events.length} event(s) successfully"

  rescue StandardError => e
    puts "❌ Error processing events: #{e.message}"
    puts e.backtrace.join("\n")
    status 500
    body 'Internal server error'
  end
end

# Health check endpoint
get '/health' do
  content_type :json
  {
    status: 'ok',
    timestamp: Time.now.iso8601,
    supported_providers: ['azure', 'aws', 'gcp']
  }.to_json
end

# Provider-specific endpoints (optional, for clarity)
post '/api/blob-webhook/azure' do
  request.body.rewind
  redirect '/api/blob-webhook'
end

post '/api/blob-webhook/aws' do
  request.body.rewind
  redirect '/api/blob-webhook'
end

post '/api/blob-webhook/gcp' do
  request.body.rewind
  redirect '/api/blob-webhook'
end

# =============================================================================
# HELPER METHODS
# =============================================================================

def detect_and_create_adapter(request, parsed_body)
  adapters = [
    AzureEventGridAdapter,
    AwsS3Adapter,
    GcpStorageAdapter
  ]

  adapters.each do |adapter_class|
    if adapter_class.can_handle?(request, parsed_body)
      puts "✅ Detected provider: #{adapter_class.name}"
      return adapter_class.new(parsed_body)
    end
  end

  nil
end

# =============================================================================
# STARTUP
# =============================================================================

puts
puts "=" * 70
puts "🚀 Cloud-Agnostic Blob Storage Event Receiver"
puts "=" * 70
puts "Supported Providers:"
puts "  ✓ Azure Blob Storage (via Event Grid)"
puts "  ✓ AWS S3 (via SNS/SQS)"
puts "  ✓ Google Cloud Storage (via Pub/Sub)"
puts
puts "Server starting on http://0.0.0.0:4567"
puts
puts "Endpoints:"
puts "  POST /api/blob-webhook          (unified endpoint)"
puts "  POST /api/blob-webhook/azure    (Azure-specific)"
puts "  POST /api/blob-webhook/aws      (AWS-specific)"
puts "  POST /api/blob-webhook/gcp      (GCP-specific)"
puts "  GET  /health                    (health check)"
puts
puts "For local development with ngrok:"
puts "  ngrok http 4567"
puts "  Use: https://your-id.ngrok.io/api/blob-webhook"
puts "=" * 70
puts
