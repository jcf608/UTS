#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to create Azure Blob Storage (General Purpose v2) using Azure CLI
# Usage: ruby create_blob_storage.rb

require 'json'
require 'securerandom'

class AzureBlobStorageCreator
  attr_reader :subscription_id, :resource_group, :location, :storage_account_name

  def initialize
    @subscription_id = ENV['AZURE_SUBSCRIPTION_ID'] || load_from_env_file
    @resource_group = nil
    @location = 'eastus'
    @storage_account_name = nil
  end

  def run
    puts "=== Azure Blob Storage Creator ==="
    puts

    # Step 1: Set subscription
    set_subscription

    # Step 2: List/select resource group
    select_resource_group

    # Step 3: Generate storage account name
    generate_storage_account_name

    # Step 4: Confirm settings
    confirm_settings

    # Step 5: Create storage account
    create_storage_account

    # Step 6: Create blob container (optional)
    create_blob_container

    puts
    puts "✅ Storage account created successfully!"
    puts "   Storage Account: #{@storage_account_name}"
    puts "   Resource Group: #{@resource_group}"
    puts "   Location: #{@location}"
  end

  private

  def refresh_azure_token
    puts "Opening browser for Azure authentication..."
    puts "Please complete the login in your browser."
    puts

    result = `az login --scope https://management.core.windows.net//.default 2>&1`

    unless $?.success?
      puts "❌ Error during login: #{result}"
      exit 1
    end

    puts "✅ Authentication refreshed"
    puts

    # Re-set the subscription after login
    set_subscription
  end

  def handle_region_restriction
    puts "Your subscription has restrictions on which regions can be used."
    puts
    puts "Recommended approach: Create a new resource group in East US"
    puts "(This region typically has the fewest restrictions)"
    puts

    puts "Options:"
    puts "  1. Create new resource group in East US (recommended)"
    puts "  2. Create new resource group in West US 2"
    puts "  3. Create new resource group in Southeast Asia"
    puts "  4. Try a different existing resource group"
    puts "  5. Exit"
    puts

    print "Select option (1-5): "
    choice = gets.chomp.to_i

    case choice
    when 1
      @location = 'eastus'
      print "Enter new resource group name [rg-#{@storage_account_name}]: "
      input = gets.chomp
      @resource_group = input.empty? ? "rg-#{@storage_account_name}" : input
      create_resource_group_direct
      create_storage_account
    when 2
      @location = 'westus2'
      print "Enter new resource group name [rg-#{@storage_account_name}]: "
      input = gets.chomp
      @resource_group = input.empty? ? "rg-#{@storage_account_name}" : input
      create_resource_group_direct
      create_storage_account
    when 3
      @location = 'southeastasia'
      print "Enter new resource group name [rg-#{@storage_account_name}]: "
      input = gets.chomp
      @resource_group = input.empty? ? "rg-#{@storage_account_name}" : input
      create_resource_group_direct
      create_storage_account
    when 4
      select_resource_group
      create_storage_account
    else
      puts "Exiting. Contact Azure support to modify region restrictions if needed."
      exit 0
    end
  end

  def handle_storage_creation_error(result)
    puts "❌ Error creating storage account: #{result}"
    exit 1
  end

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

  def select_resource_group
    puts "Fetching resource groups..."
    result = `az group list --query "[].{Name:name, Location:location}" --output json 2>&1`

    unless $?.success?
      # Check if token expired
      if result.include?('AADSTS700082') || result.include?('refresh token has expired')
        puts "⚠️  Azure token has expired. Refreshing authentication..."
        refresh_azure_token
        # Retry after login
        result = `az group list --query "[].{Name:name, Location:location}" --output json 2>&1`
        unless $?.success?
          puts "❌ Error fetching resource groups after login: #{result}"
          exit 1
        end
      else
        puts "❌ Error fetching resource groups: #{result}"
        exit 1
      end
    end

    groups = JSON.parse(result)

    if groups.empty?
      puts "No resource groups found. Creating new one..."
      create_resource_group
    else
      puts "Available resource groups:"
      groups.each_with_index do |group, index|
        puts "  #{index + 1}. #{group['Name']} (#{group['Location']})"
      end
      puts "  #{groups.length + 1}. Create new resource group"

      print "\nSelect resource group (1-#{groups.length + 1}): "
      choice = gets.chomp.to_i

      if choice > 0 && choice <= groups.length
        @resource_group = groups[choice - 1]['Name']
        @location = groups[choice - 1]['Location']
        puts "✅ Using resource group: #{@resource_group}"
      else
        create_resource_group
      end
    end
    puts
  end

  def create_resource_group
    print "Enter new resource group name: "
    @resource_group = gets.chomp

    print "Enter location (e.g., eastus, westus2) [#{@location}]: "
    location_input = gets.chomp
    @location = location_input unless location_input.empty?

    create_resource_group_direct
  end

  def create_resource_group_direct
    puts "Creating resource group: #{@resource_group} in #{@location}..."
    result = `az group create --name "#{@resource_group}" --location "#{@location}" 2>&1`

    unless $?.success?
      if result.include?('AADSTS700082') || result.include?('refresh token has expired')
        puts "⚠️  Azure token has expired. Refreshing authentication..."
        refresh_azure_token
        result = `az group create --name "#{@resource_group}" --location "#{@location}" 2>&1`
        unless $?.success?
          puts "❌ Error creating resource group: #{result}"
          exit 1
        end
      else
        puts "❌ Error creating resource group: #{result}"
        exit 1
      end
    end

    puts "✅ Resource group created"
  end

  def generate_storage_account_name
    # Storage account names must be 3-24 characters, lowercase letters and numbers only
    default_name = "storage#{SecureRandom.hex(4)}"

    print "Enter storage account name [#{default_name}]: "
    input = gets.chomp
    @storage_account_name = input.empty? ? default_name : input.downcase.gsub(/[^a-z0-9]/, '')

    if @storage_account_name.length < 3 || @storage_account_name.length > 24
      puts "⚠️  Storage account name must be 3-24 characters. Using: #{default_name}"
      @storage_account_name = default_name
    end
  end

  def confirm_settings
    puts
    puts "=== Configuration ==="
    puts "Subscription:      #{@subscription_id}"
    puts "Resource Group:    #{@resource_group}"
    puts "Location:          #{@location}"
    puts "Storage Account:   #{@storage_account_name}"
    puts "SKU:               Standard_LRS (Locally Redundant Storage)"
    puts "Kind:              StorageV2 (General Purpose v2)"
    puts "Access Tier:       Hot"
    puts

    print "Proceed with creation? (y/n): "
    response = gets.chomp.downcase

    unless response == 'y' || response == 'yes'
      puts "❌ Cancelled by user"
      exit 0
    end
    puts
  end

  def create_storage_account
    puts "Creating storage account: #{@storage_account_name}..."
    puts "(This may take 1-2 minutes)"

    cmd = <<~CMD.gsub("\n", ' ').strip
      az storage account create
        --name "#{@storage_account_name}"
        --resource-group "#{@resource_group}"
        --location "#{@location}"
        --sku Standard_LRS
        --kind StorageV2
        --access-tier Hot
        --output json
    CMD

    result = `#{cmd} 2>&1`

    unless $?.success?
      if result.include?('AADSTS700082') || result.include?('refresh token has expired')
        puts "⚠️  Azure token has expired. Refreshing authentication..."
        refresh_azure_token
        result = `#{cmd} 2>&1`
        unless $?.success?
          handle_storage_creation_error(result)
        end
      elsif result.include?('RequestDisallowedByAzure') || result.include?('best available regions')
        puts "❌ Error: Location '#{@location}' is not allowed by your Azure subscription policy."
        puts
        handle_region_restriction
      else
        puts "❌ Error creating storage account: #{result}"
        exit 1
      end
    end

    puts "✅ Storage account created"
    puts
  end

  def create_blob_container
    print "Create a blob container? (y/n): "
    response = gets.chomp.downcase

    return unless response == 'y' || response == 'yes'

    print "Enter container name: "
    container_name = gets.chomp.downcase.gsub(/[^a-z0-9-]/, '')

    if container_name.empty?
      puts "⚠️  No container name provided, skipping..."
      return
    end

    puts "Creating blob container: #{container_name}..."

    cmd = <<~CMD.gsub("\n", ' ').strip
      az storage container create
        --name "#{container_name}"
        --account-name "#{@storage_account_name}"
        --auth-mode login
        --output json
    CMD

    result = `#{cmd} 2>&1`

    if $?.success?
      puts "✅ Container created: #{container_name}"
    else
      if result.include?('AADSTS700082') || result.include?('refresh token has expired')
        puts "⚠️  Azure token has expired. Refreshing authentication..."
        refresh_azure_token
        result = `#{cmd} 2>&1`
        if $?.success?
          puts "✅ Container created: #{container_name}"
        else
          puts "⚠️  Container creation failed: #{result}"
          puts "   You can create it manually later"
        end
      else
        puts "⚠️  Container creation failed: #{result}"
        puts "   You can create it manually later"
      end
    end
  end
end

# Run the script
if __FILE__ == $PROGRAM_NAME
  creator = AzureBlobStorageCreator.new
  creator.run
end
