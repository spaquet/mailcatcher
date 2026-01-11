# Usage

## Running MailCatcher

### Basic Usage

```bash
mailcatcher
```

Then visit [http://127.0.0.1:1080](http://127.0.0.1:1080) and send mail to `smtp://127.0.0.1:1025`.

### Command Line Options

Use `mailcatcher --help` to see all available options:

```
Usage: mailcatcher [options]

MailCatcher v0.11.2

        --ip IP                      Set the ip address of both servers
        --smtp-ip IP                 Set the ip address of the smtp server
        --smtp-port PORT             Set the port of the smtp server
        --smtp-ssl                   Enable SSL/TLS support for SMTP
        --smtp-ssl-cert PATH         Path to SSL certificate file
        --smtp-ssl-key PATH          Path to SSL private key file
        --smtp-ssl-verify-peer       Verify client SSL certificates
        --smtps-port PORT            Set the port for direct TLS (default: 1465)
        --http-ip IP                 Set the ip address of the http server
        --http-port PORT             Set the port address of the http server
        --messages-limit COUNT       Only keep up to COUNT most recent messages
        --http-path PATH             Add a prefix to all HTTP paths
        --no-quit                    Don't allow quitting the process
    -f, --foreground                 Run in the foreground
    -b, --browse                     Open web browser
    -v, --verbose                    Be more verbose
    -h, --help                       Display this help information
        --version                    Display the current version
```

## Development Mode

Run MailCatcher in development mode with custom ports:

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

MailCatcher runs as a daemon in the background by default. To run in the foreground instead:

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

## Custom HTTP Path

Add a prefix to all HTTP paths (useful when running behind a reverse proxy):

```bash
mailcatcher --http-path /mailcatcher
```

Access the web interface at `http://127.0.0.1:1080/mailcatcher/`
