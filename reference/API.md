# REST API

MailCatcher NG provides a RESTful API for accessing and downloading messages programmatically.

## Endpoints

### List All Messages

```
GET /messages
```

Returns JSON array of all messages with basic metadata.

**Example:**

```bash
curl http://127.0.0.1:1080/messages
```

**Response:**

```json
[
  {
    "id": 1,
    "from": ["sender@example.com"],
    "to": ["recipient@example.com"],
    "subject": "Test Email",
    "created_at": "2024-01-10T10:30:00Z"
  },
  {
    "id": 2,
    "from": ["another@example.com"],
    "to": ["user@example.com"],
    "subject": "Another Test",
    "created_at": "2024-01-10T10:35:00Z"
  }
]
```

### Get Message Metadata

```
GET /messages/:id.json
```

Returns detailed metadata for a specific message.

**Example:**

```bash
curl http://127.0.0.1:1080/messages/1.json
```

### Get HTML Version

```
GET /messages/:id.html
```

Returns the HTML version of the message.

**Example:**

```bash
curl http://127.0.0.1:1080/messages/1.html
```

### Get Plain Text Version

```
GET /messages/:id.plain
```

Returns the plain text version of the message.

**Example:**

```bash
curl http://127.0.0.1:1080/messages/1.plain
```

### Get Message Source

```
GET /messages/:id.source
```

Returns the complete raw email source (MIME format).

**Example:**

```bash
curl http://127.0.0.1:1080/messages/1.source
```

### Download Message as EML

```
GET /messages/:id.eml
```

Downloads the complete message in EML (RFC 822) format, suitable for importing into email clients.

**Example:**

```bash
curl -O http://127.0.0.1:1080/messages/1.eml
```

### Download Message Part/Attachment

```
GET /messages/:id/parts/:cid
```

Downloads a specific message part or attachment by its Content-ID (CID).

**Example:**

```bash
curl -O http://127.0.0.1:1080/messages/1/parts/image-001
```

### Get SMTP Transcript (JSON)

```
GET /messages/:id/transcript.json
```

Returns the SMTP transcript for the message as JSON, including all SMTP commands, responses, and TLS details.

**Example:**

```bash
curl http://127.0.0.1:1080/messages/1/transcript.json
```

**Response:**

```json
{
  "id": 1,
  "session_id": "abc123def456",
  "client_ip": "192.168.1.100",
  "client_port": 54321,
  "server_ip": "127.0.0.1",
  "server_port": 1025,
  "tls_enabled": true,
  "tls_protocol": "TLSv1.2",
  "tls_cipher": "ECDHE-RSA-AES256-GCM-SHA384",
  "connection_started_at": "2024-01-10T10:30:00Z",
  "connection_ended_at": "2024-01-10T10:30:05Z",
  "entries": [
    {
      "type": "client",
      "command": "EHLO client.example.com",
      "timestamp": "2024-01-10T10:30:00Z"
    },
    {
      "type": "server",
      "response": "250-localhost Hello client.example.com",
      "timestamp": "2024-01-10T10:30:00Z"
    }
  ],
  "created_at": "2024-01-10T10:30:05Z"
}
```

### Get SMTP Transcript (HTML)

```
GET /messages/:id.transcript
```

Returns the SMTP transcript for the message rendered as an HTML page, useful for viewing in a browser.

**Example:**

```bash
curl http://127.0.0.1:1080/messages/1.transcript
```

### Delete Message

```
DELETE /messages/:id
```

Deletes a specific message from storage.

**Example:**

```bash
curl -X DELETE http://127.0.0.1:1080/messages/1
```

### Delete All Messages

```
DELETE /messages
```

Clears all stored messages.

**Example:**

```bash
curl -X DELETE http://127.0.0.1:1080/messages
```

## System Endpoints

### WebSocket Connection for Real-Time Updates

```
GET /messages (with WebSocket upgrade)
```

Upgrades the HTTP connection to WebSocket for receiving real-time notifications about new messages, deletions, and clears.

**Example:**

```javascript
const ws = new WebSocket('ws://127.0.0.1:1080/messages');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);

  if (data.type === 'add') {
    console.log('New message received:', data.message);
  } else if (data.type === 'remove') {
    console.log('Message deleted:', data.id);
  } else if (data.type === 'clear') {
    console.log('All messages cleared');
  }
};

ws.onerror = (error) => {
  console.error('WebSocket error:', error);
};
```

**Message Types:**

- `add` - New message arrived (includes full message object)
- `remove` - Message was deleted (includes message id)
- `clear` - All messages were cleared

### Server Information

```
GET /server-info
```

Returns server configuration and status information.

**Example:**

```bash
curl http://127.0.0.1:1080/server-info
```

**Response includes:**

