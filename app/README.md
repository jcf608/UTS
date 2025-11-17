# 🚀 UTS RAG Application

Full-stack RAG (Retrieval-Augmented Generation) application with Sinatra backend and React frontend.

## 📦 Stack

### Backend (Ruby/Sinatra)
- **Framework**: Sinatra 4.0 (modular)
- **ORM**: ActiveRecord 7.1
- **Database**: SQLite (dev) / PostgreSQL (prod)
- **Server**: Puma
- **Port**: `4000`

### Frontend (React/Vite)
- **Framework**: React 18
- **Build Tool**: Vite
- **Styling**: TailwindCSS
- **State**: React Query
- **Port**: `8080`

## 🏗️ Project Structure

```
app/
├── backend/              # Ruby/Sinatra API
│   ├── app.rb           # Main Sinatra application
│   ├── config.ru        # Rack configuration
│   ├── Gemfile          # Ruby dependencies
│   ├── models/          # ActiveRecord models
│   ├── routes/          # API route handlers
│   └── db/              # Database & migrations
│
└── frontend/            # React/Vite app
    ├── src/
    │   ├── App.jsx      # Main component
    │   ├── lib/api.js   # API client
    │   └── index.css    # Tailwind styles
    ├── package.json     # Node dependencies
    └── vite.config.js   # Vite configuration
```

## 🚀 Quick Start

### One-Command Startup (Recommended)

```bash
./start_dev.rb
```

This:
- ✅ Starts backend (port 4000)
- ✅ Starts frontend (port 8080)
- ✅ Opens browser automatically
- ✅ Sets up database if needed

### Manual Setup (if needed)

#### Backend Setup

```bash
cd app/backend
~/.rbenv/shims/bundle install
~/.rbenv/shims/rake db:create db:migrate
~/.rbenv/shims/rackup -p 4000
```

#### Frontend Setup

```bash
cd app/frontend
npm install
npm run dev
```

### Stop Servers

```bash
./stop_dev.rb
```

## 🌐 URLs

- **Frontend**: http://localhost:8080
- **Backend API**: http://localhost:4000
- **Health Check**: http://localhost:4000/health
- **Dashboard Stats**: http://localhost:4000/api/v1/dashboard/stats

## 🔌 API Endpoints

### Base URL: `http://localhost:4000/api/v1`

#### GET `/dashboard/stats`
Get system statistics
```json
{
  "total_documents": 0,
  "total_queries": 0,
  "avg_response_time": 0,
  "system_health": "healthy",
  "timestamp": "2025-11-17T..."
}
```

#### GET `/documents`
List all documents

#### POST `/documents`
Upload a new document

#### POST `/search`
Search documents
```json
{
  "query": "your search query"
}
```

## 🗄️ Database

### Create Migration

```bash
cd app/backend
bundle exec rake db:create_migration NAME=create_your_table
```

### Run Migrations

```bash
bundle exec rake db:migrate
```

### Rollback

```bash
bundle exec rake db:rollback
```

## 🎨 Frontend Development

### Add Tailwind Classes
All Tailwind utilities are available in your components:

```jsx
<div className="bg-blue-500 text-white p-4 rounded-lg">
  Hello World
</div>
```

### API Calls
Use the API client in `src/lib/api.js`:

```jsx
import api from './lib/api'

// In your component
const results = await api.search('my query')
const stats = await api.getDashboardStats()
```

## 🔐 Environment Variables

### Backend (`.env` in project root)
```bash
BACKEND_PORT=4000
FRONTEND_URL=http://localhost:8080

# Database
DB_ADAPTER=sqlite3
DB_NAME=db/development.db

# Azure
AZURE_STORAGE_CONNECTION_STRING=your-connection-string
AZURE_SEARCH_ENDPOINT=your-search-endpoint
AZURE_SEARCH_ADMIN_KEY=your-search-key

# OpenAI
OPENAI_API_KEY=your-openai-key
```

### Frontend (`.env.local`)
```bash
VITE_API_URL=http://localhost:4000
```

## 🧪 Testing

### Backend Tests
```bash
cd app/backend
bundle exec rspec
```

## 📦 Production Deployment

### Backend
```bash
cd app/backend
bundle exec rackup -E production -p 4000
```

### Frontend
```bash
cd app/frontend
npm run build
# Serve the dist/ directory with any static server
```

## 🎯 Next Steps

1. ✅ Install dependencies (both backend and frontend)
2. ✅ Set up database and run migrations
3. ✅ Configure environment variables
4. ✅ Start both servers
5. 🔨 Implement RAG search functionality
6. 🔨 Add document upload handling
7. 🔨 Integrate with Azure Blob Storage
8. 🔨 Connect to Azure AI Search
9. 🔨 Add OpenAI integration

## 💡 Tips

- Backend auto-reloads with `rerun` in development
- Frontend has HMR (Hot Module Replacement) via Vite
- CORS is configured for `localhost:8080` → `localhost:4000`
- Tailwind is configured and ready to use
- React Query handles caching and refetching

---

**Ports**: Frontend (8080), Backend (4000)  
**Ready to code!** 🚀

