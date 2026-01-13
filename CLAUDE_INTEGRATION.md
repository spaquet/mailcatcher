# MailCatcher NG: MCP & Claude Plugin Integration

MailCatcher NG v1.5.2+ includes built-in integration with Claude through two complementary methods:

1. **Claude Plugin** - HTTP-based plugin for Claude.com and Claude Desktop (no installation required)
2. **MCP Server** - Direct programmatic access via the Model Context Protocol (stdio-based)

## Key Features

✨ **7 Powerful Tools Available:**
- 🔍 `search_messages` - Full-text search with filtering
- 📧 `get_latest_message_for` - Find latest message for recipient
- 🔐 `extract_token_or_link` - Extract OTPs, magic links, reset tokens
- 📋 `get_parsed_auth_info` - Structured authentication data
- 👁️ `get_message_preview_html` - Responsive HTML preview
- 🗑️ `delete_message` / `clear_messages` - Cleanup tools

🚀 **Zero Configuration for Plugin** - Just start MailCatcher and install in Claude

⚡ **Optional MCP** - Enable only when you need it with `--mcp` flag

🔒 **Local-First** - Runs on localhost, no external dependencies

## Quick Start

### Option 1: Claude Plugin (Easiest)

1. **Start MailCatcher:**
```bash
mailcatcher --plugin --foreground
```

2. **Add to Claude:**
   - Go to Claude.com or Claude Desktop
   - Settings → Plugins → Create plugin
   - Paste: `http://localhost:1080/.well-known/ai-plugin.json`

3. **Use in Claude:**
```
Claude: "Search for emails from noreply@example.com"
Claude: "What's the OTP in the latest email to test@example.com?"
```

✅ That's it! No additional configuration needed.

### Option 2: MCP Server (Programmatic)

1. **Start MailCatcher with MCP:**
```bash
mailcatcher --mcp --foreground
```

2. **Configure Claude Desktop:**
Edit `~/.claude_desktop_config.json`:
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

3. **Use in Claude:**
Same as plugin - Claude automatically detects available MCP tools

### Option 3: Both Plugin + MCP

For maximum flexibility:
```bash
mailcatcher --mcp --plugin --foreground
```

## Installation Guide

### Prerequisites

- MailCatcher NG v1.5.2 or later
- Ruby 2.6+
- Claude.com account or Claude Desktop app

### Installation Steps

#### 1. Install/Update MailCatcher

```bash
# Via gem
gem install mailcatcher

# Or via bundler
bundle add mailcatcher
```

#### 2. Start MailCatcher

```bash
# With Plugin (recommended)
mailcatcher --plugin

# With MCP
mailcatcher --mcp

# With both
mailcatcher --mcp --plugin

# Full options example
mailcatcher --mcp --plugin \
  --smtp-port 1025 \
  --http-port 1080 \
  --persistence \
  --foreground
```

#### 3. Verify It's Running

```bash
# Check plugin manifest
curl http://localhost:1080/.well-known/ai-plugin.json

# Check if HTTP server is responding
curl http://localhost:1080/version.json
```

#### 4. Add to Claude

**For Plugin (Claude.com or Desktop):**
1. Open Claude
2. Click Settings/Plugins
3. Click "Create a plugin"
4. Enter: `http://localhost:1080/.well-known/ai-plugin.json`
5. Click Install

**For MCP (Claude Desktop only):**
1. Edit `~/.claude_desktop_config.json`
2. Add `mailcatcher` entry (see example above)
3. Restart Claude

## Usage Examples

### Example 1: Find Verification Email

```
User: "I sent a test email with a verification link.
       Find the latest email to admin@test.com and extract the link."

Claude:
- Searches for emails to admin@test.com
- Extracts the verification URL
- Returns: https://example.com/verify?token=abc123
```

### Example 2: Extract OTP Code

```
User: "Get the OTP from the latest 2FA email to user@example.com"

Claude:
- Finds latest email to user@example.com
- Extracts OTP codes
- Returns: 123456
```

### Example 3: Email Preview

```
User: "Show me the mobile-optimized preview of message 5"

Claude:
- Fetches HTML of message 5
- Adds mobile viewport meta tag
- Returns: HTML preview optimized for mobile
```

### Example 4: Search and Analyze

```
User: "Find all emails from support@example.com about password resets"

Claude:
- Searches for emails from support@example.com with "password reset"
- Returns: List of matching messages with subjects, dates
- Can extract tokens/links from any matched message
```

## CLI Options Reference

```bash
mailcatcher [options]

Integration Options:
  --mcp                    Enable MCP server for Claude integration
  --plugin                 Enable Claude Plugin endpoints

SMTP Options:
  --smtp-port PORT         SMTP server port (default: 1025)
  --smtp-ip IP            SMTP server IP (default: 127.0.0.1)
  --smtp-ssl              Enable SSL/TLS for SMTP

HTTP Options:
  --http-port PORT        HTTP server port (default: 1080)
  --http-ip IP            HTTP server IP (default: 127.0.0.1)
  --http-path PATH        HTTP path prefix (default: /)

Other Options:
  --persistence           Save emails to disk
  --messages-limit N      Maximum messages to keep
  --foreground            Run in foreground (don't daemonize)
  --verbose               Verbose output
```

## Documentation