- MailCatcher version
- HTTP server port
- SMTP server port
- Hostname and IP addresses
- Connection counts
- Other configuration details

### WebSocket Test Interface

```
GET /websocket-test
```

Serves a web page for testing WebSocket connectivity and real-time message updates.

**Example:**

```bash
curl http://127.0.0.1:1080/websocket-test
```

### Quit/Shutdown Server

```
DELETE /
```

Terminates the MailCatcher server instance.

**Example:**

```bash
curl -X DELETE http://127.0.0.1:1080/
```

**Response:**
- `204 No Content` - Server is shutting down
- `403 Forbidden` - Server is not configured to allow remote shutdown

## Advanced Endpoints

### Search / Filter Messages

```
GET /messages/search?q=query&has_attachments=true&from=2024-01-01&to=2024-01-31
```

Searches messages across subject, sender, recipient, and body content with optional filtering.

**Parameters:**
- `q` - Search query string (searches subject, sender, recipients, and body)
- `has_attachments` - Filter by attachment presence (`true` or `false`)
- `from` - Start date for filtering (ISO 8601 format, e.g., `2024-01-01`)
- `to` - End date for filtering (ISO 8601 format, e.g., `2024-12-31`)

**Example:**

```bash
curl "http://127.0.0.1:1080/messages/search?q=verification&has_attachments=false"
```

**Response:**

```json
[
  {
    "id": 1,
    "sender": "noreply@example.com",
    "recipients": ["user@example.com"],
    "subject": "Email Verification Required",
    "size": "1234",
    "created_at": "2024-01-10T10:30:00Z"
  }
]
```

### Extract Verification Tokens / Codes / Links

```
GET /messages/:id/extract?type=token|link|otp
```

Extracts verification tokens, magic links, OTP codes, or reset tokens from message content.

**Parameters:**
- `type` - Type of token to extract: `link` (magic links), `otp` (6-digit codes), or `token` (reset tokens)

**Example:**

```bash
curl "http://127.0.0.1:1080/messages/1/extract?type=otp"
```

**Response:**

```json
[
  {
    "type": "otp",
    "value": "123456",
    "context": "Your verification code is: 123456. This code will expire in 10 minutes."
  }
]
```

### Extract All Links with Context

```
GET /messages/:id/links.json
```

Returns all links found in the message with metadata about their purpose.

**Example:**

```bash
curl http://127.0.0.1:1080/messages/1/links.json
```

**Response:**

```json
[
  {
    "href": "https://example.com/verify?token=abc123xyz",
    "text": "Verify Your Email",
    "is_verification": true,
    "is_unsubscribe": false
  },
  {
    "href": "https://example.com/unsubscribe",
    "text": "Unsubscribe",
    "is_verification": false,
    "is_unsubscribe": true
  }
]
```

### Parse & Return Structured Data

```
GET /messages/:id/parsed.json
```

Returns comprehensive structured data parsed from the message, including verification URLs, OTP codes, reset tokens, unsubscribe links, and all message links.

**Example:**

```bash
curl http://127.0.0.1:1080/messages/1/parsed.json
```

**Response:**

```json
{
  "verification_url": "https://example.com/verify?token=abc123",
  "otp_code": "123456",
  "reset_token": "https://example.com/reset?token=xyz789",
  "unsubscribe_link": "https://example.com/unsubscribe",
  "all_links": [
    {
      "href": "https://example.com/verify?token=abc123",
      "text": "Verify Your Email",
      "is_verification": true,
      "is_unsubscribe": false
    }
  ]
}
```

### Check Render / Accessibility Score

```
GET /messages/:id/accessibility.json
```

Analyzes the HTML email for accessibility issues and returns a score (0-100) with recommendations.

**Example:**

```bash
curl http://127.0.0.1:1080/messages/1/accessibility.json
```

**Response:**

```json
{
  "score": 85,
  "breakdown": {
    "images_with_alt": 100,
    "semantic_html": 50
  },
  "recommendations": [
    "Use semantic HTML tags (header, main, article, section)"
  ]
}
```

**Score Breakdown:**
- `images_with_alt` - Percentage of images with alt text (0-100)
- `semantic_html` - Whether semantic HTML tags are used (50 = no, 100 = yes)
- `score` - Overall accessibility score (average of all metrics)

### Forward Message (SMTP)

```
POST /messages/:id/forward
```

Forwards the caught email message to its original recipient(s) using a configured SMTP server. Useful for final validation after testing.

**Configuration Required:**

Start MailCatcher with SMTP forwarding configuration:

```bash
mailcatcher \
  --forward-smtp-host smtp.example.com \
  --forward-smtp-port 587 \
  --forward-smtp-user your-username@example.com \
  --forward-smtp-password your-password
```

**Example:**

