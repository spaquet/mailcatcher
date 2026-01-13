# Testing Guide: MCP Server & Claude Plugin

This guide covers comprehensive testing of the MCP Server and Claude Plugin integrations before distribution.

## Quick Test Summary

```bash
# Run automated tests
bundle exec rspec spec/integrations/

# Manual Plugin Test
MAILCATCHER_ENV=development bundle exec mailcatcher --plugin --foreground

# Manual MCP Test
MAILCATCHER_ENV=development bundle exec mailcatcher --mcp --foreground

# Manual Combined Test
MAILCATCHER_ENV=development bundle exec mailcatcher --mcp --plugin --foreground
```

## Automated Tests

### Running All Integration Tests

```bash
bundle exec rspec spec/integrations/
```

### Running Specific Test Files

```bash
# MCP Tool Tests
bundle exec rspec spec/integrations/mcp_tools_spec.rb

# Plugin Endpoint Tests
bundle exec rspec spec/integrations/plugin_endpoints_spec.rb
```

### Test Coverage

Both test suites validate:

**MCP Tools (`mcp_tools_spec.rb`):**
- ✅ Tool definitions and schema validation
- ✅ search_messages with various filters
- ✅ get_latest_message_for with recipient/subject filtering
- ✅ extract_token_or_link for OTPs, magic links, reset tokens
- ✅ get_parsed_auth_info extraction
- ✅ get_message_preview_html with mobile optimization
- ✅ delete_message and clear_messages
- ✅ Error handling for invalid inputs and non-existent messages

**Plugin Endpoints (`plugin_endpoints_spec.rb`):**
- ✅ Plugin manifest endpoint (/.well-known/ai-plugin.json)
- ✅ OpenAPI spec generation (/plugin/openapi.json)
- ✅ All 7 plugin endpoints with various parameters
- ✅ Error handling and edge cases
- ✅ Message formatting and response structure

## Manual Testing

### Phase 1: Plugin Setup & Discovery

**1. Start MailCatcher with Plugin**

```bash
MAILCATCHER_ENV=development bundle exec mailcatcher --plugin --foreground
```

Output should include:
```
==> SMTP (127.0.0.1:1025)
==> HTTP (127.0.0.1:1080)
[Integrations] Starting integrations with options: {:plugin_enabled=>true, ...}
```

**2. Verify Plugin Manifest**

```bash
curl -s http://localhost:1080/.well-known/ai-plugin.json | jq .
```

Should return valid JSON with:
- `schema_version`: "v1"
- `name_for_human`: "MailCatcher NG"
- `api.type`: "openapi"
- `api.url`: Contains `/plugin/openapi.json`

**3. Verify OpenAPI Spec**

```bash
curl -s http://localhost:1080/plugin/openapi.json | jq .
```

Should return valid OpenAPI 3.0.0 spec with:
- All 7 plugin paths
- Proper parameter schemas
- Response definitions

### Phase 2: Plugin Endpoints Testing

**Setup: Create Test Messages**

```bash
# Send test email with OTP
ruby send_example_emails.rb
# Or send manually:
curl -X POST smtp://127.0.0.1:1025 \
  --mail-from sender@example.com \
  --mail-rcpt recipient@example.com \
  -d "From: sender@example.com
To: recipient@example.com
Subject: Test OTP
Date: $(date -R)

Your verification code is: 123456"
```

**Test: Search Endpoint**

```bash
# Search for messages
curl -X POST "http://localhost:1080/plugin/search?query=verification&limit=5"

# Expected response:
{
  "count": 1,
  "messages": [
    {
      "id": 1,
      "from": "sender@example.com",
      "to": ["recipient@example.com"],
      "subject": "Test OTP",
      "created_at": "2026-01-12T12:34:56.789Z"
    }
  ]
}
```

**Test: Get Latest Message**

```bash
curl "http://localhost:1080/plugin/message/1/latest?recipient=recipient@example.com"

# Expected: Message details JSON
```

**Test: Extract Tokens**

```bash
curl "http://localhost:1080/plugin/message/1/tokens?kind=otp"

# Expected:
{
  "extracted": [
    {
      "value": "123456",
      "context": "..."
    }
  ]
}
```

**Test: Auth Info**

```bash
curl "http://localhost:1080/plugin/message/1/auth-info"

# Expected:
{
  "verification_url": null,
  "otp_code": "123456",
  "reset_token": null,
  "unsubscribe_link": null,
  "links_count": 0
}
```

**Test: Preview HTML**

```bash
curl "http://localhost:1080/plugin/message/1/preview?mobile=true"

# Returns HTML content with viewport meta tag
```

**Test: Delete Message**

