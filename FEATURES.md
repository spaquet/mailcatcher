# MailCatcher NG Features

## Table of Contents

1. [Core Email Capture and Storage](#core-email-capture-and-storage)
2. [Message Display and Rendering](#message-display-and-rendering)
3. [Email Authentication and Verification](#email-authentication-and-verification)
4. [Email Encryption and Signature Support](#email-encryption-and-signature-support)
5. [BIMI (Brand Indicators for Message Identification)](#bimi-brand-indicators-for-message-identification)
6. [Email Preview Text Extraction](#email-preview-text-extraction)
7. [From/To Header Parsing](#fromto-header-parsing)
8. [Message List Features](#message-list-features)
9. [Message Filtering and Search](#message-filtering-and-search)
10. [Attachment Handling](#attachment-handling)
11. [Keyboard Navigation](#keyboard-navigation)
12. [WebSocket Real-Time Updates](#websocket-real-time-updates)
13. [UI/UX Features](#uiux-features)
14. [Message Metadata Display](#message-metadata-display)
15. [Message Download Options](#message-download-options)
16. [Message Management](#message-management)
17. [Persistent Storage](#persistent-storage)
18. [Server Control and Information](#server-control-and-information)
19. [Command-Line Configuration](#command-line-configuration)
20. [API Endpoints](#api-endpoints)
21. [Technical Infrastructure](#technical-infrastructure)
22. [Browser Compatibility and Features](#browser-compatibility-and-features)
23. [Email Parsing and Processing](#email-parsing-and-processing)

---

## Core Email Capture and Storage

- **SMTP Server**: Captures all mail sent to smtp://127.0.0.1:1025
- **Flexible Storage**: SQLite database with two modes:
  - **In-Memory (default)**: Fast, ephemeral storage lost on process termination
  - **Persistent (--persistence flag)**: File-based storage at ~/.mailcatcher/mailcatcher.db for retention across restarts
- **Message Parts Storage**: Stores individual MIME parts (HTML, plain text, attachments) separately with metadata
- **Message Cleanup**: Configurable message retention limit via `--messages-limit` parameter

## Message Display and Rendering

- **HTML View**: Renders HTML email content with embedded attachments and links opened in new tabs
- **Plain Text View**: Displays plain text emails with proper formatting (monospace font, pre-wrap, word-wrap)
- **Source View**: Shows raw SMTP source with syntax highlighting using Highlight.js
- **Multiple Formats**: System dynamically displays only available formats (HTML, Plain Text, Source) for each message

## Email Authentication and Verification

- **DMARC Verification**: Parses and displays DMARC authentication results (pass/fail/neutral)
- **DKIM Signature Verification**: Shows DKIM authentication status
- **SPF Verification**: Displays SPF authentication results
- **Authentication Tooltip**: Signature info button shows all auth results in an interactive tooltip with color-coded status badges
- **Multi-line Header Parsing**: Properly handles multi-line Authentication-Results headers

## Email Encryption and Signature Support

MailCatcher NG displays encryption and signature information from email headers, allowing testing and verification of email security metadata:

- **S/MIME Support**:
  - X-Certificate header: Displays S/MIME certificate information
  - X-SMIME-Signature header: Shows S/MIME signature data
  - Allows copying of certificate data for external validation

- **OpenPGP Support**:
  - X-PGP-Key header: Displays PGP public key information
  - X-PGP-Signature header: Shows PGP signature data
  - Allows copying of key data for external verification

- **Encryption Info Tooltip**: Interactive button to view detailed encryption/signature information with copy-to-clipboard functionality
- **Certificate Display**: Shows truncated certificate/key values with ability to copy full values for testing

**Note**: MailCatcher NG is a display-only tool. It extracts and displays encryption/signature headers and certificate data from emails but does not perform actual decryption or cryptographic verification. Users can copy the certificate and key data to test with external encryption tools.

## BIMI (Brand Indicators for Message Identification)

- **BIMI Display**: Shows brand logos from BIMI-Location header in message list table
- **Placeholder Icon**: Generic brand icon appears when no BIMI data available
- **BIMI Cell Column**: Dedicated column in message table for BIMI brand indicators
- **Dynamic BIMI Loading**: Updates BIMI display when full message data loads via AJAX

## Email Preview Text Extraction

3-Tier fallback system for intelligent preview text extraction:

- **Tier 1 (Preview-Text Header)**: Uses de facto standard Preview-Text header if present
- **Tier 2 (HTML Preheader)**: Extracts hidden HTML preheader text from email body
- **Tier 3 (Content Fallback)**: Falls back to first 100 characters of email content
- **Preview Display**: Shows preview text below subject in message list

## From/To Header Parsing

- **From Header Extraction**: Parses From header with multi-line support
- **To Header Extraction**: Parses To header with multi-line support
- **Email Address Parsing**: Extracts name and email portions from formatted headers
- **Two-Tier Display**: Shows sender/recipient name in bold with email address below in message list
- **Header Fallback**: Falls back to envelope sender/recipients if email headers unavailable

## Message List Features

- **Real-Time Table Display**: Shows From, To, Subject, Received, Size, Attachments, and BIMI columns
- **Message Selection**: Click rows to select and view full message details
- **Attachment Indicator**: Shows indicator for messages with attachments
- **Date/Time Formatting**: Displays formatted dates with day, date, time
- **Size Formatting**: Shows human-readable file sizes (B, KB, MB, GB)

## Message Filtering and Search

- **Full-Text Search**: Search messages by any field with case-insensitive matching
- **Multi-Token Search**: Search for multiple terms that must all match
- **Attachment Filtering**: Filter by "All", "With attachments", "Without attachments"
- **Filter Combination**: Search and attachment filters work together
- **Dynamic Filtering**: Fetches attachment data on-demand when filtering

## Attachment Handling

- **Attachment Display**: Lists all attachments with filename, MIME type, and size
- **Attachment Download**: Individual download links for each attachment
- **Embedded Images**: Rewrites image Content-IDs to serve embedded images properly
- **Attachment Column**: Shows attachment indicators in message list table
- **Content-ID Mapping**: Maps Content-ID references for embedded content

## Keyboard Navigation

- **Arrow Keys**: Up/Down for message list navigation, Left/Right for format tabs
- **Ctrl+Ctrl+Up/Down**: Jump to first/last message in list
- **Delete/Backspace**: Delete selected message
- **Tab Navigation**: Works with message format tabs (HTML, Plain Text, Source)

## WebSocket Real-Time Updates

- **WebSocket Connection**: Real-time message updates via WebSocket protocol
- **Automatic Reconnection**: Exponential backoff reconnection strategy (10 attempts)
- **Fallback Polling**: Falls back to 30-second polling if WebSocket unavailable
- **Connection Status**: Visual indicator shows connected/disconnected state
- **Live Event Types**: Supports add, remove, clear, and quit event types

## UI/UX Features

- **Responsive Layout**: Flexbox-based responsive design
- **Resizable Divider**: Draggable separator between message list and detail panes
- **Persistent Layout**: Saves resizer position in localStorage
- **Email Counter**: Displays count of messages received in header and favicon
- **Status Badge**: Connected/Disconnected status indicator with visual styling

## Message Metadata Display

- **Received Time**: Full timestamp when message was received
- **From Address**: Sender with name parsing
- **To Address**: Recipients list (supports multiple recipients)
- **Subject Line**: Email subject with fallback for no-subject messages
- **Message Size**: Total message size in human-readable format

## Message Download Options

- **EML Download**: Download full message as .eml file for native mail client viewing
- **Source Download**: Access raw message source
- **Format Selection**: Download specific format (HTML, Plain Text, Source)

## Message Management

- **Delete Single Message**: Remove individual messages with keyboard shortcut or API
- **Clear All Messages**: Bulk delete with confirmation dialog
- **Message Limit**: Automatic cleanup of oldest messages when limit exceeded
- **Event Broadcasting**: Message changes broadcast to all connected clients via event bus

## Persistent Storage

- **Optional Persistence**: Enable with `--persistence` flag to store messages across process restarts
- **File-Based Storage**: Messages stored in SQLite database file at `~/.mailcatcher/mailcatcher.db`
- **In-Memory Default**: By default, messages are stored in memory (no persistence)
- **Automatic Directory Creation**: `~/.mailcatcher` directory is automatically created when needed
- **Docker Volume Support**: Compatible with Docker volumes and bind mounts for containerized deployments
- **Combined with Limits**: Works with `--messages-limit` for retention management

## Server Control and Information

- **Server Info Page**: Displays MailCatcher NG version, SMTP/HTTP configuration, hostname, FQDN
- **Quit Button**: Gracefully stop MailCatcher NG server (if --no-quit not set)
- **Clear Button**: Delete all messages (confirmation required)
- **WebSocket Test Page**: Testing utility for WebSocket connection diagnostics

## Command-Line Configuration

- **IP Configuration**: `--ip`, `--smtp-ip`, `--http-ip` for network binding
- **Port Configuration**: `--smtp-port`, `--http-port` for custom ports
- **SSL/TLS Configuration**:
  - `--smtp-ssl` - Enable SSL/TLS support
  - `--smtp-ssl-cert PATH` - Path to SSL certificate file
  - `--smtp-ssl-key PATH` - Path to SSL private key file
  - `--smtp-ssl-verify-peer` - Enable client certificate verification
  - `--smtps-port PORT` - Port for direct TLS (default: 1465)
- **Persistence**: `--persistence` to store messages in a persistent SQLite database file
- **HTTP Path Prefix**: `--http-path` for running behind proxies
- **Daemon Mode**: `-f/--foreground`, automatic daemonization on Unix
- **Browser Launch**: `-b/--browse` to automatically open web browser
- **Message Limit**: `--messages-limit` for retention management
- **No-Quit Mode**: `--no-quit` to prevent server shutdown
- **Verbose Logging**: `-v/--verbose` for debug output

## SSL/TLS Security

- **STARTTLS Support**: Opportunistic TLS upgrade on standard SMTP port (1025)
- **Direct TLS (SMTPS)**: TLS-wrapped connections from start (port 1465)
- **Required STARTTLS Mode**: When SSL enabled, STARTTLS must be used before MAIL FROM
- **Certificate Management**: User-provided certificates and private keys
- **Certificate Validation**: Validates certificate and key format on startup
- **Optional Client Verification**: Support for mutual TLS authentication
- **Dual Server Mode**: Both STARTTLS and direct TLS run concurrently
- **EventMachine TLS**: Uses EventMachine's built-in TLS support

## API Endpoints

- `GET /messages` - List all messages (WebSocket or JSON)
- `GET /messages/:id.json` - Message metadata with auth/BIMI/encryption data
- `GET /messages/:id.html` - HTML content
- `GET /messages/:id.plain` - Plain text content
- `GET /messages/:id.source` - Raw SMTP source
- `GET /messages/:id.eml` - Full message as EML file
- `GET /messages/:id/parts/:cid` - Individual attachment/part
- `DELETE /messages` - Clear all messages
- `DELETE /messages/:id` - Delete single message
- `DELETE /` - Quit server

## Technical Infrastructure

- **EventMachine**: Async I/O framework for SMTP and HTTP servers
- **Sinatra**: Lightweight web framework for HTTP API
- **Faye WebSocket**: WebSocket implementation with automatic adapter management
- **SQLite**: In-memory database for message storage
- **Thin Web Server**: HTTP server integration with EventMachine
- **jQuery**: JavaScript framework for DOM manipulation
- **Sprockets**: Asset pipeline for development mode
- **Tippy.js**: Tooltip library for signature/encryption info display

## Browser Compatibility and Features

- **Favicon Badge**: Updates favicon with message count
- **Title Updates**: Updates page title with current message count
- **JavaScript Required**: Shows noscript message if JS disabled
- **localStorage**: Persists UI state (resizer position)
- **Clipboard API**: Copy encryption/signature data to clipboard

## Email Parsing and Processing

- **MIME Parsing**: Uses Ruby Mail gem for comprehensive MIME handling
- **Multipart Messages**: Correctly handles complex multipart email structures
- **Charset Detection**: Preserves character encoding information per part
- **Attachment Detection**: Identifies and separates attachments from inline content
- **Header Preservation**: Maintains original email headers for parsing and display
