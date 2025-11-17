import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import api from './lib/api'

function App() {
  const [currentPage, setCurrentPage] = useState('search')
  const [query, setQuery] = useState('')
  const [searchResults, setSearchResults] = useState(null)
  const [uploading, setUploading] = useState(false)
  const [uploadStatus, setUploadStatus] = useState(null)
  const [uploadProgress, setUploadProgress] = useState([])
  
  // Fetch dashboard stats
  const { data: stats, isLoading } = useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: () => api.getDashboardStats()
  })

  const handleSearch = async (e) => {
    e.preventDefault()
    if (!query.trim()) return
    
    setSearchResults({ loading: true })
    
    try {
      const results = await api.search(query)
      setSearchResults(results)
    } catch (error) {
      console.error('Search failed:', error)
      setSearchResults({ error: error.message })
    }
  }

  const handleFileSelect = (e) => {
    const files = e.target.files
    if (files && files.length > 0) {
      handleFileUpload(files[0])
    }
  }

  const handleDrop = (e) => {
    e.preventDefault()
    const files = e.dataTransfer.files
    if (files && files.length > 0) {
      handleFileUpload(files[0])
    }
  }

  const handleDragOver = (e) => {
    e.preventDefault()
  }

  const handleFileUpload = async (file) => {
    setUploading(true)
    setUploadStatus(null)
    setUploadProgress([])
    
    const addProgress = (step, status, message) => {
      setUploadProgress(prev => [...prev, { step, status, message, timestamp: new Date() }])
    }
    
    try {
      addProgress(1, 'processing', 'Uploading to Azure Blob Storage...')
      await new Promise(resolve => setTimeout(resolve, 500)) // Visual delay
      
      addProgress(2, 'processing', 'Saving to PostgreSQL database...')
      await new Promise(resolve => setTimeout(resolve, 300))
      
      addProgress(3, 'processing', 'Chunking document text...')
      await new Promise(resolve => setTimeout(resolve, 400))
      
      addProgress(4, 'processing', 'Creating OpenAI embeddings...')
      
      const result = await api.uploadDocument(file)
      
      addProgress(5, 'processing', 'Indexing in Azure AI Search...')
      await new Promise(resolve => setTimeout(resolve, 500))
      
      addProgress(6, 'complete', 'Document indexed and searchable!')
      
      setUploadStatus({ success: true, message: `${file.name} uploaded and indexed!` })
      console.log('Upload result:', result)
    } catch (error) {
      addProgress(0, 'error', `Failed: ${error.message}`)
      setUploadStatus({ success: false, message: `Failed to upload: ${error.message}` })
      console.error('Upload failed:', error)
    } finally {
      setUploading(false)
    }
  }
  
  // Fetch documents list
  const { data: documents, refetch: refetchDocuments } = useQuery({
    queryKey: ['documents'],
    queryFn: () => api.getDocuments(),
    enabled: currentPage === 'documents'
  })

  return (
    <div className="min-h-screen bg-[#FAFAFA] flex">
      {/* Vertical Sidebar Menu */}
      <aside className="w-64 bg-[#2C2C2E] min-h-screen flex flex-col">
        <div className="p-6 border-b border-[#3A3A3C]">
          <h1 className="text-xl font-semibold text-white">UTS RAG</h1>
          <p className="text-xs text-[#8E8E93] mt-1">Document Intelligence</p>
        </div>
        
        <nav className="flex-1 p-4">
          <MenuItem
            active={currentPage === 'search'}
            onClick={() => setCurrentPage('search')}
            icon="🔍"
            label="Search"
          />
          <MenuItem
            active={currentPage === 'upload'}
            onClick={() => setCurrentPage('upload')}
            icon="📤"
            label="Upload"
          />
          <MenuItem
            active={currentPage === 'documents'}
            onClick={() => setCurrentPage('documents')}
            icon="📄"
            label="Documents"
            badge={stats?.total_documents}
          />
        </nav>
        
        <div className="p-4 border-t border-[#3A3A3C]">
          <div className="flex items-center gap-2">
            <span className={`h-2 w-2 rounded-full ${stats?.system_health === 'healthy' ? 'bg-[#5A8F7B]' : 'bg-[#B85C5C]'}`}></span>
            <span className="text-xs text-[#8E8E93]">{stats?.system_health || 'Healthy'}</span>
          </div>
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="flex-1">
        {/* Header */}
        <header className="bg-white shadow-sm border-b border-[#E5E5E5]">
          <div className="px-6 py-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-2xl font-semibold text-[#1C1C1E]">
                  {currentPage === 'search' && 'Search Documents'}
                  {currentPage === 'upload' && 'Upload Documents'}
                  {currentPage === 'documents' && 'Document Library'}
                </h2>
              </div>
              <div className="flex items-center gap-4">
                <StatBadge label="Documents" value={stats?.total_documents || 0} />
                <StatBadge label="Queries" value={stats?.total_queries || 0} />
              </div>
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className="p-6">
          {currentPage === 'search' && <SearchPage 
            query={query}
            setQuery={setQuery}
            handleSearch={handleSearch}
            searchResults={searchResults}
          />}
          
          {currentPage === 'upload' && <UploadPage
            handleDrop={handleDrop}
            handleDragOver={handleDragOver}
            handleFileSelect={handleFileSelect}
            uploading={uploading}
            uploadStatus={uploadStatus}
            uploadProgress={uploadProgress}
          />}
          
          {currentPage === 'documents' && <DocumentsPage
            documents={documents}
            isLoading={isLoading}
          />}
        </main>
      </div>
    </div>
  )
}

