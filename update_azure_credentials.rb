#!/usr/bin/env ruby
# frozen_string_literal: true

# Update .env file with correct Azure storage credentials

ENV_FILE = File.join(__dir__, '.env')

# Get the correct storage account name from Azure
storage_account = `az storage account list --resource-group UTS-DEV-RG --query "[0].name" --output tsv 2>/dev/null`.strip

if storage_account.empty?
  puts "❌ Could not find storage account. Make sure you're logged in to Azure."
  exit 1
end

puts "📦 Found storage account: #{storage_account}"
puts "🔄 Updating .env file..."

# Get connection string
conn_string = `az storage account show-connection-string --name #{storage_account} --resource-group UTS-DEV-RG --output tsv 2>/dev/null`.strip

if conn_string.empty?
  puts "❌ Could not get connection string"
  exit 1
end

# Read current .env
env_content = File.read(ENV_FILE)

# Update or add Azure storage credentials
if env_content.include?('AZURE_STORAGE_CONNECTION_STRING=')
  # Replace existing
  env_content.gsub!(/AZURE_STORAGE_CONNECTION_STRING=.*$/, "AZURE_STORAGE_CONNECTION_STRING='#{conn_string}'")
else
  # Add new
  env_content += "\n# Azure Storage (Auto-updated)\n"
  env_content += "AZURE_STORAGE_CONNECTION_STRING='#{conn_string}'\n"
end

# Add storage account name if missing
unless env_content.include?('AZURE_STORAGE_ACCOUNT=')
  env_content += "AZURE_STORAGE_ACCOUNT=#{storage_account}\n"
end

# Add container name if missing
unless env_content.include?('AZURE_STORAGE_CONTAINER=')
  env_content += "AZURE_STORAGE_CONTAINER=documents\n"
end

# Write back
File.write(ENV_FILE, env_content)

puts "✅ Updated .env with credentials for: #{storage_account}"
puts
puts "You can now:"
puts "  1. Restart your app: ./start_dev.rb"
puts "  2. Upload files - they'll go to Azure!"
puts "  3. List files: ruby scripts/list_azure_documents.rb"
puts
