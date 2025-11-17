import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import api from './lib/api'

function App() {
  const [query, setQuery] = useState('')
  const [searchResults, setSearchResults] = useState(null)
  const [uploading, setUploading] = useState(false)
  const [uploadStatus, setUploadStatus] = useState(null)
  
  // Fetch dashboard stats
  const { data: stats, isLoading } = useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: () => api.getDashboardStats()
  })

  const handleSearch = async (e) => {
    e.preventDefault()
    if (!query.trim()) return
    
    try {
      const results = await api.search(query)
      setSearchResults(results)
    } catch (error) {
      console.error('Search failed:', error)
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
    
    try {
      const result = await api.uploadDocument(file)
      setUploadStatus({ success: true, message: `${file.name} uploaded successfully!` })
      console.log('Upload result:', result)
    } catch (error) {
      setUploadStatus({ success: false, message: `Failed to upload: ${error.message}` })
      console.error('Upload failed:', error)
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="min-h-screen bg-[#FAFAFA]">
      {/* Header - Nordic Clean */}
      <header className="bg-white shadow-sm border-b border-[#E5E5E5]">
        <div className="max-w-7xl mx-auto px-6 py-6">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-semibold text-[#1C1C1E]">
                UTS RAG System
              </h1>
              <p className="mt-1 text-sm text-[#636366]">
                Intelligent Document Retrieval & Search
              </p>
            </div>
            <div className="flex items-center gap-2">
              <span className="inline-flex items-center rounded-full bg-[#5A8F7B]/10 px-3 py-1.5 text-xs font-medium text-[#5A8F7B]">
                <span className="mr-2 h-2 w-2 rounded-full bg-[#5A8F7B]"></span>
                {isLoading ? 'Loading...' : stats?.system_health || 'Healthy'}
              </span>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-6 py-8">
        {/* Stats Cards - Nordic Minimal */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <StatCard
            title="Documents"
            value={stats?.total_documents || 0}
            isLoading={isLoading}
          />
          <StatCard
            title="Queries"
            value={stats?.total_queries || 0}
            isLoading={isLoading}
          />
          <StatCard
            title="Avg Response"
            value={`${stats?.avg_response_time || 0}ms`}
            isLoading={isLoading}
          />
        </div>

        {/* Search Box - Clean Nordic Design */}
        <div className="bg-white rounded-lg shadow-sm border-l-4 border-[#5E87B0] p-6 mb-8">
          <h2 className="text-xl font-semibold text-[#1C1C1E] mb-4">
            Search Documents
          </h2>
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
              <h3 className="text-sm font-medium text-[#636366] mb-3">Results</h3>
              <p className="text-[#3A3A3C]">No results yet - implement RAG search</p>
            </div>
          )}
        </div>

        {/* Document Upload - Nordic Minimal */}
        <div className="bg-white rounded-lg shadow-sm border-l-4 border-[#8BA3B8] p-6">
          <h2 className="text-xl font-semibold text-[#1C1C1E] mb-4">
            Upload Documents
          </h2>
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
              {uploading ? 'Uploading...' : 'Drop files here or click to browse'}
            </p>
            <button 
              onClick={() => document.getElementById('fileInput').click()}
              disabled={uploading}
              className="mt-4 bg-[#F5F5F7] hover:bg-[#E5E5E5] disabled:bg-[#E5E5E5] disabled:cursor-not-allowed text-[#3A3A3C] font-medium py-2 px-6 rounded-lg transition-all duration-300 ease-in-out"
            >
              {uploading ? 'Uploading...' : 'Select Files'}
            </button>
          </div>
          
          {/* Upload Status */}
          {uploadStatus && (
            <div className={`mt-4 p-4 rounded-lg ${uploadStatus.success ? 'bg-[#5A8F7B]/10 text-[#5A8F7B]' : 'bg-[#B85C5C]/10 text-[#B85C5C]'}`}>
              <p className="text-sm font-medium">{uploadStatus.message}</p>
            </div>
          )}
        </div>
      </main>

      {/* Footer */}
      <footer className="max-w-7xl mx-auto px-6 py-6 mt-12">
        <div className="border-t border-[#E5E5E5] pt-6 text-center text-sm text-[#8E8E93]">
          UTS RAG System · Enterprise AI Platform · v1.0.0
        </div>
      </footer>
    </div>
  )
}

function StatCard({ title, value, isLoading }) {
  return (
    <div className="bg-white rounded-lg shadow-sm p-6 border-l-4 border-[#A8B9C9] hover:shadow-md transition-shadow duration-300 ease-in-out">
      <h3 className="text-sm font-medium text-[#636366] uppercase tracking-wide">
        {title}
      </h3>
      <p className="mt-3 text-3xl font-semibold text-[#1C1C1E]">
        {isLoading ? '···' : value}
      </p>
    </div>
  )
}

export default App
