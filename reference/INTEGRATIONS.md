# Framework & Application Integration

Configure your favorite framework or application to send mail through MailCatcher.

## Rails

Add this to your `config/environments/development.rb`:

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: '127.0.0.1',
  port: 1025
}
config.action_mailer.raise_delivery_errors = false
```

With STARTTLS enabled:

```ruby
config.action_mailer.smtp_settings = {
  address: '127.0.0.1',
  port: 1025,
  enable_starttls_auto: true
}
```

With direct TLS (SMTPS):

```ruby
config.action_mailer.smtp_settings = {
  address: '127.0.0.1',
  port: 1465,
  enable_starttls_auto: false,
  ssl: true
}
```

## Django

Add the following configuration to your `settings.py`:

```python
if DEBUG:
    EMAIL_HOST = '127.0.0.1'
    EMAIL_HOST_USER = ''
    EMAIL_HOST_PASSWORD = ''
    EMAIL_PORT = 1025
    EMAIL_USE_TLS = False
```

With direct TLS (SMTPS):

```python
if DEBUG:
    EMAIL_HOST = '127.0.0.1'
    EMAIL_PORT = 1465  # Direct TLS
    EMAIL_USE_TLS = True
    EMAIL_USE_SSL = True
```

## PHP

Use the `catchmail` command to send mail via MailCatcher. Set [PHP's mail configuration](https://www.php.net/manual/en/mail.configuration.php) in your [php.ini](https://www.php.net/manual/en/configuration.file.php):

```ini
sendmail_path = /usr/bin/env catchmail -f some@from.address
```

Or in your [Apache configuration](https://www.php.net/manual/en/configuration.changes.php):

```
php_admin_value sendmail_path "/usr/bin/env catchmail -f some@from.address"
```

### Custom SMTP Server

If you've started MailCatcher on alternative SMTP IP and/or port with parameters like `--smtp-ip 192.168.0.1 --smtp-port 10025`, add the same parameters to your `catchmail` command:

```ini
sendmail_path = /usr/bin/env catchmail --smtp-ip 192.168.0.1 --smtp-port 10025 -f some@from.address
```

### RVM Compatibility

If installed via RVM, `catchmail` may not be available in your system PATH. Run `which catchmail` to get the full path:

```ini
sendmail_path = /path/to/rvm/rubies/ruby-X.X.X/bin/catchmail -f some@from.address
```

### Popular Platforms

- **Drupal**: Set the mail system to use `catchmail` via appropriate modules
- **WordPress**: Use a mail plugin configured to use the local sendmail path
- **Other PHP applications**: Refer to the application's mail configuration documentation

## Docker

The official MailCatcher Docker image is available on [Docker Hub](https://hub.docker.com/r/stpaquet/alpinemailcatcher):

### Basic Setup

```bash
docker run -d -p 1080:1080 -p 1025:1025 stpaquet/alpinemailcatcher
```

### Docker Compose

```yaml
version: '3.8'

services:
  mailcatcher:
    image: stpaquet/alpinemailcatcher:latest
    ports:
      - "1080:1080"
      - "1025:1025"
    environment:
      MAILCATCHER_ENV: development

  app:
    image: your-app:latest
    depends_on:
      - mailcatcher
    environment:
      SMTP_HOST: mailcatcher
      SMTP_PORT: 1025
```

### Configuration

Configure your application container to connect to the mailcatcher service:

- **Host**: `mailcatcher` (when using Docker Compose)
- **SMTP Port**: `1025`
- **HTTP Port**: `1080`

### Image Details

- Alpine Linux based for minimal size and quick startup
- Pre-configured with all dependencies
- Ready to use with any mail-sending application
