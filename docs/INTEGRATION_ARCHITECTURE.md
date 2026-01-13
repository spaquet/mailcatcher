# MailCatcher NG Integration Architecture

This document describes the architecture of the MCP and Claude Plugin integrations for MailCatcher NG.

## Overview

MailCatcher NG provides two complementary integration methods:

1. **MCP Server**: Direct programmatic access via the Model Context Protocol (stdio-based)
2. **Claude Plugin**: HTTP-based plugin for Claude.com and Claude Desktop

Both integrations expose the same underlying tools, implemented once and reused by both interfaces.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        MailCatcher NG                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────┐      ┌──────────────────────────┐ │
│  │   MCP Server             │      │  Claude Plugin           │ │
│  │  (stdio transport)       │      │  (HTTP endpoints)        │ │
│  │                          │      │                          │ │
│  │  - search_messages       │      │  - POST /plugin/search   │ │
│  │  - extract_tokens        │      │  - GET /plugin/message/* │ │
│  │  - get_auth_info         │      │  - DELETE /plugin/*      │ │
│  │  - etc.                  │      │                          │ │
│  └──────────┬───────────────┘      └───────────┬──────────────┘ │
│             │                                  │                 │
│  ┌──────────▼──────────────────────────────────▼───────────────┐ │
│  │         Shared Tool Registry (MCPTools)                      │ │
│  │                                                              │ │
│  │  - Tool definitions (metadata, schemas)                     │ │
│  │  - Tool implementations (business logic)                    │ │
│  │  - Parameter validation and coercion                        │ │
│  │  - Response formatting                                      │ │
│  └────────────────────────┬─────────────────────────────────────┘ │
│                           │                                       │
│  ┌────────────────────────▼─────────────────────────────────────┐ │
│  │         Mail Module (Existing)                               │ │
│  │                                                              │ │
│  │  - search_messages()      - extract_tokens()               │ │
│  │  - message()              - parse_message_structured()     │ │
│  │  - delete_message!()      - accessibility_score()          │ │
│  │                                                              │ │
│  └────────────────────────┬─────────────────────────────────────┘ │
│                           │                                       │
│  ┌────────────────────────▼─────────────────────────────────────┐ │
│  │         SQLite Database                                      │ │
│  │                                                              │ │
│  │  - message table                                             │ │
│  │  - message_part table                                        │ │
│  │  - smtp_transcript table                                     │ │
│  │  - websocket_connection table                                │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## File Structure

```
lib/mail_catcher/
├── integrations/               # New: Integration layer
│   ├── mcp_tools.rb           # Tool definitions and implementations
│   ├── mcp_server.rb          # MCP protocol handler (stdio)
│   └── mcp/
│       └── transport.rb        # Future: Socket/network transport
├── integrations.rb            # Integration orchestrator
├── mail_catcher.rb            # Main module (updated: add CLI options, startup)
├── web/
│   └── application.rb         # Sinatra app (updated: add plugin routes)
├── mail.rb                    # Mail module (unchanged)
├── smtp.rb                    # SMTP server (unchanged)
└── ...

docs/
├── MCP_SETUP.md              # MCP usage guide
├── CLAUDE_PLUGIN_SETUP.md    # Plugin usage guide
└── INTEGRATION_ARCHITECTURE.md  # This file
```

## Design Principles

### 1. Single Source of Truth for Tools

Tools are defined once in `MCPTools` module and reused by both MCP and Plugin:

```ruby
# lib/mail_catcher/integrations/mcp_tools.rb
MCPTools::TOOLS = {
  search_messages: {
    description: "...",
    input_schema: { ... }
  },
  # ... more tools
}
```

Both MCP server and plugin endpoints call `MCPTools.call_tool(name, input)`.

**Benefits:**
- No duplication of tool definitions
- Single place to update tool behavior
- Consistent behavior across interfaces

### 2. Protocol Independence

Tool implementation is separate from protocol handling:

- **Tools** (`mcp_tools.rb`): Pure Ruby, no protocol awareness
- **MCP** (`mcp_server.rb`): JSON-RPC protocol over stdio
- **Plugin** (`application.rb`): HTTP REST routes

This allows adding new transports (socket, WebSocket) without changing tools.

### 3. Minimal Core Changes

Existing MailCatcher code is unchanged:
- `Mail` module: Not modified, only called
- `Smtp` module: No changes
- `Bus` module: No changes
- CLI: Only adds two optional flags (`--mcp`, `--plugin`)

Integration is additive, not intrusive.

### 4. Opt-In Features

Both MCP and Plugin are disabled by default:

```bash
mailcatcher                              # No integrations
mailcatcher --mcp                        # Only MCP
mailcatcher --plugin                     # Only Plugin
mailcatcher --mcp --plugin               # Both
```

Zero overhead if not used.

## MCP Server Implementation

### Startup Flow

```
1. CLI: mailcatcher --mcp
   ↓
2. mail_catcher.rb: parse_options detects --mcp flag
   ↓
3. mail_catcher.rb: run!() starts EventMachine loop
   ↓
4. After HTTP/SMTP servers start:
   Integrations.start(options)
   ↓
5. integrations.rb: start_mcp_server()
   ↓
6. mcp_server.rb: MCPServer.new() and .run()
   ↓
7. MCP server enters main loop:
   - Reads JSON-RPC messages from stdin
   - Dispatches to handlers
   - Sends responses to stdout
```

### Protocol: JSON-RPC 2.0 over stdio

**Client → Server:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list"
}
```

**Server → Client:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "search_messages",
        "description": "...",
        "inputSchema": { ... }
      }
    ]
  }
}
```

### Tool Invocation

```
Client sends:
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "search_messages",
    "arguments": {
      "query": "from:test@example.com",
      "limit": 5
    }
  }
}

Server:
1. Validates tool exists
2. Validates input parameters
3. Calls MCPTools.call_tool(:search_messages, params)
4. Formats response
5. Sends back to client
```

## Plugin Implementation

### Startup Flow

```
1. CLI: mailcatcher --plugin
   ↓
2. mail_catcher.rb: parse_options detects --plugin flag
   ↓
3. mail_catcher.rb: run!() starts Sinatra/Thin server
   ↓
4. Sinatra routes are automatically registered:
   - GET /.well-known/ai-plugin.json
   - GET /plugin/openapi.json
   - POST /plugin/search
   - GET /plugin/message/:id/...
   - DELETE /plugin/...
```

### Plugin Discovery

Claude finds the plugin via `.well-known/ai-plugin.json`:

```json
{
  "schema_version": "v1",
  "name_for_human": "MailCatcher NG",
  "api": {
    "type": "openapi",
    "url": "http://localhost:1080/plugin/openapi.json"
  }
}
```

Claude fetches the OpenAPI spec and discovers available endpoints.

### HTTP Endpoints

Each endpoint:
1. Extracts parameters from query string or body
2. Validates parameters
3. Calls `MCPTools.call_tool()` or `Mail.*` methods directly
4. Returns JSON or HTML response

**Pattern:**

```ruby
post "/plugin/search" do
  query = params[:query]
  limit = (params[:limit] || 5).to_i

  # Validation
  unless query
    return status(400) && { error: "..." }.to_json
  end

  # Call tool or Mail methods
  results = Mail.search_messages(query: query)

  # Format response
  { count: results.size, messages: results }.to_json
end
```

## Tool Catalog

### Tool: `search_messages`

**Input:**
```ruby
{
  query: String,                    # Search term (required)
  limit: Integer = 5,               # Max results
  has_attachments: Boolean = false, # Optional filter
  from_date: String,                # ISO 8601 datetime
  to_date: String                   # ISO 8601 datetime
}
```

**Implementation:**
```ruby
results = Mail.search_messages(query:, has_attachments:, from_date:, to_date:)
```

**Output:**
```ruby
{
  count: Integer,
  messages: [
    {
      id: Integer,
      from: String,
      to: Array<String>,
      subject: String,
      created_at: String
    }
  ]
}
```

### Tool: `extract_token_or_link`

**Input:**
```ruby
{
  message_id: Integer,                                    # Required
  kind: "magic_link" | "otp" | "reset_token" | "all"    # Required
}
```

**Implementation:**
```ruby
# Maps kind to Mail.extract_tokens() type
Mail.extract_tokens(id, type: 'link|otp|token|all')
```

**Output:**
```ruby
# For single kind:
{ extracted: Array<Token> }

# For "all":
{
  magic_links: Array<Token>,
  otps: Array<Token>,
  reset_tokens: Array<Token>
}
```

### Tool: `get_parsed_auth_info`

**Implementation:**
```ruby
Mail.parse_message_structured(message_id)
```

**Output:**
```ruby
{
  verification_url: String | nil,
  otp_code: String | nil,
  reset_token: String | nil,
  unsubscribe_link: String | nil,
  links_count: Integer
}
```

### Tool: `get_message_preview_html`

**Input:**
```ruby
{
  message_id: Integer,        # Required
  mobile: Boolean = false     # Optional
}
```

**Implementation:**
```ruby
html_part = Mail.message_part_html(message_id)
body = html_part["body"]
# Add viewport meta tag if mobile
# Truncate if > 200KB
```

**Output:**
```ruby
{
  message_id: Integer,
  charset: String,
  mobile_optimized: Boolean,
  size_bytes: Integer,
  html: String
}
```

### Tool: `delete_message`

**Input:**
```ruby
{
  message_id: Integer  # Required
}
```

**Implementation:**
```ruby
Mail.delete_message!(message_id)
```

**Output:**
```ruby
{
  deleted: true,
  message_id: Integer
}
```

### Tool: `clear_messages`

**Input:** None

**Implementation:**
```ruby
Mail.delete!
```

**Output:**
```ruby
{
  cleared: true,
  message: "All messages have been deleted"
}
```

## Error Handling

### Tool Execution Errors

All tool calls are wrapped in rescue blocks:

```ruby
def call_tool(tool_name, input)
  case tool_name.to_sym
  when :search_messages
    # ...
  else
    { error: "Unknown tool" }
  end
rescue => e
  {
    error: "Tool execution failed: #{e.message}",
    type: e.class.name,
    backtrace: e.backtrace.first(3)
  }
end
```

### HTTP Endpoint Errors

Plugin endpoints return appropriate HTTP status codes:

```ruby
# 400 Bad Request - invalid parameters
return status(400) && { error: "..." }.to_json

# 404 Not Found - message doesn't exist
return not_found

# 500 Internal Server Error - unexpected error
status 500 && { error: "..." }.to_json
```

## Performance Considerations

### Search Optimization

- Queries are limited to configurable max results (default: 50)
- Index on `message_id` in `smtp_transcript` for fast joins
- Pre-computed token extraction only on demand

### Memory Usage

- Large HTML previews truncated at 200KB
- Links limited to first 10 returned from auth-info
- Search results paginated via `limit` parameter
- No caching (fresh data on each request)

### Concurrency

- MCP server runs in separate thread (doesn't block EventMachine)
- Plugin routes run in Sinatra/Thin (thread-safe)
- Mail module uses SQLite (thread-safe with WAL mode)

## Extension Points

### Adding New Tools

1. Add tool definition to `MCPTools::TOOLS`:
   ```ruby
   TOOLS = {
     my_new_tool: {
       description: "...",
       input_schema: { ... }
     }
   }
   ```

2. Add implementation method:
   ```ruby
   def call_my_new_tool(input)
     # implementation
   end
   ```

3. Add case to `call_tool()`:
   ```ruby
   when :my_new_tool
     call_my_new_tool(input)
   ```

4. Plugin routes are auto-generated if you follow the pattern

### Adding New Transports

Create `lib/mail_catcher/integrations/mcp/transport.rb`:

```ruby
module MailCatcher::Integrations::MCP
  class SocketTransport
    def run
      # Connect to socket, read/write JSON-RPC messages
    end
  end
end
```

Update `Integrations.start()` to select transport based on options.

## Testing

### Unit Tests

Test tool implementations directly:

```ruby
# spec/integrations/mcp_tools_spec.rb
describe "MCPTools.search_messages" do
  it "searches for messages" do
    Mail.add_message(...)
    result = MCPTools.call_tool(:search_messages, query: "test")
    expect(result[:count]).to eq(1)
  end
end
```

### Integration Tests

Test MCP server and routes:

```ruby
# spec/integrations/mcp_server_spec.rb
describe "MCP Server" do
  it "handles tools/list request" do
    server = MCPServer.new
    response = server.handle_request({
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/list"
    })
    expect(response["result"]["tools"]).not_to be_empty
  end
end
```

### E2E Tests

Test plugin endpoints:

```ruby
# spec/integrations/plugin_endpoints_spec.rb
describe "Plugin endpoints" do
  it "POST /plugin/search returns results" do
    Mail.add_message(...)
    response = post "/plugin/search", query: "test"
    expect(response.status).to eq(200)
    expect(response.json["count"]).to eq(1)
  end
end
```

## Security Considerations

### Authentication

- No authentication in default configuration (assumes localhost)
- For remote access, implement external auth layer (reverse proxy with OAuth, etc.)

### Input Validation

- All user input is validated and sanitized
- SQL injection prevented by using SQLite prepared statements
- XSS prevention: no unescaped HTML output

### Message Confidentiality

- Messages contain email content
- Ensure MCP server and plugin are only accessible to authorized users
- Consider using a VPN or SSH tunnel for remote access

### Rate Limiting

Not implemented by default. For production:
- Add rate limiting middleware in Sinatra
- Configure ulimit on MCP server connections
- Monitor CPU/memory usage

## Monitoring and Debugging

### Enable Verbose Logging

```bash
mailcatcher --mcp --plugin --foreground -v
```

MCP logging is sent to stderr:
```
[MCP Server] Starting MailCatcher MCP Server
[MCP Server] Received: tools/list (id: 1)
[MCP Server] Calling tool: search_messages with input: {...}
[MCP Server] Sent: 1
```

### Check Running Processes

```bash
ps aux | grep mailcatcher
```

### Test Plugin Endpoint

```bash
curl http://localhost:1080/.well-known/ai-plugin.json
curl http://localhost:1080/plugin/openapi.json
```

### View Messages in HTTP UI

Open http://localhost:1080 in browser to see all messages and verify plugin can access them.

## Future Enhancements

1. **Socket Transport**: TCP/WebSocket MCP transport for remote clients
2. **Authentication**: OAuth/API key authentication for plugin
3. **Caching**: Cache repeated searches for performance
4. **Webhooks**: Event-driven notifications on new messages
5. **Analytics**: Track which tools are used and how often
6. **Rate Limiting**: Protect against abusive clients
7. **Batch Operations**: Handle multiple message operations in one call
8. **Advanced Filtering**: More granular search and filtering options

## References

- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [Claude Plugin Documentation](https://platform.openai.com/docs/plugins/)
- [Sinatra Documentation](http://sinatrarb.com/)
- [EventMachine Documentation](https://eventmachine.github.io/)