```bash
curl -X DELETE "http://localhost:1080/plugin/message/1"

# Returns: 204 No Content
```

**Test: Clear All Messages**

```bash
curl -X DELETE "http://localhost:1080/plugin/messages"

# Returns: 204 No Content
```

### Phase 3: Claude Plugin Installation

**1. Start MailCatcher with Plugin**

```bash
mailcatcher --plugin --foreground
```

**2. Add Plugin to Claude (Claude.com)**

1. Go to https://claude.com
2. Click on Profile/Settings → Plugins
3. Click "Create a plugin"
4. Paste: `http://localhost:1080/.well-known/ai-plugin.json`
5. Click "Install"

**3. Test in Claude Conversation**

Ask Claude:
```
"I have a test email server running. Search for emails from noreply@example.com"
```

Claude should:
- Recognize the plugin is available
- Call the search_messages tool
- Return matching messages

**4. Test Each Tool in Claude**

Try these natural language requests:

```
"Find the latest email to user@example.com"
"Extract the OTP code from message 1"
"Get the verification link from message 2"
"Show me the mobile preview of message 1"
"Delete all test emails"
```

### Phase 4: MCP Server Testing

**1. Start MailCatcher with MCP**

```bash
MAILCATCHER_ENV=development bundle exec mailcatcher --mcp --foreground
```

Output should include:
```
[MCP Server] Starting MailCatcher MCP Server
```

**2. Test MCP Protocol Manually**

Use `nc` (netcat) or similar to send JSON-RPC messages:

```bash
# List tools request
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | nc localhost 1080
```

Expected:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {"name": "search_messages", "description": "...", "inputSchema": {...}},
      {"name": "get_latest_message_for", ...},
      ...
    ]
  }
}
```

**3. Configure Claude Desktop for MCP**

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

Restart Claude Desktop.

**4. Test MCP Tools in Claude Desktop**

Claude should now show "MailCatcher" in the tools section with all 7 tools available.

Try using them in conversations - Claude will call them via JSON-RPC.

### Phase 5: Combined Plugin + MCP Testing

**1. Start MailCatcher with Both**

```bash
MAILCATCHER_ENV=development bundle exec mailcatcher --mcp --plugin --foreground
```

**2. Test Both Simultaneously**

- Use the Plugin in Claude.com for natural language
- Use MCP in Claude Desktop for programmatic access
- Both should return identical results

**3. Verify No Conflicts**

- Both servers should run without errors
- Message state should be shared (delete in one affects the other)
- No port conflicts or resource issues

## Edge Case Testing

### Error Scenarios

Test error handling for:

```bash
# Invalid message ID
curl http://localhost:1080/plugin/message/99999/auth-info
# Expected: 404 Not Found

# Missing required parameter
curl http://localhost:1080/plugin/search
# Expected: 400 Bad Request with error message

# Invalid token kind
curl "http://localhost:1080/plugin/message/1/tokens?kind=invalid"
# Expected: 400 Bad Request

# Message without HTML for preview
# Send plain text email, then:
curl http://localhost:1080/plugin/message/X/preview
# Expected: 404 Not Found
```

### Performance Testing

```bash
# Load test with many messages
for i in {1..100}; do
  echo "Test email $i" | curl -X POST smtp://127.0.0.1:1025 \
    --mail-from sender@example.com \
    --mail-rcpt recipient@example.com \
    -d @- &
done
wait

# Search should still be fast
time curl "http://localhost:1080/plugin/search?query=Test&limit=50"
```

### Charset & Encoding

```bash
# Test with UTF-8 characters
curl -X POST "http://localhost:1080/plugin/search?query=café"

