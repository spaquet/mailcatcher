# frozen_string_literal: true

require "json"
require "mail_catcher/integrations/mcp_tools"

module MailCatcher
  module Integrations
    # MCP Server
    # Implements the Model Context Protocol (MCP) over stdio
    # Allows Claude and other MCP clients to interact with MailCatcher tools
    class MCPServer
      attr_accessor :running

      def initialize(options = {})
        @options = options
        @running = false
        @request_id_counter = 0
      end

      def self.start(options = {})
        server = new(options)
        server.run
        server
      end

      # Main server loop - handles JSON-RPC messages from stdin
      def run
        @running = true
        $stderr.puts "[MCP Server] Starting MailCatcher MCP Server"

        # Output MCP initialization
        send_response(
          jsonrpc: "2.0",
          id: 0,
          result: {
            protocolVersion: "2024-11-05",
            capabilities: {
              tools: {},
              resources: {},
              logging: {}
            },
            serverInfo: {
              name: "mailcatcher-ng",
              version: MailCatcher::VERSION
            }
          }
        )

        # Main loop - read and process requests
        while @running && (line = $stdin.gets)
          begin
            request = JSON.parse(line)
            handle_request(request)
          rescue JSON::ParserError => e
            $stderr.puts "[MCP Server] JSON parse error: #{e.message}"
            send_error_response(nil, -32700, "Parse error")
          rescue => e
            $stderr.puts "[MCP Server] Error: #{e.message}"
            $stderr.puts e.backtrace.first(5)
          end
        end

        $stderr.puts "[MCP Server] MCP Server stopped"
        @running = false
      end

      def stop
        @running = false
      end

      private

      def handle_request(request)
        method = request["method"]
        params = request["params"] || {}
        request_id = request["id"]

        $stderr.puts "[MCP Server] Received: #{method} (id: #{request_id})"

        case method
        when "initialize"
          handle_initialize(request_id, params)
        when "tools/list"
          handle_tools_list(request_id)
        when "tools/call"
          handle_tools_call(request_id, params)
        when "completion/complete"
          handle_completion(request_id, params)
        else
          send_error_response(request_id, -32601, "Method not found: #{method}")
        end
      end

      def handle_initialize(request_id, params)
        send_response(
          jsonrpc: "2.0",
          id: request_id,
          result: {
            protocolVersion: "2024-11-05",
            capabilities: {
              tools: {},
              resources: {},
              logging: {}
            },
            serverInfo: {
              name: "mailcatcher-ng",
              version: MailCatcher::VERSION
            }
          }
        )
      end

      def handle_tools_list(request_id)
        tools = MCPTools.all_tools.map do |name, definition|
          {
            name: name.to_s,
            description: definition[:description],
            inputSchema: definition[:input_schema]
          }
        end

        send_response(
          jsonrpc: "2.0",
          id: request_id,
          result: {
            tools: tools
          }
        )
      end

      def handle_tools_call(request_id, params)
        tool_name = params["name"]
        tool_input = params["arguments"] || {}

        $stderr.puts "[MCP Server] Calling tool: #{tool_name} with input: #{tool_input.inspect}"

        result = MCPTools.call_tool(tool_name, tool_input)

        send_response(
          jsonrpc: "2.0",
          id: request_id,
          result: {
            content: [
              {
                type: "text",
                text: JSON.pretty_generate(result)
              }
            ]
          }
        )
      end

      def handle_completion(request_id, params)
        # Placeholder for completion support
        send_response(
          jsonrpc: "2.0",
          id: request_id,
          result: {
            completion: {
              values: [],
              total: 0
            }
          }
        )
      end

      def send_response(response)
        output = JSON.generate(response)
        puts output
        $stderr.puts "[MCP Server] Sent: #{response[:id]}"
      rescue => e
        $stderr.puts "[MCP Server] Error sending response: #{e.message}"
      end

      def send_error_response(request_id, code, message)
        send_response(
          jsonrpc: "2.0",
          id: request_id,
          error: {
            code: code,
            message: message
          }
        )
      end
    end
  end
end
