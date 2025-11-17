#!/usr/bin/env ruby

require 'dotenv'

puts "azure_auth_oop.rb - Version 2.0"
puts

# SUPERCLASS: LoginProvider
# Base class for cloud provider authentication
class LoginProvider
  attr_reader :credentials

  def initialize
    Dotenv.load('.env')
    @credentials = {}
    load_credentials
    validate_credentials
  end

  # Template method - defines the login workflow
  def login
    puts "Logging in to #{provider_name}..."
    display_credentials

    command = login_cli_commands
    puts "Executing: #{command}"
    puts

    success = system(command)

    unless success
      puts
      puts "ERROR: Login failed"
      exit 1
    end

    post_login_setup
    verify_connection
  end

  # Template method - defines the logout workflow
  def logout
    puts
    puts "Logging out from #{provider_name}..."
    system(logout_cli_command)
    puts
    puts "Session complete."
  end

  # Abstract methods - must be implemented by subclasses
  def provider_name
    raise NotImplementedError, "Subclass must implement provider_name"
  end

  def load_credentials
    raise NotImplementedError, "Subclass must implement load_credentials"
  end

  def validate_credentials
    raise NotImplementedError, "Subclass must implement validate_credentials"
  end

  def login_cli_commands
    raise NotImplementedError, "Subclass must implement login_cli_commands"
  end

  def logout_cli_command
    raise NotImplementedError, "Subclass must implement logout_cli_command"
  end

  def post_login_setup
    # Optional hook for subclasses
  end

  def verify_connection
    # Optional hook for subclasses
  end

  protected

  def display_credentials
    @credentials.each do |key, value|
      puts "#{key}: #{value}"
    end
    puts
  end
end


# SUBCLASS: AzureLoginProvider
# Implements Azure-specific authentication
class AzureLoginProvider < LoginProvider
  def provider_name
    "Azure"
  end

  # Load Azure-specific environment variables
  def load_credentials
    @credentials[:subscription_id] = ENV['AZURE_SUBSCRIPTION_ID']
    @credentials[:tenant_id] = ENV['AZURE_TENANT_ID']
  end

  # Validate Azure-specific credentials
  def validate_credentials
    if @credentials[:subscription_id].nil? || @credentials[:subscription_id].empty?
      puts "ERROR: AZURE_SUBSCRIPTION_ID not found in .env file"
      exit 1
    end

    if @credentials[:tenant_id].nil? || @credentials[:tenant_id].empty?
      puts "ERROR: AZURE_TENANT_ID not found in .env file"
      exit 1
    end
  end

  # Returns the Azure CLI login command as a string
  def login_cli_commands
    "az login --tenant #{@credentials[:tenant_id]}"
  end

  # Returns the Azure CLI logout command
  def logout_cli_command
    "az logout"
  end

  # Azure-specific: Set subscription context after login
  def post_login_setup
    puts
    puts "Setting subscription context..."
    system("az account set --subscription #{@credentials[:subscription_id]}")
  end

  # Azure-specific: Verify the current subscription
  def verify_connection
    puts
    puts "Verifying current subscription..."
    system("az account show")
  end
end


# SUBCLASS: AWSLoginProvider
# Implements AWS-specific authentication (STUB)
class AWSLoginProvider < LoginProvider
  def provider_name
    "Amazon Web Services"
  end

  # Load AWS-specific environment variables
  def load_credentials
    @credentials[:account_id] = ENV['AWS_ACCOUNT_ID']
    @credentials[:region] = ENV['AWS_REGION']
    @credentials[:profile] = ENV['AWS_PROFILE'] || 'default'
  end

  # Validate AWS-specific credentials
  def validate_credentials
    if @credentials[:account_id].nil? || @credentials[:account_id].empty?
      puts "ERROR: AWS_ACCOUNT_ID not found in .env file"
      exit 1
    end

    if @credentials[:region].nil? || @credentials[:region].empty?
      puts "ERROR: AWS_REGION not found in .env file"
      exit 1
    end
  end

  # Returns the AWS CLI login command as a string
  def login_cli_commands
    "aws configure set region #{@credentials[:region]}"
  end

  # Returns the AWS CLI logout command (AWS doesn't have explicit logout)
  def logout_cli_command
    "echo 'AWS session ended (no explicit logout command)'"
  end

  # AWS-specific: Verify credentials
  def verify_connection
    puts
    puts "Verifying AWS credentials..."
    system("aws sts get-caller-identity")
  end
end


# SUBCLASS: GCPLoginProvider
# Implements Google Cloud Platform-specific authentication (STUB)
class GCPLoginProvider < LoginProvider
  def provider_name
    "Google Cloud Platform"
  end

  # Load GCP-specific environment variables
  def load_credentials
    @credentials[:project_id] = ENV['GCP_PROJECT_ID']
    @credentials[:region] = ENV['GCP_REGION'] || 'us-central1'
  end

  # Validate GCP-specific credentials
  def validate_credentials
    if @credentials[:project_id].nil? || @credentials[:project_id].empty?
      puts "ERROR: GCP_PROJECT_ID not found in .env file"
      exit 1
    end
  end

  # Returns the GCP CLI login command as a string
  def login_cli_commands
    "gcloud auth login --project #{@credentials[:project_id]}"
  end

  # Returns the GCP CLI logout command
  def logout_cli_command
    "gcloud auth revoke"
  end

  # GCP-specific: Set project context after login
  def post_login_setup
    puts
    puts "Setting project context..."
    system("gcloud config set project #{@credentials[:project_id]}")
  end

  # GCP-specific: Verify the current project
  def verify_connection
    puts
    puts "Verifying current project..."
    system("gcloud config list")
  end
end


# MAIN EXECUTION
# ==============

# CHOOSE YOUR PROVIDER - uncomment the one you want to use:

provider = AzureLoginProvider.new     # Default for Valorica project
 provider = AWSLoginProvider.new     # Uncomment to test AWS
# provider = GCPLoginProvider.new     # Uncomment to test GCP

# Execute the login workflow
provider.login

# Execute the logout workflow
provider.logout
