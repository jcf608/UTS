require 'net/http'
require 'uri'
require 'json'

# Azure implementation of base search service
class AzureSearchService < BaseSearchService

  def self.provider_name
    'azure'
  end

  def self.validate_configuration!
    raise StandardError, 'AZURE_SEARCH_ENDPOINT not set' unless ENV['AZURE_SEARCH_ENDPOINT']
    raise StandardError, 'AZURE_SEARCH_ADMIN_KEY not set' unless ENV['AZURE_SEARCH_ADMIN_KEY']
  end

  # Implement index_exists? (called by base class)
  def self.index_exists?
    uri = URI("#{search_endpoint}/indexes/#{INDEX_NAME}?api-version=2024-05-01-preview")
    request = Net::HTTP::Get.new(uri)
    request['api-key'] = search_key

    # Use shared HTTP client from base class
    response = https_client(uri).request(request)

    response.code.to_i == 200
  rescue StandardError
    false
  end

  def self.create_index
    # Use newer API version that supports vector search
    uri = URI("#{search_endpoint}/indexes?api-version=2024-05-01-preview")
    request = Net::HTTP::Post.new(uri)
    request['api-key'] = search_key
    request['Content-Type'] = 'application/json'

    index_schema = {
      name: INDEX_NAME,
      fields: [
        { name: 'id', type: 'Edm.String', key: true, filterable: true },
        { name: 'document_id', type: 'Edm.Int32', filterable: true },
        { name: 'title', type: 'Edm.String', searchable: true },
        { name: 'content', type: 'Edm.String', searchable: true },
        {
          name: 'content_vector',
          type: 'Collection(Edm.Single)',
          searchable: true,
          dimensions: 1536,
          vectorSearchProfile: 'vector-profile'
        }
      ],
      vectorSearch: {
        profiles: [
          {
            name: 'vector-profile',
            algorithm: 'hnsw-config'
          }
        ],
        algorithms: [
          {
            name: 'hnsw-config',
            kind: 'hnsw',
            hnswParameters: {
              metric: 'cosine',
              m: 4,
              efConstruction: 400,
              efSearch: 500
            }
          }
        ]
      }
    }

    request.body = index_schema.to_json

    # Use shared HTTP client
    response = https_client(uri).request(request)

    # Validate using base class method
    unless response.code.to_i == 201
      handle_search_error(StandardError.new(response.body), 'create index')
    end

    true
  rescue StandardError => e
    handle_search_error(e, 'create index')
  end

  # Implement index_chunks (called by base class template method)
  def self.index_chunks(document_id, title, chunks_with_embeddings)

    uri = URI("#{search_endpoint}/indexes/#{INDEX_NAME}/docs/index?api-version=2024-05-01-preview")
    request = Net::HTTP::Post.new(uri)
    request['api-key'] = search_key
    request['Content-Type'] = 'application/json'

    # Prepare documents for indexing
    docs = chunks_with_embeddings.map.with_index do |chunk, i|
      {
        '@search.action': 'upload',
        id: "#{document_id}_#{i}",
        document_id: document_id,
        title: title,
        content: chunk[:text],
        content_vector: chunk[:embedding]
      }
    end

    request.body = { value: docs }.to_json

    # Use shared HTTP client
    response = https_client(uri).request(request)

    unless response.code.to_i == 200
      handle_search_error(StandardError.new(response.body), 'index document')
    end

    true
  rescue StandardError => e
    handle_search_error(e, 'index document')
  end

  # Implement search_vectors (called by base class template method)
  def self.search_vectors(query_embedding, top_k)

    uri = URI("#{search_endpoint}/indexes/#{INDEX_NAME}/docs/search?api-version=2024-05-01-preview")
    request = Net::HTTP::Post.new(uri)
    request['api-key'] = search_key
    request['Content-Type'] = 'application/json'

    search_query = {
      vectorQueries: [
        {
          kind: 'vector',
          vector: query_embedding,
          fields: 'content_vector',
          k: top_k
        }
      ],
      select: 'id,document_id,title,content'
    }

    request.body = search_query.to_json

    # Use shared HTTP client and response parsing
    response = https_client(uri).request(request)
    result = parse_json_response(response)

    # Use shared result validation
    validate_search_results(result)
  rescue StandardError => e
    handle_search_error(e, 'vector search')
  end

  private

  def self.search_endpoint
    ENV['AZURE_SEARCH_ENDPOINT']
  end

  def self.search_key
    ENV['AZURE_SEARCH_ADMIN_KEY']
  end
end
