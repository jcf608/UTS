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

  // Azure budget info
  getAzureBudget: async () => {
    const { data } = await client.get('/api/v1/azure/budget')
    return data
  },

  // Documents with pagination
  getDocuments: async (page = 1, perPage = 20) => {
    const { data } = await client.get('/api/v1/documents', {
      params: { page, per_page: perPage }
    })
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

  // Settings
  getSettings: async () => {
    const { data } = await client.get('/api/v1/settings')
    return data
  },

  getSetting: async (key) => {
    const { data } = await client.get(`/api/v1/settings/${key}`)
    return data
  },

  updateSetting: async (key, value) => {
    const { data } = await client.put(`/api/v1/settings/${key}`, { value })
    return data
  },

  createSetting: async (key, value, description, category = 'general') => {
    const { data } = await client.post('/api/v1/settings', {
      key,
      value,
      description,
      category
    })
    return data
  },
}

export default api

