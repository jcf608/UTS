#!/usr/bin/env ruby
# frozen_string_literal: true

# Universal deployment script for RAG infrastructure
# Automatically detects provider and runs appropriate script

require 'dotenv/load'

class InfrastructureDeployer
  PROVIDERS = {
    azure: 'azure/azure_rag_infrastructure.rb',
    aws: 'aws/aws_rag_infrastructure.rb',
    gcp: 'gcp/gcp_rag_infrastructure.rb'
  }.freeze

  def initialize
    @provider = detect_provider
    @command = ARGV[0] || 'deploy'
  end

  def run
    print_banner
    validate_provider
    check_prerequisites
    execute_deployment
  end

  private

  def detect_provider
    provider = ENV['CLOUD_PROVIDER']&.downcase&.to_sym || :azure

    unless PROVIDERS.key?(provider)
      puts "❌ Invalid provider: #{provider}"
      puts "   Supported providers: #{PROVIDERS.keys.join(', ')}"
      exit 1
    end

    provider
  end

  def validate_provider
    script_path = File.join(__dir__, PROVIDERS[@provider])

    unless File.exist?(script_path)
      puts "❌ Provider script not found: #{script_path}"
      puts "   This provider may not be implemented yet."
      puts "   Implemented providers: azure"
      puts "   Coming soon: aws, gcp"
      exit 1
    end

    @script_path = script_path
  end

  def check_prerequisites
    case @provider
    when :azure
      check_azure_cli
    when :aws
      check_aws_cli
    when :gcp
      check_gcp_cli
    end
  end

  def check_azure_cli
    unless system('which az > /dev/null 2>&1')
      puts '❌ Azure CLI not found'
      puts '   Install: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli'
      exit 1
    end

    version = `az version --output tsv 2>&1 | head -1`
    puts "✅ Azure CLI detected: #{version.strip}"
  end

  def check_aws_cli
    unless system('which aws > /dev/null 2>&1')
      puts '❌ AWS CLI not found'
      puts '   Install: https://aws.amazon.com/cli/'
      exit 1
    end

    puts '✅ AWS CLI detected'
  end

  def check_gcp_cli
    unless system('which gcloud > /dev/null 2>&1')
      puts '❌ Google Cloud CLI not found'
      puts '   Install: https://cloud.google.com/sdk/docs/install'
      exit 1
    end

    puts '✅ Google Cloud CLI detected'
  end

  def execute_deployment
    puts
    puts '=' * 80
    puts "Executing: ruby #{@script_path} #{@command}"
    puts '=' * 80
    puts

    # Execute the provider-specific script
    exec("ruby #{@script_path} #{@command}")
  end

  def print_banner
    puts
    puts '╔' + '═' * 78 + '╗'
    puts '║' + ' ' * 20 + 'RAG INFRASTRUCTURE DEPLOYER' + ' ' * 31 + '║'
    puts '╚' + '═' * 78 + '╝'
    puts
    puts "  Provider: #{@provider.to_s.upcase}"
    puts "  Command:  #{@command}"
    puts "  Script:   #{PROVIDERS[@provider]}"
    puts
  end
end

# Display help
if ARGV.include?('--help') || ARGV.include?('-h')
  puts 'RAG Infrastructure Deployment Tool'
  puts
  puts 'Usage: ruby deploy.rb [COMMAND]'
  puts
  puts 'Commands:'
  puts '  deploy  - Create all cloud resources (default)'
  puts '  destroy - Delete all cloud resources'
  puts '  status  - Check status of deployed resources'
  puts
  puts 'Environment Variables:'
  puts '  CLOUD_PROVIDER - Cloud provider to use (azure, aws, gcp)'
  puts '                   Default: azure'
  puts
  puts 'Examples:'
  puts '  # Deploy to Azure (default)'
  puts '  ruby deploy.rb deploy'
  puts
  puts '  # Deploy to AWS'
  puts '  CLOUD_PROVIDER=aws ruby deploy.rb deploy'
  puts
  puts '  # Check status'
  puts '  ruby deploy.rb status'
  puts
  puts '  # Destroy infrastructure'
  puts '  ruby deploy.rb destroy'
  puts
  puts 'Configuration:'
  puts '  1. Copy env.template to .env'
  puts '  2. Fill in your credentials'
  puts '  3. Run deployment'
  puts
  exit 0
end

# Run deployment
deployer = InfrastructureDeployer.new
deployer.run
