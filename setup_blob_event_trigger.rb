#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to set up Azure Event Grid subscription for Blob Storage events
# This enables your application to be notified when blobs are uploaded

require 'json'

class AzureBlobEventTriggerSetup
  attr_reader :subscription_id, :resource_group, :storage_account_name, :endpoint_url

  def initialize
    @subscription_id = ENV['AZURE_SUBSCRIPTION_ID'] || load_from_env_file
    @resource_group = nil
    @storage_account_name = nil
    @endpoint_url = nil
    @event_subscription_name = nil
  end

  def run
    puts "=== Azure Blob Event Grid Trigger Setup ==="
    puts
    puts "This script will configure Event Grid to notify your application"
    puts "when new blobs are uploaded to your storage account."
    puts

    # Step 1: Set subscription
    set_subscription

    # Step 2: Select storage account
    select_storage_account

    # Step 3: Configure webhook endpoint
    configure_webhook_endpoint

    # Step 4: Select event types
    select_event_types

    # Step 5: Optional filters (container name, blob prefix/suffix)
    configure_filters

    # Step 6: Confirm and create Event Grid subscription
    confirm_and_create

    puts
    puts "✅ Event Grid subscription created successfully!"
    puts
    display_testing_instructions
  end

  private

  def load_from_env_file
    env_file = File.join(Dir.pwd, '.env')
    return nil unless File.exist?(env_file)

    File.readlines(env_file).each do |line|
      next if line.strip.empty? || line.start_with?('#')
      key, value = line.strip.split('=', 2)
      return value if key == 'AZURE_SUBSCRIPTION_ID'
    end
    nil
  end

  def set_subscription
    unless @subscription_id
      puts "❌ Error: AZURE_SUBSCRIPTION_ID not found in environment or .env file"
      exit 1
    end

    puts "Setting subscription: #{@subscription_id}"
    result = `az account set --subscription "#{@subscription_id}" 2>&1`
    unless $?.success?
      puts "❌ Error setting subscription: #{result}"
      exit 1
    end
    puts "✅ Subscription set"
    puts
  end

  def select_storage_account
    puts "Fetching storage accounts..."
    result = `az storage account list --query "[].{Name:name, ResourceGroup:resourceGroup}" --output json 2>&1`

    unless $?.success?
      puts "❌ Error fetching storage accounts: #{result}"
      exit 1
    end

    accounts = JSON.parse(result)

    if accounts.empty?
      puts "❌ No storage accounts found. Please create one first using create_blob_storage.rb"
      exit 1
    end

    puts "Available storage accounts:"
    accounts.each_with_index do |account, index|
      puts "  #{index + 1}. #{account['Name']} (Resource Group: #{account['ResourceGroup']})"
    end

    print "\nSelect storage account (1-#{accounts.length}): "
    choice = gets.chomp.to_i

    if choice > 0 && choice <= accounts.length
      @storage_account_name = accounts[choice - 1]['Name']
      @resource_group = accounts[choice - 1]['ResourceGroup']
      puts "✅ Using storage account: #{@storage_account_name}"
    else
      puts "❌ Invalid selection"
      exit 1
    end
    puts
  end

  def configure_webhook_endpoint
    puts "=== Webhook Endpoint Configuration ==="
    puts
    puts "Your application needs a publicly accessible HTTPS endpoint to receive events."
    puts "Example: https://yourdomain.com/api/blob-upload-webhook"
    puts
    puts "Options:"
    puts "  1. Enter your production webhook URL"
    puts "  2. Use a development webhook (ngrok, webhook.site, etc.)"
    puts "  3. Use Azure Functions (recommended for serverless)"
    puts

    print "Select option (1-3): "
    choice = gets.chomp.to_i

    case choice
    when 1
      print "Enter your webhook URL: "
      @endpoint_url = gets.chomp
    when 2
      puts
      puts "Development webhook services:"
      puts "  - ngrok: https://ngrok.com (tunnels localhost to public URL)"
      puts "  - webhook.site: https://webhook.site (instant webhook for testing)"
      puts "  - RequestBin: https://requestbin.com"
      puts
      print "Enter your development webhook URL: "
      @endpoint_url = gets.chomp
    when 3
      puts
      puts "To use Azure Functions, you'll need to:"
      puts "  1. Create a Function App: az functionapp create ..."
      puts "  2. Deploy your function code"
      puts "  3. Get the function URL: az functionapp function show ..."
      puts
      puts "For now, you can use a placeholder and update it later."
      print "Enter Azure Function URL (or press Enter to use placeholder): "
      url = gets.chomp
      @endpoint_url = url.empty? ? "https://placeholder-update-later.azurewebsites.net/api/blob-event" : url
    else
      puts "❌ Invalid selection"
      exit 1
    end

    unless @endpoint_url.start_with?('https://')
      puts "⚠️  Warning: Event Grid requires HTTPS endpoints"
      print "Continue anyway? (y/n): "
      response = gets.chomp.downcase
      exit 0 unless response == 'y' || response == 'yes'
    end

    print "Enter event subscription name [blob-events-#{Time.now.to_i}]: "
    input = gets.chomp
    @event_subscription_name = input.empty? ? "blob-events-#{Time.now.to_i}" : input

    puts
  end

  def select_event_types
    puts "=== Event Types ==="
    puts
    puts "Select which events should trigger your application:"
    puts "  1. BlobCreated only (recommended - triggers on new uploads)"
    puts "  2. BlobDeleted only"
    puts "  3. Both BlobCreated and BlobDeleted"
    puts "  4. All blob events"
    puts

    print "Select option (1-4) [1]: "
    choice = gets.chomp
    choice = "1" if choice.empty?

    @event_types = case choice
    when "1"
      ["Microsoft.Storage.BlobCreated"]
    when "2"
      ["Microsoft.Storage.BlobDeleted"]
    when "3"
      ["Microsoft.Storage.BlobCreated", "Microsoft.Storage.BlobDeleted"]
    when "4"
      ["Microsoft.Storage.BlobCreated", "Microsoft.Storage.BlobDeleted",
       "Microsoft.Storage.BlobTierChanged", "Microsoft.Storage.BlobInventoryPolicyCompleted"]
    else
      puts "Invalid choice, using BlobCreated only"
      ["Microsoft.Storage.BlobCreated"]
    end

    puts "✅ Event types: #{@event_types.join(', ')}"
    puts
  end

  def configure_filters
    puts "=== Optional Filters ==="
    puts
    puts "You can filter events by container name or blob name patterns."
    puts

    print "Filter by specific container? (y/n): "
    if gets.chomp.downcase == 'y'
      print "Enter container name: "
      @container_filter = gets.chomp
    end

    print "Filter by blob prefix (e.g., 'uploads/')? (y/n): "
    if gets.chomp.downcase == 'y'
      print "Enter prefix: "
      @blob_prefix = gets.chomp
    end

    print "Filter by blob suffix (e.g., '.jpg', '.pdf')? (y/n): "
    if gets.chomp.downcase == 'y'
      print "Enter suffix: "
      @blob_suffix = gets.chomp
    end

    puts
  end

  def confirm_and_create
    puts "=== Configuration Summary ==="
    puts "Subscription:           #{@subscription_id}"
    puts "Storage Account:        #{@storage_account_name}"
    puts "Resource Group:         #{@resource_group}"
    puts "Event Subscription:     #{@event_subscription_name}"
    puts "Webhook Endpoint:       #{@endpoint_url}"
    puts "Event Types:            #{@event_types.join(', ')}"
    puts "Container Filter:       #{@container_filter || 'None'}"
    puts "Blob Prefix Filter:     #{@blob_prefix || 'None'}"
    puts "Blob Suffix Filter:     #{@blob_suffix || 'None'}"
    puts

    print "Create Event Grid subscription? (y/n): "
    response = gets.chomp.downcase

    unless response == 'y' || response == 'yes'
      puts "❌ Cancelled by user"
      exit 0
    end

    create_event_subscription
  end

  def create_event_subscription
    puts
    puts "Creating Event Grid subscription..."

    # Get storage account resource ID
    storage_id = get_storage_account_id

    # Build the command
    cmd = build_event_subscription_command(storage_id)

    puts "Executing command..."
    result = `#{cmd} 2>&1`

    unless $?.success?
      puts "❌ Error creating Event Grid subscription: #{result}"
      exit 1
    end

    puts "✅ Event Grid subscription created successfully"
  end

  def get_storage_account_id
    result = `az storage account show --name "#{@storage_account_name}" --resource-group "#{@resource_group}" --query id -o tsv 2>&1`

    unless $?.success?
      puts "❌ Error getting storage account ID: #{result}"
      exit 1
    end

    result.strip
  end

  def build_event_subscription_command(storage_id)
    cmd = <<~CMD.gsub("\n", ' ').strip
      az eventgrid event-subscription create
        --name "#{@event_subscription_name}"
        --source-resource-id "#{storage_id}"
        --endpoint "#{@endpoint_url}"
        --endpoint-type webhook
        --included-event-types #{@event_types.join(' ')}
    CMD

    # Add subject filters if specified
    if @container_filter || @blob_prefix || @blob_suffix
      filters = []

      if @container_filter && @blob_prefix
        prefix = "/blobServices/default/containers/#{@container_filter}/blobs/#{@blob_prefix}"
        filters << "--subject-begins-with \"#{prefix}\""
      elsif @container_filter
        prefix = "/blobServices/default/containers/#{@container_filter}/"
        filters << "--subject-begins-with \"#{prefix}\""
      elsif @blob_prefix
        filters << "--subject-begins-with \"/blobServices/default/containers/\"" # Will need manual refinement
      end

      if @blob_suffix
        filters << "--subject-ends-with \"#{@blob_suffix}\""
      end

      cmd += " " + filters.join(' ')
    end

    cmd
  end

  def display_testing_instructions
    puts "=== Next Steps ==="
    puts
    puts "1. Verify your webhook endpoint is ready to receive events"
    puts "   Event Grid will send a validation request first."
    puts
    puts "2. Test by uploading a blob:"
    puts "   az storage blob upload \\"
    puts "     --account-name #{@storage_account_name} \\"
    puts "     --container-name <container-name> \\"
    puts "     --name test.txt \\"
    puts "     --file test.txt \\"
    puts "     --auth-mode login"
    puts
    puts "3. View Event Grid metrics:"
    puts "   https://portal.azure.com -> Event Grid Subscriptions -> #{@event_subscription_name}"
    puts
    puts "4. Monitor events:"
    puts "   az eventgrid event-subscription show \\"
    puts "     --name #{@event_subscription_name} \\"
    puts "     --source-resource-id $(az storage account show \\"
    puts "       --name #{@storage_account_name} \\"
    puts "       --resource-group #{@resource_group} \\"
    puts "       --query id -o tsv)"
    puts
    puts "Event payload will include:"
    puts "  - Blob URL: data.url (e.g., https://#{@storage_account_name}.blob.core.windows.net/...)"
    puts "  - Container: extracted from subject path"
    puts "  - Blob name: extracted from subject path"
    puts "  - Event time: eventTime"
    puts "  - Event type: eventType"
    puts
  end
end

# Run the script
if __FILE__ == $PROGRAM_NAME
  setup = AzureBlobEventTriggerSetup.new
  setup.run
end
