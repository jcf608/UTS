#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick deployment of webhook receiver to Azure Container Instances
# This is the easiest way to test your webhook in Azure

require 'json'
require 'fileutils'

class AzureContainerDeployer
  attr_reader :subscription_id, :resource_group, :container_name, :location

  def initialize
    @subscription_id = ENV['AZURE_SUBSCRIPTION_ID']
    @resource_group = "webhook-test-rg"
    @container_name = "blob-webhook-receiver"
    @location = 'centralus'
    @dns_name = "webhook-#{Time.now.to_i}"
    @registry_name = nil
  end

  def run
    puts
    puts "=" * 70
    puts "🐳 Azure Container Instance - Webhook Deployment"
    puts "=" * 70
    puts
    puts "This will deploy your webhook receiver as a container in Azure"
    puts "Perfect for testing blob storage events!"
    puts

    check_prerequisites
    authenticate
    configure_deployment
    build_container_image
    create_container_registry
    push_image_to_acr
    deploy_container_instance
    display_results
    setup_event_grid_instructions
  end

  private

  def check_prerequisites
    puts "🔍 Checking prerequisites..."

    # Check Azure CLI
    unless system('which az > /dev/null 2>&1')
      puts "❌ Azure CLI not found"
      puts "   Install: brew install azure-cli"
      exit 1
    end

    # Check subscription ID
    unless @subscription_id
      puts "❌ AZURE_SUBSCRIPTION_ID not set"
      puts "   Run: export AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)"
      exit 1
    end

    puts "✅ Prerequisites checked"
    puts "   Note: No Docker needed! Azure will build the container for you."
    puts
  end

  def authenticate
    puts "🔐 Authenticating with Azure..."

    result = `az account set --subscription "#{@subscription_id}" 2>&1`

    unless $?.success?
      puts "❌ Authentication failed"
      puts "   Run: az login"
      exit 1
    end

    account_info = `az account show --output json 2>&1`
    if $?.success?
      info = JSON.parse(account_info)
      puts "✅ Authenticated as: #{info['user']['name']}"
      puts "   Subscription: #{info['name']}"
    end

    puts
  end

  def configure_deployment
    puts "⚙️  Configuration"
    puts

    print "Resource Group name [#{@resource_group}]: "
    input = gets.chomp
    @resource_group = input unless input.empty?

    print "Container name [#{@container_name}]: "
    input = gets.chomp
    @container_name = input unless input.empty?

    print "Location [#{@location}]: "
    input = gets.chomp
    @location = input unless input.empty?

    print "DNS name prefix [#{@dns_name}]: "
    input = gets.chomp
    @dns_name = input unless input.empty?

    puts
    puts "Summary:"
    puts "  Resource Group: #{@resource_group}"
    puts "  Container: #{@container_name}"
    puts "  Location: #{@location}"
    puts "  DNS: #{@dns_name}.#{@location}.azurecontainer.io"
    puts

    print "Continue? (y/n): "
    response = gets.chomp.downcase

    unless response == 'y' || response == 'yes'
      puts "Cancelled"
      exit 0
    end

    puts
  end

  def build_container_image
    puts "🔨 Preparing container image..."

    # Get the examples directory
    examples_dir = File.expand_path('../../examples', __dir__)
    dockerfile_path = File.join(examples_dir, 'Dockerfile')

    # Create Dockerfile if it doesn't exist
    unless File.exist?(dockerfile_path)
      puts "📝 Creating Dockerfile..."

      dockerfile_content = <<~DOCKERFILE
        FROM ruby:3.2-slim

        WORKDIR /app

        # Install dependencies
        RUN gem install sinatra puma

        # Copy webhook receiver
        COPY webhook_receiver_example.rb .

        # Expose port
        EXPOSE 4567

        # Use Puma as production server
        ENV RACK_ENV=production

        # Run the application
        CMD ["ruby", "webhook_receiver_example.rb"]
      DOCKERFILE

      File.write(dockerfile_path, dockerfile_content)
      puts "✅ Dockerfile created at: #{dockerfile_path}"
    end

    puts "✅ Container configuration ready"
    puts "   (Azure will build the image in the cloud - no local Docker needed!)"
    puts
  end

  def create_container_registry
    puts "📦 Setting up Azure Container Registry..."

    # Generate unique registry name
    @registry_name = "webhookreg#{Time.now.to_i}"[0..49].downcase.gsub(/[^a-z0-9]/, '')

    # Create resource group if it doesn't exist
    puts "Creating resource group: #{@resource_group}..."
    `az group create --name "#{@resource_group}" --location "#{@location}" --output none 2>&1`

    # Check if registry exists
    check_result = `az acr show --name "#{@registry_name}" --resource-group "#{@resource_group}" 2>&1`

    if $?.success?
      puts "✅ Container Registry already exists"
    else
      puts "Creating container registry: #{@registry_name}..."
      puts "   (This may take a few minutes...)"

      result = `az acr create \
        --resource-group "#{@resource_group}" \
        --name "#{@registry_name}" \
        --sku Basic \
        --admin-enabled true \
        --output none 2>&1`

      unless $?.success?
        puts "❌ Failed to create container registry: #{result}"
        exit 1
      end

      puts "✅ Container Registry created"
    end

    puts
  end

  def push_image_to_acr
    puts "📤 Building and pushing image to Azure Container Registry..."
    puts "   (Building in Azure - no local Docker required!)"
    puts

    # Get the examples directory
    examples_dir = File.expand_path('../../examples', __dir__)

    # Use Azure Container Registry Build (builds in the cloud!)
    puts "Building image in Azure (this may take a few minutes)..."
    puts

    result = system("az acr build \
      --registry #{@registry_name} \
      --image webhook-receiver:latest \
      --file #{examples_dir}/Dockerfile \
      #{examples_dir}")

    unless result
      puts "❌ Failed to build image in Azure"
      exit 1
    end

    puts
    puts "✅ Image built and pushed successfully in Azure"
    puts
  end

  def deploy_container_instance
    puts "🚀 Deploying container instance..."

    # Get ACR details
    login_server = `az acr show --name "#{@registry_name}" --resource-group "#{@resource_group}" --query loginServer --output tsv`.strip

    credentials = `az acr credential show --name "#{@registry_name}" --resource-group "#{@resource_group}" --output json`
    creds = JSON.parse(credentials)
    username = creds['username']
    password = creds['passwords'][0]['value']

    image = "#{login_server}/webhook-receiver:latest"

    puts "Deploying container with image: #{image}"
    puts "   DNS: #{@dns_name}.#{@location}.azurecontainer.io"
    puts

    result = `az container create \
      --resource-group "#{@resource_group}" \
      --name "#{@container_name}" \
      --image "#{image}" \
      --registry-login-server "#{login_server}" \
      --registry-username "#{username}" \
      --registry-password "#{password}" \
      --dns-name-label "#{@dns_name}" \
      --ports 4567 \
      --cpu 1 \
      --memory 1 \
      --location "#{@location}" \
      --output json 2>&1`

    unless $?.success?
      puts "❌ Failed to deploy container: #{result}"
      exit 1
    end

    puts "✅ Container deployed successfully"
    puts

    # Wait a moment for container to start
    puts "⏳ Waiting for container to start..."
    sleep 10

    puts
  end

  def display_results
    puts "=" * 70
    puts "🎉 Deployment Complete!"
    puts "=" * 70
    puts

    # Get container details
    container_info = `az container show \
      --resource-group "#{@resource_group}" \
      --name "#{@container_name}" \
      --output json 2>&1`

    if $?.success?
      info = JSON.parse(container_info)
      fqdn = info.dig('ipAddress', 'fqdn')
      ip = info.dig('ipAddress', 'ip')
      state = info.dig('instanceView', 'state')

      puts "Container Status: #{state}"
      puts "IP Address: #{ip}"
      puts "FQDN: #{fqdn}"
      puts
      puts "🌐 Webhook URLs:"
      puts "   Health:  http://#{fqdn}:4567/health"
      puts "   Webhook: http://#{fqdn}:4567/api/blob-upload-webhook"
      puts

      # Save deployment info
      deployment_info = {
        resource_group: @resource_group,
        container_name: @container_name,
        location: @location,
        fqdn: fqdn,
        ip_address: ip,
        webhook_url: "http://#{fqdn}:4567/api/blob-upload-webhook",
        health_url: "http://#{fqdn}:4567/health",
        deployed_at: Time.now.iso8601
      }

      info_file = 'webhook_container_deployment.json'
      File.write(info_file, JSON.pretty_generate(deployment_info))
      puts "📝 Deployment info saved to: #{info_file}"
      puts

      # Test health endpoint
      puts "🔍 Testing health endpoint..."
      sleep 2
      health_result = `curl -s "http://#{fqdn}:4567/health" 2>&1`

      if $?.success? && health_result.include?('ok')
        puts "✅ Health check passed!"
        puts "   Response: #{health_result}"
      else
        puts "⚠️  Health check pending (container may still be starting)"
        puts "   Try: curl http://#{fqdn}:4567/health"
      end

      puts
    end
  end

  def setup_event_grid_instructions
    # Get FQDN
    container_info = `az container show \
      --resource-group "#{@resource_group}" \
      --name "#{@container_name}" \
      --query "ipAddress.fqdn" --output tsv 2>&1`.strip

    webhook_url = "http://#{container_info}:4567/api/blob-upload-webhook"

    puts "=" * 70
    puts "📡 Next Steps: Configure Event Grid"
    puts "=" * 70
    puts
    puts "1. Run the Event Grid setup script:"
    puts "   cd #{File.expand_path('..', __dir__)}"
    puts "   ruby setup_blob_event_trigger.rb"
    puts
    puts "2. When prompted for webhook URL, use:"
    puts "   #{webhook_url}"
    puts
    puts "⚠️  Note: This uses HTTP (not HTTPS)"
    puts "   Event Grid requires HTTPS for production."
    puts "   For testing, this works, but you may need to configure"
    puts "   'Allow HTTP' in Event Grid settings."
    puts
    puts "3. View container logs:"
    puts "   az container logs --resource-group #{@resource_group} --name #{@container_name} --follow"
    puts
    puts "4. To delete when done:"
    puts "   az container delete --resource-group #{@resource_group} --name #{@container_name} --yes"
    puts
  end
end

# Run the deployment
if __FILE__ == $PROGRAM_NAME
  deployer = AzureContainerDeployer.new
  deployer.run
end
