# Document processing service using Factory pattern
# Cloud-agnostic - works with any storage/search provider
class DocumentProcessor
  CHUNK_SIZE = 1000  # Characters per chunk
  CHUNK_OVERLAP = 200  # Overlap between chunks

  # Split document into chunks for embedding (cloud-agnostic)
  def self.chunk_text(text)
    chunks = []
    start = 0

    while start < text.length
      # Get chunk
      chunk_end = [start + CHUNK_SIZE, text.length].min
      chunk_text = text[start...chunk_end]

      chunks << {
        text: chunk_text,
        start: start,
        end: chunk_end
      }

      # Move to next chunk with overlap
      start += (CHUNK_SIZE - CHUNK_OVERLAP)
    end

    chunks
  end

  # Process document: chunk → embed → index
  def self.process_document(document)
    puts "🔄 Processing document #{document.id}: #{document.title}"

    # Split into chunks
    chunks = chunk_text(document.content)
    puts "   📄 Created #{chunks.length} chunks"

    # Create embeddings for each chunk
    chunks_with_embeddings = chunks.map.with_index do |chunk, i|
      puts "   🧠 Creating embedding #{i + 1}/#{chunks.length}..."
      embedding = OpenAIService.create_embedding(chunk[:text])
      chunk.merge(embedding: embedding)
    end

    puts "   ✅ Created #{chunks_with_embeddings.length} embeddings"

    # Index in vector search (using factory - cloud-agnostic!)
    search_service = ServiceFactory.search_service
    puts "   📊 Indexing in #{search_service.provider_name.upcase} search..."
    search_service.index_document(
      document.id,
      document.title,
      chunks_with_embeddings
    )

    puts "   ✅ Indexed successfully"

    # Update document status
    search_service = ServiceFactory.search_service
    document.update!(
      status: :indexed,
      search_index_id: "#{search_service::INDEX_NAME}/#{document.id}"
    )

    puts "✅ Processing complete for document #{document.id}"

    {
      success: true,
      chunks_created: chunks.length,
      embeddings_created: chunks_with_embeddings.length
    }
  rescue StandardError => e
    # Mark as failed
    document.update!(status: :failed) if document

    puts "❌ Processing failed: #{e.message}"
    {
      success: false,
      error: e.message
    }
  end

  # Perform RAG search
  def self.search(query)
    puts "🔍 RAG Search: #{query}"

    # Create embedding for query
    puts "   🧠 Creating query embedding..."
    query_embedding = OpenAIService.create_embedding(query)

    # Search for similar chunks (using factory - cloud-agnostic!)
    search_service = ServiceFactory.search_service
    puts "   📊 Searching #{search_service.provider_name.upcase}..."
    results = search_service.vector_search(query_embedding, top_k: 5)

    puts "   ✅ Found #{results.length} relevant chunks"

    # Clean chunks - remove encoding issues before sending to OpenAI
    clean_results = results.map do |r|
      {
        title: r[:title],
        content: clean_text(r[:content].to_s),
        document_id: r[:document_id]
      }
    end

    # Generate answer using OpenAI
    puts "   🤖 Generating answer with GPT-4..."
    answer = OpenAIService.generate_answer(query, clean_results)

    puts "   ✅ Answer generated"

    {
      query: query,
      answer: answer,
      sources: clean_results.map { |r| { title: r[:title], content: r[:content][0...200] } },
      chunks_found: results.length
    }
  end

  private

  # Clean text for safe processing
  def self.clean_text(text)
    text.force_encoding('UTF-8')
        .encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
        .gsub("\u0000", '')  # Remove null bytes
        .gsub(/[^\x20-\x7E\n\r\t]/, '')  # Remove non-printable chars except newlines/tabs
  end
end
