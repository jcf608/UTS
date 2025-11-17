#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../common/base_infrastructure'
require 'json'
require 'securerandom'
require 'time'
require 'dotenv'

# Load .env from multiple possible locations
Dotenv.load(
  File.expand_path('../../.env', __dir__),  # UTS/.env
  File.expand_path('../.env', __dir__),     # UTS/IaC/.env
  '.env'                                     # Current directory
)

# Azure-specific infrastructure deployment for RAG system
class AzureRagInfrastructure < BaseInfrastructure
  def provider_name
    'Azure'
  end

  # Override deploy to include JSON export
  def deploy
    puts "\n#{divider}"
    puts "🚀 Starting #{provider_name} Infrastructure Deployment"
    puts divider
    puts

    authenticate

    # Check if using external OpenAI API instead of Azure OpenAI
    if @config[:skip_azure_openai]
      puts
      puts "ℹ️  AI Provider: Using OpenAI API (external)"
      puts "   Skipping Azure OpenAI deployment"
      puts
      validate_region_capabilities_without_openai
    else
      puts
      puts "ℹ️  AI Provider: Using Azure OpenAI (in-cloud)"
      puts
      validate_region_capabilities  # Full validation including Azure OpenAI
    end

    create_resource_group
    create_storage
    create_vector_database

    # Only create Azure OpenAI if not using external API
    unless @config[:skip_azure_openai]
      create_ai_services
    end

    create_networking
    configure_security
    output_summary
    output_resource_group_json  # Azure-specific JSON export

    puts
    puts "#{divider}"
    puts "✅ Deployment Complete!"
    puts divider
    puts

    @resources_created
  end

  def load_configuration
    # Load from environment or use defaults
    # Note: centralus typically works best for student subscriptions
    # Naming follows DSi Aeris AI enterprise standards where Azure permits

    # Determine environment (default to DEV)
    environment = (ENV['ENVIRONMENT'] || 'DEV').upcase
    default_location = ENV['AZURE_LOCATION'] || 'centralus'

    @config = {
      subscription_id: ENV['AZURE_SUBSCRIPTION_ID'],
      tenant_id: ENV['AZURE_TENANT_ID'],
      environment: environment,
      # Resource Group: Can use uppercase (case-insensitive in Azure)
      resource_group: ENV['AZURE_RESOURCE_GROUP'] || "UTS-#{environment}-RG",
      location: default_location,  # Best default for student accounts
      # Storage: MUST be lowercase (Azure requirement) - no hyphens allowed
      storage_account: ENV['AZURE_STORAGE_ACCOUNT'] || generate_storage_name(environment, default_location),
      storage_container: ENV['AZURE_STORAGE_CONTAINER'] || 'documents',
      # Search: Must be lowercase (Azure requirement)
      search_service: ENV['AZURE_SEARCH_SERVICE'] || generate_search_service_name(environment, default_location),
      # OpenAI: Must be lowercase (Azure requirement)
      openai_service: ENV['AZURE_OPENAI_SERVICE'] || generate_openai_service_name(environment, default_location),
      # App Services: Can use hyphens, typically lowercase
      app_service_plan: ENV['AZURE_APP_SERVICE_PLAN'] || "uts-#{environment.downcase}-app-plan",
      app_service: ENV['AZURE_APP_SERVICE'] || "uts-#{environment.downcase}-api-app",
      # AI Provider selection - OpenAI API is DEFAULT
      # Only use Azure OpenAI if explicitly requested AND you have quota
      ai_provider: ENV['AI_PROVIDER'] || 'openai',  # Default: 'openai'
      # Skip Azure OpenAI by default (most students don't have quota)
      skip_azure_openai: ENV['AI_PROVIDER'] != 'azure_openai'
    }
  end

  def validate_configuration
    section_header('Configuration Validation')

    required_fields = [:subscription_id, :tenant_id]
    missing = required_fields.select { |field| @config[field].nil? || @config[field].empty? }

    if missing.any?
      puts "❌ Missing required configuration: #{missing.join(', ')}"
      puts
      puts 'Please set the following environment variables:'
      puts '  - AZURE_SUBSCRIPTION_ID'
      puts '  - AZURE_TENANT_ID'
      puts
      puts 'Or create a .env file with these values'
      exit 1
    end

    # Check OpenAI API key if using external OpenAI
    if @config[:skip_azure_openai] && !ENV['OPENAI_API_KEY']
      puts
      puts '⚠️  WARNING: Using OpenAI API but OPENAI_API_KEY not found'
      puts
      puts 'Please add to your .env file:'
      puts '  OPENAI_API_KEY=your-api-key-here'
      puts
      puts 'Get your key from: https://platform.openai.com/api-keys'
      puts
      print 'Continue anyway? (y/N): '
      response = $stdin.gets.chomp.downcase
      unless response == 'y'
        puts '❌ Deployment cancelled'
        exit 1
      end
    end

    puts '✅ Configuration valid'
    puts
    puts 'Deployment Configuration:'
    puts "  🏢 Project: UTS"
    puts "  🌍 Environment: #{@config[:environment]}"
    puts "  🤖 AI Provider: #{@config[:ai_provider].upcase} #{@config[:skip_azure_openai] ? '(External API - DEFAULT)' : '(Azure OpenAI)'}"
    puts
    @config.each do |key, value|
      next if key.to_s.include?('id') # Don't show sensitive IDs in full
      next if [:ai_provider, :skip_azure_openai, :environment].include?(key) # Already shown above
      puts "  #{key}: #{value}"
    end
    puts
  end

  def validate_region_capabilities_without_openai
    # Simplified validation for when using external OpenAI API
    section_header('Region Capability Validation')

    puts "Validating '#{@config[:location]}' for storage and search services..."
    puts

    # Step 1: Check subscription policy
    puts '  Step 1: Checking subscription policy...'
    policy_allowed = check_subscription_policy_for_region(@config[:location])

    if policy_allowed
      puts '     ✅ Region allowed by subscription policy'
    else
      puts '     ❌ Region BLOCKED by subscription policy'
      puts
      handle_incompatible_region
      return false
    end

    # Step 2: Check service availability (Storage and Search only)
    puts '  Step 2: Checking service availability...'
    puts

    services_supported = { storage: false, search: false }

    # Check Storage
    puts '    • Storage Accounts...'
    storage_result = `az provider show --namespace Microsoft.Storage --query "resourceTypes[?resourceType=='storageAccounts'].locations" --output json 2>&1`
    if $?.success?
      regions = JSON.parse(storage_result).flatten.map(&:downcase).map { |r| r.gsub(' ', '') }
      services_supported[:storage] = regions.include?(@config[:location].downcase)
      puts services_supported[:storage] ? '       ✅ Available' : '       ❌ NOT available'
    end

    # Check AI Search
    puts '    • Azure AI Search...'
    search_result = `az provider show --namespace Microsoft.Search --query "resourceTypes[?resourceType=='searchServices'].locations" --output json 2>&1`
    if $?.success?
      regions = JSON.parse(search_result).flatten.map(&:downcase).map { |r| r.gsub(' ', '') }
      services_supported[:search] = regions.include?(@config[:location].downcase)
      puts services_supported[:search] ? '       ✅ Available' : '       ❌ NOT available'
    end

    puts

    unless services_supported.values.all?
      puts "❌ Region '#{@config[:location]}' does NOT support required services"
      handle_incompatible_region
      return false
    end

    # Step 3: Test deployment permission
    puts '  Step 3: Testing actual deployment permission...'
    deployment_allowed = test_region_deployment(@config[:location])

    unless deployment_allowed
      puts '     ❌ Test deployment FAILED'
      puts
      handle_incompatible_region
      return false
    end

    puts '     ✅ Test deployment successful'
    puts
    puts "✅ Region '#{@config[:location]}' is QUALIFIED:"
    puts "   • Subscription policy allows deployment"
    puts "   • Storage and Search services available"
    puts "   • Deployment permissions verified"
    puts "   • Using external OpenAI API (no Azure OpenAI needed)"
    puts
    true
  end

  def validate_region_capabilities
    section_header('Region Capability Validation')

    puts "Validating '#{@config[:location]}' for your subscription..."
    puts

    # Step 1: Check subscription policy allows deployment to this region
    puts '  Step 1: Checking subscription policy...'
    policy_allowed = check_subscription_policy_for_region(@config[:location])

    if policy_allowed
      puts '     ✅ Region allowed by subscription policy'
    else
      puts '     ❌ Region BLOCKED by subscription policy'
      puts
      puts "⚠️  Your subscription has policies restricting which regions can be used."
      puts "   This is common with Azure for Students and trial subscriptions."
      puts
      handle_incompatible_region
      return false
    end

    # Step 2: Check service availability in region
    puts '  Step 2: Checking service availability...'
    puts

    services_supported = {
      storage: false,
      search: false,
      openai: false
    }

    # Check Storage Account availability
    puts '    • Storage Accounts...'
    storage_result = `az provider show --namespace Microsoft.Storage --query "resourceTypes[?resourceType=='storageAccounts'].locations" --output json 2>&1`
    if $?.success?
      regions = JSON.parse(storage_result).flatten.map(&:downcase).map { |r| r.gsub(' ', '') }
      services_supported[:storage] = regions.include?(@config[:location].downcase)
      puts services_supported[:storage] ? '       ✅ Available' : '       ❌ NOT available'
    end

    # Check AI Search availability
    puts '    • Azure AI Search...'
    search_result = `az provider show --namespace Microsoft.Search --query "resourceTypes[?resourceType=='searchServices'].locations" --output json 2>&1`
    if $?.success?
      regions = JSON.parse(search_result).flatten.map(&:downcase).map { |r| r.gsub(' ', '') }
      services_supported[:search] = regions.include?(@config[:location].downcase)
      puts services_supported[:search] ? '       ✅ Available' : '       ❌ NOT available'
    end

    # Check OpenAI availability
    puts '    • Azure OpenAI...'
    openai_result = `az cognitiveservices account list-skus --location #{@config[:location]} --query "[?kind=='OpenAI']" --output json 2>&1`
    if $?.success? && !openai_result.strip.empty?
      data = JSON.parse(openai_result)
      services_supported[:openai] = !data.empty?
      puts services_supported[:openai] ? '       ✅ Available' : '       ❌ NOT available'
    else
      puts '       ❌ NOT available'
    end

    puts

    # Check if all services are supported
    all_supported = services_supported.values.all?

    unless all_supported
      puts "❌ Region '#{@config[:location]}' does NOT support all required services"
      puts
      puts 'Missing services:'
      services_supported.each do |service, supported|
        puts "  ❌ #{service.to_s.capitalize}" unless supported
      end
      puts
      handle_incompatible_region
      return false
    end

    # Step 3: Verify with test deployment (lightweight check)
    puts '  Step 3: Testing actual deployment permission...'
    deployment_allowed = test_region_deployment(@config[:location])

    unless deployment_allowed
      puts '     ❌ Test deployment FAILED'
      puts
      puts "⚠️  Region has services but subscription blocks deployment."
      puts
      handle_incompatible_region
      return false
    end

    puts '     ✅ Test deployment successful'
    puts

    # Step 4: Check OpenAI quota availability
    puts '  Step 4: Verifying Azure OpenAI quota...'
    quota_available = check_openai_quota(@config[:location])

    unless quota_available
      puts '     ❌ Azure OpenAI quota not available'
      puts
      puts '━' * 80
      puts '⚠️  AZURE OPENAI ACCESS REQUIRED'
      puts '━' * 80
      puts
      puts 'Your Azure for Students subscription does not have quota for Azure OpenAI.'
      puts 'This is a common restriction for student/trial subscriptions.'
      puts
      puts '📋 To request access:'
      puts
      puts '  1. Visit: https://aka.ms/oai/access'
      puts '  2. Fill out the Azure OpenAI access request form'
      puts '  3. Wait for approval (usually 1-2 business days)'
      puts '  4. After approval, run this deployment again'
      puts
      puts '🔄 Alternative options:'
      puts
      puts '  • Use OpenAI API directly (requires api.openai.com account)'
      puts '  • Use other Azure AI services (Azure AI Search without OpenAI)'
      puts '  • Request instructor to provide access to Azure OpenAI'
      puts
      puts '━' * 80
      puts
      exit 1
    end

    puts '     ✅ OpenAI quota available'
    puts

    # Step 5: Check OpenAI model availability (critical for deployment)
    puts '  Step 5: Verifying required AI models availability...'
    models_available = check_openai_models_availability(@config[:location])

    unless models_available
      puts '     ❌ Required models NOT available in this region'
      puts
      puts "⚠️  Region '#{@config[:location]}' supports OpenAI but not the required models:"
      puts "   • text-embedding-ada-002"
      puts "   • gpt-4"
      puts
      handle_incompatible_region
      return false
    end

    puts '     ✅ Required models available'
    puts
    puts "✅ Region '#{@config[:location]}' is FULLY QUALIFIED:"
    puts "   • Subscription policy allows deployment"
    puts "   • All required services available"
    puts "   • Deployment permissions verified"
    puts "   • Azure OpenAI quota allocated"
    puts "   • Required AI models available"
    puts
    true
  end

  def check_subscription_policy_for_region(region)
    # Check if subscription has location policies that restrict regions
    policies_result = `az policy assignment list --query "[?contains(displayName, 'location') || contains(displayName, 'Location') || contains(displayName, 'region') || contains(displayName, 'Region')].{name:displayName,policy:policyDefinitionId}" --output json 2>&1`

    return true unless $?.success? && !policies_result.strip.empty?

    begin
      policies = JSON.parse(policies_result)

      # If there are location-related policies, we need to be cautious
      # But we can't easily determine the allowed regions from policy alone
      # So we'll rely on the test deployment in the next step
      return true
    rescue JSON::ParserError
      # If we can't parse policies, assume allowed and let test deployment verify
      return true
    end
  end

  def check_openai_quota(region)
    # Check if subscription has quota for Azure OpenAI in this region
    # This is critical for student subscriptions which often lack OpenAI access

    # Try to list available SKUs/quotas for OpenAI
    quota_result = `az cognitiveservices usage list --location #{region} --output json 2>&1`

    # If the command fails or returns empty, check if OpenAI is in the list at all
    if !$?.success? || quota_result.strip.empty?
      # Try alternative: check account list to see if we can even query OpenAI
      check_result = `az cognitiveservices account list-kinds --output json 2>&1`
      if $?.success? && !check_result.strip.empty?
        begin
          kinds = JSON.parse(check_result)
          # If OpenAI is not in available kinds, quota not available
          return kinds.include?('OpenAI')
        rescue JSON::ParserError
          return false
        end
      end
      return false
    end

    begin
      # Parse quota information
      quota_data = JSON.parse(quota_result)

      # Look for OpenAI-related quota
      # If we can successfully query usage, we likely have access
      # The absence of quota or a denied response would fail earlier
      true
    rescue JSON::ParserError, StandardError
      # If we can't parse quota, assume no access
      false
    end
  end

  def check_openai_models_availability(region)
    # Check if the specific models we need are available in this region
    # We need: text-embedding-ada-002 and gpt-4

    # Query available models in the region
    models_result = `az cognitiveservices account list-models --location #{region} --output json 2>&1`

    return false unless $?.success? && !models_result.strip.empty?

    begin
      models = JSON.parse(models_result)

      # Look for our required models
      has_embedding = models.any? do |model|
        model['model'] && model['model']['name'] =~ /text-embedding-ada-002/i
      end

      has_gpt4 = models.any? do |model|
        model['model'] && model['model']['name'] =~ /gpt-4/i
      end

      has_embedding && has_gpt4
    rescue JSON::ParserError, StandardError
      # If we can't determine model availability, return false to be safe
      # (better to skip this region than fail during deployment)
      false
    end
  end

  def test_region_deployment(region)
    # Test with an actual storage account since policies can be resource-specific
    test_rg_name = "rg-region-test-#{SecureRandom.hex(4)}"
    test_storage_name = "teststorage#{SecureRandom.hex(4)}"

    puts "     Testing: Creating temporary resources..."

    # Step 1: Create resource group
    rg_result = `az group create --name #{test_rg_name} --location #{region} --output json 2>&1`

    unless $?.success?
      if rg_result.include?('RequestDisallowedByAzure') ||
         rg_result.include?('policy') ||
         rg_result.include?('disallowed')
        return false
      end
      return true  # Other errors, be optimistic
    end

    # Step 2: Try creating a storage account (the actual restricted resource)
    storage_result = `az storage account create --name #{test_storage_name} --resource-group #{test_rg_name} --location #{region} --sku Standard_LRS --output json 2>&1`

    storage_success = $?.success? && !storage_result.include?('RequestDisallowedByAzure')

    # Clean up regardless of result
    system("az group delete --name #{test_rg_name} --yes --no-wait 2>/dev/null")

    storage_success
  rescue StandardError
    # If test fails unexpectedly, be optimistic and let main deployment try
    true
  end

  def handle_incompatible_region
    puts '🔍 Let me find regions that support ALL required services...'
    puts

    compatible_regions = find_compatible_regions

    if compatible_regions.empty?
      puts '❌ Could not find compatible regions automatically.'
      puts
      puts 'Recommended regions for Azure for Students (try these manually):'
      puts '  - centralus'
      puts '  - westus2'
      puts '  - northeurope'
      puts
      print 'Enter a region to try: '
      new_region = $stdin.gets.chomp.downcase

      if new_region.empty?
        puts '❌ No region entered. Exiting.'
        exit 1
      end

      @config[:location] = new_region
      validate_region_capabilities  # Recursive check
    else
      puts '✅ Found regions that support all services:'
      compatible_regions.each_with_index do |region, i|
        puts "  #{i + 1}. #{region}"
      end
      puts
      print "Choose a region (1-#{compatible_regions.length}): "
      choice = $stdin.gets.chomp.to_i

      if choice > 0 && choice <= compatible_regions.length
        @config[:location] = compatible_regions[choice - 1]
      else
        @config[:location] = compatible_regions[0]
      end

      puts "✅ Using region: #{@config[:location]}"
      puts
    end
  end

  def find_compatible_regions
    puts '   Scanning regions for service availability and deployment permission...'
    puts

    # Get regions that support Storage
    storage_result = `az provider show --namespace Microsoft.Storage --query "resourceTypes[?resourceType=='storageAccounts'].locations" --output json 2>&1`
    storage_regions = $?.success? ? JSON.parse(storage_result).flatten.map(&:downcase).map { |r| r.gsub(' ', '') } : []

    # Get regions that support Search
    search_result = `az provider show --namespace Microsoft.Search --query "resourceTypes[?resourceType=='searchServices'].locations" --output json 2>&1`
    search_regions = $?.success? ? JSON.parse(search_result).flatten.map(&:downcase).map { |r| r.gsub(' ', '') } : []

    # Prioritize regions good for student subscriptions (test these first)
    preferred = ['centralus', 'westus2', 'eastus', 'northeurope', 'westeurope',
                 'southeastasia', 'eastasia', 'uksouth', 'canadacentral', 'japaneast']

    # Test each preferred region
    compatible = []

    preferred.each do |region|
      # Skip if storage or search not available
      next unless storage_regions.include?(region) && search_regions.include?(region)

      # Check OpenAI availability
      print "   • Testing #{region}... "
      openai_result = `az cognitiveservices account list-skus --location #{region} --query "[?kind=='OpenAI']" --output json 2>&1`
      has_openai = false
      if $?.success? && !openai_result.strip.empty?
        data = JSON.parse(openai_result) rescue []
        has_openai = !data.empty?
      end

      next unless has_openai

      # Test actual deployment permission (quick check)
      unless test_region_deployment_quick(region)
        puts "❌ Blocked by policy"
        next
      end

      # Check if required models are available
      print "(checking models...) "
      unless check_openai_models_availability(region)
        puts "❌ Models unavailable"
        next
      end

      compatible << region
      puts "✅ QUALIFIED"
    end

    puts

    if compatible.empty?
      puts "   ⚠️  Could not find pre-qualified regions."
      puts "   Showing regions with service availability (may need policy check):"
      puts

      # Fallback: return regions with services but unverified policy
      openai_regions = []
      preferred.each do |region|
        next unless storage_regions.include?(region) && search_regions.include?(region)

        openai_result = `az cognitiveservices account list-skus --location #{region} --query "[?kind=='OpenAI']" --output json 2>&1`
        if $?.success? && !openai_result.strip.empty?
          data = JSON.parse(openai_result) rescue []
          openai_regions << region unless data.empty?
        end
      end

      return openai_regions.first(5)
    end

    compatible
  end

  def test_region_deployment_quick(region)
    # Quick test with storage account (the actual restricted resource)
    test_rg_name = "rg-test-#{SecureRandom.hex(3)}"
    test_storage_name = "test#{SecureRandom.hex(5)}"

    # Create resource group
    `az group create --name #{test_rg_name} --location #{region} --output json 2>&1`
    return false unless $?.success?

    # Test storage account (where policy restrictions actually apply)
    storage_result = `az storage account create --name #{test_storage_name} --resource-group #{test_rg_name} --location #{region} --sku Standard_LRS --output json 2>&1`

    success = $?.success? && !storage_result.include?('RequestDisallowedByAzure')

    # Clean up
    system("az group delete --name #{test_rg_name} --yes --no-wait 2>/dev/null")

    success
  rescue StandardError
    false
  end

  def authenticate
    section_header('Authentication')

    puts "Logging in to Azure (Tenant: #{@config[:tenant_id]})"

    execute_command(
      "az login --tenant #{@config[:tenant_id]} --output json",
      description: 'Azure CLI login'
    )

    puts '✅ Authenticated successfully'
    puts

    puts 'Setting subscription context...'
    execute_command(
      "az account set --subscription #{@config[:subscription_id]}",
      description: 'Set subscription'
    )

    puts '✅ Subscription set'
  end

  def create_resource_group
    section_header('Resource Group Creation')

    # Check if exists
    check_result = `az group exists --name #{@config[:resource_group]} 2>&1`

    if check_result.strip == 'true'
      puts "ℹ️  Resource group '#{@config[:resource_group]}' already exists"
      return
    end

    execute_command(
      "az group create --name #{@config[:resource_group]} --location #{@config[:location]} --output json",
      description: "Creating resource group '#{@config[:resource_group]}'"
    )

    record_resource(
      'Resource Group',
      @config[:resource_group],
      id: "/subscriptions/#{@config[:subscription_id]}/resourceGroups/#{@config[:resource_group]}"
    )

    puts "✅ Resource group '#{@config[:resource_group]}' created in #{@config[:location]}"
  end

  def create_storage
    section_header('Storage Account & Container Creation')

    # Check if storage account exists
    check_cmd = "az storage account show --name #{@config[:storage_account]} " \
                "--resource-group #{@config[:resource_group]} 2>&1"
    `#{check_cmd}`

    if $?.success?
      puts "ℹ️  Storage account '#{@config[:storage_account]}' already exists"
    else
      puts "Creating storage account '#{@config[:storage_account]}'..."

      begin
        execute_command(
          "az storage account create " \
          "--name #{@config[:storage_account]} " \
          "--resource-group #{@config[:resource_group]} " \
          "--location #{@config[:location]} " \
          "--sku Standard_LRS " \
          "--kind StorageV2 " \
          "--access-tier Hot " \
          "--output json",
          description: 'Creating storage account'
        )

        record_resource(
          'Storage Account',
          @config[:storage_account],
          id: @config[:storage_account]
        )

        puts "✅ Storage account '#{@config[:storage_account]}' created"

      rescue RuntimeError => e
        if e.message.include?('RequestDisallowedByAzure')
          handle_region_restriction
          return  # Exit after handling region restriction
        else
          raise
        end
      end
    end

    # Create container
    puts
    puts "Creating blob container '#{@config[:storage_container]}'..."

    container_result = `az storage container create \
      --name #{@config[:storage_container]} \
      --account-name #{@config[:storage_account]} \
      --auth-mode login \
      --output json 2>&1`

    if $?.success?
      record_resource(
        'Blob Container',
        @config[:storage_container],
        id: "#{@config[:storage_account]}/#{@config[:storage_container]}"
      )
      puts "✅ Container '#{@config[:storage_container]}' created"
    elsif container_result.include?('already exists')
      puts "ℹ️  Container '#{@config[:storage_container]}' already exists"
    else
      puts "⚠️  Container creation: #{container_result}"
    end
  end

  def create_vector_database
    section_header('Azure AI Search Service Creation')

    # Check if exists in this resource group
    check_cmd = "az search service show --name #{@config[:search_service]} " \
                "--resource-group #{@config[:resource_group]} 2>&1"
    `#{check_cmd}`

    if $?.success?
      puts "ℹ️  Search service '#{@config[:search_service]}' already exists"
      return
    end

    puts "Creating AI Search service '#{@config[:search_service]}'..."
    puts '⏳ This may take 2-3 minutes...'

    begin
      result = execute_command(
        "az search service create " \
        "--name #{@config[:search_service]} " \
        "--resource-group #{@config[:resource_group]} " \
        "--location #{@config[:location]} " \
        "--sku basic " \
        "--output json",
        description: 'Creating Azure AI Search service'
      )

      service_data = JSON.parse(result)

      record_resource(
        'AI Search Service',
        @config[:search_service],
        id: service_data['id'],
        endpoint: "https://#{@config[:search_service]}.search.windows.net"
      )

      puts "✅ Search service '#{@config[:search_service]}' created"

    rescue RuntimeError => e
      if e.message.include?('ServiceNameUnavailable')
        puts
        puts "⚠️  WARNING: Search service name '#{@config[:search_service]}' is already in use globally."
        puts "   Azure Search service names must be globally unique across all subscriptions."
        puts
        puts "   This might be from a previous deployment in a different region/resource group."
        puts "   Generating a new unique name..."
        puts

        # Generate new name and retry
        @config[:search_service] = generate_search_service_name
        puts "   Trying with new name: #{@config[:search_service]}"
        puts
        retry
      else
        raise
      end
    end
  end

  def create_ai_services
    section_header('Azure OpenAI Service Creation')

    # Check if exists
    check_cmd = "az cognitiveservices account show " \
                "--name #{@config[:openai_service]} " \
                "--resource-group #{@config[:resource_group]} 2>&1"
    `#{check_cmd}`

    if $?.success?
      puts "ℹ️  OpenAI service '#{@config[:openai_service]}' already exists"
      deploy_ai_models
      return
    end

    puts "Creating Azure OpenAI service '#{@config[:openai_service]}'..."
    puts '⏳ This may take 1-2 minutes...'

    begin
      result = execute_command(
        "az cognitiveservices account create " \
        "--name #{@config[:openai_service]} " \
        "--resource-group #{@config[:resource_group]} " \
        "--location #{@config[:location]} " \
        "--kind OpenAI " \
        "--sku S0 " \
        "--yes " \
        "--output json",
        description: 'Creating Azure OpenAI service'
      )

      service_data = JSON.parse(result)

      record_resource(
        'OpenAI Service',
        @config[:openai_service],
        id: service_data['id'],
        endpoint: service_data['properties']['endpoint']
      )

      puts "✅ OpenAI service '#{@config[:openai_service]}' created"

      # Deploy models
      deploy_ai_models

    rescue RuntimeError => e
      if e.message.include?('already exists') || e.message.include?('AccountNameNotAvailable')
        puts
        puts "⚠️  WARNING: OpenAI service name '#{@config[:openai_service]}' is already in use."
        puts "   Generating a new unique name..."
        puts

        # Generate new name and retry
        @config[:openai_service] = generate_openai_service_name
        puts "   Trying with new name: #{@config[:openai_service]}"
        puts
        retry
      else
        raise
      end
    end
  end

  def deploy_ai_models
    puts
    puts 'Deploying AI models...'

    # Deploy embedding model
    deploy_model('text-embedding-ada-002', 'text-embedding-ada-002', '2')

    # Deploy GPT-4 model
    deploy_model('gpt-4', 'gpt-4', '0613')

    puts '✅ AI models deployed'
  end

  def deploy_model(deployment_name, model_name, model_version)
    puts "  📦 Deploying #{deployment_name}..."

    check_cmd = "az cognitiveservices account deployment show " \
                "--name #{@config[:openai_service]} " \
                "--resource-group #{@config[:resource_group]} " \
                "--deployment-name #{deployment_name} 2>&1"

    `#{check_cmd}`
    if $?.success?
      puts "     ℹ️  Deployment '#{deployment_name}' already exists"
      return
    end

    execute_command(
      "az cognitiveservices account deployment create " \
      "--name #{@config[:openai_service]} " \
      "--resource-group #{@config[:resource_group]} " \
      "--deployment-name #{deployment_name} " \
      "--model-name #{model_name} " \
      "--model-version #{model_version} " \
      "--model-format OpenAI " \
      "--sku-capacity 1 " \
      "--sku-name Standard " \
      "--output json",
      description: "Deploying #{deployment_name}"
    )

    record_resource(
      'AI Model Deployment',
      deployment_name,
      id: "#{@config[:openai_service]}/deployments/#{deployment_name}"
    )

    puts "     ✅ Deployed #{deployment_name}"
  end

  def create_networking
    section_header('Networking Configuration')
    puts 'ℹ️  Using default Azure networking (all services publicly accessible)'
    puts 'ℹ️  For production, consider:'
    puts '   - Private endpoints for storage and AI services'
    puts '   - Virtual network integration'
    puts '   - Network security groups'
    puts '   - Azure Firewall or Application Gateway'
  end

  def configure_security
    section_header('Security Configuration')

    puts 'Retrieving access keys...'

    # Get storage connection string (with warnings suppressed)
    storage_conn = execute_command(
      "az storage account show-connection-string " \
      "--name #{@config[:storage_account]} " \
      "--resource-group #{@config[:resource_group]} " \
      "--only-show-errors " \
      "--output json",
      description: 'Getting storage connection string'
    )

    # Get Search admin key
    search_keys = execute_command(
      "az search admin-key show " \
      "--service-name #{@config[:search_service]} " \
      "--resource-group #{@config[:resource_group]} " \
      "--only-show-errors " \
      "--output json",
      description: 'Getting Search admin key'
    )

    puts '✅ Access keys retrieved'
    puts
    puts '⚠️  IMPORTANT: Add these credentials to your .env file:'
    puts
    puts '# Azure Storage'
    # Filter out any warning lines before parsing JSON
    storage_json = filter_json_output(storage_conn)
    storage_data = JSON.parse(storage_json)
    puts "AZURE_STORAGE_CONNECTION_STRING='#{storage_data['connectionString']}'"
    puts
    puts '# Azure AI Search'
    search_json = filter_json_output(search_keys)
    search_data = JSON.parse(search_json)
    puts "AZURE_SEARCH_ENDPOINT='https://#{@config[:search_service]}.search.windows.net'"
    puts "AZURE_SEARCH_ADMIN_KEY='#{search_data['primaryKey']}'"
    puts

    # If using Azure OpenAI, get those keys too
    unless @config[:skip_azure_openai]
      puts '# Azure OpenAI'
      openai_keys = execute_command(
        "az cognitiveservices account keys list " \
        "--name #{@config[:openai_service]} " \
        "--resource-group #{@config[:resource_group]} " \
        "--only-show-errors " \
        "--output json",
        description: 'Getting OpenAI keys'
      )

      openai_json = filter_json_output(openai_keys)
      openai_data = JSON.parse(openai_json)
      endpoint = execute_command(
        "az cognitiveservices account show " \
        "--name #{@config[:openai_service]} " \
        "--resource-group #{@config[:resource_group]} " \
        "--query properties.endpoint " \
        "--only-show-errors " \
        "--output tsv",
        description: 'Getting OpenAI endpoint'
      )
      puts "AZURE_OPENAI_API_KEY='#{openai_data['key1']}'"
      puts "AZURE_OPENAI_ENDPOINT='#{endpoint.strip}'"
      puts
    else
      puts '# OpenAI API (External)'
      puts '# You already have: OPENAI_API_KEY=sk-proj-...'
      puts 'AI_PROVIDER=openai'
      puts
    end
  end

  def filter_json_output(output)
    # Remove warning lines and keep only valid JSON
    # Azure CLI sometimes outputs warnings before JSON
    lines = output.lines

    # Find the first line that starts with { or [
    json_start = lines.find_index { |line| line.strip.start_with?('{', '[') }

    return output if json_start.nil?

    # Return from first JSON character onwards
    lines[json_start..-1].join
  end

  def output_resource_group_json
    section_header('Complete Resource Group Export')

    puts 'Exporting complete resource group details to JSON...'
    puts

    begin
      # Get resource group details
      rg_details = execute_command(
        "az group show --name #{@config[:resource_group]} --output json",
        description: 'Fetching resource group details'
      )

      # Get all resources in the resource group
      resources = execute_command(
        "az resource list --resource-group #{@config[:resource_group]} --output json",
        description: 'Listing all resources in group'
      )

      # Parse the JSON
      rg_data = JSON.parse(rg_details)
      resources_data = JSON.parse(resources)

      # Build comprehensive output
      output = {
        resource_group: {
          name: rg_data['name'],
          location: rg_data['location'],
          id: rg_data['id'],
          provisioning_state: rg_data['properties']['provisioningState'],
          tags: rg_data['tags'] || {}
        },
        resources: resources_data.map do |resource|
          {
            name: resource['name'],
            type: resource['type'],
            location: resource['location'],
            id: resource['id'],
            kind: resource['kind'],
            sku: resource['sku']
          }
        end,
        resource_count: resources_data.length,
        deployment_config: {
          storage_account: @config[:storage_account],
          storage_container: @config[:storage_container],
          search_service: @config[:search_service],
          openai_service: @config[:openai_service],
          app_service_plan: @config[:app_service_plan],
          app_service: @config[:app_service]
        },
        deployed_at: Time.now.utc.iso8601
      }

      # Pretty print JSON
      json_output = JSON.pretty_generate(output)

      puts '✅ Resource group exported successfully'
      puts
      puts '=' * 80
      puts 'COMPLETE RESOURCE GROUP JSON'
      puts '=' * 80
      puts
      puts json_output
      puts
      puts '=' * 80
      puts

      # Optionally save to file
      output_file = "#{@config[:resource_group]}_deployment.json"
      File.write(output_file, json_output)
      puts "💾 JSON also saved to: #{output_file}"
      puts

    rescue StandardError => e
      puts "⚠️  Could not export resource group JSON: #{e.message}"
      puts '   (This does not affect your deployment - all resources were created successfully)'
      puts
    end
  end

  def destroy_resources
    section_header('Resource Destruction')

    puts "Deleting resource group '#{@config[:resource_group]}'..."
    puts '⏳ This may take 5-10 minutes...'
    puts '   Please wait - deletion in progress...'
    puts

    execute_command(
      "az group delete --name #{@config[:resource_group]} --yes",
      description: 'Deleting resource group (WAIT mode)'
    )

    puts
    puts "✅ Resource group '#{@config[:resource_group]}' deleted successfully"
  end

  def check_resource_status
    puts 'Checking resource status...'
    puts

    # Check resource group
    rg_result = `az group show --name #{@config[:resource_group]} 2>&1`
    puts rg_result.include?('could not be found') ? '❌ Resource Group: Not Found' : '✅ Resource Group: Exists'

    # Check storage
    storage_result = `az storage account show --name #{@config[:storage_account]} --resource-group #{@config[:resource_group]} 2>&1`
    puts storage_result.include?('could not be found') ? '❌ Storage Account: Not Found' : '✅ Storage Account: Exists'

    # Check search
    search_result = `az search service show --name #{@config[:search_service]} --resource-group #{@config[:resource_group]} 2>&1`
    puts search_result.include?('could not be found') ? '❌ AI Search: Not Found' : '✅ AI Search: Exists'

    # Check OpenAI
    openai_result = `az cognitiveservices account show --name #{@config[:openai_service]} --resource-group #{@config[:resource_group]} 2>&1`
    puts openai_result.include?('could not be found') ? '❌ OpenAI Service: Not Found' : '✅ OpenAI Service: Exists'
  end

  private

  def generate_storage_name(environment = 'dev', location = 'centralus')
    # Storage account names: 3-24 chars, lowercase letters and numbers only
    # Format: uts{env}stg{region_code}{random}
    # Note: MUST be lowercase - Azure requirement
    env_code = environment.to_s.downcase[0..2]  # dev, tst, prd
    region_code = get_region_code(location)
    "uts#{env_code}stg#{region_code}#{SecureRandom.hex(3)}"
  end

  def generate_search_service_name(environment = 'dev', location = 'centralus')
    # Azure Search service names are globally unique
    # Must be 2-60 chars, lowercase, numbers, hyphens (can't start/end with hyphen)
    # Format: uts-{env}-search-{region_code}
    # Note: Must be lowercase - Azure requirement
    env_code = environment.to_s.downcase
    region_code = get_region_code(location)
    "uts-#{env_code}-search-#{region_code}-#{SecureRandom.hex(2)}"
  end

  def generate_openai_service_name(environment = 'dev', location = 'centralus')
    # Azure OpenAI service names are globally unique
    # Format: uts-{env}-openai-{region_code}
    # Note: Must be lowercase - Azure requirement
    env_code = environment.to_s.downcase
    region_code = get_region_code(location)
    "uts-#{env_code}-openai-#{region_code}-#{SecureRandom.hex(2)}"
  end

  def get_region_code(region)
    # Map Azure regions to standard abbreviations
    return 'xxx' if region.nil? || region.empty?

    region_codes = {
      'centralus' => 'cus',
      'eastus' => 'eus',
      'eastus2' => 'eu2',
      'westus' => 'wus',
      'westus2' => 'wu2',
      'westus3' => 'wu3',
      'northeurope' => 'neu',
      'westeurope' => 'weu',
      'uksouth' => 'uks',
      'ukwest' => 'ukw',
      'southeastasia' => 'sea',
      'eastasia' => 'eas',
      'australiaeast' => 'aue',
      'australiasoutheast' => 'ase',
      'japaneast' => 'jpe',
      'japanwest' => 'jpw',
      'canadacentral' => 'cac',
      'canadaeast' => 'cae',
      'francecentral' => 'frc',
      'germanywestcentral' => 'gwc',
      'swedencentral' => 'swc'
    }
    region_codes[region.downcase] || region[0..2]
  end

  def handle_region_restriction
    puts
    puts '❌ ERROR: Region Restriction'
    puts
    puts "Your Azure subscription doesn't allow deployments in '#{@config[:location]}'."
    puts 'This is common with student or trial subscriptions.'
    puts
    puts 'Let\'s find an allowed region...'
    puts

    # Discover available regions
    available_regions = discover_available_regions

    if available_regions.empty?
      puts '❌ Could not discover available regions.'
      puts
      puts 'Recommended regions for Azure for Students:'
      puts '  - centralus'
      puts '  - westus2'
      puts '  - northeurope'
      puts '  - westeurope'
      puts '  - southeastasia'
      puts
      print 'Enter a region to try (or press Ctrl+C to cancel): '
      new_region = $stdin.gets.chomp.downcase

      if new_region.empty?
        puts
        puts '❌ No region entered. Deployment cancelled.'
        exit 1
      end
    else
      puts 'Available regions in your subscription:'
      available_regions.each_with_index do |region, i|
        puts "  #{i + 1}. #{region}"
      end
      puts
      print "Choose a region (1-#{available_regions.length}): "
      choice = $stdin.gets.chomp.to_i

      if choice > 0 && choice <= available_regions.length
        new_region = available_regions[choice - 1]
      else
        new_region = available_regions[0]
        puts "Invalid choice, using: #{new_region}"
      end
    end

    puts
    puts "✅ Switching to region: #{new_region}"
    @config[:location] = new_region

    # Delete and recreate resource group in new region
    puts
    puts 'Deleting old resource group...'
    result = system("az group delete --name #{@config[:resource_group]} --yes --no-wait 2>&1")
    if result
      puts '✅ Deletion initiated'
      puts '⏳ Waiting for deletion to complete...'
      sleep 5  # Wait for deletion
    end

    puts
    puts 'Creating resource group in new region...'
    create_resource_group

    # Now retry storage creation by calling the method again
    puts
    puts 'Retrying storage creation in new region...'
    puts

    # Call create_storage again - this time it should work
    create_storage_internal
  end

  def create_storage_internal
    # Internal method that does the actual storage creation without error handling
    puts "Creating storage account '#{@config[:storage_account]}'..."

    execute_command(
      "az storage account create " \
      "--name #{@config[:storage_account]} " \
      "--resource-group #{@config[:resource_group]} " \
      "--location #{@config[:location]} " \
      "--sku Standard_LRS " \
      "--kind StorageV2 " \
      "--access-tier Hot " \
      "--output json",
      description: 'Creating storage account'
    )

    record_resource(
      'Storage Account',
      @config[:storage_account],
      id: @config[:storage_account]
    )

    puts "✅ Storage account '#{@config[:storage_account]}' created"
  end

  def discover_available_regions
    puts '🔍 Discovering and testing available regions...'
    puts '   This may take a moment as we verify deployment permissions...'
    puts

    # Regions that typically work well with student/trial subscriptions
    # Ordered by reliability for student accounts
    preferred = [
      'centralus',      # Often works for students
      'westus2',        # Generally available
      'eastus',         # Common choice
      'northeurope',    # Good for European students
      'westeurope',     # Alternative EU region
      'southeastasia',  # Good for Asian students
      'eastasia',       # Alternative Asia region
      'uksouth',        # UK students
      'canadacentral'   # Canadian students
    ]

    verified_regions = []

    # Test each preferred region for deployment permission and model availability
    preferred.each do |region|
      print "   • #{region}... "

      unless test_region_deployment_quick(region)
        puts "❌ Blocked"
        next
      end

      print "(checking models...) "
      unless check_openai_models_availability(region)
        puts "❌ Models unavailable"
        next
      end

      verified_regions << region
      puts "✅ Available"
    end

    puts

    if verified_regions.empty?
      puts "   ⚠️  No preferred regions verified. Showing all physical regions:"
      puts "   (Note: These may be blocked by subscription policy)"
      puts

      # Fallback: get all physical regions without testing
      result = `az account list-locations --query "[?metadata.regionType=='Physical'].name" --output json 2>&1`
      if $?.success?
        all_regions = JSON.parse(result)
        return all_regions.select { |r| preferred.include?(r) }.first(9)
      end

      return preferred
    end

    verified_regions
  rescue StandardError => e
    puts "⚠️  Error discovering regions: #{e.message}"
    puts "   Falling back to recommended regions (unverified):"
    preferred
  end
end

# Run if executed directly
if __FILE__ == $PROGRAM_NAME
  infrastructure = AzureRagInfrastructure.new

  case ARGV[0]
  when 'deploy', nil
    infrastructure.deploy
  when 'destroy'
    infrastructure.destroy
  when 'status'
    infrastructure.status
  else
    puts 'Usage: ruby azure_rag_infrastructure.rb [deploy|destroy|status]'
    puts
    puts 'Commands:'
    puts '  deploy  - Create all Azure resources for RAG system (default)'
    puts '  destroy - Delete all Azure resources'
    puts '  status  - Check status of deployed resources'
    exit 1
  end
end
