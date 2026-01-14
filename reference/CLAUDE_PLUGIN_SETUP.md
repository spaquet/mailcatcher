# Claude Plugin Setup for MailCatcher NG

 MailCatcher NG can be used as a Claude Plugin, giving Claude direct access to all mail inspection features without requiring any special installation on your machine.

## Quick Start

### 1. Start MailCatcher with Plugin Support

```bash
mailcatcher --plugin --foreground
```

Or enable both MCP and Plugin:

```bash
mailcatcher --mcp --plugin --foreground
```

### 2. Add Plugin to Claude

In Claude.com or Claude Desktop:

1. Open settings/plugins menu
2. Select "Create a plugin"
3. Paste this plugin manifest URL (or install manually below):
   ```
   http://localhost:1080/.well-known/ai-plugin.json
   ```

4. Click "Install" or "Add"

That's it! Claude now has access to all MailCatcher tools.

## Manual Plugin Installation

If the automatic discovery doesn't work:

1. Go to https://claude.com (or open Claude Desktop)
2. Open the plugin settings
3. Click "Create a plugin"
4. Provide these details:
   - **Name:** MailCatcher NG
   - **Plugin URL:** `http://localhost:1080/.well-known/ai-plugin.json`
   - **API Base URL:** `http://localhost:1080`

## Using the Plugin with Claude

Once installed, you can interact with MailCatcher through natural language:

### Examples

**Search for emails:**
```
Claude: "Search my emails for messages from noreply@example.com"
```

**Extract authentication codes:**
```
Claude: "What's the OTP code in the latest email to admin@test.com?"
```

**Get email previews:**
```
Claude: "Show me the HTML preview of message 1 optimized for mobile"
```

**Manage messages:**
```
Claude: "Clear all my test emails"
```

## Available Plugin Endpoints

The plugin exposes HTTP endpoints that Claude uses:

### POST /plugin/search

Search through emails.

**Parameters:**
- `query` (string, required): Search term
- `limit` (integer, optional): Max results (default: 5)

**Example:**
```json
POST /plugin/search?query=password&limit=10
```

### GET /plugin/message/{id}/latest

Get latest message for a recipient.

**Parameters:**
- `recipient` (string, required): Email address
- `subject_contains` (string, optional): Subject filter

**Example:**
```
GET /plugin/message/1/latest?recipient=user@example.com&subject_contains=verify
```

### GET /plugin/message/{id}/tokens

Extract tokens from a message.

**Parameters:**
- `id` (integer, path): Message ID
- `kind` (string, optional): `magic_link`, `otp`, `reset_token`, or `all`

**Example:**
```
GET /plugin/message/1/tokens?kind=otp
```

### GET /plugin/message/{id}/auth-info

Get structured authentication information.

**Parameters:**
- `id` (integer, path): Message ID

**Returns:**
```json
{
  "verification_url": "https://example.com/verify?token=...",
  "otp_code": "123456",
  "reset_token": "...",
  "unsubscribe_link": "...",
  "links_count": 5
}
```

### GET /plugin/message/{id}/preview

Get HTML preview of a message.

**Parameters:**
- `id` (integer, path): Message ID
- `mobile` (boolean, optional): Mobile-optimized (default: false)

**Returns:** HTML content

### DELETE /plugin/messages

Delete all messages.

**Returns:** 204 No Content

### DELETE /plugin/message/{id}

Delete a specific message.

**Parameters:**
- `id` (integer, path): Message ID

**Returns:** 204 No Content

## Plugin vs MCP: Which Should I Use?

### Use the Plugin if:
- You want to interact with Claude.com or Claude Desktop
- You don't want to configure anything beyond starting MailCatcher
- You prefer natural language interactions
- You're testing email workflows with Claude

### Use MCP if:
- You need programmatic access from other tools
- You want to integrate with Claude Desktop configurations
- You need more precise tool control
- You're building automated test workflows

### Use Both if:
- You want maximum flexibility
- You need both natural language (plugin) and programmatic (MCP) access
- You're running a shared testing environment

```bash
mailcatcher --mcp --plugin --foreground
```

## Configuration

### Remote Access

If MailCatcher is on a different machine:

1. Start MailCatcher with the `--http-ip` flag:
   ```bash
   mailcatcher --plugin --http-ip 0.0.0.0 --foreground
   ```

2. Update the plugin URL in Claude:
   - Change `localhost` to your server's IP or hostname
   - Example: `http://192.168.1.100:1080/.well-known/ai-plugin.json`

### HTTPS (Optional, for remote deployments)

For production deployments, use HTTPS:

1. Set up a reverse proxy (nginx, caddy, etc.)
2. Configure the plugin URL to use `https://`
3. Ensure SSL certificates are valid

## Troubleshooting

### Plugin Not Appearing in Claude

1. **Check MailCatcher is running:**
   ```bash
   curl http://localhost:1080/.well-known/ai-plugin.json
   ```

2. **Clear Claude's cache:**
   - Reload the page
   - Log out and log back in

3. **Verify plugin endpoint is accessible:**
   ```bash
   curl http://localhost:1080/plugin/openapi.json
   ```

### "Unable to reach plugin" Error

1. **Check MailCatcher is running:**
   ```bash
   ps aux | grep mailcatcher
   ```

2. **Verify port is correct:**
   ```bash
   lsof -i :1080
   ```

3. **Test connectivity:**
   ```bash
   curl -v http://localhost:1080/version.json
   ```

### Plugin Commands Not Working

1. **Check for errors in HTTP response:**
   ```bash
   curl -X POST "http://localhost:1080/plugin/search?query=test" -v
   ```

2. **Verify message exists:**
   - Go to http://localhost:1080 in your browser
   - Check if messages are actually present

3. **Check MailCatcher logs:**
   ```bash
   mailcatcher --plugin --foreground -v
   ```

## Using with Automated Testing

The plugin can be used in test workflows:

```python
# Python example using Claude SDK
from anthropic import Anthropic

client = Anthropic()

# Start MailCatcher with plugin first!
# mailcatcher --plugin --foreground

response = client.messages.create(
    model="claude-3-5-sonnet-20241022",
    max_tokens=1024,
    messages=[
        {
            "role": "user",
            "content": "Search for emails from support@example.com and tell me the subject lines"
        }
    ]
)

print(response.content[0].text)
```

## Performance Considerations

- Search results are limited to configurable max (default: 5)
- Large HTML previews are truncated at 200KB
- Limit returned from `auth-info` endpoint is 10 links

For better performance with large datasets:
- Use specific search queries
- Limit result sizes
- Regular cleanup of old messages

## Security Notes

- The plugin communicates over HTTP (uses localhost)
- No authentication is required
- Messages contain email content - keep access restricted
- For production use, implement network security controls

## Next Steps

- See [MCP_SETUP.md](MCP_SETUP.md) for programmatic access via MCP
- See [INTEGRATION_ARCHITECTURE.md](INTEGRATION_ARCHITECTURE.md) for technical details
- Check README.md for general MailCatcher documentation
