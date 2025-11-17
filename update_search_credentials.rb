#!/usr/bin/env ruby
# frozen_string_literal: true

# Update .env file with correct Azure Search credentials

ENV_FILE = File.join(__dir__, '.env')

# Get the correct search service name from Azure
search_service = `az search service list --resource-group UTS-DEV-RG --query "[0].name" --output tsv 2>/dev/null`.strip

if search_service.empty?
  puts "❌ Could not find search service. Make sure you're logged in to Azure."
  exit 1
end

puts "🔍 Found search service: #{search_service}"
puts "🔄 Updating .env file..."

# Get admin key
admin_key = `az search admin-key show --service-name #{search_service} --resource-group UTS-DEV-RG --query primaryKey --output tsv 2>/dev/null`.strip

if admin_key.empty?
  puts "❌ Could not get admin key"
  exit 1
end

# Read current .env
env_content = File.read(ENV_FILE)

# Update endpoint
endpoint = "https://#{search_service}.search.windows.net"
if env_content.include?('AZURE_SEARCH_ENDPOINT=')
  env_content.gsub!(/AZURE_SEARCH_ENDPOINT=.*$/, "AZURE_SEARCH_ENDPOINT='#{endpoint}'")
else
  env_content += "\nAZURE_SEARCH_ENDPOINT='#{endpoint}'\n"
end

# Update admin key
if env_content.include?('AZURE_SEARCH_ADMIN_KEY=')
  env_content.gsub!(/AZURE_SEARCH_ADMIN_KEY=.*$/, "AZURE_SEARCH_ADMIN_KEY='#{admin_key}'")
else
  env_content += "AZURE_SEARCH_ADMIN_KEY='#{admin_key}'\n"
end

# Write back
File.write(ENV_FILE, env_content)

puts "✅ Updated .env with:"
puts "   Endpoint: #{endpoint}"
puts "   Admin Key: #{admin_key[0..10]}..."
puts
puts "Restart your app: ./start_dev.rb"
puts
