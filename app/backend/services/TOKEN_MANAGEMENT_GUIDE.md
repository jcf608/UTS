# OpenAI Service Token Management Guide

## Overview

The OpenAI service now includes comprehensive token management to prevent exceeding model limits and track usage costs. This guide explains how to configure and use these features.

## What Was Added

✅ **Token Counting** - Accurate token counting using tiktoken_ruby  
✅ **Context Truncation** - Automatic truncation to fit within token budgets  
✅ **Model Upgrade** - Default changed from gpt-4 to gpt-4-turbo (128K tokens)  
✅ **Usage Monitoring** - Detailed logging of token usage and estimated costs  

## Configuration via Environment Variables

### Model Selection

```bash
# Chat model (default: gpt-4-turbo)
export OPENAI_CHAT_MODEL=gpt-4-turbo      # 128K context (recommended)
export OPENAI_CHAT_MODEL=gpt-4o           # 128K context (faster, cheaper)
export OPENAI_CHAT_MODEL=gpt-4o-mini      # 128K context (cheapest)
export OPENAI_CHAT_MODEL=gpt-4            # 8K context (legacy)

# Embedding model (default: text-embedding-ada-002)
export OPENAI_EMBEDDING_MODEL=text-embedding-ada-002
```

### Token Budgets

```bash
# Maximum output tokens (default: 2000)
export OPENAI_MAX_OUTPUT_TOKENS=2000      # Balanced
export OPENAI_MAX_OUTPUT_TOKENS=4000      # Longer responses
export OPENAI_MAX_OUTPUT_TOKENS=1000      # Shorter responses

# Note: Context budget is hardcoded at 6000 tokens
# This can be adjusted in OpenAIService::CONTEXT_TOKEN_BUDGET
```

### Logging Level

```bash
# Control verbosity (default: info)
export LOG_LEVEL=debug    # Detailed token counts, costs per request
export LOG_LEVEL=info     # Summary information, warnings
export LOG_LEVEL=warn     # Only warnings and errors
```

## Model Comparison

| Model | Context Window | Speed | Cost (Input) | Cost (Output) | Best For |
|-------|---------------|-------|--------------|---------------|----------|
| gpt-4-turbo | 128K tokens | Fast | $0.01/1K | $0.03/1K | **Recommended** - Large documents |
| gpt-4o | 128K tokens | Fastest | $0.005/1K | $0.015/1K | Best value - Production |
| gpt-4o-mini | 128K tokens | Fastest | $0.00015/1K | $0.0006/1K | Development/testing |
| gpt-4 | 8K tokens | Slow | $0.03/1K | $0.06/1K | Legacy (avoid) |

## Token Limits by Model

```ruby
MODEL_LIMITS = {
  'text-embedding-ada-002' => 8,191,
  'gpt-4' => 8,192,
  'gpt-4-turbo' => 128,000,
  'gpt-4o' => 128,000,
  'gpt-4o-mini' => 128,000
}
```

## How Context Truncation Works

When you call `generate_answer`, the service:

1. **Counts tokens** in each context chunk
2. **Fits chunks** into 6000-token budget (configurable)
3. **Truncates** partial chunks if needed
4. **Warns** if chunks were truncated
5. **Logs** final context size

### Example Flow

```ruby
# You provide 10 chunks, each 1000 tokens = 10,000 tokens total
context_chunks = retrieve_relevant_chunks(question, limit: 10)

# Service automatically truncates to fit 6000-token budget
# Result: First 6 complete chunks used (6000 tokens)
# Logs: "Context: 6 chunks, 6000 tokens"
# Logs: "Stopped adding chunks at 6/10 (6000 tokens)"

answer = OpenAIService.generate_answer(question, context_chunks)
```

## Usage Monitoring

### Log Output Examples

#### Info Level (Default)

```
I, [2024-11-17] INFO -- : Context: 8 chunks, 5847 tokens
I, [2024-11-17] INFO -- : Chat request: model=gpt-4-turbo, input_tokens=6124, max_output=2000
I, [2024-11-17] INFO -- : Token usage: 62.4% of model limit
I, [2024-11-17] INFO -- : 📊 Token Usage [chat]: prompt=6124, completion=487, total=6611
```

