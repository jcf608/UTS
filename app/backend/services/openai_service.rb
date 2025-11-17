require 'openai'
require 'tiktoken_ruby'
require 'logger'

class OpenAIService
  # Token limits for different models
  MODEL_LIMITS = {
    'text-embedding-ada-002' => 8191,
    'gpt-4' => 8192,
    'gpt-4-turbo' => 128_000,
    'gpt-4o' => 128_000,
    'gpt-4o-mini' => 128_000
  }.freeze

  # Model to use for chat completions (configurable via Settings or ENV)
  def self.chat_model
    Setting.get('openai_chat_model', ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-4-turbo'))
  rescue StandardError
    ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-4-turbo')
  end

  def self.embedding_model
    Setting.get('openai_embedding_model', ENV.fetch('OPENAI_EMBEDDING_MODEL', 'text-embedding-ada-002'))
  rescue StandardError
    ENV.fetch('OPENAI_EMBEDDING_MODEL', 'text-embedding-ada-002')
  end

  # Token budgets for answer generation (configurable via Settings or ENV)
  def self.max_output_tokens
    Setting.get('openai_max_output_tokens', ENV.fetch('OPENAI_MAX_OUTPUT_TOKENS', '2000')).to_i
  rescue StandardError
    ENV.fetch('OPENAI_MAX_OUTPUT_TOKENS', '2000').to_i
  end

  def self.context_token_budget
    Setting.get('openai_context_budget', '6000').to_i
  rescue StandardError
    6000
  end

  SYSTEM_PROMPT_BUFFER = 100   # Buffer for system prompt tokens
  QUESTION_BUFFER = 500        # Buffer for question tokens

  def self.client
    @client ||= OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def self.logger
    @logger ||= Logger.new($stdout).tap do |log|
      level_name = begin
        Setting.get('log_level', ENV.fetch('LOG_LEVEL', 'info'))
      rescue StandardError
        ENV.fetch('LOG_LEVEL', 'info')
      end

      log.level = case level_name.downcase
                  when 'debug' then Logger::DEBUG
                  when 'info' then Logger::INFO
                  when 'warn' then Logger::WARN
                  when 'error' then Logger::ERROR
                  else Logger::INFO
                  end
    end
  end

  # Get token encoder for a specific model
  def self.encoder_for_model(model)
    @encoders ||= {}
    @encoders[model] ||= Tiktoken.encoding_for_model(model)
  end

  # Count tokens in text for a specific model
  def self.count_tokens(text, model = nil)
    model ||= chat_model
    return 0 if text.nil? || text.empty?
    encoder = encoder_for_model(model)
    encoder.encode(text).length
  rescue StandardError => e
    logger.warn "Token counting failed: #{e.message}. Using rough estimate."
    # Fallback: rough estimate (1 token ≈ 4 characters)
    (text.length / 4.0).ceil
  end

  # Count tokens in messages array
  def self.count_message_tokens(messages, model = nil)
    model ||= chat_model
    # Tokens per message overhead varies by model
    tokens_per_message = model.start_with?('gpt-4') ? 3 : 4
    tokens_per_name = 1

    num_tokens = 0
    messages.each do |message|
      num_tokens += tokens_per_message
      message.each do |key, value|
        num_tokens += count_tokens(value.to_s, model)
        num_tokens += tokens_per_name if key == :name
      end
    end
    num_tokens += 3  # Every reply is primed with assistant
    num_tokens
  end

  # Create embeddings for text with token limit checking
  def self.create_embedding(text)
    model = embedding_model
    token_count = count_tokens(text, model)
    max_tokens = MODEL_LIMITS[model]

    if token_count > max_tokens
      logger.warn "Text exceeds embedding limit (#{token_count} > #{max_tokens}). Truncating..."
      text = truncate_text_to_tokens(text, max_tokens - 10, model)
      token_count = count_tokens(text, model)
    end

    logger.debug "Creating embedding for #{token_count} tokens"

    response = client.embeddings(
      parameters: {
        model: model,
        input: text
      }
    )

    # Log usage
    usage = response['usage']
    log_token_usage('embedding', usage) if usage

    response.dig('data', 0, 'embedding')
  end

  # Truncate text to fit within token limit
  def self.truncate_text_to_tokens(text, max_tokens, model = nil)
    model ||= chat_model
    encoder = encoder_for_model(model)
    tokens = encoder.encode(text)

    if tokens.length <= max_tokens
      return text
    end

    truncated_tokens = tokens[0...max_tokens]
    encoder.decode(truncated_tokens)
  end

  # Truncate context chunks to fit within budget
  def self.truncate_context_chunks(context_chunks, max_tokens = nil)
    max_tokens ||= context_token_budget
    return [] if context_chunks.nil? || context_chunks.empty?

    truncated_chunks = []
    total_tokens = 0

    model = chat_model
    context_chunks.each do |chunk|
      chunk_text = chunk[:content] || chunk[:text] || ''
      chunk_tokens = count_tokens(chunk_text, model)

      if total_tokens + chunk_tokens <= max_tokens
        # Whole chunk fits
        truncated_chunks << chunk_text
        total_tokens += chunk_tokens
      elsif total_tokens < max_tokens
        # Partial chunk fits
        remaining_tokens = max_tokens - total_tokens
        truncated_text = truncate_text_to_tokens(chunk_text, remaining_tokens, model)
        truncated_chunks << truncated_text
        total_tokens += remaining_tokens
        logger.warn "Truncated chunk to fit budget (#{chunk_tokens} -> #{remaining_tokens} tokens)"
        break
      else
        # No more space
        logger.warn "Stopped adding chunks at #{truncated_chunks.length}/#{context_chunks.length} (#{total_tokens} tokens)"
        break
      end
    end

    logger.info "Context: #{truncated_chunks.length} chunks, #{total_tokens} tokens"
    truncated_chunks
  end

  # Generate answer from context with comprehensive token management
  def self.generate_answer(question, context_chunks)
    model = chat_model
    # Truncate context to fit within budget
    truncated_texts = truncate_context_chunks(context_chunks, context_token_budget)
    context_text = truncated_texts.join("\n\n---\n\n")

    system_prompt = 'You are a helpful assistant that answers questions based on the provided documents. ' \
                    'Only use information from the documents to answer. If the answer is not in the documents, say so.'

    messages = [
      { role: 'system', content: system_prompt },
      { role: 'user', content: "Context from documents:\n\n#{context_text}\n\n---\n\nQuestion: #{question}" }
    ]

    # Count total input tokens
    input_tokens = count_message_tokens(messages, model)
    max_model_tokens = MODEL_LIMITS[model]
    max_output = [max_output_tokens, max_model_tokens - input_tokens - 100].min

    logger.info "Chat request: model=#{model}, input_tokens=#{input_tokens}, max_output=#{max_output}"

    # Check if we're within limits
    if input_tokens + max_output > max_model_tokens
      logger.error "Token limit exceeded! input=#{input_tokens} + output=#{max_output} > #{max_model_tokens}"
      raise "Token limit exceeded. Try reducing context or question length."
    end

    # Log token usage warning if close to limit
    usage_percent = (input_tokens.to_f / max_model_tokens * 100).round(1)
    if usage_percent > 80
      logger.warn "⚠️  High token usage: #{usage_percent}% of model limit"
    elsif usage_percent > 60
      logger.info "Token usage: #{usage_percent}% of model limit"
    end

    response = client.chat(
      parameters: {
        model: model,
        messages: messages,
        temperature: 0.7,
        max_tokens: max_output
      }
    )

    # Log detailed usage
    usage = response['usage']
    log_token_usage('chat', usage) if usage

    response.dig('choices', 0, 'message', 'content')
  end

  # Log token usage statistics
  def self.log_token_usage(operation, usage)
    prompt_tokens = usage['prompt_tokens'] || 0
    completion_tokens = usage['completion_tokens'] || 0
    total_tokens = usage['total_tokens'] || 0

    logger.info "📊 Token Usage [#{operation}]: " \
                "prompt=#{prompt_tokens}, " \
                "completion=#{completion_tokens}, " \
                "total=#{total_tokens}"

    # Estimate cost (as of 2024 pricing - adjust as needed)
    cost = estimate_cost(operation, prompt_tokens, completion_tokens)
    logger.debug "💰 Estimated cost: $#{format('%.6f', cost)}" if cost > 0
  end

  # Estimate API costs based on token usage
  def self.estimate_cost(operation, prompt_tokens, completion_tokens)
    case operation
    when 'embedding'
      # text-embedding-ada-002: $0.0001 / 1K tokens
      (prompt_tokens / 1000.0) * 0.0001
    when 'chat'
      case chat_model
      when 'gpt-4-turbo', 'gpt-4-turbo-preview'
        # GPT-4 Turbo: $0.01 / 1K prompt, $0.03 / 1K completion
        (prompt_tokens / 1000.0) * 0.01 + (completion_tokens / 1000.0) * 0.03
      when 'gpt-4o'
        # GPT-4o: $0.005 / 1K prompt, $0.015 / 1K completion
        (prompt_tokens / 1000.0) * 0.005 + (completion_tokens / 1000.0) * 0.015
      when 'gpt-4o-mini'
        # GPT-4o-mini: $0.00015 / 1K prompt, $0.0006 / 1K completion
        (prompt_tokens / 1000.0) * 0.00015 + (completion_tokens / 1000.0) * 0.0006
      when 'gpt-4'
        # GPT-4: $0.03 / 1K prompt, $0.06 / 1K completion
        (prompt_tokens / 1000.0) * 0.03 + (completion_tokens / 1000.0) * 0.06
      else
        0
      end
    else
      0
    end
  end
end
