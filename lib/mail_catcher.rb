# frozen_string_literal: true

require 'logger'
require 'open3'
require 'optparse'
require 'rbconfig'
require 'openssl'

require 'eventmachine'
require 'thin'

module EventMachine
  # Monkey patch fix for 10deb4
  # See https://github.com/eventmachine/eventmachine/issues/569
  def self.reactor_running?
    @reactor_running || false
  end
end

require 'mail_catcher/version'

module MailCatcher
  extend self
  autoload :Bus, 'mail_catcher/bus'
  autoload :Mail, 'mail_catcher/mail'
  autoload :Smtp, 'mail_catcher/smtp'
  autoload :Web, 'mail_catcher/web'

  @logger = Logger.new($stdout)
  @logger.level = Logger::INFO

  def env
    ENV.fetch('MAILCATCHER_ENV', 'production')
  end

  def development?
    env == 'development'
  end

  def which?(command)
    ENV['PATH'].split(File::PATH_SEPARATOR).any? do |directory|
      File.executable?(File.join(directory, command.to_s))
    end
  end

  def windows?
    RbConfig::CONFIG['host_os'].match?(/mswin|mingw/)
  end

  def browsable?
    windows? or which? 'open'
  end

  def browse(url)
    if windows?
      system 'start', '/b', url
    elsif which? 'open'
      system 'open', url
    end
  end

  def log_exception(message, context, exception)
    gems_paths = (Gem.path | [Gem.default_dir]).map { |path| Regexp.escape(path) }
    gems_regexp = %r{(?:#{gems_paths.join('|')})/gems/([^/]+)-([\w.]+)/(.*)}
    gems_replace = '\1 (\2) \3'

    @logger.error("#{message}: #{context.inspect}")
    @logger.error("Exception: #{exception}")

    backtrace = exception.backtrace&.map { |line| line.sub(gems_regexp, gems_replace) }
    backtrace&.each { |line| @logger.error("  #{line}") }

    @logger.error('Please submit this as an issue at https://github.com/spaquet/mailcatcher')
  end

  @defaults = {
    smtp_ip: '127.0.0.1',
    smtp_port: '1025',
    smtp_ssl: false,
    smtp_ssl_cert: nil,
    smtp_ssl_key: nil,
    smtp_ssl_verify_peer: false,
    smtps_port: '1465',
    http_ip: '127.0.0.1',
    http_port: '1080',
    http_path: '/',
    messages_limit: nil,
    persistence: false,
    verbose: false,
    daemon: !windows?,
    browse: false,
    quit: true
  }

  def options
    @options
  end

  def http_server
    @http_server
  end

  def quittable?
    options[:quit]
  end

  def parse!(arguments = ARGV, defaults = @defaults)
    @defaults.dup.tap do |options|
      OptionParser.new do |parser|
        parser.banner = 'Usage: mailcatcher [options]'
        parser.version = VERSION
        parser.separator ''
        parser.separator "MailCatcher v#{VERSION}"
        parser.separator ''

        parser.on('--ip IP', 'Set the ip address of both servers') do |ip|
          options[:smtp_ip] = options[:http_ip] = ip
        end

        parser.on('--smtp-ip IP', 'Set the ip address of the smtp server') do |ip|
          options[:smtp_ip] = ip
        end

        parser.on('--smtp-port PORT', Integer, 'Set the port of the smtp server') do |port|
          options[:smtp_port] = port
        end

        parser.on('--smtp-ssl', 'Enable SSL/TLS support for SMTP') do
          options[:smtp_ssl] = true
        end

        parser.on('--smtp-ssl-cert PATH', 'Path to SSL certificate file (required with --smtp-ssl)') do |path|
          options[:smtp_ssl_cert] = path
        end

        parser.on('--smtp-ssl-key PATH', 'Path to SSL private key file (required with --smtp-ssl)') do |path|
          options[:smtp_ssl_key] = path
        end

        parser.on('--smtp-ssl-verify-peer', 'Verify client SSL certificates') do
          options[:smtp_ssl_verify_peer] = true
        end

        parser.on('--smtps-port PORT', Integer, 'Set the port for direct TLS SMTP server (default: 1465)') do |port|
          options[:smtps_port] = port
        end

        parser.on('--http-ip IP', 'Set the ip address of the http server') do |ip|
          options[:http_ip] = ip
        end

        parser.on('--http-port PORT', Integer, 'Set the port address of the http server') do |port|
          options[:http_port] = port
        end

        parser.on('--messages-limit COUNT', Integer,
                  'Only keep up to COUNT most recent messages') do |count|
          options[:messages_limit] = count
        end

        parser.on('--persistence', 'Store messages in a persistent SQLite database file') do
          options[:persistence] = true
        end

        parser.on('--http-path PATH', String, 'Add a prefix to all HTTP paths') do |path|
          clean_path = Rack::Utils.clean_path_info("/#{path}")

          options[:http_path] = clean_path
        end

        parser.on('--no-quit', "Don't allow quitting the process") do
          options[:quit] = false
        end

        unless windows?
          parser.on('-f', '--foreground', 'Run in the foreground') do
            options[:daemon] = false
          end
        end

        if browsable?
          parser.on('-b', '--browse', 'Open web browser') do
            options[:browse] = true
          end
        end

        parser.on('-v', '--verbose', 'Be more verbose') do
          options[:verbose] = true
        end

        parser.on_tail('-h', '--help', 'Display this help information') do
          puts parser
          exit
        end

        parser.on_tail('--version', 'Display the current version') do
          puts "MailCatcher v#{VERSION}"
          exit
        end
      end.parse!
    end
  end

  def run!(options = nil)
    # If we are passed options, fill in the blanks
    options &&= @defaults.merge options
    # Otherwise, parse them from ARGV
    options ||= parse!

    # Stash them away for later
    @options = options

    # Validate SSL configuration if enabled
    validate_ssl_config!

    # If we're running in the foreground sync the output.
    $stdout.sync = $stderr.sync = true unless options[:daemon]

    @logger.info("Starting MailCatcher NG v#{VERSION}")

    Thin::Logging.debug = development?
    Thin::Logging.silent = !development?
    @logger.level = development? ? Logger::DEBUG : Logger::INFO

    # Configure SSL/TLS if enabled
    configure_smtp_ssl!

    # One EventMachine loop...
    EventMachine.run do
      # Set up an SMTP server to run within EventMachine
      rescue_port options[:smtp_port] do
        EventMachine.start_server options[:smtp_ip], options[:smtp_port], Smtp
        @logger.info("==> #{smtp_url}")
      end

      # Set up direct TLS (SMTPS) server if SSL is enabled
      if options[:smtp_ssl]
        rescue_port options[:smtps_port] do
          EventMachine.start_server options[:smtp_ip], options[:smtps_port], SmtpTls
          @logger.info("==> #{smtps_url}")
        end
      end

      # Let Thin set itself up inside our EventMachine loop
      # Faye connections are hijacked but continue to be supervised by thin
      rescue_port options[:http_port] do
        @http_server = Thin::Server.new(options[:http_ip], options[:http_port], Web, signals: false)
        @http_server.start
        @logger.info("==> #{http_url}")
      end

      # Make sure we quit nicely when asked
      # We need to handle outside the trap context, hence the timer
      trap('INT') { EM.add_timer(0) { quit! } }
      trap('TERM') { EM.add_timer(0) { quit! } }
      trap('QUIT') { EM.add_timer(0) { quit! } } unless windows?

      # Open the web browser before detaching console
      if options[:browse]
        EventMachine.next_tick do
          browse http_url
        end
      end

      # Daemonize, if we should, but only after the servers have started.
      if options[:daemon]
        EventMachine.next_tick do
          if quittable?
            @logger.info('MailCatcher runs as a daemon by default. Go to the web interface to quit.')
          else
            @logger.info('MailCatcher is now running as a daemon that cannot be quit.')
          end
          Process.daemon
        end
      end
    end
  end

  def quit!
    MailCatcher::Bus.push(type: 'quit')

    EventMachine.next_tick { EventMachine.stop_event_loop }
  end

  protected

  def validate_ssl_config!
    return unless @options[:smtp_ssl]

    # Require certificate and key files
    unless @options[:smtp_ssl_cert] && @options[:smtp_ssl_key]
      @logger.error('SSL/TLS enabled but certificate or key file not specified')
      @logger.error('Use --smtp-ssl-cert and --smtp-ssl-key to provide paths')
      exit(-1)
    end

    # Check certificate file exists and is readable
    unless File.exist?(@options[:smtp_ssl_cert])
      @logger.error("SSL certificate file not found: #{@options[:smtp_ssl_cert]}")
      exit(-1)
    end

    unless File.readable?(@options[:smtp_ssl_cert])
      @logger.error("SSL certificate file not readable: #{@options[:smtp_ssl_cert]}")
      exit(-1)
    end

    # Check key file exists and is readable
    unless File.exist?(@options[:smtp_ssl_key])
      @logger.error("SSL private key file not found: #{@options[:smtp_ssl_key]}")
      exit(-1)
    end

    unless File.readable?(@options[:smtp_ssl_key])
      @logger.error("SSL private key file not readable: #{@options[:smtp_ssl_key]}")
      exit(-1)
    end

    # Try to load the certificate to validate format
    begin
      OpenSSL::X509::Certificate.new(File.read(@options[:smtp_ssl_cert]))
    rescue OpenSSL::X509::CertificateError => e
      @logger.error("Invalid SSL certificate file: #{e.message}")
      exit(-1)
    end

    # Try to load the private key to validate format
    begin
      OpenSSL::PKey.read(File.read(@options[:smtp_ssl_key]))
    rescue OpenSSL::PKey::PKeyError => e
      @logger.error("Invalid SSL private key file: #{e.message}")
      exit(-1)
    end

    @logger.info('SSL/TLS certificate and key validated successfully')
  end

  def configure_smtp_ssl!
    return unless @options[:smtp_ssl]

    # Build TLS options hash for EventMachine
    ssl_options = {
      cert_chain_file: @options[:smtp_ssl_cert],
      private_key_file: @options[:smtp_ssl_key],
      verify_peer: @options[:smtp_ssl_verify_peer]
    }

    # Configure the STARTTLS Smtp class
    Smtp.class_variable_set(:@@parms, {
      starttls: :required,
      starttls_options: ssl_options
    })

    # Configure the Direct TLS SmtpTls class
    SmtpTls.class_variable_set(:@@parms, {
      starttls: :required,
      starttls_options: ssl_options
    })

    @ssl_options = ssl_options
  end

  def smtp_url
    if @options[:smtp_ssl]
      "smtp+starttls://#{@options[:smtp_ip]}:#{@options[:smtp_port]}"
    else
      "smtp://#{@options[:smtp_ip]}:#{@options[:smtp_port]}"
    end
  end

  def smtps_url
    "smtps://#{@options[:smtp_ip]}:#{@options[:smtps_port]}"
  end

  def http_url
    "http://#{@options[:http_ip]}:#{@options[:http_port]}#{@options[:http_path]}".chomp('/')
  end

  def rescue_port(port)
    yield

  # XXX: EventMachine only spits out RuntimeError with a string description
  rescue RuntimeError
    raise unless $!.to_s =~ /\bno acceptor\b/

    @logger.error("Something's using port #{port}. Are you already running MailCatcher?")
    @logger.error("==> #{smtp_url}")
    @logger.error("==> #{http_url}")
    exit(-1)
  end
end
