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

### Download Message Part/Attachment

```
GET /messages/:id/parts/:cid
```

Downloads a specific message part or attachment by its Content-ID (CID).

**Example:**

```bash
curl -O http://127.0.0.1:1080/messages/1/parts/image-001
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

## Notes

- All timestamps are in ISO 8601 format
- Message IDs are sequential integers
- Content-IDs for attachments are extracted from message headers
- API responses use standard HTTP status codes
- No authentication is required (suitable for local development only)
