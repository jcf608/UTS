#!/usr/bin/env ruby
# frozen_string_literal: true

# Deploy webhook receiver to Azure App Service
# This script deploys the Sinatra webhook receiver to Azure for testing

require 'json'

class AzureWebhookDeployer
  attr_reader :subscription_id, :resource_group, :app_name, :location

  def initialize
    @subscription_id = ENV['AZURE_SUBSCRIPTION_ID']
    @resource_group = nil
    @app_name = nil
    @location = 'centralus'
    @app_service_plan = nil
  end

  def run
    puts "=" * 70
    puts "🚀 Azure Webhook Receiver Deployment"
    puts "=" * 70
    puts
    puts "This will deploy your blob event webhook receiver to Azure App Service"
    puts

    check_prerequisites
    authenticate
    select_or_create_resource_group
    configure_app_service
    create_app_service_plan
    create_web_app
    configure_deployment
    deploy_application
    display_webhook_url
    configure_event_grid

    puts
    puts "=" * 70
    puts "✅ Deployment Complete!"
    puts "=" * 70
  end

  private

  def check_prerequisites
    puts "🔍 Checking prerequisites..."

    # Check if az CLI is installed
    unless system('which az > /dev/null 2>&1')
      puts "❌ Azure CLI not found. Please install it:"
      puts "   brew install azure-cli"
      exit 1
    end

    # Check if subscription ID is set
    unless @subscription_id
      puts "❌ AZURE_SUBSCRIPTION_ID not set in environment"
      puts "   Run: export AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)"
      exit 1
    end

    puts "✅ Prerequisites checked"
    puts
  end

  def authenticate
    puts "🔐 Authenticating with Azure..."
    result = `az account set --subscription "#{@subscription_id}" 2>&1`

    unless $?.success?
      puts "❌ Failed to authenticate. Please run: az login"
      exit 1
    end

    puts "✅ Authenticated"
    puts
  end

  def select_or_create_resource_group
    puts "📦 Select or create Resource Group..."

    # List existing resource groups
    result = `az group list --query "[].{Name:name, Location:location}" --output json 2>&1`

    if $?.success?
      groups = JSON.parse(result)

      if groups.any?
        puts
        puts "Existing resource groups:"
        groups.each_with_index do |group, index|
          puts "  #{index + 1}. #{group['Name']} (#{group['Location']})"
        end
        puts "  #{groups.length + 1}. Create new resource group"
        puts

        print "Select option (1-#{groups.length + 1}): "
        choice = gets.chomp.to_i

        if choice > 0 && choice <= groups.length
          @resource_group = groups[choice - 1]['Name']
          @location = groups[choice - 1]['Location']
        elsif choice == groups.length + 1
          create_new_resource_group
        else
          puts "❌ Invalid selection"
          exit 1
        end
      else
        create_new_resource_group
      end
    else
      create_new_resource_group
    end

    puts "✅ Resource Group: #{@resource_group}"
    puts
  end

  def create_new_resource_group
    print "Enter new resource group name [webhook-receiver-rg]: "
    input = gets.chomp
    @resource_group = input.empty? ? "webhook-receiver-rg" : input

    print "Enter location [centralus]: "
    input = gets.chomp
    @location = input.empty? ? "centralus" : input

    puts "Creating resource group..."
    result = `az group create --name "#{@resource_group}" --location "#{@location}" 2>&1`

    unless $?.success?
      puts "❌ Failed to create resource group: #{result}"
      exit 1
    end
  end

  def configure_app_service
    print "Enter web app name [blob-webhook-#{Time.now.to_i}]: "
    input = gets.chomp
    @app_name = input.empty? ? "blob-webhook-#{Time.now.to_i}" : input

    # App Service Plan name
    @app_service_plan = "#{@app_name}-plan"

    puts
  end

  def create_app_service_plan
    puts "📋 Creating App Service Plan..."
    puts "   Plan: #{@app_service_plan}"
    puts "   Tier: F1 (Free)"

    # Check if plan exists
    check_result = `az appservice plan show --name "#{@app_service_plan}" --resource-group "#{@resource_group}" 2>&1`

    if $?.success?
      puts "✅ App Service Plan already exists"
    else
      # Create new plan
      result = `az appservice plan create \
        --name "#{@app_service_plan}" \
        --resource-group "#{@resource_group}" \
        --location "#{@location}" \
        --sku F1 \
        --is-linux 2>&1`

      unless $?.success?
        puts "❌ Failed to create App Service Plan: #{result}"
        puts
        puts "💡 Trying with B1 (Basic) tier instead..."

        result = `az appservice plan create \
          --name "#{@app_service_plan}" \
          --resource-group "#{@resource_group}" \
          --location "#{@location}" \
          --sku B1 \
          --is-linux 2>&1`

        unless $?.success?
          puts "❌ Failed to create App Service Plan: #{result}"
          exit 1
        end
      end

      puts "✅ App Service Plan created"
    end

    puts
  end

  def create_web_app
    puts "🌐 Creating Web App..."
    puts "   Name: #{@app_name}"
    puts "   Runtime: RUBY:3.2"

    # Check if web app exists
    check_result = `az webapp show --name "#{@app_name}" --resource-group "#{@resource_group}" 2>&1`

    if $?.success?
      puts "✅ Web App already exists"
    else
      # Create web app with Ruby runtime
      result = `az webapp create \
        --name "#{@app_name}" \
        --resource-group "#{@resource_group}" \
        --plan "#{@app_service_plan}" \
        --runtime "RUBY:3.2" 2>&1`

      unless $?.success?
        puts "❌ Failed to create Web App: #{result}"
        puts
        puts "💡 Azure App Service might not support Ruby runtime in your region."
        puts "   Consider using Container deployment instead (Option 2)."
        exit 1
      end

      puts "✅ Web App created"
    end

    # Configure app settings
    puts "⚙️  Configuring application settings..."

    `az webapp config appsettings set \
      --name "#{@app_name}" \
      --resource-group "#{@resource_group}" \
      --settings PORT=8080 RACK_ENV=production 2>&1`

    puts
  end

  def configure_deployment
    puts "📦 Configuring deployment..."

    # Enable local git deployment
    result = `az webapp deployment source config-local-git \
      --name "#{@app_name}" \
      --resource-group "#{@resource_group}" 2>&1`

    if $?.success?
      puts "✅ Local Git deployment configured"
    end

    puts
  end

  def deploy_application
    puts "🚀 Deploying application..."
    puts
    puts "To deploy your webhook receiver:"
    puts
    puts "1. Navigate to your webhook receiver directory:"
    puts "   cd #{File.expand_path('../../examples', __dir__)}"
    puts
    puts "2. Create a Gemfile if not exists:"
    puts "   echo 'source \"https://rubygems.org\"' > Gemfile"
    puts "   echo 'gem \"sinatra\"' >> Gemfile"
    puts "   echo 'gem \"puma\"' >> Gemfile"
    puts
    puts "3. Create a config.ru file:"
    puts "   # (See output below)"
    puts
    puts "4. Get deployment credentials:"
    puts "   az webapp deployment list-publishing-credentials \\"
    puts "     --name #{@app_name} \\"
    puts "     --resource-group #{@resource_group}"
    puts
    puts "5. Deploy using Git or ZIP deployment"
    puts

    print "Press Enter to continue..."
    gets
    puts
  end

  def display_webhook_url
    puts "=" * 70
    puts "🎉 Webhook URL Ready!"
    puts "=" * 70
    puts
    puts "Your webhook is available at:"
    puts "  https://#{@app_name}.azurewebsites.net/api/blob-upload-webhook"
    puts
    puts "Health check:"
    puts "  https://#{@app_name}.azurewebsites.net/health"
    puts
    puts "Use this URL when configuring Event Grid subscription"
    puts

    # Save to file
    webhook_info = {
      app_name: @app_name,
      resource_group: @resource_group,
      webhook_url: "https://#{@app_name}.azurewebsites.net/api/blob-upload-webhook",
      health_url: "https://#{@app_name}.azurewebsites.net/health"
    }

    File.write('webhook_deployment_info.json', JSON.pretty_generate(webhook_info))
    puts "📝 Deployment info saved to: webhook_deployment_info.json"
    puts
  end

  def configure_event_grid
    puts "=" * 70
    puts "📡 Next: Configure Event Grid"
    puts "=" * 70
    puts
    puts "Run the Event Grid setup script with your webhook URL:"
    puts
    puts "  cd #{File.expand_path('..', __dir__)}"
    puts "  ruby setup_blob_event_trigger.rb"
    puts
    puts "When prompted for webhook URL, use:"
    puts "  https://#{@app_name}.azurewebsites.net/api/blob-upload-webhook"
    puts
  end
end

# Run the deployment
if __FILE__ == $PROGRAM_NAME
  deployer = AzureWebhookDeployer.new
  deployer.run
end
