#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to set up Google Cloud Storage event notifications via Pub/Sub
# This enables your application to be notified when objects are uploaded to GCS

require 'json'

class GcpStorageEventSetup
  attr_reader :bucket_name, :topic_name, :webhook_url

  def initialize
    @project_id = ENV['GCP_PROJECT_ID'] || load_from_gcloud
    @bucket_name = nil
    @topic_name = nil
    @webhook_url = nil
    @subscription_name = nil
  end

  def run
    puts "=== Google Cloud Storage Event Notification Setup ==="
    puts
    puts "This script will configure Cloud Storage to send notifications via Pub/Sub"
    puts "when objects are uploaded to your bucket."
    puts

    # Step 1: Verify project
    verify_project

    # Step 2: Select GCS bucket
    select_gcs_bucket

    # Step 3: Create or select Pub/Sub topic
    setup_pubsub_topic

    # Step 4: Configure GCS notification
    configure_gcs_notification

    # Step 5: Create push subscription to webhook
    create_push_subscription

    puts
    puts "✅ GCS event notifications configured successfully!"
    puts
    display_testing_instructions
  end

  private

  def load_from_gcloud
    result = `gcloud config get-value project 2>&1`.strip
    result if $?.success?
  end

  def verify_project
    unless @project_id
      puts "❌ Error: GCP_PROJECT_ID not found in environment"
      puts "   Set it with: export GCP_PROJECT_ID=your-project-id"
      puts "   Or: gcloud config set project your-project-id"
      exit 1
    end

    puts "Using GCP Project: #{@project_id}"
    puts
  end

  def select_gcs_bucket
    puts "Fetching Cloud Storage buckets..."
    result = `gsutil ls 2>&1`

    unless $?.success?
      puts "❌ Error fetching GCS buckets: #{result}"
      exit 1
    end

    buckets = result.split("\n").map { |b| b.gsub('gs://', '').gsub('/', '') }

    if buckets.empty?
      puts "❌ No GCS buckets found. Please create one first."
      exit 1
    end

    puts "Available GCS buckets:"
    buckets.each_with_index do |bucket, index|
      puts "  #{index + 1}. #{bucket}"
    end

    print "\nSelect bucket (1-#{buckets.length}): "
    choice = gets.chomp.to_i

    if choice > 0 && choice <= buckets.length
      @bucket_name = buckets[choice - 1]
      puts "✅ Using bucket: #{@bucket_name}"
    else
      puts "❌ Invalid selection"
      exit 1
    end
    puts
  end

  def setup_pubsub_topic
    puts "=== Pub/Sub Topic Setup ==="
    puts
    puts "Options:"
    puts "  1. Create new Pub/Sub topic"
    puts "  2. Use existing Pub/Sub topic"
    puts

    print "Select option (1-2): "
    choice = gets.chomp.to_i

    case choice
    when 1
      create_pubsub_topic
    when 2
      select_existing_topic
    else
      puts "❌ Invalid selection"
      exit 1
    end
  end

  def create_pubsub_topic
    default_name = "gcs-events-#{@bucket_name}"
    print "Enter Pub/Sub topic name [#{default_name}]: "
    input = gets.chomp
    @topic_name = input.empty? ? default_name : input

    puts "Creating Pub/Sub topic: #{@topic_name}..."
    result = `gcloud pubsub topics create #{@topic_name} --project=#{@project_id} 2>&1`

    unless $?.success?
      if result.include?('already exists')
        puts "⚠️  Topic already exists, using it..."
      else
        puts "❌ Error creating Pub/Sub topic: #{result}"
        exit 1
      end
    else
      puts "✅ Pub/Sub topic created: #{@topic_name}"
    end
    puts
  end

  def select_existing_topic
    result = `gcloud pubsub topics list --project=#{@project_id} --format=json 2>&1`

    unless $?.success?
      puts "❌ Error listing Pub/Sub topics: #{result}"
      exit 1
    end

    topics = JSON.parse(result)

    if topics.empty?
      puts "No existing topics found. Creating new one..."
      create_pubsub_topic
      return
    end

    puts "Available Pub/Sub topics:"
    topics.each_with_index do |topic, index|
      name = topic['name'].split('/').last
      puts "  #{index + 1}. #{name}"
    end

    print "\nSelect topic (1-#{topics.length}): "
    choice = gets.chomp.to_i

    if choice > 0 && choice <= topics.length
      @topic_name = topics[choice - 1]['name'].split('/').last
      puts "✅ Using topic: #{@topic_name}"
    else
      puts "❌ Invalid selection"
      exit 1
    end
    puts
  end

  def configure_gcs_notification
    puts "=== GCS Notification Configuration ==="
    puts

    # Grant GCS permission to publish to Pub/Sub topic
    puts "Granting Cloud Storage permission to publish to Pub/Sub..."

    # Get GCS service account
    service_account = "service-#{get_project_number}@gs-project-accounts.iam.gserviceaccount.com"

    result = `gcloud pubsub topics add-iam-policy-binding #{@topic_name} --member="serviceAccount:#{service_account}" --role="roles/pubsub.publisher" --project=#{@project_id} 2>&1`

    unless $?.success?
      puts "⚠️  Warning: Could not set IAM policy: #{result}"
      puts "   You may need to set this manually in GCP Console"
    else
      puts "✅ IAM policy updated"
    end

    # Configure GCS bucket notification
    puts "Configuring GCS bucket notification..."

    result = `gsutil notification create -t #{@topic_name} -f json -e OBJECT_FINALIZE gs://#{@bucket_name} 2>&1`

    unless $?.success?
      puts "❌ Error configuring GCS notification: #{result}"
      exit 1
    end

    puts "✅ GCS bucket notification configured"
    puts
  end

  def create_push_subscription
    puts "=== Webhook Push Subscription ==="
    puts
    print "Enter your webhook URL: "
    @webhook_url = gets.chomp

    unless @webhook_url.start_with?('https://')
      puts "⚠️  Warning: HTTPS is required for Pub/Sub push subscriptions"
      print "Continue anyway? (y/n): "
      response = gets.chomp.downcase
      exit 0 unless response == 'y'
    end

    default_sub_name = "#{@topic_name}-webhook-sub"
    print "Enter subscription name [#{default_sub_name}]: "
    input = gets.chomp
    @subscription_name = input.empty? ? default_sub_name : input

    puts "Creating push subscription..."

    result = `gcloud pubsub subscriptions create #{@subscription_name} --topic=#{@topic_name} --push-endpoint="#{@webhook_url}" --project=#{@project_id} 2>&1`

    unless $?.success?
      puts "❌ Error creating subscription: #{result}"
      exit 1
    end

    puts "✅ Push subscription created: #{@subscription_name}"
    puts
  end

  def get_project_number
    result = `gcloud projects describe #{@project_id} --format="value(projectNumber)" 2>&1`.strip

    unless $?.success?
      puts "⚠️  Could not get project number, using placeholder"
      return "PROJECT_NUMBER"
    end

    result
  end

  def display_testing_instructions
    puts "=== Testing Instructions ==="
    puts
    puts "1. Ensure your webhook is running and accessible"
    puts
    puts "2. Upload a test file to GCS:"
    puts "   gsutil cp test.txt gs://#{@bucket_name}/test.txt"
    puts
    puts "3. Your webhook should receive a Pub/Sub push notification with GCS event"
    puts
    puts "4. Monitor Pub/Sub subscription:"
    puts "   gcloud pubsub subscriptions describe #{@subscription_name}"
    puts
    puts "5. View notification configuration:"
    puts "   gsutil notification list gs://#{@bucket_name}"
    puts
    puts "Event payload will include:"
    puts "  - Bucket name: message.attributes.bucketId"
    puts "  - Object name: message.attributes.objectId"
    puts "  - Event type: message.attributes.eventType"
    puts "  - Generation: message.attributes.objectGeneration"
    puts
  end
end

# Run the script
if __FILE__ == $PROGRAM_NAME
  setup = GcpStorageEventSetup.new
  setup.run
end
