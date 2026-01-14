#!/bin/bash

# Quick Manual Testing Script for MCP & Plugin Integration
# Usage: ./test_mcp_plugin.sh [plugin|mcp|both]

set -e

MODE=${1:-both}
SMTP_PORT=1025
HTTP_PORT=1080
LOCALHOST=127.0.0.1

echo "=================================================="
echo "MailCatcher NG - MCP & Plugin Testing Script"
echo "=================================================="
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to wait for port
wait_for_port() {
    local port=$1
    local timeout=30
    local elapsed=0

    while ! nc -z $LOCALHOST $port 2>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            echo "Timeout waiting for port $port"
            exit 1
        fi
        sleep 0.5
        elapsed=$((elapsed + 1))
    done
    echo -e "${GREEN}✓ Port $port is ready${NC}"
}

# Function to start MailCatcher
start_mailcatcher() {
    local args="--foreground --smtp-port $SMTP_PORT --http-port $HTTP_PORT"

    if [ "$MODE" == "plugin" ] || [ "$MODE" == "both" ]; then
        args="$args --plugin"
    fi

    if [ "$MODE" == "mcp" ] || [ "$MODE" == "both" ]; then
        args="$args --mcp"
    fi

    echo -e "${BLUE}Starting MailCatcher with: MAILCATCHER_ENV=development bundle exec mailcatcher $args${NC}"
    MAILCATCHER_ENV=development bundle exec mailcatcher $args &
    MAILCATCHER_PID=$!
    echo "MailCatcher PID: $MAILCATCHER_PID"

    # Wait for ports
    wait_for_port $SMTP_PORT
    wait_for_port $HTTP_PORT
}

# Function to send test email
send_test_email() {
    echo ""
    echo -e "${BLUE}Sending test email...${NC}"

    ruby -r net/smtp << 'EOF'
require 'net/smtp'

message = "From: sender@example.com\r\nTo: recipient@example.com\r\nSubject: Test Email with OTP\r\nDate: #{Time.now.rfc2822}\r\n\r\nYour verification code is: 123456\r\nClick here to verify: https://example.com/verify?token=abc123"

Net::SMTP.start('127.0.0.1', 1025) do |smtp|
  smtp.send_message message, 'sender@example.com', 'recipient@example.com'
end

puts "✓ Email sent successfully"
EOF
}

# Function to test plugin
test_plugin() {
    echo ""
    echo -e "${BLUE}=== Testing Claude Plugin ===${NC}"

    # Test manifest
    echo ""
    echo "Testing manifest endpoint..."
    if curl -s http://localhost:$HTTP_PORT/.well-known/ai-plugin.json | jq . > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Plugin manifest is valid${NC}"
    else
        echo "✗ Plugin manifest invalid"
        return 1
    fi

    # Test OpenAPI spec
    echo ""
    echo "Testing OpenAPI spec endpoint..."
    if curl -s http://localhost:$HTTP_PORT/plugin/openapi.json | jq . > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OpenAPI spec is valid${NC}"
    else
        echo "✗ OpenAPI spec invalid"
        return 1
    fi

    # Test search endpoint
    echo ""
    echo "Testing search endpoint..."
    response=$(curl -s "http://localhost:$HTTP_PORT/plugin/search?query=Test")
    if echo "$response" | jq . > /dev/null 2>&1; then
        count=$(echo "$response" | jq '.count')
        echo -e "${GREEN}✓ Search found $count message(s)${NC}"
    else
        echo "✗ Search endpoint failed"
        return 1
    fi

    # Test token extraction
    echo ""
    echo "Testing token extraction endpoint..."
    response=$(curl -s "http://localhost:$HTTP_PORT/plugin/message/1/tokens?kind=otp")
    if echo "$response" | jq . > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Token extraction works${NC}"
    else
        echo "✗ Token extraction failed"
        return 1
    fi

    # Test auth info
    echo ""
    echo "Testing auth info endpoint..."
    response=$(curl -s "http://localhost:$HTTP_PORT/plugin/message/1/auth-info")
    if echo "$response" | jq . > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Auth info extraction works${NC}"
    else
        echo "✗ Auth info extraction failed"
        return 1
    fi

    # Test preview
    echo ""
    echo "Testing preview endpoint..."
    if curl -s "http://localhost:$HTTP_PORT/plugin/message/1/preview" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Preview endpoint works${NC}"
    else
        echo "✗ Preview endpoint failed"
        return 1
    fi

    echo ""
    echo -e "${GREEN}=== Plugin Tests Complete ===${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Go to https://claude.com"
    echo "2. Settings → Plugins → Create plugin"
    echo "3. Enter: http://localhost:$HTTP_PORT/.well-known/ai-plugin.json"
    echo "4. Try asking Claude to search your emails"
}

# Function to test MCP
test_mcp() {
    echo ""
    echo -e "${BLUE}=== Testing MCP Server ===${NC}"

    echo ""
    echo "MCP Server is running on stdin/stdout"
    echo -e "${YELLOW}To test MCP:${NC}"
    echo ""
    echo "1. Configure Claude Desktop:"
    echo "   Edit ~/.claude_desktop_config.json"
    echo "   Add:"
    echo "   {"
    echo "     \"mcpServers\": {"
    echo "       \"mailcatcher\": {"
    echo "         \"command\": \"mailcatcher\","
    echo "         \"args\": [\"--mcp\", \"--foreground\"]"
    echo "       }"
    echo "     }"
    echo "   }"
    echo ""
    echo "2. Restart Claude Desktop"
    echo "3. Tools from MailCatcher should now be available"
    echo ""
    echo -e "${GREEN}✓ MCP Server is running${NC}"
}

# Function to cleanup
cleanup() {
    echo ""
    echo "Cleaning up..."
    if [ ! -z "$MAILCATCHER_PID" ]; then
        kill $MAILCATCHER_PID 2>/dev/null || true
        wait $MAILCATCHER_PID 2>/dev/null || true
    fi
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
case "$MODE" in
    plugin)
        echo "Mode: Plugin Only"
        ;;
    mcp)
        echo "Mode: MCP Only"
        ;;
    both)
        echo "Mode: Both Plugin and MCP"
        ;;
    *)
        echo "Invalid mode: $MODE"
        echo "Usage: ./test_mcp_plugin.sh [plugin|mcp|both]"
        exit 1
        ;;
esac

echo ""

# Start MailCatcher
start_mailcatcher

# Send test email
send_test_email

# Run tests
if [ "$MODE" == "plugin" ] || [ "$MODE" == "both" ]; then
    test_plugin || exit 1
fi

if [ "$MODE" == "mcp" ] || [ "$MODE" == "both" ]; then
    test_mcp
fi

echo ""
echo -e "${GREEN}=================================================="
echo "All tests completed successfully!"
echo "==================================================${NC}"
