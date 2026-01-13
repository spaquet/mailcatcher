# MCP Server Setup for MailCatcher NG

MailCatcher NG includes a built-in MCP (Model Context Protocol) server that allows Claude and other MCP-compatible clients to interact with caught emails programmatically.

## Quick Start

### Option 1: Command Line

Start MailCatcher with MCP enabled:

```bash
mailcatcher --mcp --foreground
```

This will:
1. Start the normal MailCatcher SMTP and HTTP servers
2. Start the MCP server over stdio
3. Output available tools to stderr

### Option 2: Docker

When using Docker, add the `--mcp` flag:

```bash
docker run -p 1025:1025 -p 1080:1080 mailcatcher/mailcatcher-ng --mcp --foreground
```

## Using with Claude Desktop

Claude Desktop's built-in configuration allows you to add custom MCP servers.

### 1. Create Configuration

Create or edit `~/.claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "mailcatcher": {
      "command": "mailcatcher",
      "args": ["--mcp", "--foreground"]
    }
  }
}
```

### 2. Configure MailCatcher Options (Optional)

If you need to customize MailCatcher settings:

```json
{
  "mcpServers": {
    "mailcatcher": {
      "command": "mailcatcher",
      "args": [
        "--mcp",
        "--foreground",
        "--smtp-port", "1025",
        "--http-port", "1080",
        "--persistence"
      ]
    }
  }
}
```

### 3. Restart Claude

After updating the config, restart Claude Desktop.

## Available Tools

The MCP server exposes 7 tools:

### 1. `search_messages`

Search through caught emails with flexible filtering.

**Parameters:**
- `query` (string, required): Search term (searches subject, sender, recipients, body)
- `limit` (integer, optional, default: 5): Maximum results
- `has_attachments` (boolean, optional): Filter to only messages with attachments
- `from_date` (string, optional): ISO 8601 datetime to search from
- `to_date` (string, optional): ISO 8601 datetime to search until

**Example:**
```
Search for emails from noreply@example.com
```

### 2. `get_latest_message_for`

Get the latest email received by a specific recipient.

**Parameters:**
- `recipient` (string, required): Email address to match in recipients
- `subject_contains` (string, optional): Only return if subject contains this text

**Example:**
```
Get the latest email to user@example.com about password reset
```

### 3. `extract_token_or_link`

Extract authentication tokens or links from a message.

**Parameters:**
- `message_id` (integer, required): Message ID
- `kind` (string, required): `magic_link`, `otp`, `reset_token`, or `all`

**Example:**
```
Extract the OTP code from message 5
```

### 4. `get_parsed_auth_info`

Get structured authentication information from a message.

**Parameters:**
- `message_id` (integer, required): Message ID

**Returns:**
- `verification_url`: First magic link found
- `otp_code`: First OTP code found
- `reset_token`: First reset token found
- `unsubscribe_link`: Unsubscribe link from List-Unsubscribe header
- `links_count`: Total number of links

### 5. `get_message_preview_html`

Get HTML preview of a message (responsive for mobile if requested).

**Parameters:**
- `message_id` (integer, required): Message ID
- `mobile` (boolean, optional, default: false): Return mobile-optimized preview

**Returns:**
- Full HTML content (truncated at 200KB if very large)
- Character set information

### 6. `delete_message`

Delete a specific message by ID.

**Parameters:**
- `message_id` (integer, required): Message ID to delete

### 7. `clear_messages`

Delete all caught messages (destructive operation).

**Parameters:** None

## Common Use Cases

### Testing Email-Based Authentication

```
Claude: "I'm testing a login flow. Send a test email to test@example.com and extract the verification link."

[Claude creates a test email]

Claude: "Now find the latest email to test@example.com and get the verification URL."

Claude uses: get_latest_message_for(recipient: "test@example.com", subject_contains: "verify")
Claude uses: get_parsed_auth_info(message_id: 1)
```

### Debugging Email Content

```
Claude: "Show me the HTML preview of message 3, optimized for mobile"

Claude uses: get_message_preview_html(message_id: 3, mobile: true)
```

### Searching Email History

```
Claude: "Find all emails from send@newsletter.com that arrived in the last hour"

Claude uses: search_messages(query: "send@newsletter.com", from_date: "2024-01-12T15:00:00Z", to_date: "2024-01-12T16:00:00Z")
```

## Troubleshooting

### MCP Server Not Starting

1. Check that MailCatcher is running:
   ```bash
   mailcatcher --mcp --foreground -v
   ```

2. Verify no port conflicts:
   ```bash
   lsof -i :1025  # Check SMTP port
   lsof -i :1080  # Check HTTP port
   ```

3. Check stderr for errors:
   - MCP logging is sent to stderr, not stdout
   - Look for `[MCP Server]` log lines

### Tools Not Available

1. Check Claude can see the tools:
   - In Claude, type `@mailcatcher` to see available tools
   - Tools should appear in the tool selector

2. Verify MCP server is running:
   ```bash
   ps aux | grep mailcatcher
   ```

### Message Not Found

1. Ensure the message ID is correct
2. Check the HTTP UI to see available messages: http://localhost:1080/

## Performance Notes

- Message searches are limited to configurable max results (default: 50)
- Large HTML previews are truncated at 200KB for performance
- First 10 links are returned from `get_parsed_auth_info` to keep responses manageable
- Search queries should be specific to avoid long response times

## Security Considerations

- The MCP server runs over stdio (in-process) - no network exposure
- No authentication is required (assumes localhost-only MailCatcher)
- Messages contain email content - keep MCP server access restricted to trusted users
- For remote access, use additional network-level security controls

## Advanced Configuration

### Environment Variables

```bash
# Enable verbose logging
export MAILCATCHER_ENV=development
mailcatcher --mcp --foreground

# Use specific database
export MAILCATCHER_HOME=~/.my_mailcatcher
mailcatcher --mcp --persistence
```

### Programmatic Access

You can also call MCP tools directly from Ruby:

```ruby
require 'mail_catcher/integrations/mcp_tools'

# Search for messages
results = MailCatcher::Integrations::MCPTools.call_tool(:search_messages, {
  query: "from:test@example.com",
  limit: 10
})

# Extract tokens
tokens = MailCatcher::Integrations::MCPTools.call_tool(:extract_token_or_link, {
  message_id: 1,
  kind: "otp"
})
```

## Next Steps

- See [CLAUDE_PLUGIN_SETUP.md](CLAUDE_PLUGIN_SETUP.md) for using the Claude Plugin (no installation needed)
- See [INTEGRATION_ARCHITECTURE.md](INTEGRATION_ARCHITECTURE.md) for detailed architecture information
