#!/usr/bin/env ruby
# frozen_string_literal: true

# UTS RAG System - Development Server Startup Script
# Starts both backend (Sinatra) and frontend (Vite/React) servers

require 'fileutils'

class DevServer
  BACKEND_PORT = 4000
  FRONTEND_PORT = 8080

  def self.start
    new.start
  end

  def initialize
    @root_dir = File.expand_path(__dir__)
    @app_dir = File.join(@root_dir, 'app')
    @logs_dir = File.join(@app_dir, 'logs')
    FileUtils.mkdir_p(@logs_dir)
  end

  def start
    puts "\n#{'=' * 80}"
    puts "🚀 Starting UTS RAG System (Development Mode)"
    puts "#{'=' * 80}\n\n"

    check_prerequisites
    start_backend
    start_frontend
    open_browser
    display_info
    wait_for_interrupt
  end

  private

  def check_prerequisites
    puts "📋 Checking prerequisites..."

    # Check if app directory exists
    unless Dir.exist?(@app_dir)
      puts "❌ Error: app/ directory not found"
      puts "   Current: #{Dir.pwd}"
      exit 1
    end

    # Check backend dependencies
    unless File.exist?('backend/Gemfile.lock')
      puts "⚠️  Backend dependencies not installed"
      puts "   Run: cd backend && bundle install"
    end

    # Check frontend dependencies
    unless Dir.exist?('frontend/node_modules')
      puts "⚠️  Frontend dependencies not installed"
      puts "   Run: cd frontend && npm install"
    end

    puts "✅ Prerequisites checked\n\n"
  end

  def start_backend
    puts "📦 Starting Backend (Sinatra/Ruby - Port #{BACKEND_PORT})..."

    Dir.chdir(File.join(@app_dir, 'backend')) do
      # Setup PostgreSQL database (creates if doesn't exist)
      setup_database

      # Start server in background
      # Note: Using bundler for server (PRINCIPLES.md: avoid bundle exec for TESTS only)
      pid = spawn(
        { 'BUNDLE_GEMFILE' => File.join(@app_dir, 'backend', 'Gemfile') },
        File.join(ENV['HOME'], '.rbenv/shims/bundle'),
        'exec', 'rackup', '-p', BACKEND_PORT.to_s,
        out: File.join(@logs_dir, 'backend.log'),
        err: File.join(@logs_dir, 'backend.log'),
        chdir: File.join(@app_dir, 'backend')
      )

      Process.detach(pid)
      File.write(File.join(@logs_dir, 'backend.pid'), pid)

      puts "   ✅ Backend PID: #{pid}"
      puts "   📄 Logs: logs/backend.log"
    end

    sleep 2 # Give backend time to start
    puts
  end

  def start_frontend
    puts "⚛️  Starting Frontend (React/Vite - Port #{FRONTEND_PORT})..."

    Dir.chdir(File.join(@app_dir, 'frontend')) do
      pid = spawn(
        'npm', 'run', 'dev',
        out: File.join(@logs_dir, 'frontend.log'),
        err: File.join(@logs_dir, 'frontend.log')
      )

      Process.detach(pid)
      File.write(File.join(@logs_dir, 'frontend.pid'), pid)

      puts "   ✅ Frontend PID: #{pid}"
      puts "   📄 Logs: logs/frontend.log"
    end

    sleep 3 # Give frontend time to start
    puts
  end

  def open_browser
    puts "🌐 Opening browser..."

    # Wait for frontend to be ready
    sleep 2

    # Open browser based on OS
    case RbConfig::CONFIG['host_os']
    when /darwin/i  # macOS - use Chrome
      system("open -a 'Google Chrome' http://localhost:#{FRONTEND_PORT}")
    when /linux/i
      system("google-chrome http://localhost:#{FRONTEND_PORT} 2>/dev/null || xdg-open http://localhost:#{FRONTEND_PORT}")
    when /mswin|mingw|cygwin/i  # Windows
      system("start chrome http://localhost:#{FRONTEND_PORT}")
    end

    puts "   ✅ Browser opened\n\n"
  end

  def setup_database
    puts "   🔨 Setting up database..."
    Dir.chdir(File.join(@app_dir, 'backend')) do
      system(
        File.join(ENV['HOME'], '.rbenv/shims/bundle'),
        'exec', 'rake', 'db:create', 'db:migrate'
      )
    end
  end

  def display_info
    puts "#{'━' * 80}"
    puts "✅ UTS RAG System Started!"
    puts "#{'━' * 80}\n\n"

    puts "📍 URLs:"
    puts "   Frontend:  http://localhost:#{FRONTEND_PORT}"
    puts "   Backend:   http://localhost:#{BACKEND_PORT}"
    puts "   API:       http://localhost:#{BACKEND_PORT}/api/v1/dashboard/stats"
    puts "   Health:    http://localhost:#{BACKEND_PORT}/health\n\n"

    puts "📝 Logs:"
    puts "   Backend:   app/logs/backend.log"
    puts "   Frontend:  app/logs/frontend.log\n\n"

    puts "🛑 To stop:"
    puts "   Press Ctrl+C or run: ./stop_dev.rb\n\n"

    puts "#{'━' * 80}\n\n"
  end

  def wait_for_interrupt
    puts "Press Ctrl+C to stop all servers...\n\n"

    trap('INT') do
      puts "\n\n🛑 Shutting down servers..."
      stop_servers
      puts "✅ All servers stopped\n"
      exit 0
    end

    trap('TERM') do
      stop_servers
      exit 0
    end

    sleep
  end

  def stop_servers
    # Stop backend
    backend_pid_file = File.join(@logs_dir, 'backend.pid')
    if File.exist?(backend_pid_file)
      pid = File.read(backend_pid_file).to_i
      Process.kill('TERM', pid) rescue nil
      File.delete(backend_pid_file)
      puts "   ✅ Backend stopped (PID: #{pid})"
    end

    # Stop frontend
    frontend_pid_file = File.join(@logs_dir, 'frontend.pid')
    if File.exist?(frontend_pid_file)
      pid = File.read(frontend_pid_file).to_i
      Process.kill('TERM', pid) rescue nil
      File.delete(frontend_pid_file)
      puts "   ✅ Frontend stopped (PID: #{pid})"
    end

    # Fallback: kill by port
    system("lsof -ti:#{BACKEND_PORT} | xargs kill -9 2>/dev/null")
    system("lsof -ti:#{FRONTEND_PORT} | xargs kill -9 2>/dev/null")
  end
end

# Run if executed directly
DevServer.start if __FILE__ == $PROGRAM_NAME
