# UTS RAG Application - Setup Guide

Complete setup instructions for the full-stack RAG application.

## 📋 Prerequisites

### Required
- **Ruby**: 3.3.0+ (via rbenv)
- **Node.js**: 18+ (via nvm or system install)
- **Bundler**: `gem install bundler`
- **Database**: SQLite3 (dev) or PostgreSQL (prod)

### Optional
- **Azure CLI**: For cloud deployments
- **OpenAI Account**: For AI features

## 🔧 Installation

### 1. Install Backend Dependencies

```bash
cd app/backend
~/.rbenv/shims/bundle install
```

### 2. Install Frontend Dependencies

```bash
cd app/frontend
npm install
```

### 3. Configure Environment

Copy and configure your `.env` file in the project root (`UTS/.env`):

```bash
# Your .env should already have from infrastructure deployment:
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_TENANT_ID=your-tenant-id
OPENAI_API_KEY=your-openai-key
AI_PROVIDER=openai
ENVIRONMENT=DEV

# Add these for the application:
BACKEND_PORT=4000
FRONTEND_URL=http://localhost:8080

# Azure credentials (from deployment)
AZURE_STORAGE_CONNECTION_STRING=your-connection-string
AZURE_SEARCH_ENDPOINT=https://uts-dev-search-xxx.search.windows.net
AZURE_SEARCH_ADMIN_KEY=your-search-key
```

### 4. Setup Database

```bash
cd app/backend
~/.rbenv/shims/rake db:create
~/.rbenv/shims/rake db:migrate
```

## 🚀 Running the Application

### Quick Start (Both Servers)

```bash
cd app
ruby start_dev.rb
```

This starts:
- ✅ Backend on http://localhost:4000
- ✅ Frontend on http://localhost:8080

### Manual Start (Individual Servers)

**Backend Only:**
```bash
cd app/backend
~/.rbenv/shims/rackup -p 4000
```

**Frontend Only:**
```bash
cd app/frontend
npm run dev
```

## 🛑 Stopping the Application

### Quick Stop

```bash
cd app
ruby stop_dev.rb
```

### Manual Stop

Press `Ctrl+C` in each terminal, or:

```bash
lsof -ti:4000 | xargs kill -9  # Backend
lsof -ti:8080 | xargs kill -9  # Frontend
```

## 📊 Verify Installation

### Check Backend

```bash
curl http://localhost:4000/health
```

Expected response:
```json
{"status":"ok","timestamp":"2025-11-17T..."}
```

### Check Frontend

Open browser: http://localhost:8080

You should see the UTS RAG System dashboard.

### Check API

```bash
curl http://localhost:4000/api/v1/dashboard/stats
```

Expected response:
```json
{
  "total_documents": 0,
  "total_queries": 0,
  "avg_response_time": 0,
  "system_health": "healthy",
  "timestamp": "2025-11-17T..."
}
```

## 🐛 Troubleshooting

### Port Already in Use

```bash
# Kill process on port 4000
lsof -ti:4000 | xargs kill -9

# Kill process on port 8080
lsof -ti:8080 | xargs kill -9
```

### Bundle Install Fails

```bash
# Update bundler
gem install bundler
bundle update --bundler
```

### NPM Install Fails

```bash
# Clear cache and retry
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
```

### Database Migration Errors

```bash
# Reset database
cd app/backend
~/.rbenv/shims/rake db:drop db:create db:migrate
```

### CORS Errors

Ensure backend `.env` has:
```bash
FRONTEND_URL=http://localhost:8080
```

## 📝 Development Workflow

### 1. Start Development Servers

```bash
cd app
ruby start_dev.rb
```

### 2. Make Changes

- **Backend**: Edit files in `app/backend/`
  - Server auto-reloads with changes
  
- **Frontend**: Edit files in `app/frontend/src/`
  - Vite hot-reloads automatically

### 3. View Logs

```bash
# Backend logs
tail -f app/logs/backend.log

# Frontend logs
tail -f app/logs/frontend.log
```

### 4. Run Tests

```bash
# Backend tests
cd app/backend
~/.rbenv/shims/rspec
```

### 5. Stop Servers

```bash
cd app
ruby stop_dev.rb
```

## 🎨 Design System

Following **DSi Aeris AI Nordic/Scandinavian palette**:

**Colors:**
- Background: `#FAFAFA` (clean white)
- Cards: `#FFFFFF` (pure white)
- Primary: `#5E87B0` (cool blue)
- Secondary: `#8BA3B8` (grey-blue)
- Success: `#5A8F7B` (muted teal)
- Warning: `#D4A373` (soft amber)
- Error: `#B85C5C` (muted red)

**Border Accent:** 4px left border (`#A8B9C9` slate)

See [`docs/PRINCIPLES.md`](../docs/PRINCIPLES.md) for complete design standards.

## 🔐 Security

- `.env` files are git-ignored
- Never commit API keys
- Use environment variables for all secrets
- Backend validates and sanitizes all inputs

## 📚 Additional Resources

- [Backend API Documentation](backend/README.md) (coming soon)
- [Frontend Component Guide](frontend/README.md) (coming soon)
- [Main Project README](../README.md)
- [Infrastructure Guide](../IaC/README.md)

---

**Ports**: Frontend (8080), Backend (4000)  
**Stack**: Ruby/Sinatra + React/Vite + TailwindCSS  
**Database**: SQLite (dev) / PostgreSQL (prod)  
**Ready to build!** 🚀

