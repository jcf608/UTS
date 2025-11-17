#!/usr/bin/env ruby

require 'dotenv'

puts "azure_auth_simple.rb - Version 1.0"
puts

Dotenv.load('.env')

subscription_id = ENV['AZURE_SUBSCRIPTION_ID']
tenant_id = ENV['AZURE_TENANT_ID']

if subscription_id.nil? || subscription_id.empty?
  puts "ERROR: AZURE_SUBSCRIPTION_ID not found in .env file"
  exit 1
end

if tenant_id.nil? || tenant_id.empty?
  puts "ERROR: AZURE_TENANT_ID not found in .env file"
  exit 1
end

puts "Logging in to Azure..."
puts "Tenant: #{tenant_id}"
puts "Subscription: #{subscription_id}"
puts

login_success = system("az login --tenant #{tenant_id}")

unless login_success
  puts
  puts "ERROR: Azure login failed"
  exit 1
end

puts
puts "Setting subscription context..."
system("az account set --subscription #{subscription_id}")

puts
puts "Verifying current subscription..."
system("az account show")

puts
puts "Logging out from Azure..."
system("az logout")

puts
puts "Azure session complete."
