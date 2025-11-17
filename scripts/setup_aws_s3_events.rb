#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to set up AWS S3 event notifications via SNS
# This enables your application to be notified when objects are uploaded to S3

require 'json'

class AwsS3EventSetup
  attr_reader :bucket_name, :sns_topic_arn, :webhook_url

  def initialize
    @bucket_name = nil
    @sns_topic_arn = nil
    @webhook_url = nil
    @region = ENV['AWS_REGION'] || 'us-east-1'
  end

  def run
    puts "=== AWS S3 Event Notification Setup ==="
    puts
    puts "This script will configure S3 to send notifications via SNS"
    puts "when objects are uploaded to your bucket."
    puts

    # Step 1: Select S3 bucket
    select_s3_bucket

    # Step 2: Create or select SNS topic
    setup_sns_topic

    # Step 3: Subscribe webhook to SNS topic
    subscribe_webhook

    # Step 4: Configure S3 bucket notification
    configure_s3_notification

    puts
    puts "✅ S3 event notifications configured successfully!"
    puts
    display_testing_instructions
  end

  private

  def select_s3_bucket
    puts "Fetching S3 buckets..."
    result = `aws s3api list-buckets --query "Buckets[].Name" --output json 2>&1`

    unless $?.success?
      puts "❌ Error fetching S3 buckets: #{result}"
      exit 1
    end

    buckets = JSON.parse(result)

    if buckets.empty?
      puts "❌ No S3 buckets found. Please create one first."
      exit 1
    end

    puts "Available S3 buckets:"
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

  def setup_sns_topic
    puts "=== SNS Topic Setup ==="
    puts
    puts "Options:"
    puts "  1. Create new SNS topic"
    puts "  2. Use existing SNS topic"
    puts

    print "Select option (1-2): "
    choice = gets.chomp.to_i

    case choice
    when 1
      create_sns_topic
    when 2
      select_existing_topic
    else
      puts "❌ Invalid selection"
      exit 1
    end
  end

  def create_sns_topic
    default_name = "s3-events-#{@bucket_name}"
    print "Enter SNS topic name [#{default_name}]: "
    input = gets.chomp
    topic_name = input.empty? ? default_name : input

    puts "Creating SNS topic: #{topic_name}..."
    result = `aws sns create-topic --name "#{topic_name}" --region #{@region} --output json 2>&1`

    unless $?.success?
      puts "❌ Error creating SNS topic: #{result}"
      exit 1
    end

    topic_data = JSON.parse(result)
    @sns_topic_arn = topic_data['TopicArn']
    puts "✅ SNS topic created: #{@sns_topic_arn}"
    puts
  end

  def select_existing_topic
    result = `aws sns list-topics --region #{@region} --output json 2>&1`

    unless $?.success?
      puts "❌ Error listing SNS topics: #{result}"
      exit 1
    end

    topics = JSON.parse(result)['Topics']

    if topics.empty?
      puts "No existing topics found. Creating new one..."
      create_sns_topic
      return
    end

    puts "Available SNS topics:"
    topics.each_with_index do |topic, index|
      puts "  #{index + 1}. #{topic['TopicArn']}"
    end

    print "\nSelect topic (1-#{topics.length}): "
    choice = gets.chomp.to_i

    if choice > 0 && choice <= topics.length
      @sns_topic_arn = topics[choice - 1]['TopicArn']
      puts "✅ Using topic: #{@sns_topic_arn}"
    else
      puts "❌ Invalid selection"
      exit 1
    end
    puts
  end

  def subscribe_webhook
    puts "=== Webhook Configuration ==="
    puts
    print "Enter your webhook URL: "
    @webhook_url = gets.chomp

    unless @webhook_url.start_with?('https://')
      puts "⚠️  Warning: HTTPS is recommended for production"
      print "Continue anyway? (y/n): "
      response = gets.chomp.downcase
      exit 0 unless response == 'y'
    end

    puts "Subscribing webhook to SNS topic..."
    cmd = <<~CMD.gsub("\n", ' ').strip
      aws sns subscribe
        --topic-arn "#{@sns_topic_arn}"
        --protocol https
        --notification-endpoint "#{@webhook_url}"
        --region #{@region}
        --output json
    CMD

    result = `#{cmd} 2>&1`

    unless $?.success?
      puts "❌ Error subscribing webhook: #{result}"
      exit 1
    end

    subscription = JSON.parse(result)
    puts "✅ Webhook subscribed: #{subscription['SubscriptionArn']}"
    puts
    puts "⚠️  IMPORTANT: You must confirm the subscription by visiting the URL"
    puts "   that will be sent to your webhook endpoint."
    puts "   The cloud-agnostic webhook receiver will auto-confirm if possible."
    puts
  end

  def configure_s3_notification
    puts "=== S3 Bucket Notification Configuration ==="
    puts

    # Allow SNS to receive messages from S3
    puts "Setting SNS topic policy to allow S3 notifications..."
    policy = {
      Version: '2012-10-17',
      Statement: [{
        Effect: 'Allow',
        Principal: { Service: 's3.amazonaws.com' },
        Action: 'SNS:Publish',
        Resource: @sns_topic_arn,
        Condition: {
          ArnLike: {
            'aws:SourceArn': "arn:aws:s3:::#{@bucket_name}"
          }
        }
      }]
    }.to_json

    result = `aws sns set-topic-attributes --topic-arn "#{@sns_topic_arn}" --attribute-name Policy --attribute-value '#{policy}' --region #{@region} 2>&1`

    unless $?.success?
      puts "⚠️  Warning: Could not set topic policy: #{result}"
      puts "   You may need to set this manually in AWS Console"
    else
      puts "✅ SNS topic policy updated"
    end

    # Configure S3 bucket notification
    puts "Configuring S3 bucket notification..."

    notification_config = {
      TopicConfigurations: [{
        TopicArn: @sns_topic_arn,
        Events: ['s3:ObjectCreated:*'],
        Filter: {
          Key: {
            FilterRules: []
          }
        }
      }]
    }.to_json

    # Write config to temp file
    config_file = '/tmp/s3-notification-config.json'
    File.write(config_file, notification_config)

    result = `aws s3api put-bucket-notification-configuration --bucket "#{@bucket_name}" --notification-configuration file://#{config_file} 2>&1`

    unless $?.success?
      puts "❌ Error configuring S3 notification: #{result}"
      exit 1
    end

    puts "✅ S3 bucket notification configured"
    puts
  end

  def display_testing_instructions
    puts "=== Testing Instructions ==="
    puts
    puts "1. Ensure your webhook is running and accessible"
    puts
    puts "2. Upload a test file to S3:"
    puts "   aws s3 cp test.txt s3://#{@bucket_name}/test.txt"
    puts
    puts "3. Your webhook should receive an SNS notification with S3 event"
    puts
    puts "4. Monitor SNS topic:"
    puts "   aws sns get-topic-attributes --topic-arn #{@sns_topic_arn}"
    puts
    puts "Event payload will include:"
    puts "  - Bucket name: Records[0].s3.bucket.name"
    puts "  - Object key: Records[0].s3.object.key"
    puts "  - Object size: Records[0].s3.object.size"
    puts "  - Event time: Records[0].eventTime"
    puts
  end
end

# Run the script
if __FILE__ == $PROGRAM_NAME
  setup = AwsS3EventSetup.new
  setup.run
end
