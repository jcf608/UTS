# Base class for vector search services
# Template Method Pattern for search workflow
class BaseSearchService
  INDEX_NAME = 'documents-index'
  VECTOR_DIMENSIONS = 1536  # OpenAI ada-002 embedding size

  # Template method - search workflow
  def self.index_document(document_id, title, chunks_with_embeddings)
    validate_configuration!
    ensure_index_exists

    # Subclass implements actual indexing
    index_chunks(document_id, title, chunks_with_embeddings)
  end

  # Template method - vector search workflow
  def self.vector_search(query_embedding, top_k: 5)
    validate_configuration!
    ensure_index_exists

    # Subclass implements actual search
    search_vectors(query_embedding, top_k)
  end

  # Template methods for index management
  def self.ensure_index_exists
    create_index unless index_exists?
  end

  # Abstract methods - must be implemented by subclasses
  def self.index_exists?
    raise NotImplementedError, "#{name} must implement index_exists?"
  end

  def self.create_index
    raise NotImplementedError, "#{name} must implement create_index"
  end

  def self.index_chunks(document_id, title, chunks_with_embeddings)
    raise NotImplementedError, "#{name} must implement index_chunks"
  end

  def self.search_vectors(query_embedding, top_k)
    raise NotImplementedError, "#{name} must implement search_vectors"
  end

  def self.validate_configuration!
    raise NotImplementedError, "#{name} must implement validate_configuration!"
  end

  def self.provider_name
    raise NotImplementedError, "#{name} must implement provider_name"
  end

  # Shared HTTP client setup
  def self.https_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if ENV['RACK_ENV'] == 'development'
    http
  end

  # Shared JSON response parsing
  def self.parse_json_response(response)
    unless response.code.to_i == 200
      raise StandardError, "Request failed: #{response.code} - #{response.body}"
    end

    JSON.parse(response.body, symbolize_names: true)
  end

  # Shared error handling
  def self.handle_search_error(error, operation)
    raise StandardError, "#{provider_name.upcase} #{operation} failed: #{error.message}"
  end

  # Shared validation for search results
  def self.validate_search_results(results)
    return [] unless results && results[:value]
    results[:value]
  end
end