#### Debug Level

```
D, [2024-11-17] DEBUG -- : Creating embedding for 342 tokens
D, [2024-11-17] DEBUG -- : 💰 Estimated cost: $0.000034
I, [2024-11-17] INFO -- : 📊 Token Usage [embedding]: prompt=342, completion=0, total=342
```

#### Warning Level

```
W, [2024-11-17] WARN -- : Text exceeds embedding limit (8500 > 8191). Truncating...
W, [2024-11-17] WARN -- : Truncated chunk to fit budget (1200 -> 800 tokens)
W, [2024-11-17] WARN -- : Stopped adding chunks at 5/10 (6000 tokens)
W, [2024-11-17] WARN -- : ⚠️  High token usage: 87.3% of model limit
```

### Cost Tracking

The service estimates costs based on current OpenAI pricing:

| Operation | Model | Pricing |
|-----------|-------|---------|
| Embeddings | text-embedding-ada-002 | $0.0001 / 1K tokens |
| Chat | gpt-4-turbo | $0.01 / 1K input, $0.03 / 1K output |
| Chat | gpt-4o | $0.005 / 1K input, $0.015 / 1K output |
| Chat | gpt-4o-mini | $0.00015 / 1K input, $0.0006 / 1K output |
| Chat | gpt-4 | $0.03 / 1K input, $0.06 / 1K output |

**Note:** Prices hardcoded in `estimate_cost` method. Update if OpenAI changes pricing.

## Adjusting Token Budgets

To customize the context budget, edit `openai_service.rb`:

```ruby
class OpenAIService
  # Change this constant
  CONTEXT_TOKEN_BUDGET = 6000  # Increase for larger contexts
  
  # Or make it configurable via ENV
  CONTEXT_TOKEN_BUDGET = ENV.fetch('OPENAI_CONTEXT_BUDGET', '6000').to_i
end
```

Recommended budgets by model:

- **gpt-4**: 5000-6000 tokens (leave room for output)
- **gpt-4-turbo**: 10,000-100,000 tokens (huge context)
- **gpt-4o**: 10,000-100,000 tokens (huge context)

## Error Handling

### Token Limit Exceeded

```ruby
# Error message
"Token limit exceeded. Try reducing context or question length."

# When it happens
input_tokens + max_output > model_limit

# How to fix
1. Reduce number of context chunks retrieved
2. Use a model with larger context window
3. Ask shorter questions
```

### Truncation Warnings

```ruby
# Warning message
"Text exceeds embedding limit (8500 > 8191). Truncating..."

# When it happens
Single chunk exceeds embedding model limit

# Impact
Text is truncated to fit, may lose information

# How to fix
Chunk documents smaller during processing
```

## Best Practices

### 1. Choose the Right Model

```ruby
# Development/Testing
ENV['OPENAI_CHAT_MODEL'] = 'gpt-4o-mini'  # Cheap, fast

# Production with short context
ENV['OPENAI_CHAT_MODEL'] = 'gpt-4o'  # Good value

# Production with large documents
ENV['OPENAI_CHAT_MODEL'] = 'gpt-4-turbo'  # Max context
```

### 2. Monitor Token Usage

```bash
# Enable debug logging to see costs
export LOG_LEVEL=debug

# Watch logs during testing
tail -f log/development.log | grep "Token Usage"
```

### 3. Optimize Context Retrieval

```ruby
# Retrieve fewer, more relevant chunks
context_chunks = search_service.search(
  query: question,
  top_k: 5  # Instead of 20
)

# Or increase context budget for large models
CONTEXT_TOKEN_BUDGET = 20_000  # For gpt-4-turbo
```

### 4. Handle Truncation Gracefully

```ruby
# Check logs for truncation warnings
# If you see: "Stopped adding chunks at 6/20"
# Either:
# 1. Increase CONTEXT_TOKEN_BUDGET
# 2. Retrieve fewer, better chunks
# 3. Use a larger model
```

## Testing Token Management

### Count Tokens Manually

```ruby
text = "Your sample text here"
token_count = OpenAIService.count_tokens(text, 'gpt-4-turbo')
puts "Token count: #{token_count}"
```

### Test Truncation

