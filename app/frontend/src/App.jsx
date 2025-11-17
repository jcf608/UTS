import { useState, useEffect } from 'react'
import { useQuery } from '@tanstack/react-query'
import api from './lib/api'

function App() {
  const [currentPage, setCurrentPage] = useState('search')
  const [query, setQuery] = useState('')
  const [searchResults, setSearchResults] = useState(null)
  const [uploading, setUploading] = useState(false)
  const [uploadStatus, setUploadStatus] = useState(null)
  const [uploadProgress, setUploadProgress] = useState([])
  const [fileQueue, setFileQueue] = useState([])
  const [currentFileIndex, setCurrentFileIndex] = useState(-1)
  const [fileProgress, setFileProgress] = useState({})
  
  // Fetch dashboard stats
  const { data: stats, isLoading } = useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: () => api.getDashboardStats()
  })

  // Fetch Azure budget info
  const { data: budgetInfo } = useQuery({
    queryKey: ['azure-budget'],
    queryFn: () => api.getAzureBudget(),
    refetchInterval: 60000 // Refresh every minute
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
    const files = Array.from(e.target.files || [])
    if (files.length > 0) {
      handleMultipleFiles(files)
    }
  }

  const handleDrop = (e) => {
    e.preventDefault()
    const files = Array.from(e.dataTransfer.files || [])
    if (files.length > 0) {
      handleMultipleFiles(files)
    }
  }
  
  const handleMultipleFiles = async (files) => {
    // Initialize file queue
    const queue = files.map((file, index) => ({
      id: index,
      name: file.name,
      size: file.size,
      status: 'pending',
      file: file
    }))
    
    setFileQueue(queue)
    setUploadProgress([])
    
    // Process files sequentially
    for (let i = 0; i < files.length; i++) {
      setCurrentFileIndex(i)
      
      // Update status to processing
      setFileQueue(prev => prev.map((f, idx) => 
        idx === i ? { ...f, status: 'processing' } : f
      ))
      
      await handleFileUpload(files[i], i)
      
      // Update status to complete
      setFileQueue(prev => prev.map((f, idx) => 
        idx === i ? { ...f, status: 'complete' } : f
      ))
      
      // Small delay between uploads
      if (i < files.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 1000))
      }
    }
    
    setCurrentFileIndex(-1)
    setFileProgress({})
  }

  const handleDragOver = (e) => {
    e.preventDefault()
  }

  const handleFileUpload = async (file, fileId) => {
    setUploading(true)
    setUploadStatus(null)
    setUploadProgress([])
    
    const addProgress = (step, status, message) => {
      setUploadProgress(prev => [...prev, { step, status, message, timestamp: new Date() }])
      // Also update breadcrumb for this file
      if (fileId !== undefined) {
        setFileProgress(prev => ({
          ...prev,
          [fileId]: step
        }))
      }
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
  
  // Pagination state
  const [currentDocPage, setCurrentDocPage] = useState(1)
  
  // Fetch documents list with pagination
  const { data: documentsData, refetch: refetchDocuments, isLoading: docsLoading } = useQuery({
    queryKey: ['documents', currentDocPage],
    queryFn: () => api.getDocuments(currentDocPage, 20),
    enabled: currentPage === 'documents'
  })

  return (
    <div className="min-h-screen bg-[#FAFAFA] flex">
      {/* Vertical Sidebar Menu - Fixed */}
      <aside className="w-64 bg-[#2C2C2E] h-screen flex flex-col fixed left-0 top-0">
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
          <MenuItem
            active={currentPage === 'settings'}
            onClick={() => setCurrentPage('settings')}
            icon="⚙️"
            label="Settings"
          />
        </nav>
        
        <div className="p-4 border-t border-[#3A3A3C] space-y-3">
          <div className="flex items-center gap-2">
            <span className={`h-2 w-2 rounded-full ${stats?.system_health === 'healthy' ? 'bg-[#5A8F7B]' : 'bg-[#B85C5C]'}`}></span>
            <span className="text-xs text-[#8E8E93]">{stats?.system_health || 'Healthy'}</span>
          </div>
          
          {/* Azure Budget Badge */}
          {budgetInfo && (
            <div className="bg-[#3A3A3C] rounded-lg p-3">
              <div className="flex items-center justify-between mb-1">
                <span className="text-xs text-[#8E8E93]">Azure Budget</span>
                <span className="text-xs font-medium text-white">
                  {budgetInfo.currency} {budgetInfo.remaining.toFixed(2)}
                </span>
              </div>
              <div className="w-full bg-[#2C2C2E] rounded-full h-2 mb-1">
                <div 
                  className={`h-2 rounded-full transition-all ${
                    budgetInfo.percentage_used > 80 ? 'bg-[#B85C5C]' :
                    budgetInfo.percentage_used > 50 ? 'bg-[#D4A373]' :
                    'bg-[#5A8F7B]'
                  }`}
                  style={{ width: `${Math.min(budgetInfo.percentage_used, 100)}%` }}
                ></div>
              </div>
              <div className="flex items-center justify-between text-xs">
                <span className="text-[#636366]">
                  {budgetInfo.percentage_used}% used
                </span>
                <span className="text-[#636366]">
                  of {budgetInfo.currency} {budgetInfo.budget_limit.toFixed(0)}
                </span>
              </div>
            </div>
          )}
        </div>
      </aside>

      {/* Main Content Area - With left margin for fixed sidebar */}
      <div className="flex-1 ml-64">
        {/* Header */}
        <header className="bg-white shadow-sm border-b border-[#E5E5E5]">
          <div className="px-6 py-6">
            <div className="flex items-center justify-between">
      <div>
                <h2 className="text-2xl font-semibold text-[#1C1C1E]">
                  {currentPage === 'search' && 'Search Documents'}
                  {currentPage === 'upload' && 'Upload Documents'}
                  {currentPage === 'documents' && 'Document Library'}
                  {currentPage === 'settings' && 'System Settings'}
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
            fileQueue={fileQueue}
            currentFileIndex={currentFileIndex}
            fileProgress={fileProgress}
          />}
          
          {currentPage === 'documents' && <DocumentsPage
            documentsData={documentsData}
            isLoading={docsLoading}
            currentPage={currentDocPage}
            onPageChange={setCurrentDocPage}
          />}
          
          {currentPage === 'settings' && <SettingsPage />}
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
function UploadPage({ handleDrop, handleDragOver, handleFileSelect, uploading, uploadStatus, uploadProgress, fileQueue, currentFileIndex, fileProgress }) {
  const uploadSteps = [
    { id: 1, name: 'Upload to Azure Blob', short: 'Upload' },
    { id: 2, name: 'Save to PostgreSQL', short: 'Save' },
    { id: 3, name: 'Chunk Document', short: 'Chunk' },
    { id: 4, name: 'Create Embeddings', short: 'Embed' },
    { id: 5, name: 'Index in AI Search', short: 'Index' },
    { id: 6, name: 'Ready to Search', short: 'Done' }
  ]
  
  return (
    <div className="space-y-6">
      {/* File Queue List */}
      {fileQueue.length > 0 && (
        <div className="bg-white rounded-lg shadow-sm border-l-4 border-[#6B9AC4] p-6">
          <h3 className="text-lg font-semibold text-[#1C1C1E] mb-4">
            Upload Queue ({fileQueue.filter(f => f.status === 'complete').length}/{fileQueue.length} complete)
          </h3>
          <div className="space-y-2">
            {fileQueue.map((file, index) => (
              <div key={file.id} className="flex items-center gap-3 p-3 bg-[#FAFAFA] rounded-lg">
                <div className={`flex-shrink-0 ${
                  file.status === 'complete' ? 'text-[#5A8F7B]' :
                  file.status === 'processing' ? 'text-[#5E87B0] animate-pulse' :
                  'text-[#8E8E93]'
                }`}>
                  {file.status === 'complete' && (
                    <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                  )}
                  {file.status === 'processing' && (
                    <svg className="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 5l7 7-7 7M5 5l7 7-7 7" />
                    </svg>
                  )}
                  {file.status === 'pending' && (
                    <svg className="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="text-sm font-medium text-[#1C1C1E] truncate">{file.name}</div>
                  <div className="text-xs text-[#636366] mt-1">
                    {(file.size / 1024).toFixed(1)} KB
                  </div>
                  
                  {/* Breadcrumb Progress */}
                  {file.status !== 'pending' && (
                    <div className="flex items-center gap-1 mt-2 text-xs">
                      {uploadSteps.map((step, stepIdx) => {
                        const currentStep = fileProgress[file.id] || 0
                        const isComplete = file.status === 'complete' || currentStep > step.id
                        const isCurrent = file.status === 'processing' && currentStep === step.id
                        const isPending = currentStep < step.id
                        
                        return (
                          <div key={step.id} className="flex items-center">
                            <span className={`font-medium ${
                              isComplete ? 'text-[#5A8F7B]' :
                              isCurrent ? 'text-[#5E87B0]' :
                              'text-[#E5E5E5]'
                            }`}>
                              {step.short}
                            </span>
                            {stepIdx < uploadSteps.length - 1 && (
                              <span className={`mx-1 ${
                                isComplete ? 'text-[#5A8F7B]' :
                                isCurrent && currentStep >= step.id ? 'text-[#5E87B0]' :
                                'text-[#E5E5E5]'
                              }`}>→</span>
                            )}
                          </div>
                        )
                      })}
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
      
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
              accept=".pdf,.txt,.doc,.docx,.md,.png,.jpg,.jpeg,.gif,.webp,.bmp,.svg"
              multiple
            />
            <svg className="mx-auto h-12 w-12 text-[#8E8E93]" stroke="currentColor" fill="none" viewBox="0 0 48 48" strokeWidth="1.5">
              <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            <p className="mt-3 text-sm text-[#636366]">
              {uploading ? 'Processing...' : 'Drop multiple files here or click to browse'}
            </p>
            <p className="mt-1 text-xs text-[#8E8E93]">
              {uploading ? '' : 'Supports PDF, Word, Text, Markdown, and Image files (PNG, JPG, GIF, etc.)'}
            </p>
            <button 
              onClick={() => document.getElementById('fileInput').click()}
              disabled={uploading}
              className="mt-4 bg-[#F5F5F7] hover:bg-[#E5E5E5] disabled:bg-[#E5E5E5] disabled:cursor-not-allowed text-[#3A3A3C] font-medium py-2 px-6 rounded-lg transition-all duration-300 ease-in-out"
            >
              {uploading ? 'Processing...' : 'Select Multiple Files'}
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
function DocumentsPage({ documentsData, isLoading, currentPage, onPageChange }) {
  if (isLoading) {
    return <div className="text-center py-12 text-[#8E8E93]">Loading documents...</div>
  }
  
  const docs = documentsData?.documents || []
  const pagination = documentsData?.pagination || {}
  const totalPages = pagination.total_pages || 1
  
  return (
    <div className="space-y-4">
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
      
      {/* Breadcrumb Pagination */}
      {totalPages > 1 && (
        <div className="bg-white rounded-lg shadow-sm p-4">
          <div className="flex items-center justify-between">
            <div className="text-sm text-[#636366]">
              Showing {docs.length} of {pagination.total_count} documents
            </div>
            
            <div className="flex items-center gap-2">
              {/* Previous Button */}
              <button
                onClick={() => onPageChange(Math.max(1, currentPage - 1))}
                disabled={currentPage === 1}
                className="px-3 py-1 text-sm font-medium text-[#5E87B0] hover:bg-[#F5F5F7] disabled:text-[#E5E5E5] disabled:cursor-not-allowed rounded transition-colors"
              >
                ← Prev
              </button>
              
              {/* Page Breadcrumbs */}
              <div className="flex items-center gap-1">
                {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => {
                  // Show first, last, current, and neighbors
                  const showPage = page === 1 || 
                                   page === totalPages || 
                                   Math.abs(page - currentPage) <= 1
                  
                  if (!showPage) {
                    // Show ellipsis for gaps
                    if (page === currentPage - 2 || page === currentPage + 2) {
                      return <span key={page} className="text-[#8E8E93] px-1">...</span>
                    }
                    return null
                  }
                  
                  return (
                    <button
                      key={page}
                      onClick={() => onPageChange(page)}
                      className={`min-w-[32px] px-3 py-1 text-sm font-medium rounded transition-all ${
                        page === currentPage
                          ? 'bg-[#5E87B0] text-white'
                          : 'text-[#636366] hover:bg-[#F5F5F7]'
                      }`}
                    >
                      {page}
                    </button>
                  )
                })}
              </div>
              
              {/* Next Button */}
              <button
                onClick={() => onPageChange(Math.min(totalPages, currentPage + 1))}
                disabled={currentPage === totalPages}
                className="px-3 py-1 text-sm font-medium text-[#5E87B0] hover:bg-[#F5F5F7] disabled:text-[#E5E5E5] disabled:cursor-not-allowed rounded transition-colors"
              >
                Next →
              </button>
            </div>
          </div>
        </div>
      )}
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

// Settings Page Component
function SettingsPage() {
  const [settings, setSettings] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [saveStatus, setSaveStatus] = useState(null)

  // Load settings on mount
  const loadSettings = async () => {
    try {
      setLoading(true)
      const data = await api.getSettings()
      setSettings(data.settings)
    } catch (error) {
      console.error('Failed to load settings:', error)
      setSaveStatus({ success: false, message: `Failed to load settings: ${error.message}` })
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadSettings()
  }, [])

  const handleSettingChange = async (key, newValue) => {
    try {
      setSaving(true)
      setSaveStatus(null)
      
      await api.updateSetting(key, newValue)
      
      // Update local state
      setSettings(prev => ({
        ...prev,
        [Object.keys(prev).find(cat => prev[cat].some(s => s.key === key))]: prev[Object.keys(prev).find(cat => prev[cat].some(s => s.key === key))].map(s => 
          s.key === key ? { ...s, value: newValue } : s
        )
      }))
      
      setSaveStatus({ success: true, message: 'Setting saved successfully!' })
      setTimeout(() => setSaveStatus(null), 3000)
    } catch (error) {
      console.error('Failed to save setting:', error)
      setSaveStatus({ success: false, message: `Failed to save: ${error.message}` })
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <div className="text-center py-12 text-[#8E8E93]">
        Loading settings...
      </div>
    )
  }

  if (!settings) {
    return (
      <div className="text-center py-12 text-[#B85C5C]">
        Failed to load settings
      </div>
    )
  }

  return (
    <div className="max-w-4xl space-y-6">
      {/* Save Status */}
      {saveStatus && (
        <div className={`p-4 rounded-lg ${saveStatus.success ? 'bg-[#5A8F7B]/10 text-[#5A8F7B]' : 'bg-[#B85C5C]/10 text-[#B85C5C]'}`}>
          <p className="text-sm font-medium">{saveStatus.message}</p>
        </div>
      )}

      {/* AI Settings */}
      {settings.ai && (
        <div className="bg-white rounded-lg shadow-sm border-l-4 border-[#5E87B0] p-6">
          <h3 className="text-lg font-semibold text-[#1C1C1E] mb-4 flex items-center gap-2">
            🤖 AI Configuration
          </h3>
          <div className="space-y-6">
            {settings.ai.map(setting => (
              <SettingControl
                key={setting.key}
                setting={setting}
                onChange={(value) => handleSettingChange(setting.key, value)}
                disabled={saving}
              />
            ))}
          </div>
        </div>
      )}

      {/* System Settings */}
      {settings.system && (
        <div className="bg-white rounded-lg shadow-sm border-l-4 border-[#8BA3B8] p-6">
          <h3 className="text-lg font-semibold text-[#1C1C1E] mb-4 flex items-center gap-2">
            ⚙️ System Configuration
          </h3>
          <div className="space-y-6">
            {settings.system.map(setting => (
              <SettingControl
                key={setting.key}
                setting={setting}
                onChange={(value) => handleSettingChange(setting.key, value)}
                disabled={saving}
              />
            ))}
          </div>
        </div>
      )}

      {/* Info Panel */}
      <div className="bg-[#F5F5F7] rounded-lg p-6">
        <h4 className="text-sm font-semibold text-[#3A3A3C] mb-2">ℹ️ About Token Management</h4>
        <p className="text-sm text-[#636366] mb-3">
          Token management helps control costs and prevent API limit errors. Settings are applied immediately.
        </p>
        <div className="space-y-1 text-xs text-[#8E8E93]">
          <div>• <strong>gpt-4-turbo:</strong> 128K context, $0.01/1K input, $0.03/1K output (recommended)</div>
          <div>• <strong>gpt-4o:</strong> 128K context, $0.005/1K input, $0.015/1K output (best value)</div>
          <div>• <strong>gpt-4o-mini:</strong> 128K context, $0.00015/1K input, $0.0006/1K output (cheapest)</div>
          <div>• <strong>gpt-4:</strong> 8K context, $0.03/1K input, $0.06/1K output (legacy)</div>
        </div>
      </div>
    </div>
  )
}

// Setting Control Component
function SettingControl({ setting, onChange, disabled }) {
  const [value, setValue] = useState(setting.value)

  const handleChange = (newValue) => {
    setValue(newValue)
    onChange(newValue)
  }

  // Render different controls based on setting key
  if (setting.key === 'openai_chat_model') {
    return (
      <div>
        <label className="block text-sm font-medium text-[#1C1C1E] mb-2">
          Chat Model
        </label>
        <select
          value={value}
          onChange={(e) => handleChange(e.target.value)}
          disabled={disabled}
          className="w-full px-4 py-2 border border-[#E5E5E5] rounded-lg focus:ring-2 focus:ring-[#5E87B0] focus:border-transparent outline-none disabled:bg-[#F5F5F7] disabled:cursor-not-allowed text-[#1C1C1E]"
        >
          <option value="gpt-4-turbo">GPT-4 Turbo (128K context) - Recommended</option>
          <option value="gpt-4o">GPT-4o (128K context) - Best Value</option>
          <option value="gpt-4o-mini">GPT-4o Mini (128K context) - Cheapest</option>
          <option value="gpt-4">GPT-4 (8K context) - Legacy</option>
        </select>
        <p className="mt-1 text-xs text-[#8E8E93]">{setting.description}</p>
      </div>
    )
  }

  if (setting.key === 'log_level') {
    return (
      <div>
        <label className="block text-sm font-medium text-[#1C1C1E] mb-2">
          Log Level
        </label>
        <select
          value={value}
          onChange={(e) => handleChange(e.target.value)}
          disabled={disabled}
          className="w-full px-4 py-2 border border-[#E5E5E5] rounded-lg focus:ring-2 focus:ring-[#5E87B0] focus:border-transparent outline-none disabled:bg-[#F5F5F7] disabled:cursor-not-allowed text-[#1C1C1E]"
        >
          <option value="debug">Debug (Verbose - includes costs)</option>
          <option value="info">Info (Normal)</option>
          <option value="warn">Warn (Warnings only)</option>
          <option value="error">Error (Errors only)</option>
        </select>
        <p className="mt-1 text-xs text-[#8E8E93]">{setting.description}</p>
      </div>
    )
  }

  // Number inputs for token settings
  if (setting.key.includes('token') || setting.key.includes('budget')) {
    return (
      <div>
        <label className="block text-sm font-medium text-[#1C1C1E] mb-2">
          {setting.key.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ')}
        </label>
        <input
          type="number"
          value={value}
          onChange={(e) => handleChange(e.target.value)}
          disabled={disabled}
          min="100"
          max="100000"
          step="100"
          className="w-full px-4 py-2 border border-[#E5E5E5] rounded-lg focus:ring-2 focus:ring-[#5E87B0] focus:border-transparent outline-none disabled:bg-[#F5F5F7] disabled:cursor-not-allowed text-[#1C1C1E]"
        />
        <p className="mt-1 text-xs text-[#8E8E93]">{setting.description}</p>
      </div>
    )
  }

  // Default: text input
  return (
    <div>
      <label className="block text-sm font-medium text-[#1C1C1E] mb-2">
        {setting.key.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ')}
      </label>
      <input
        type="text"
        value={value}
        onChange={(e) => handleChange(e.target.value)}
        disabled={disabled}
        className="w-full px-4 py-2 border border-[#E5E5E5] rounded-lg focus:ring-2 focus:ring-[#5E87B0] focus:border-transparent outline-none disabled:bg-[#F5F5F7] disabled:cursor-not-allowed text-[#1C1C1E]"
      />
      <p className="mt-1 text-xs text-[#8E8E93]">{setting.description}</p>
    </div>
  )
}

export default App