```bash
curl -X POST http://127.0.0.1:1080/messages/1/forward
```

**Response (Success):**

```json
{
  "success": true,
  "forwarded_to": ["user@example.com"],
  "forwarded_at": "2024-01-10T10:30:00Z"
}
```

**Response (Error - SMTP not configured):**

```json
{
  "error": "SMTP not configured"
}
```

## Usage Examples

### Check for New Messages

```bash
#!/bin/bash

MAILCATCHER_URL="http://127.0.0.1:1080"

# Get all messages
messages=$(curl -s $MAILCATCHER_URL/messages)

# Check message count
count=$(echo $messages | jq '. | length')
echo "Total messages: $count"

# Extract first message details
echo $messages | jq '.[0]'
```

### Extract Email Content

```bash
# Get HTML content
curl -s http://127.0.0.1:1080/messages/1.html > email.html

# Get plain text
curl -s http://127.0.0.1:1080/messages/1.plain > email.txt

# Get raw source
curl -s http://127.0.0.1:1080/messages/1.source > email.eml
```

### Download Attachments

```bash
# List message parts (in JSON metadata)
curl -s http://127.0.0.1:1080/messages/1.json | jq '.parts'

# Download specific attachment by CID
curl -O http://127.0.0.1:1080/messages/1/parts/attachment-id
```

### Inspect SMTP Transcript

```bash
# Get SMTP transcript as JSON
curl -s http://127.0.0.1:1080/messages/1/transcript.json | jq '.'

# Extract TLS information
curl -s http://127.0.0.1:1080/messages/1/transcript.json | jq '.tls_protocol, .tls_cipher'

# View in browser
open http://127.0.0.1:1080/messages/1.transcript
```

### Automated Testing

Use the API in your test suite to verify email delivery:

```bash
#!/bin/bash

# Wait for message
max_attempts=10
attempt=0

while [ $attempt -lt $max_attempts ]; do
  messages=$(curl -s http://127.0.0.1:1080/messages)
  count=$(echo $messages | jq '. | length')

  if [ $count -gt 0 ]; then
    echo "Email received!"
    exit 0
  fi

  sleep 1
  ((attempt++))
done

echo "Email not received"
exit 1
```

## Real-Time Message Monitoring

Monitor incoming messages in real-time using WebSocket:

```bash
#!/bin/bash

# Simple WebSocket client using websocat (install with: brew install websocat)
websocat ws://127.0.0.1:1080/messages | while read line; do
  echo "Update: $line" | jq '.'
done
```

Or using Python:

```python
import websocket
import json

def on_message(ws, message):
    data = json.loads(message)
    print(f"Received: {data['type']}")
    if data['type'] == 'add':
        print(f"New message: {data['message']['subject']}")

def on_error(ws, error):
    print(f"Error: {error}")

def on_close(ws, close_status_code, close_msg):
    print("Connection closed")

ws = websocket.WebSocketApp("ws://127.0.0.1:1080/messages",
                            on_message=on_message,
                            on_error=on_error,
                            on_close=on_close)
ws.run_forever()
```

## Notes

- All timestamps are in ISO 8601 format
- Message IDs are sequential integers
- Content-IDs for attachments are extracted from message headers
- API responses use standard HTTP status codes
- No authentication is required (suitable for local development only)
- WebSocket connections persist until closed by client or server
- Real-time updates are broadcast to all connected WebSocket clients

## Complete API Reference

| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| GET | `/` | Web UI |
| GET | `/server-info` | Server info and configuration |
| GET | `/websocket-test` | WebSocket test interface |
| DELETE | `/` | Shutdown server |
| GET | `/messages` | List messages or WebSocket upgrade |
| GET | `/messages/search` | Search messages by query and filters |
| DELETE | `/messages` | Clear all messages |
| GET | `/messages/:id.json` | Message metadata (JSON) |
| GET | `/messages/:id.html` | Message body (HTML format) |
| GET | `/messages/:id.plain` | Message body (plain text format) |
| GET | `/messages/:id.source` | Raw MIME source |
| GET | `/messages/:id.eml` | Download as EML file |
| GET | `/messages/:id/transcript.json` | SMTP transcript (JSON) |
| GET | `/messages/:id.transcript` | SMTP transcript (HTML) |
| GET | `/messages/:id/parts/:cid` | Message part/attachment by Content-ID |
| GET | `/messages/:id/extract` | Extract tokens, OTPs, or magic links |
| GET | `/messages/:id/links.json` | Extract all links with context |
| GET | `/messages/:id/parsed.json` | Parse structured data from message |
| GET | `/messages/:id/accessibility.json` | Check accessibility score |
| POST | `/messages/:id/forward` | Forward message to recipients via SMTP |
| DELETE | `/messages/:id` | Delete specific message |
