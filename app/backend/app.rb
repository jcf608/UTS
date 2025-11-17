require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/namespace'
require 'sinatra/cross_origin'
require 'sinatra/activerecord'
require 'dotenv'
require 'time'

# Load environment from multiple locations
Dotenv.load(
  File.expand_path('../../.env', __dir__),  # UTS/.env
  File.expand_path('.env', __dir__)         # backend/.env
)

# Database configuration handled by config/database.yml

module UTS
  class API < Sinatra::Base
    register Sinatra::Namespace
    register Sinatra::ActiveRecordExtension

    # Configuration
    configure do
      set :port, ENV['BACKEND_PORT'] || 4000
      set :bind, '0.0.0.0'
      enable :cross_origin
      set :allow_origin, ENV['FRONTEND_URL'] || 'http://localhost:8080'
      set :allow_methods, 'GET,HEAD,POST,PUT,DELETE,OPTIONS,PATCH'
      set :allow_headers, 'Content-Type,Accept,Authorization'
      set :expose_headers, 'Content-Type'
      set :database_file, File.join(settings.root, 'config', 'database.yml')
    end

    # Load models after database is configured
    Dir[File.join(settings.root, 'models', '*.rb')].sort.each { |file| require file }

    # Load services - base classes first (inheritance)
    require File.join(settings.root, 'services', 'base_storage_service.rb')
    require File.join(settings.root, 'services', 'base_search_service.rb')
    require File.join(settings.root, 'services', 'service_factory.rb')

    # Then load concrete implementations and other services
    Dir[File.join(settings.root, 'services', '*.rb')]
      .sort
      .reject { |f| f.include?('base_') || f.include?('factory') }
      .each { |file| require file }

    # CORS - More permissive for development
    before do
      response.headers['Access-Control-Allow-Origin'] = '*'
      response.headers['Access-Control-Allow-Methods'] = 'GET,HEAD,POST,PUT,DELETE,OPTIONS,PATCH'
      response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Accept,Authorization,X-Requested-With'
      response.headers['Access-Control-Max-Age'] = '86400'
    end

    options '*' do
      response.headers['Access-Control-Allow-Origin'] = '*'
      response.headers['Access-Control-Allow-Methods'] = 'GET,HEAD,POST,PUT,DELETE,OPTIONS,PATCH'
      response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Accept,Authorization,X-Requested-With'
      200
    end

    # Health check
    get '/health' do
      json status: 'ok', timestamp: Time.now.iso8601
    end

    # API v1
    namespace '/api/v1' do
      # Load route handlers
      Dir[File.join(__dir__, 'routes', '*.rb')].sort.each { |file| require file }

      # Dashboard
      get '/dashboard/stats' do
        json({
          total_documents: Document.count,
          total_queries: 0,  # TODO: implement query tracking
          avg_response_time: 0,  # TODO: implement timing
          system_health: 'healthy',
          timestamp: Time.now.iso8601
        })
      end

      # Documents - with SAS URLs for download
      get '/documents' do
        storage_service = ServiceFactory.storage_service

        documents = Document.recent.map do |doc|
          doc_json = doc.to_json_api

          # Generate temporary download URL if blob exists
          if doc.metadata && doc.metadata['blob_name']
            doc_json[:download_url] = storage_service.generate_download_url(
              doc.metadata['blob_name'],
              expires_in: 3600  # 1 hour
            )
          end

          doc_json
        end

        json documents: documents
      end

      post '/documents' do
        # Handle file upload
        puts "📥 Received upload request. Params: #{params.keys}"
        puts "   File param present: #{params[:file].present?}"

        unless params[:file] && params[:file][:tempfile]
          puts "❌ No file in params"
          response.headers['Access-Control-Allow-Origin'] = '*'
          halt 400, json(error: 'No file provided', params_received: params.keys)
        end

        file = params[:file]
        content = file[:tempfile].read

        puts "📤 Uploading: #{file[:filename]} (#{content.bytesize} bytes)"

        # Clean content for PostgreSQL - remove null bytes and fix encoding
        safe_content = content.force_encoding('UTF-8')
                              .encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
                              .gsub("\u0000", '')  # Remove null bytes

        # Upload to cloud storage (using factory - cloud-agnostic!)
        storage_service = ServiceFactory.storage_service
        storage_result = storage_service.upload_document(file[:filename], content)
        puts "✅ #{storage_result[:provider].upcase} upload successful: #{storage_result[:blob_url]}"

        # Save to database with cloud storage URL
        document = Document.create!(
          title: file[:filename],
          content: safe_content[0..10000], # Store first 10KB only
          status: :pending,
          blob_url: storage_result[:blob_url],
          metadata: {
            size: content.bytesize,
            content_type: file[:type],
            uploaded_at: Time.now.iso8601,
            cloud_provider: storage_result[:provider],
            blob_name: storage_result[:blob_name],
            container: storage_result[:container]
          }
        )

        puts "✅ Database save successful: Document ID #{document.id}"

        # Process document in background (create embeddings and index)
        puts "🔄 Starting document processing..."
        processing_result = DocumentProcessor.process_document(document)

        response.headers['Access-Control-Allow-Origin'] = '*'
        json({
          success: true,
          document: document.to_json_api,
          processing: processing_result,
          message: 'Document uploaded, embedded, and indexed successfully'
        })
      rescue StandardError => e
        # Handle encoding in error messages
        safe_error_msg = e.message.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        puts "❌ Upload error: #{e.class.name}: #{safe_error_msg}"
        puts e.backtrace.first(5).join("\n")
        response.headers['Access-Control-Allow-Origin'] = '*'
        status 422
        json error: 'Upload failed', message: safe_error_msg, error_class: e.class.name
      end

      # Search - RAG Implementation
      post '/search' do
        body = JSON.parse(request.body.read)
        query_text = body['query']

        halt 400, json(error: 'Query is required') if query_text.nil? || query_text.empty?

        # Perform RAG search
        result = DocumentProcessor.search(query_text)

        json({
          success: true,
          query: query_text,
          answer: result[:answer],
          sources: result[:sources],
          chunks_found: result[:chunks_found],
          timestamp: Time.now.iso8601
        })
      rescue StandardError => e
        status 422
        json error: 'Search failed', message: e.message
      end
    end

    # Error handlers - ensure CORS headers
    error do
      response.headers['Access-Control-Allow-Origin'] = '*'
      json error: 'Internal server error', message: env['sinatra.error'].message
    end

    not_found do
      response.headers['Access-Control-Allow-Origin'] = '*'
      json error: 'Not found'
    end
  end
end