- **[MCP_SETUP.md](docs/MCP_SETUP.md)** - Detailed MCP configuration and usage
- **[CLAUDE_PLUGIN_SETUP.md](docs/CLAUDE_PLUGIN_SETUP.md)** - Plugin installation and troubleshooting
- **[INTEGRATION_ARCHITECTURE.md](docs/INTEGRATION_ARCHITECTURE.md)** - Technical architecture details

## How It Works

### Claude Plugin Architecture

```
Claude.com / Claude Desktop
         ↓
    HTTP Request
         ↓
MailCatcher Plugin Endpoint
         ↓
Shared Tool Implementation
         ↓
Mail Module (Core Business Logic)
         ↓
SQLite Database
```

### MCP Server Architecture

```
Claude (MCP Client)
         ↓
JSON-RPC over stdio
         ↓
MCP Server
         ↓
Shared Tool Implementation
         ↓
Mail Module (Core Business Logic)
         ↓
SQLite Database
```

**Key Point:** Both use the same tool implementations - defined once, used twice.

## Troubleshooting

### Plugin Not Appearing

1. Verify MailCatcher is running:
   ```bash
   curl http://localhost:1080/version.json
   ```

2. Clear Claude's cache:
   - Reload page or restart Claude

3. Check plugin manifest:
   ```bash
   curl http://localhost:1080/.well-known/ai-plugin.json
   ```

### MCP Tools Not Available

1. Check MailCatcher is running with `--mcp`:
   ```bash
   ps aux | grep mailcatcher
   ```

2. Verify config file has MCP server:
   ```bash
   cat ~/.claude_desktop_config.json
   ```

3. Check MailCatcher logs:
   ```bash
   mailcatcher --mcp --foreground -v
   ```

### Message Not Found

- Verify message exists: go to http://localhost:1080
- Check message ID is correct
- Ensure MailCatcher hasn't cleared messages

## Security & Privacy

### Default Configuration
- Runs on localhost only (127.0.0.1)
- No network exposure unless explicitly configured
- No authentication required (assumes trusted local access)

### For Production/Remote Access
- Use reverse proxy with authentication (nginx + OAuth, etc.)
- Enable HTTPS
- Implement rate limiting
- Monitor access logs

### Data Handling
- Emails are stored locally in SQLite (or memory)
- Claude sees email content needed for requested operation
- No data sent to external services
- Full control over message lifecycle (can delete anytime)

## Performance Notes

- Search results limited to prevent large responses
- HTML previews truncated at 200KB
- Links returned are limited (first 10)
- SQLite database is thread-safe
- No external API calls

## Supported Use Cases

✅ **Email Testing**
- Extract OTPs for 2FA testing
- Get verification links for signup flows
- Test password reset emails

✅ **Debugging**
- Verify email content before sending
- Check email formatting
- Review headers and structure

✅ **Automation**
- Validate emails in CI/CD pipelines
- Extract data for integration testing
- Manage test message state

✅ **Development**
- Catch emails during local development
- Preview HTML rendering
- Extract links for manual testing

## Limitations

- Local to single machine (unless reverse proxy configured)
- No built-in authentication
- Searches are simple text matching (not complex boolean queries)
- Large attachments truncated in preview
- No scheduling or batch operations

## Comparison: Plugin vs MCP

| Feature | Plugin | MCP |
|---------|--------|-----|
| Setup | 1 minute | 2 minutes |
| Installation | None | Config file |
| Requires restart | No | Yes (Claude) |
| Natural language | ✅ Full | ✅ Full |
| Network | HTTP | stdio (in-process) |
| Remote access | Via reverse proxy | SSH tunnel recommended |
| Programmatic access | No | ✅ Yes |
| Both available | ✅ Yes | Can run together |

## API Reference

### Plugin Endpoints

All plugin endpoints return JSON unless otherwise specified:

```
POST   /plugin/search                    Search messages
GET    /plugin/message/:id/latest        Get latest for recipient
GET    /plugin/message/:id/tokens        Extract tokens
GET    /plugin/message/:id/auth-info     Get auth data
GET    /plugin/message/:id/preview       Get HTML preview
DELETE /plugin/messages                  Clear all
DELETE /plugin/message/:id               Delete one
```

### MCP Tools

Same 7 tools available via MCP protocol:
- `search_messages`
- `get_latest_message_for`
- `extract_token_or_link`
- `get_parsed_auth_info`
- `get_message_preview_html`
- `delete_message`
- `clear_messages`

## Contributing

To add new features or report bugs:

1. Check [INTEGRATION_ARCHITECTURE.md](docs/INTEGRATION_ARCHITECTURE.md) for design details
2. File issue on GitHub: https://github.com/spaquet/mailcatcher
3. Submit PR with tests

## Version History

- **v1.5.2+** - MCP Server and Claude Plugin support added
- **v1.5.0** - Comprehensive API improvements
- **v1.4.x** - Core MailCatcher NG features

## License

MailCatcher NG is MIT licensed. See LICENSE file for details.

## Support

- 📖 Documentation: See `/docs` directory
- 🐛 Issues: https://github.com/spaquet/mailcatcher/issues
- 💬 Discussions: GitHub Discussions
- 📧 Contact: support@mailcatcher.app

## Next Steps

- **Getting Started:** [CLAUDE_PLUGIN_SETUP.md](docs/CLAUDE_PLUGIN_SETUP.md)
- **Advanced Setup:** [MCP_SETUP.md](docs/MCP_SETUP.md)
- **Architecture Deep Dive:** [INTEGRATION_ARCHITECTURE.md](docs/INTEGRATION_ARCHITECTURE.md)