# Test with non-ASCII emails
# Send emails with subject: "测试 Test 🚀"
```

### Large Messages

```bash
# Send large email (>1MB)
# Verify preview truncation at 200KB
curl http://localhost:1080/plugin/message/X/preview | wc -c
# Should be <= 200KB
```

## Verification Checklist

### Plugin Verification

- [ ] Plugin manifest is valid JSON
- [ ] OpenAPI spec is valid and includes all endpoints
- [ ] All 7 tools are exposed via plugin
- [ ] Claude can discover the plugin automatically
- [ ] All endpoints return correct HTTP status codes
- [ ] Error responses include helpful messages
- [ ] Mobile preview includes viewport meta tag
- [ ] HTML preview is truncated for large messages
- [ ] Delete operations actually remove messages
- [ ] No sensitive data in logs

### MCP Server Verification

- [ ] MCP server starts without errors
- [ ] JSON-RPC protocol is properly implemented
- [ ] All tools are listed in tools/list
- [ ] All tools can be called successfully
- [ ] Parameter validation works correctly
- [ ] Error responses follow JSON-RPC format
- [ ] Server stops cleanly
- [ ] Works with Claude Desktop config
- [ ] No race conditions with concurrent calls

### Integration Verification

- [ ] Both Plugin and MCP can run together
- [ ] Message state is shared between Plugin and MCP
- [ ] No conflicts or port issues
- [ ] CLI options --mcp and --plugin are recognized
- [ ] Help text shows new options: `mailcatcher --help`
- [ ] Works with other MailCatcher options (--persistence, --smtp-port, etc.)
- [ ] No breaking changes to existing functionality

## Troubleshooting

### Plugin Not Discoverable

1. Verify manifest is reachable:
   ```bash
   curl http://localhost:1080/.well-known/ai-plugin.json
   ```

2. Check OpenAPI spec is valid:
   ```bash
   curl http://localhost:1080/plugin/openapi.json | jq .
   ```

3. Try Claude's plugin creation with explicit URL

### MCP Server Not Starting

1. Check for port conflicts:
   ```bash
   lsof -i :1025  # SMTP
   lsof -i :1080  # HTTP
   ```

2. Check logs for errors:
   ```bash
   MAILCATCHER_ENV=development bundle exec mailcatcher --mcp --foreground -v
   ```

3. Verify configuration:
   ```bash
   cat ~/.claude_desktop_config.json
   ```

### Tool Calls Failing

1. Verify message exists:
   - Go to http://localhost:1080 in browser
   - Check message ID matches

2. Check message content:
   - Ensure email has expected parts (HTML, plain text, etc.)
   - Some tools require specific content

3. Check logs for detailed errors:
   ```bash
   MAILCATCHER_ENV=development bundle exec mailcatcher --foreground -v 2>&1 | grep -E "(ERROR|Exception|error)"
   ```

## Performance Metrics

Benchmark these operations:

```bash
# Search performance
time curl "http://localhost:1080/plugin/search?query=test&limit=50"

# Expected: < 100ms

# Token extraction performance
time curl "http://localhost:1080/plugin/message/1/tokens?kind=all"

# Expected: < 50ms

# HTML preview performance
time curl "http://localhost:1080/plugin/message/1/preview?mobile=true"

# Expected: < 200ms (depends on message size)
```

## Distribution Checklist

Before releasing v1.5.2:

- [ ] All automated tests pass: `bundle exec rspec spec/integrations/`
- [ ] Manual Plugin tests completed (Phase 1-3)
- [ ] Manual MCP tests completed (Phase 4)
- [ ] Combined testing works (Phase 5)
- [ ] Edge cases handled properly
- [ ] Documentation is accurate
- [ ] No console errors or warnings
- [ ] Performance is acceptable
- [ ] Works on macOS, Linux, Windows (if applicable)
- [ ] No breaking changes to existing features
- [ ] Version bumped to 1.5.2
- [ ] Changelog updated
- [ ] README reflects new features

## Quick Reference

```bash
# Automated testing
bundle exec rspec spec/integrations/mcp_tools_spec.rb      # MCP tools
bundle exec rspec spec/integrations/plugin_endpoints_spec.rb # Plugin
bundle exec rspec spec/integrations/                        # All integration tests

# Manual testing - Plugin
MAILCATCHER_ENV=development bundle exec mailcatcher --plugin --foreground
# Test: http://localhost:1080/.well-known/ai-plugin.json
# Test: http://localhost:1080/plugin/openapi.json
# Test: POST http://localhost:1080/plugin/search?query=test

# Manual testing - MCP
MAILCATCHER_ENV=development bundle exec mailcatcher --mcp --foreground
# Configure: ~/.claude_desktop_config.json
# Test: Use in Claude Desktop

# Combined
MAILCATCHER_ENV=development bundle exec mailcatcher --mcp --plugin --foreground
# Test both simultaneously
```

## Success Criteria

✅ **Plugin Tests Pass:**
- Manifest is valid and discoverable
- OpenAPI spec is complete and valid
- All 7 endpoints work correctly
- Claude can use the plugin
- Error handling is robust

✅ **MCP Tests Pass:**
- Server starts and stops cleanly
- JSON-RPC protocol is correct
- All 7 tools are accessible
- Claude Desktop can connect
- Error handling follows spec

✅ **Integration Tests Pass:**
- Both can run together
- No conflicts or issues
- Message state is consistent
- Backward compatible

✅ **Ready for Distribution**
- All checks pass
- Documentation is complete
- No known issues
- Performance is good

For issues or questions, see [CLAUDE_INTEGRATION.md](CLAUDE_INTEGRATION.md) and [docs/INTEGRATION_ARCHITECTURE.md](docs/INTEGRATION_ARCHITECTURE.md).