```ruby
# Create oversized context
large_chunks = Array.new(100) { { content: "A" * 1000 } }

# Will automatically truncate to fit budget
answer = OpenAIService.generate_answer("Question?", large_chunks)

# Check logs for truncation warnings
```

### Test Cost Estimation

```ruby
# Enable debug logging
ENV['LOG_LEVEL'] = 'debug'

# Run query
answer = OpenAIService.generate_answer(question, chunks)

# See cost estimate in logs:
# 💰 Estimated cost: $0.001234
```

## Migration from Old Version

### What Changed

**Before:**
```ruby
# Fixed model, fixed output tokens
response = client.chat(
  parameters: {
    model: 'gpt-4',           # Hardcoded
    messages: messages,
    temperature: 0.7,
    max_tokens: 500           # Hardcoded
  }
)
```

**After:**
```ruby
# Configurable model, dynamic output tokens
response = client.chat(
  parameters: {
    model: CHAT_MODEL,        # ENV configurable
    messages: messages,
    temperature: 0.7,
    max_tokens: max_output    # Calculated based on input
  }
)
```

### Breaking Changes

1. **Default model changed**: `gpt-4` → `gpt-4-turbo`
2. **Output tokens increased**: 500 → 2000 (configurable)
3. **Context may be truncated**: If exceeds 6000 tokens
4. **New logging**: More verbose token/cost logging

### To Keep Old Behavior

```bash
export OPENAI_CHAT_MODEL=gpt-4
export OPENAI_MAX_OUTPUT_TOKENS=500
```

## Troubleshooting

### Issue: "Token limit exceeded"

**Cause:** Input + output exceeds model limit  
**Fix:** Reduce context chunks or use larger model

### Issue: Too many truncation warnings

**Cause:** Context budget too low for your use case  
**Fix:** Increase `CONTEXT_TOKEN_BUDGET` constant

### Issue: Costs too high

**Cause:** Using expensive model or large contexts  
**Fix:** Switch to gpt-4o or gpt-4o-mini

### Issue: Responses cut off mid-sentence

**Cause:** `MAX_OUTPUT_TOKENS` too low  
**Fix:** Increase `OPENAI_MAX_OUTPUT_TOKENS` env var

### Issue: Poor quality answers

**Cause:** Context truncation losing critical information  
**Fix:** 
1. Increase context budget
2. Improve chunk relevance scoring
3. Use larger model

## Performance Impact

### Token Counting Overhead

- **First call:** ~50ms (loads tiktoken encoder)
- **Subsequent calls:** <1ms (cached encoder)
- **Impact:** Negligible for typical use cases

### Memory Usage

- **Encoder cache:** ~5MB per model
- **Impact:** Minimal (one-time load)

## Future Enhancements

Potential improvements to consider:

1. **Dynamic context budgets** based on question complexity
2. **Smart chunk prioritization** to maximize relevance within budget
3. **Cost tracking database** for billing and analytics
4. **Token usage APIs** for frontend display
5. **Automatic model selection** based on context size
6. **Streaming responses** for very long outputs

---

## Quick Reference

```bash
# Recommended Production Setup
export OPENAI_CHAT_MODEL=gpt-4o
export OPENAI_MAX_OUTPUT_TOKENS=2000
export LOG_LEVEL=info

# Cost-Optimized Setup
export OPENAI_CHAT_MODEL=gpt-4o-mini
export OPENAI_MAX_OUTPUT_TOKENS=1000
export LOG_LEVEL=warn

# Maximum Context Setup (large documents)
export OPENAI_CHAT_MODEL=gpt-4-turbo
export OPENAI_MAX_OUTPUT_TOKENS=4000
export LOG_LEVEL=debug
# Then edit: CONTEXT_TOKEN_BUDGET = 50_000 in openai_service.rb

# Legacy Setup (match old behavior)
export OPENAI_CHAT_MODEL=gpt-4
export OPENAI_MAX_OUTPUT_TOKENS=500
export LOG_LEVEL=info
```

---

**Last Updated:** November 17, 2024  
**Service File:** `app/backend/services/openai_service.rb`  
**Dependencies:** `tiktoken_ruby` gem (v0.0.7+)

