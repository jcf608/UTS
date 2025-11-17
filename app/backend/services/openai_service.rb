require 'openai'

class OpenAIService
  def self.client
    @client ||= OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  # Create embeddings for text
  def self.create_embedding(text)
    response = client.embeddings(
      parameters: {
        model: 'text-embedding-ada-002',
        input: text
      }
    )

    response.dig('data', 0, 'embedding')
  end

  # Generate answer from context
  def self.generate_answer(question, context_chunks)
    # Use :content (from search results) or :text (from processing)
    context_text = context_chunks.map { |chunk| chunk[:content] || chunk[:text] }.join("\n\n---\n\n")

    messages = [
      {
        role: 'system',
        content: 'You are a helpful assistant that answers questions based on the provided documents. ' \
                 'Only use information from the documents to answer. If the answer is not in the documents, say so.'
      },
      {
        role: 'user',
        content: "Context from documents:\n\n#{context_text}\n\n---\n\nQuestion: #{question}"
      }
    ]

    response = client.chat(
      parameters: {
        model: 'gpt-4',
        messages: messages,
        temperature: 0.7,
        max_tokens: 500
      }
    )

    response.dig('choices', 0, 'message', 'content')
  end
end
