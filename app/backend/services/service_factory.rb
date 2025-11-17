# Factory for cloud services with metaprogramming
# Eliminates repetitive case statements per PRINCIPLES.md
class ServiceFactory
  # Service configuration - easily extensible
  PROVIDERS = {
    azure: {
      storage: 'AzureStorageService',
      search: 'AzureSearchService'
    },
    aws: {
      storage: 'S3StorageService',
      search: 'OpenSearchService'
    },
    gcp: {
      storage: 'GcsStorageService',
      search: 'VertexSearchService'
    }
  }.freeze

  # Metaprogramming: Create storage service for current provider
  def self.storage_service
    create_service(:storage)
  end

  # Metaprogramming: Create search service for current provider
  def self.search_service
    create_service(:search)
  end

  # Generic service creator using metaprogramming
  # Avoids repetitive case statements per PRINCIPLES.md Section 1.2
  def self.create_service(service_type)
    provider = current_provider

    unless PROVIDERS.key?(provider)
      raise ArgumentError, "Unknown provider: #{provider}. Valid: #{PROVIDERS.keys.join(', ')}"
    end

    class_name = PROVIDERS[provider][service_type]

    unless class_name
      raise ArgumentError, "No #{service_type} service for provider: #{provider}"
    end

    # Use const_get for metaprogramming (avoids case statement)
    Object.const_get(class_name)
  rescue NameError => e
    raise StandardError, "Service #{class_name} not found. Implement it or check configuration. Error: #{e.message}"
  end

  # Determine current provider from environment
  def self.current_provider
    provider = ENV['CLOUD_PROVIDER']&.to_sym || :azure

    # Auto-detect if not explicitly set
    if provider == :azure && ENV['AZURE_STORAGE_CONNECTION_STRING']
      return :azure
    elsif provider == :aws && ENV['AWS_ACCESS_KEY_ID']
      return :aws
    elsif provider == :gcp && ENV['GCP_PROJECT_ID']
      return :gcp
    end

    provider
  end

  # List all configured providers
  def self.available_providers
    PROVIDERS.keys.select do |provider|
      case provider
      when :azure
        ENV['AZURE_STORAGE_CONNECTION_STRING'].present?
      when :aws
        ENV['AWS_ACCESS_KEY_ID'].present?
      when :gcp
        ENV['GCP_PROJECT_ID'].present?
      else
        false
      end
    end
  end
end
