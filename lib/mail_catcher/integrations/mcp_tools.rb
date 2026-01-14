# frozen_string_literal: true

require "mail_catcher/mail"

module MailCatcher
  module Integrations
    # MCP Tool Registry
    # Defines the set of tools available to Claude through MCP and Claude Plugins
    # Each tool maps to existing Mail module methods
    module MCPTools
      extend self

      # Tool definitions for MCP and Plugin
      TOOLS = {
        search_messages: {
          description: "Search through caught emails with flexible filtering",
          input_schema: {
            type: "object",
            properties: {
              query: {
                type: "string",
                description: "Search term (searches subject, sender, recipients, body)"
              },
              limit: {
                type: "integer",
                description: "Maximum number of results to return",
                default: 5
              },
              has_attachments: {
                type: "boolean",
                description: "Filter to only messages with attachments",
                default: false
              },
              from_date: {
                type: "string",
                description: "ISO 8601 datetime to search from (e.g., '2024-01-12T00:00:00Z')",
                default: nil
              },
              to_date: {
                type: "string",
                description: "ISO 8601 datetime to search until (e.g., '2024-01-12T23:59:59Z')",
                default: nil
              }
            },
            required: ["query"]
          }
        },

        get_latest_message_for: {
          description: "Get the latest email received by a specific recipient",
          input_schema: {
            type: "object",
            properties: {
              recipient: {
                type: "string",
                description: "Email address to match in recipients"
              },
              subject_contains: {
                type: "string",
                description: "Optional: Only return message if subject contains this text",
                default: nil
              }
            },
            required: ["recipient"]
          }
        },

        extract_token_or_link: {
          description: "Extract authentication tokens or links from a message",
          input_schema: {
            type: "object",
            properties: {
              message_id: {
                type: "integer",
                description: "ID of the message to extract from"
              },
              kind: {
                type: "string",
                enum: ["magic_link", "otp", "reset_token", "all"],
                description: "Type of token/link to extract"
              }
            },
            required: ["message_id", "kind"]
          }
        },

        get_parsed_auth_info: {
          description: "Get structured authentication information from a message",
          input_schema: {
            type: "object",
            properties: {
              message_id: {
                type: "integer",
                description: "ID of the message to parse"
              }
            },
            required: ["message_id"]
          }
        },

        get_message_preview_html: {
          description: "Get HTML preview of a message (responsive for mobile if requested)",
          input_schema: {
            type: "object",
            properties: {
              message_id: {
                type: "integer",
                description: "ID of the message to preview"
              },
              mobile: {
                type: "boolean",
                description: "Return mobile-optimized preview",
                default: false
              }
            },
            required: ["message_id"]
          }
        },

        delete_message: {
          description: "Delete a specific message by ID",
          input_schema: {
            type: "object",
            properties: {
              message_id: {
                type: "integer",
                description: "ID of the message to delete"
              }
            },
            required: ["message_id"]
          }
        },

        clear_messages: {
          description: "Delete all caught messages (destructive operation)",
          input_schema: {
            type: "object",
            properties: {}
          }
        }
      }.freeze

      # Get tool definition by name
      def tool(name)
        TOOLS[name.to_sym]
      end

      # Get all tool names
      def tool_names
        TOOLS.keys.map(&:to_s)
      end

      # Get all tools
      def all_tools
        TOOLS
      end

      # Execute a tool with the given parameters
      def call_tool(tool_name, input)
        case tool_name.to_sym
        when :search_messages
          call_search_messages(input)
        when :get_latest_message_for
          call_get_latest_message_for(input)
        when :extract_token_or_link
          call_extract_token_or_link(input)
        when :get_parsed_auth_info
          call_get_parsed_auth_info(input)
        when :get_message_preview_html
          call_get_message_preview_html(input)
        when :delete_message
          call_delete_message(input)
        when :clear_messages
          call_clear_messages(input)
        else
          { error: "Unknown tool: #{tool_name}" }
        end
      rescue => e
        {
          error: "Tool execution failed: #{e.message}",
          type: e.class.name,
          backtrace: e.backtrace.first(3)
        }
      end

      # Tool implementations

      def call_search_messages(input)
        query = input["query"] || input[:query]
        limit = (input["limit"] || input[:limit] || 5).to_i
        has_attachments = input["has_attachments"] || input[:has_attachments]
        from_date = input["from_date"] || input[:from_date]
        to_date = input["to_date"] || input[:to_date]

        results = Mail.search_messages(
          query: query,
          has_attachments: has_attachments,
          from_date: from_date,
          to_date: to_date
        )

        # Limit results
        results = results.slice(0, limit)

        {
          count: results.size,
          messages: results.map { |msg| format_message_summary(msg) }
        }
      end

      def call_get_latest_message_for(input)
        recipient = input["recipient"] || input[:recipient]
        subject_contains = input["subject_contains"] || input[:subject_contains]

        # Search all messages to find matching recipient
        all_messages = Mail.messages
        matching = all_messages.select do |msg|
          recipients = msg["recipients"]
          recipients_array = recipients.is_a?(Array) ? recipients : [recipients]
          recipients_array.any? { |r| r.to_s.include?(recipient) }
        end

        # Filter by subject if provided
        matching = matching.select do |msg|
          msg["subject"].to_s.include?(subject_contains)
        end if subject_contains

        # Get the latest
        latest = matching.max_by { |msg| msg["created_at"] }

        if latest
          {
            found: true,
            message: format_message_detail(latest["id"])
          }
        else
          {
            found: false,
            error: "No matching message found for recipient: #{recipient}"
          }
        end
      end

      def call_extract_token_or_link(input)
        message_id = (input["message_id"] || input[:message_id]).to_i
        kind = input["kind"] || input[:kind]

        return { error: "Message not found" } unless Mail.message(message_id)

        # Map kind parameter to Mail.extract_tokens type
        type_map = {
          "magic_link" => "link",
          "otp" => "otp",
          "reset_token" => "token",
          "all" => "all"
        }

        type = type_map[kind]
        return { error: "Invalid kind: #{kind}" } unless type

        if kind == "all"
          # Extract all types
          {
            magic_links: Mail.extract_tokens(message_id, type: 'link'),
            otps: Mail.extract_tokens(message_id, type: 'otp'),
            reset_tokens: Mail.extract_tokens(message_id, type: 'token')
          }
        else
          {
            extracted: Mail.extract_tokens(message_id, type: type)
          }
        end
      end

      def call_get_parsed_auth_info(input)
        message_id = (input["message_id"] || input[:message_id]).to_i

        return { error: "Message not found" } unless Mail.message(message_id)

        parsed = Mail.parse_message_structured(message_id)
        {
          verification_url: parsed[:verification_url],
          otp_code: parsed[:otp_code],
          reset_token: parsed[:reset_token],
          unsubscribe_link: parsed[:unsubscribe_link],
          links_count: parsed[:all_links]&.count || 0,
          links: parsed[:all_links]&.slice(0, 10) # Return first 10 links
        }
      end

      def call_get_message_preview_html(input)
        message_id = (input["message_id"] || input[:message_id]).to_i
        mobile = input["mobile"] || input[:mobile] || false

        html_part = Mail.message_part_html(message_id)
        return { error: "No HTML content found in message" } unless html_part

        body = html_part["body"].to_s

        # For mobile, add viewport meta tag if not present
        if mobile && !body.include?("viewport")
          body = "<head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"></head>\n" + body
        end

        # Truncate if very large (limit to ~200KB for performance)
        if body.bytesize > 200_000
          body = body[0, 200_000] + "\n<!-- Truncated for display -->"
        end

        {
          message_id: message_id,
          charset: html_part["charset"] || "utf-8",
          mobile_optimized: mobile,
          size_bytes: body.bytesize,
          html: body
        }
      end

      def call_delete_message(input)
        message_id = (input["message_id"] || input[:message_id]).to_i

        return { error: "Message not found" } unless Mail.message(message_id)

        Mail.delete_message!(message_id)
        {
          deleted: true,
          message_id: message_id
        }
      end

      def call_clear_messages(input)
        Mail.delete!
        {
          cleared: true,
          message: "All messages have been deleted"
        }
      end

      # Helper methods

      def format_message_summary(message)
        {
          id: message["id"],
          from: message["sender"],
          to: message["recipients"],
          subject: message["subject"],
          size: message["size"],
          created_at: message["created_at"]
        }
      end

      def format_message_detail(message_id)
        msg = Mail.message(message_id)
        return nil unless msg

        {
          id: msg["id"],
          from: msg["sender"],
          to: msg["recipients"],
          subject: msg["subject"],
          size: msg["size"],
          created_at: msg["created_at"],
          has_html: Mail.message_has_html?(message_id),
          has_plain: Mail.message_has_plain?(message_id),
          attachments_count: Mail.message_attachments(message_id)&.count || 0
        }
      end
    end
  end
end
