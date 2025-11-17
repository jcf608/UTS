import axios from 'axios'

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:4000'

const client = axios.create({
  baseURL: API_BASE,
  headers: {
    'Content-Type': 'application/json',
  },
})

const api = {
  // Health check
  health: async () => {
    const { data } = await client.get('/health')
    return data
  },

  // Dashboard stats
  getDashboardStats: async () => {
    const { data } = await client.get('/api/v1/dashboard/stats')
    return data
  },

  // Documents
  getDocuments: async () => {
    const { data } = await client.get('/api/v1/documents')
    return data
  },

  uploadDocument: async (file) => {
    const formData = new FormData()
    formData.append('file', file)
    const { data } = await client.post('/api/v1/documents', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    return data
  },

  // Search
  search: async (query) => {
    const { data } = await client.post('/api/v1/search', { query })
    return data
  },
}

export default api

