#!/usr/bin/env ruby
# frozen_string_literal: true

# Base class for infrastructure deployment across cloud providers
# Follows Template Method pattern for consistent deployment workflow

class BaseInfrastructure
  attr_reader :config, :resources_created

  def initialize(config = {})
    @config = config
    @resources_created = []
    @provider = self.class.name.split('::').first.downcase.to_sym
    load_configuration
    validate_configuration
  end

  # Template method - defines the deployment workflow
  def deploy
    puts "\n#{divider}"
    puts "🚀 Starting #{provider_name} Infrastructure Deployment"
    puts divider
    puts

    authenticate
    validate_region_capabilities  # Check BEFORE creating anything
    create_resource_group
    create_storage
    create_vector_database
    create_ai_services
    create_networking
    configure_security
    output_summary

    puts
    puts "#{divider}"
    puts "✅ Deployment Complete!"
    puts divider
    puts

    @resources_created
  end

  # Template method - cleanup/destroy infrastructure
  def destroy
    puts "\n#{divider}"
    puts "🗑️  Destroying #{provider_name} Infrastructure"
    puts divider
    puts

    confirm_destruction
    authenticate
    destroy_resources

    puts
    puts "#{divider}"
    puts "✅ Destruction Complete!"
    puts divider
    puts
  end

  # Template method - show current infrastructure status
  def status
    puts "\n#{divider}"
    puts "📊 #{provider_name} Infrastructure Status"
    puts divider
    puts

    authenticate
    check_resource_status

    puts divider
    puts
  end

  protected

  # Abstract methods - must be implemented by subclasses
  def provider_name
    raise NotImplementedError, 'Subclass must implement provider_name'
  end

  def load_configuration
    raise NotImplementedError, 'Subclass must implement load_configuration'
  end

  def validate_configuration
    raise NotImplementedError, 'Subclass must implement validate_configuration'
  end

  def authenticate
    raise NotImplementedError, 'Subclass must implement authenticate'
  end

  def create_resource_group
    raise NotImplementedError, 'Subclass must implement create_resource_group'
  end

  def create_storage
    raise NotImplementedError, 'Subclass must implement create_storage'
  end

  def create_vector_database
    raise NotImplementedError, 'Subclass must implement create_vector_database'
  end

  def create_ai_services
    raise NotImplementedError, 'Subclass must implement create_ai_services'
  end

  def validate_region_capabilities
    # Optional - providers can override this for region validation
    # Default: assume region is valid
    puts 'ℹ️  Region validation: Skipped (provider-specific validation available)'
    true
  end

  def create_networking
    # Optional - some providers may not need this
    puts '⏭️  Networking: Using default configuration'
  end

  def configure_security
    # Optional - some providers may not need explicit setup
    puts '⏭️  Security: Using default configuration'
  end

  def destroy_resources
    raise NotImplementedError, 'Subclass must implement destroy_resources'
  end

  def check_resource_status
    raise NotImplementedError, 'Subclass must implement check_resource_status'
  end

  # Helper methods available to all subclasses
  def confirm_destruction
    print "\n⚠️  WARNING: This will DELETE ALL resources. Type 'destroy' to confirm: "
    confirmation = $stdin.gets.chomp

    unless confirmation == 'destroy'
      puts '❌ Destruction cancelled'
      exit 0
    end

    puts '✅ Destruction confirmed'
  end

  def output_summary
    puts
    puts '=' * 80
    puts '📋 Deployment Summary'
    puts '=' * 80
    puts

    if @resources_created.empty?
      puts '  No resources created (they may already exist)'
    else
      @resources_created.each do |resource|
        puts "  ✅ #{resource[:type]}: #{resource[:name]}"
        puts "     ID: #{resource[:id]}" if resource[:id]
        puts "     Endpoint: #{resource[:endpoint]}" if resource[:endpoint]
        puts
      end
    end

    puts '=' * 80
  end

  def record_resource(type, name, id: nil, endpoint: nil, **extras)
    @resources_created << {
      type: type,
      name: name,
      id: id,
      endpoint: endpoint,
      provider: @provider
    }.merge(extras)
  end

  def execute_command(command, description: nil)
    puts "▶️  #{description || 'Executing command'}"
    puts "   Command: #{command}" if ENV['DEBUG']

    output = `#{command} 2>&1`
    success = $?.success?

    if success
      puts '   ✅ Success'
      output
    else
      puts "   ❌ Failed: #{output}"
      # Include the output in the error message so it can be checked
      raise "Command failed: #{command}\nOutput: #{output}"
    end
  end

  def divider
    '=' * 80
  end

  def section_header(title)
    puts
    puts '-' * 80
    puts "  #{title}"
    puts '-' * 80
  end
end