// Menu Item Component
function MenuItem({ active, onClick, icon, label, badge }) {
  return (
    <button
      onClick={onClick}
      className={`w-full flex items-center justify-between px-4 py-3 rounded-lg mb-2 transition-all duration-300 ease-in-out ${
        active 
          ? 'bg-[#5E87B0] text-white' 
          : 'text-[#8E8E93] hover:bg-[#3A3A3C] hover:text-white'
      }`}
    >
      <div className="flex items-center gap-3">
        <span className="text-lg">{icon}</span>
        <span className="font-medium">{label}</span>
      </div>
      {badge !== undefined && badge > 0 && (
        <span className="bg-white/20 px-2 py-0.5 rounded-full text-xs">
          {badge}
        </span>
      )}
    </button>
  )
}

// Stat Badge Component
function StatBadge({ label, value }) {
  return (
    <div className="text-center">
      <div className="text-xs text-[#636366] uppercase tracking-wide">{label}</div>
      <div className="text-lg font-semibold text-[#1C1C1E]">{value}</div>
    </div>
  )
}

// Search Page Component
function SearchPage({ query, setQuery, handleSearch, searchResults }) {
  return (
    <div className="max-w-4xl">
      {/* Stats Cards */}
      <div className="grid grid-cols-3 gap-6 mb-6">
        {/* Removed - now in header */}
      </div>

      {/* Search Box - Clean Nordic Design */}
      <div className="bg-white rounded-lg shadow-sm border-l-4 border-[#5E87B0] p-6">
        <h3 className="text-lg font-semibold text-[#1C1C1E] mb-4">
          Ask a Question
        </h3>
        <form onSubmit={handleSearch} className="space-y-4">
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Ask a question about your documents..."
            className="w-full px-4 py-3 border border-[#E5E5E5] rounded-lg focus:ring-2 focus:ring-[#5E87B0] focus:border-transparent outline-none transition-all text-[#1C1C1E] placeholder:text-[#8E8E93]"
          />
          <button
            type="submit"
            disabled={!query.trim()}
            className="w-full bg-[#5E87B0] hover:bg-[#6B9AC4] disabled:bg-[#8BA3B8] disabled:cursor-not-allowed text-white font-medium py-3 px-6 rounded-lg transition-all duration-300 ease-in-out"
          >
            Search
          </button>
        </form>
        
        {/* Search Results */}
        {searchResults && (
          <div className="mt-6 pt-6 border-t border-[#E5E5E5]">
            <h3 className="text-sm font-medium text-[#636366] uppercase tracking-wide mb-3">
              Answer
            </h3>
            
            {searchResults.loading && (
              <p className="text-[#8E8E93]">Searching...</p>
            )}
            
            {searchResults.error && (
              <p className="text-[#B85C5C]">Error: {searchResults.error}</p>
            )}
            
            {searchResults.answer && (
              <>
                <div className="bg-[#F5F5F7] rounded-lg p-4 mb-4">
                  <p className="text-[#1C1C1E] leading-relaxed">{searchResults.answer}</p>
                </div>
                
                {searchResults.sources && searchResults.sources.length > 0 && (
                  <div className="mt-4">
                    <h4 className="text-xs font-medium text-[#8E8E93] uppercase tracking-wide mb-2">
                      Sources ({searchResults.chunks_found} chunks)
                    </h4>
                    <div className="space-y-2">
                      {searchResults.sources.map((source, i) => (
                        <div key={i} className="text-xs text-[#636366] bg-white border border-[#E5E5E5] rounded p-3">
                          <div className="font-medium text-[#3A3A3C] mb-1">{source.title}</div>
                          <div className="text-[#8E8E93]">{source.content}...</div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

// Upload Page Component
function UploadPage({ handleDrop, handleDragOver, handleFileSelect, uploading, uploadStatus, uploadProgress }) {
  const uploadSteps = [
    { id: 1, name: 'Upload to Azure Blob' },
    { id: 2, name: 'Save to PostgreSQL' },
    { id: 3, name: 'Chunk Document' },
    { id: 4, name: 'Create Embeddings' },
    { id: 5, name: 'Index in AI Search' },
    { id: 6, name: 'Ready to Search' }
  ]
  
  return (
    <div className="max-w-4xl">
      <div className="grid grid-cols-2 gap-6">
        {/* Upload Area */}
        <div className="bg-white rounded-lg shadow-sm border-l-4 border-[#8BA3B8] p-6">
          <h3 className="text-lg font-semibold text-[#1C1C1E] mb-4">
            Select Document
          </h3>
          <div 
            onDrop={handleDrop}
            onDragOver={handleDragOver}
            className="border-2 border-dashed border-[#E5E5E5] rounded-lg p-12 text-center hover:border-[#5E87B0] hover:bg-[#F5F5F7] transition-all duration-300 ease-in-out"
          >
            <input
              type="file"
              id="fileInput"
              onChange={handleFileSelect}
              className="hidden"
              accept=".pdf,.txt,.doc,.docx,.md"
            />
            <svg className="mx-auto h-12 w-12 text-[#8E8E93]" stroke="currentColor" fill="none" viewBox="0 0 48 48" strokeWidth="1.5">
              <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            <p className="mt-3 text-sm text-[#636366]">
              {uploading ? 'Processing...' : 'Drop files here or click to browse'}
            </p>
            <button 
              onClick={() => document.getElementById('fileInput').click()}
              disabled={uploading}
              className="mt-4 bg-[#F5F5F7] hover:bg-[#E5E5E5] disabled:bg-[#E5E5E5] disabled:cursor-not-allowed text-[#3A3A3C] font-medium py-2 px-6 rounded-lg transition-all duration-300 ease-in-out"
            >
              {uploading ? 'Processing...' : 'Select Files'}
            </button>
          </div>
          
          {/* Upload Status */}
          {uploadStatus && (
            <div className={`mt-4 p-4 rounded-lg ${uploadStatus.success ? 'bg-[#5A8F7B]/10 text-[#5A8F7B]' : 'bg-[#B85C5C]/10 text-[#B85C5C]'}`}>
              <p className="text-sm font-medium">{uploadStatus.message}</p>
            </div>
          )}
        </div>
        
        {/* Processing Steps */}
        <div className="bg-white rounded-lg shadow-sm border-l-4 border-[#5E87B0] p-6">
          <h3 className="text-lg font-semibold text-[#1C1C1E] mb-4">
            Processing Status
          </h3>
          
          {uploadProgress.length === 0 ? (
            <div className="text-sm text-[#8E8E93] text-center py-8">
              Upload a file to see processing steps
            </div>
          ) : (
            <div className="space-y-3">
              {uploadSteps.map((step) => {
                const progress = uploadProgress.find(p => p.step === step.id)
                const isComplete = progress && progress.status === 'complete'
                const isProcessing = progress && progress.status === 'processing'
                const isError = progress && progress.status === 'error'
                const isPending = !progress
                
                return (
                  <div key={step.id} className="flex items-start gap-3">
                    <div className={`mt-0.5 h-6 w-6 rounded-full flex items-center justify-center text-xs font-bold ${
                      isComplete ? 'bg-[#5A8F7B] text-white' :
                      isProcessing ? 'bg-[#5E87B0] text-white animate-pulse' :
                      isError ? 'bg-[#B85C5C] text-white' :
                      'bg-[#E5E5E5] text-[#8E8E93]'
                    }`}>
                      {isComplete ? '✓' : 
                       isError ? '✗' :
                       step.id}
                    </div>
                    <div className="flex-1">
                      <div className="text-sm font-medium text-[#1C1C1E]">{step.name}</div>
                      {progress && (
                        <div className={`text-xs mt-0.5 ${
                          isComplete ? 'text-[#5A8F7B]' :
                          isProcessing ? 'text-[#5E87B0]' :
                          isError ? 'text-[#B85C5C]' :
                          'text-[#8E8E93]'
                        }`}>
                          {progress.message}
                        </div>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// Documents Page Component
function DocumentsPage({ documents, isLoading }) {
  if (isLoading) {
    return <div className="text-center py-12 text-[#8E8E93]">Loading documents...</div>
  }
  
  const docs = documents?.documents || []
  
  return (
    <div className="bg-white rounded-lg shadow-sm border-l-4 border-[#8BA3B8]">
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-[#F5F5F7] border-b border-[#E5E5E5]">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-[#636366] uppercase tracking-wide">
                Document
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-[#636366] uppercase tracking-wide">
                Azure Blob URL
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-[#636366] uppercase tracking-wide">
                Status
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-[#636366] uppercase tracking-wide">
                Uploaded
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-[#E5E5E5]">
            {docs.length === 0 ? (
              <tr>
                <td colSpan="4" className="px-6 py-12 text-center text-[#8E8E93]">
                  No documents uploaded yet
                </td>
              </tr>
            ) : (
              docs.map((doc) => (
                <tr key={doc.id} className="hover:bg-[#FAFAFA] transition-colors">
                  <td className="px-6 py-4">
                    <div>
                      <div className="text-sm font-medium text-[#1C1C1E]">
                        ID: {doc.id}
                      </div>
                      <div className="text-sm text-[#3A3A3C] mt-1">{doc.title}</div>
                      {doc.metadata && (
                        <div className="text-xs text-[#8E8E93] mt-1">
                          {(doc.metadata.size / 1024).toFixed(1)} KB • {doc.metadata.content_type}
                        </div>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    {doc.download_url ? (
                      <div>
                        <a 
                          href={doc.download_url} 
                          target="_blank" 
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 text-xs text-[#5E87B0] hover:text-[#6B9AC4] font-medium mb-1"
                        >
                          <svg className="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                          </svg>
                          Download
                        </a>
                        <div className="text-xs text-[#8E8E93] break-all">
                          {doc.blob_url}
                        </div>
                      </div>
                    ) : (
                      <span className="text-xs text-[#8E8E93]">Not in cloud</span>
                    )}
                  </td>
                  <td className="px-6 py-4">
                    <StatusBadge status={doc.status} />
                  </td>
                  <td className="px-6 py-4">
                    <div className="text-xs text-[#636366]">
                      {new Date(doc.created_at).toLocaleDateString()}
                    </div>
                    <div className="text-xs text-[#8E8E93]">
                      {new Date(doc.created_at).toLocaleTimeString()}
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}

// Status Badge Component
function StatusBadge({ status }) {
  const statusConfig = {
    pending: { color: 'text-[#D4A373]', bg: 'bg-[#D4A373]/10', label: 'Pending' },
    processing: { color: 'text-[#5E87B0]', bg: 'bg-[#5E87B0]/10', label: 'Processing' },
    indexed: { color: 'text-[#5A8F7B]', bg: 'bg-[#5A8F7B]/10', label: 'Indexed' },
    failed: { color: 'text-[#B85C5C]', bg: 'bg-[#B85C5C]/10', label: 'Failed' }
  }
  
  const config = statusConfig[status] || statusConfig.pending
  
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${config.bg} ${config.color}`}>
      {config.label}
    </span>
  )
}

export default App
