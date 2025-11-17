#!/usr/bin/env ruby
# frozen_string_literal: true

# UTS RAG System - Stop Development Servers

require 'fileutils'

class DevServerStopper
  BACKEND_PORT = 4000
  FRONTEND_PORT = 8080

  def self.stop
    new.stop
  end

  def initialize
    @root_dir = File.expand_path(__dir__)
    @app_dir = File.join(@root_dir, 'app')
    @logs_dir = File.join(@app_dir, 'logs')
  end

  def stop
    puts "🛑 Stopping UTS RAG System...\n\n"

    stopped = []

    # Stop backend
    backend_pid = read_pid('backend.pid')
    if backend_pid
      if stop_process(backend_pid)
        stopped << "Backend (PID: #{backend_pid})"
        File.delete(File.join(@logs_dir, 'backend.pid'))
      end
    end

    # Stop frontend
    frontend_pid = read_pid('frontend.pid')
    if frontend_pid
      if stop_process(frontend_pid)
        stopped << "Frontend (PID: #{frontend_pid})"
        File.delete(File.join(@logs_dir, 'frontend.pid'))
      end
    end

    # Fallback: kill by port
    if kill_by_port(BACKEND_PORT)
      stopped << "Process on port #{BACKEND_PORT}"
    end

    if kill_by_port(FRONTEND_PORT)
      stopped << "Process on port #{FRONTEND_PORT}"
    end

    if stopped.any?
      puts "✅ Stopped:"
      stopped.each { |s| puts "   • #{s}" }
    else
      puts "ℹ️  No running servers found"
    end

    puts "\n✅ All servers stopped\n"
  end

  private

  def read_pid(filename)
    pid_file = File.join(@logs_dir, filename)
    return nil unless File.exist?(pid_file)

    File.read(pid_file).strip.to_i
  end

  def stop_process(pid)
    Process.kill('TERM', pid)
    true
  rescue Errno::ESRCH
    false # Process doesn't exist
  rescue StandardError
    false
  end

  def kill_by_port(port)
    result = `lsof -ti:#{port} 2>/dev/null`.strip
    return false if result.empty?

    system("kill -9 #{result} 2>/dev/null")
    true
  rescue StandardError
    false
  end
end

# Run if executed directly
DevServerStopper.stop if __FILE__ == $PROGRAM_NAME
