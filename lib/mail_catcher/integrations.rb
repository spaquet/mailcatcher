# frozen_string_literal: true

require "mail_catcher/integrations/mcp_tools"
require "mail_catcher/integrations/mcp_server"

module MailCatcher
  # Integration manager for optional features like MCP and Claude Plugins
  module Integrations
    extend self

    attr_accessor :mcp_server

    def initialize
      @mcp_server = nil
    end

    # Start integrations based on options
    def start(options = {})
      $stderr.puts "[Integrations] Starting integrations with options: #{options.inspect}"

      if options[:mcp_enabled]
        start_mcp_server(options)
      end
    end

    # Start the MCP server
    def start_mcp_server(options = {})
      $stderr.puts "[Integrations] Starting MCP server"
      @mcp_server = MCPServer.new(options)

      # Run MCP server in a separate thread
      Thread.new do
        begin
          @mcp_server.run
        rescue => e
          $stderr.puts "[Integrations] MCP server error: #{e.message}"
          $stderr.puts e.backtrace
        end
      end

      # Give the server a moment to start
      sleep 0.1
      $stderr.puts "[Integrations] MCP server started"
    end

    # Stop all integrations
    def stop
      $stderr.puts "[Integrations] Stopping integrations"
      @mcp_server&.stop
      @mcp_server = nil
    end

    # Check if MCP server is running
    def mcp_running?
      @mcp_server&.running
    end

    # Get available tools
    def available_tools
      MCPTools.tool_names
    end
  end
end
