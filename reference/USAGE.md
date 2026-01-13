# Usage

## Running MailCatcher NG

### Basic Usage

```bash
mailcatcher
```

Then visit [http://127.0.0.1:1080](http://127.0.0.1:1080) and send mail to `smtp://127.0.0.1:1025`.

### Command Line Options

Use `mailcatcher --help` to see all available options:

```
Usage: mailcatcher [options]

 MailCatcher NG v1.5.0

        --ip IP                        Set the ip address of both servers
        --smtp-ip IP                   Set the ip address of the smtp server
        --smtp-port PORT               Set the port of the smtp server
        --smtp-ssl                     Enable SSL/TLS support for SMTP
        --smtp-ssl-cert PATH           Path to SSL certificate file
        --smtp-ssl-key PATH            Path to SSL private key file
        --smtp-ssl-verify-peer         Verify client SSL certificates
        --smtps-port PORT              Set the port for direct TLS (default: 1465)
        --http-ip IP                   Set the ip address of the http server
        --http-port PORT               Set the port address of the http server
        --messages-limit COUNT         Only keep up to COUNT most recent messages
        --persistence                  Store messages in a persistent SQLite database file
        --http-path PATH               Add a prefix to all HTTP paths
        --forward-smtp-host HOST       SMTP server for forwarding messages
        --forward-smtp-port PORT       SMTP port for forwarding messages
        --forward-smtp-user USER       SMTP username for forwarding messages
        --forward-smtp-password PASS   SMTP password for forwarding messages
        --[no-]forward-smtp-tls        Enable/disable TLS for forwarding SMTP (default: enabled)
        --no-quit                      Don't allow quitting the process
    -f, --foreground                   Run in the foreground
    -b, --browse                       Open web browser
    -v, --verbose                      Be more verbose
    -h, --help                         Display this help information
        --version                      Display the current version
```

## Message Forwarding

Forward caught email messages to real SMTP servers for validation before production deployment:

```bash
mailcatcher \
  --forward-smtp-host smtp.example.com \
  --forward-smtp-port 587 \
  --forward-smtp-user your-username@example.com \
  --forward-smtp-password your-password
```

Then use the `/messages/:id/forward` API endpoint to forward specific messages. See [API documentation](./API.md) for details.

## Development Mode

Run MailCatcher NG in development mode with custom ports:

```bash
MAILCATCHER_ENV=development bundle exec mailcatcher --foreground --smtp-port 1025 --http-port 1080
```

Then access the web interface at [http://127.0.0.1:1080](http://127.0.0.1:1080) and send mail to `smtp://127.0.0.1:1025`.

### Sending Example Emails

Use the provided test script to send example emails:

```bash
SMTP_HOST=127.0.0.1 SMTP_PORT=20025 ruby send_example_emails.rb
```

## Web Interface

### Features

- View HTML, plain text, and source versions of messages
- Download original email to view in your native mail client
- List attachments and download individual parts
- HTML rewriting for embedded images and safe link opening

### Real-time Updates

Mail appears instantly if your browser supports [WebSockets](https://tools.ietf.org/html/rfc6455) with automatic reconnection and exponential backoff. Otherwise, updates refresh every thirty seconds.

### WebSocket Testing

To monitor WebSocket connectivity and test the connection status, visit [http://127.0.0.1:1080/websocket-test](http://127.0.0.1:1080/websocket-test). This page provides real-time feedback on WebSocket connection state and helps verify that automatic reconnection with exponential backoff is functioning correctly.

### Keyboard Navigation

Use keyboard shortcuts to navigate between messages in the web interface.

## Background Operation

MailCatcher NG runs as a daemon in the background by default. To run in the foreground instead:

```bash
mailcatcher --foreground
```

### Browser Integration

Open your default web browser automatically on startup:

```bash
mailcatcher --browse
```

## Limiting Messages

To prevent excessive memory usage, limit the number of messages stored:

```bash
mailcatcher --messages-limit 100
```

Only the 100 most recent messages will be kept.

## Persistent Storage

By default, MailCatcher NG stores messages in memory and they are lost when the process terminates. To keep messages across restarts, enable persistent storage:

```bash
mailcatcher --persistence
```

Messages will be stored in a SQLite database file at `~/.mailcatcher/mailcatcher.db`. The directory is automatically created if it doesn't exist.

You can combine persistence with other options:

```bash
mailcatcher --persistence --messages-limit 500
```

## Custom HTTP Path

Add a prefix to all HTTP paths (useful when running behind a reverse proxy):

```bash
mailcatcher --http-path /mailcatcher
```

Access the web interface at `http://127.0.0.1:1080/mailcatcher/`
