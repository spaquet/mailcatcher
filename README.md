# MailCatcher NG (Next Generation)

[![Gem Version](https://img.shields.io/gem/v/mailcatcher-ng)](https://rubygems.org/gems/mailcatcher-ng)
[![CI](https://github.com/spaquet/mailcatcher/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/spaquet/mailcatcher/actions/workflows/ci.yml)
[![GitHub License](https://img.shields.io/github/license/spaquet/mailcatcher)](LICENSE)

Catches mail and serves it through a dream.

MailCatcher NG runs a super simple SMTP server which catches any message sent to it to display in a web interface. Run mailcatcher, set your favourite app to deliver to smtp://127.0.0.1:1025 instead of your default SMTP server, then check out http://127.0.0.1:1080 to see the mail that's arrived so far.

![MailCatcher screenshot](screenshots/inbox.webp)


## Features

* Catches all mail and stores it for display.
* Shows HTML, Plain Text and Source version of messages, as applicable.
* Rewrites HTML enabling display of embedded, inline images/etc and opens links in a new window.
* Lists attachments and allows separate downloading of parts.
* Download original email to view in your native mail client(s).
* Command line options to override the default SMTP/HTTP IP and port settings.
* Mail appears instantly if your browser supports [WebSockets][websockets] with automatic reconnection and exponential backoff, otherwise updates every thirty seconds.
* Runs as a daemon in the background, optionally in foreground.
* Sendmail-analogue command, `catchmail`, makes using mailcatcher from PHP a lot easier.
* Keyboard navigation between messages
* Email authentication verification (DMARC, DKIM, SPF)
* Email encryption and signature support (S/MIME and OpenPGP)
* BIMI (Brand Indicators for Message Identification) display
* Advanced preview text extraction with intelligent fallback

For a comprehensive list of all features, see [FEATURES.md](FEATURES.md).

## How

1. `gem install mailcatcher-ng`
2. `mailcatcher`
3. Go to http://127.0.0.1:1080/
4. Send mail through smtp://127.0.0.1:1025

### Development Mode

To run MailCatcher in development mode with custom ports:

```bash
MAILCATCHER_ENV=development bundle exec mailcatcher --foreground --smtp-port 1025 --http-port 1080
```

Then access the web interface at [http://127.0.0.1:1080](http://127.0.0.1:1080) and send mail to `smtp://127.0.0.1:1025`.

Or use the provided test script to send example emails:

```bash
SMTP_HOST=127.0.0.1 SMTP_PORT=20025 ruby send_example_emails.rb
```

### WebSocket Testing

To monitor WebSocket connectivity and test the connection status, visit [http://127.0.0.1:1080/websocket-test](http://127.0.0.1:1080/websocket-test). This page provides real-time feedback on WebSocket connection state and helps verify that automatic reconnection with exponential backoff is functioning correctly.

### Command Line Options

Use `mailcatcher --help` to see the command line options.

```
Usage: mailcatcher [options]

MailCatcher v0.11.2

        --ip IP                      Set the ip address of both servers
        --smtp-ip IP                 Set the ip address of the smtp server
        --smtp-port PORT             Set the port of the smtp server
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

### Upgrading

Upgrading works the same as installation:

```
gem install mailcatcher
```

### Ruby

If you have trouble with the setup commands, make sure you have [Ruby installed](https://www.ruby-lang.org/en/documentation/installation/):

```
ruby -v
gem environment
```

You might need to install build tools for some of the gem dependencies. On Debian or Ubuntu, `apt install build-essential`. On macOS, `xcode-select --install`.

### How to Compile the Gem

To compile MailCatcher as a gem from source:

1. Clone the repository:

```bash
git clone https://github.com/spaquet/mailcatcher.git
cd mailcatcher
```

1. Install dependencies:

```bash
bundle install
```

1. Compile assets and build the gem:

```bash
bundle exec rake package
```

This will create a `.gem` file in the project directory. The build process:

* Compiles JavaScript assets using Sprockets and Uglifier
* Creates a gem package with all required files

You can then install the compiled gem locally:

```bash
gem install mailcatcher-VERSION.gem
```

### Bundler

Please don't put mailcatcher into your Gemfile. It will conflict with your application's gems at some point.

Instead, pop a note in your README stating you use mailcatcher, and to run `gem install mailcatcher` then `mailcatcher` to get started.

### RVM

Under RVM your mailcatcher command may only be available under the ruby you install mailcatcher into. To prevent this, and to prevent gem conflicts, install mailcatcher into a dedicated gemset with a wrapper script:

    rvm default@mailcatcher --create do gem install mailcatcher
    ln -s "$(rvm default@mailcatcher do rvm wrapper show mailcatcher)" "$rvm_bin_path/"

### Rails

To set up your rails app, I recommend adding this to your `environments/development.rb`:

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = { :address => '127.0.0.1', :port => 1025 }
    config.action_mailer.raise_delivery_errors = false

### PHP

For projects using PHP, or PHP frameworks and application platforms like Drupal, you can set [PHP's mail configuration](https://www.php.net/manual/en/mail.configuration.php) in your [php.ini](https://www.php.net/manual/en/configuration.file.php) to send via MailCatcher with:

    sendmail_path = /usr/bin/env catchmail -f some@from.address

You can do this in your [Apache configuration](https://www.php.net/manual/en/configuration.changes.php) like so:

    php_admin_value sendmail_path "/usr/bin/env catchmail -f some@from.address"

If you've installed via RVM this probably won't work unless you've manually added your RVM bin paths to your system environment's PATH. In that case, run `which catchmail` and put that path into the `sendmail_path` directive above instead of `/usr/bin/env catchmail`.

If starting `mailcatcher` on alternative SMTP IP and/or port with parameters like `--smtp-ip 192.168.0.1 --smtp-port 10025`, add the same parameters to your `catchmail` command:

    sendmail_path = /usr/bin/env catchmail --smtp-ip 192.160.0.1 --smtp-port 10025 -f some@from.address

### Django

For use in Django, add the following configuration to your projects' settings.py

```python
if DEBUG:
    EMAIL_HOST = '127.0.0.1'
    EMAIL_HOST_USER = ''
    EMAIL_HOST_PASSWORD = ''
    EMAIL_PORT = 1025
    EMAIL_USE_TLS = False
```

### Docker

The official MailCatcher Docker image is available [on Docker Hub](https://hub.docker.com/r/stpaquet/alpinemailcatcher):

```
$ docker run -d -p 1080:1080 -p 1025:1025 stpaquet/alpinemailcatcher
Unable to find image 'stpaquet/alpinemailcatcher:latest' locally
latest: Pulling from stpaquet/alpinemailcatcher
4abcf2090661: Pull complete
9f403268fa96: Pull complete
6c9f5f5b4c6d: Pull complete
Digest: sha256:a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0
Status: Downloaded newer image for stpaquet/alpinemailcatcher:latest
Starting MailCatcher v0.12.0
==> smtp://0.0.0.0:1025
==> http://0.0.0.0:1080
```

How those ports appear and can be accessed may vary based on your Docker configuration. For example, you may need to use `http://127.0.0.1:1080` or `smtp://127.0.0.1:1025` instead of the listed address. The image is Alpine Linux based for minimal size and quick startup.

### API

A fairly RESTful URL schema means you can download a list of messages in JSON from `/messages`, each message's metadata with `/messages/:id.json`, and then the pertinent parts with `/messages/:id.html` and `/messages/:id.plain` for the default HTML and plain text version, `/messages/:id/parts/:cid` for individual attachments by CID, or the whole message with `/messages/:id.source`.

## Caveats

* Mail processing is fairly basic but easily modified. If something doesn't work for you, fork and fix it or [file an issue](https://github.com/spaquet/mailcatcher-ng/issues). Include the whole message you're having problems with.
* Encodings are difficult. MailCatcher NG does not completely support utf-8 straight over the wire, you must use a mail library which encodes things properly based on SMTP server capabilities.

## License

MailCatcher NG is released under the MIT License, see [LICENSE](LICENSE) for details.

## Credits

MailCatcher NG is a significantly improved fork of the original MailCatcher project. We've added many advanced features including:

* Email authentication verification (DMARC, DKIM, SPF)
* Email encryption and signature display (S/MIME and OpenPGP)
* BIMI (Brand Indicators for Message Identification) support
* Advanced preview text extraction with 3-tier fallback system
* Enhanced sender/recipient name parsing and display
* Improved UI/UX with keyboard navigation and better filtering
* WebSocket real-time updates with automatic reconnection
* And many more improvements to the original codebase

The original MailCatcher project was created by Samuel Cochran and released under the MIT License. We're grateful for this solid foundation and have built upon it to create MailCatcher NG.

  [websockets]: https://tools.ietf.org/html/rfc6455
