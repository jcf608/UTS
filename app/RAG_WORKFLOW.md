# 🤖 RAG (Retrieval-Augmented Generation) Workflow

## How Documents Become Searchable with OpenAI

### 📤 Upload Process

When you upload a document, here's what happens:

```
1. User uploads file
   ↓
2. File → Azure Blob Storage (full content)
   ↓
3. File → PostgreSQL (metadata + preview)
   ↓
4. Document → Chunking (1000 chars per chunk, 200 overlap)
   ↓
5. Each chunk → OpenAI Embeddings API
   ↓
6. Embeddings → Azure AI Search (vector index)
   ↓
7. Document status → "indexed" ✅
```

### 🔍 Search Process

When you search for information:

```
1. User asks question
   ↓
2. Question → OpenAI Embeddings API (create query vector)
   ↓
3. Query vector → Azure AI Search (find similar chunks)
   ↓
4. Top 5 most relevant chunks retrieved
   ↓
5. Chunks + Question → OpenAI GPT-4 API
   ↓
6. GPT-4 generates answer based on your documents
   ↓
7. Answer + Sources shown to user ✅
```

## 🧩 Components

### 1. Document Chunking
**File**: `services/document_processor.rb`

- Splits documents into 1000-character chunks
- 200-character overlap between chunks (for context continuity)
- Preserves semantic meaning across boundaries

### 2. Embedding Creation
**File**: `services/openai_service.rb`

- Uses OpenAI `text-embedding-ada-002` model
- Creates 1536-dimensional vectors
- Each chunk gets its own embedding
- Embeddings capture semantic meaning

### 3. Vector Storage
**File**: `services/azure_search_service.rb`

- Stores embeddings in Azure AI Search
- Uses HNSW algorithm (fast similarity search)
- Cosine similarity metric
- Automatically creates index on first use

### 4. Search
**Endpoint**: `POST /api/v1/search`

**Process**:
1. Create embedding for user's question
2. Find top 5 most similar chunks (vector search)
3. Send chunks + question to GPT-4
4. Return GPT-4's answer with sources

## 🎯 Example Usage

### Upload a Document

Via UI:
- Click "Select Files" or drag-and-drop
- File uploads to Azure Blob Storage
- Document is chunked and embedded
- Indexed in Azure AI Search

Via API:
```bash
curl -X POST http://localhost:4000/api/v1/documents \
  -F "file=@document.pdf"
```

### Search Your Documents

Via UI:
- Type question: "What is the deployment process?"
- Click "Search"
- Get AI-generated answer with sources

Via API:
```bash
curl -X POST http://localhost:4000/api/v1/search \
  -H "Content-Type: application/json" \
  -d '{"query": "What is the deployment process?"}'
```

**Response**:
```json
{
  "success": true,
  "query": "What is the deployment process?",
  "answer": "Based on the documents, the deployment process involves...",
  "sources": [
    {
      "title": "deployment_guide.md",
      "content": "The deployment process starts with..."
    }
  ],
  "chunks_found": 5
}
```

## 💰 Costs

**OpenAI API**:
- Embeddings: $0.0001 per 1K tokens (~$0.01 per document)
- GPT-4: $0.03 per 1K tokens (~$0.05 per search)

**Azure**:
- AI Search (Basic): ~$75/month
- Blob Storage: ~$0.01/GB/month

**Example Monthly Cost** (1000 documents, 500 searches):
- Embedding 1000 docs: ~$10
- 500 searches: ~$25
- Azure Search: $75
- **Total**: ~$110/month

## 🔧 Configuration

Ensure your `.env` has:

```bash
# OpenAI
OPENAI_API_KEY=your-openai-key

# Azure AI Search (from deployment)
AZURE_SEARCH_ENDPOINT=https://uts-dev-search-xxx.search.windows.net
AZURE_SEARCH_ADMIN_KEY=your-search-key

# Azure Storage (from deployment)
AZURE_STORAGE_CONNECTION_STRING='DefaultEndpointsProtocol=https;...'
AZURE_STORAGE_ACCOUNT=utsdevstgcus9a9a6f
AZURE_STORAGE_CONTAINER=documents
```

## 🚀 Try It Now!

1. **Start the app**:
   ```bash
   ./start_dev.rb
   ```

2. **Upload a document** (any PDF, TXT, MD, DOC)

3. **Wait for processing** (you'll see in terminal):
   ```
   📤 Uploading: document.pdf (X bytes)
   ✅ Azure upload successful
   ✅ Database save successful
   🔄 Processing document...
   📄 Created 5 chunks
   🧠 Creating embedding 1/5...
   🧠 Creating embedding 2/5...
   ...
   📊 Indexing in Azure AI Search...
   ✅ Processing complete
   ```

4. **Ask a question** about your document:
   - Type: "What is this document about?"
   - Click "Search"
   - Get AI-powered answer with sources!

## 🧪 Testing

**Check if document is indexed**:
```bash
cd app/backend
psql -d uts_rag_development -c "SELECT id, title, status FROM documents WHERE status = 2;"
```

Status values:
- `0` = pending
- `1` = processing  
- `2` = indexed ✅
- `3` = failed

**Verify Azure AI Search**:
```bash
curl -X GET "${AZURE_SEARCH_ENDPOINT}/indexes/documents-index?api-version=2023-11-01" \
  -H "api-key: ${AZURE_SEARCH_ADMIN_KEY}"
```

## 📚 Next Steps

1. ✅ Upload documents
2. ✅ Ask questions
3. 🔨 Implement background jobs for processing (Sidekiq/Resque)
4. 🔨 Add document list view
5. 🔨 Add search history
6. 🔨 Implement caching for common queries
7. 🔨 Add user authentication

---

**The RAG system is now fully functional!** 🎉

Upload documents → They become searchable via AI → Ask questions → Get intelligent answers!

