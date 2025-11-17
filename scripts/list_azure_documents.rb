#!/usr/bin/env ruby
# frozen_string_literal: true

# List documents in Azure Blob Storage

puts "\n📦 Listing documents in Azure Blob Storage...\n\n"

# Auto-discover storage account from UTS-DEV-RG
puts "🔍 Finding UTS storage account..."
storage_account = `az storage account list --resource-group UTS-DEV-RG --query "[0].name" --output tsv 2>/dev/null`.strip

if storage_account.empty?
  puts "❌ Could not find storage account in UTS-DEV-RG"
  puts "   Make sure you're logged in: az login"
  exit 1
end

container = 'documents'

puts "Storage Account: #{storage_account}"
puts "Container: #{container}\n\n"

# List blobs using Azure CLI with account key (not RBAC)
result = `az storage blob list \
  --account-name #{storage_account} \
  --container-name #{container} \
  --auth-mode key \
  --output json 2>&1`

if $?.success?
  require 'json'
  # Filter out warnings - find JSON array start
  json_start = result.index('[')
  if json_start
    json_content = result[json_start..-1]
    blobs = JSON.parse(json_content)
  else
    blobs = []
  end

  if blobs.empty?
    puts "📭 No documents uploaded yet"
  else
    puts "📄 Found #{blobs.length} document(s):\n\n"

    blobs.each_with_index do |blob, i|
      size_kb = (blob['properties']['contentLength'].to_f / 1024).round(2)
      created = blob['properties']['creationTime']

      puts "#{i + 1}. #{blob['name']}"
      puts "   Size: #{size_kb} KB"
      puts "   Uploaded: #{created}"
      puts "   URL: https://#{storage_account}.blob.core.windows.net/#{container}/#{blob['name']}"
      puts
    end
  end
else
  puts "❌ Error listing blobs:"
  puts result
  puts
  puts "Make sure you're logged in to Azure:"
  puts "  az login"
end
