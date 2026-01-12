# frozen_string_literal: true

require "eventmachine"
require "securerandom"
require "socket"

require "mail_catcher/mail"

class MailCatcher::Smtp < EventMachine::Protocols::SmtpServer
  @@active_connections = 0

  def self.connection_count
    @@active_connections
  end

  def initialize(*args)
    @transcript_entries = []
    @session_id = SecureRandom.uuid
    @connection_started_at = Time.now
    @data_started = false
    @last_message_id = nil
    super
  end

  def post_init
    @@active_connections += 1

    # Get connection details
    begin
      peer_sockaddr = get_peername
      if peer_sockaddr
        port, client_ip = Socket.unpack_sockaddr_in(peer_sockaddr)
        @client_ip = client_ip
        @client_port = port
      end
    rescue => e
      $stderr.puts "Error getting peer info: #{e.message}"
    end

    begin
      local_sockaddr = get_sockname
      if local_sockaddr
        port, server_ip = Socket.unpack_sockaddr_in(local_sockaddr)
        @server_ip = server_ip
        @server_port = port
      end
    rescue => e
      $stderr.puts "Error getting local info: #{e.message}"
    end

    log_transcript('connection', 'server', "Connection established from #{@client_ip}:#{@client_port}")

    super
  end

  def unbind
    @@active_connections -= 1

    @connection_ended_at = Time.now
    log_transcript('connection', 'server', "Connection closed")

    # Save transcript with the last message if available, otherwise without message_id
    # This ensures "Connection closed" is included in the transcript
    save_transcript(@last_message_id) if @transcript_entries.any?

    super
  end

  def log_transcript(type, direction, message)
    @transcript_entries << {
      timestamp: Time.now.utc.iso8601(3),
      type: type,
      direction: direction,
      message: message
    }
  rescue => e
    $stderr.puts "Error logging transcript: #{e.message}"
  end

  def save_transcript(message_id)
    return if @transcript_entries.empty?

    begin
      tls_enabled = @tls_started ? 1 : 0
      tls_protocol = nil
      tls_cipher = nil

      if @tls_started
        begin
          tls_protocol = get_cipher_protocol
        rescue
          # TLS info not available
        end
        begin
          tls_cipher = get_cipher_name
        rescue
          # TLS info not available
        end
      end

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: @session_id,
        client_ip: @client_ip,
        client_port: @client_port,
        server_ip: @server_ip,
        server_port: @server_port,
        tls_enabled: tls_enabled,
        tls_protocol: tls_protocol,
        tls_cipher: tls_cipher,
        connection_started_at: @connection_started_at,
        connection_ended_at: @connection_ended_at || Time.now,
        entries: @transcript_entries
      )

      @transcript_entries = []
    rescue => e
      $stderr.puts "Error saving SMTP transcript: #{e.message}"
      $stderr.puts e.backtrace.join("\n")
    end
  end

  # We override EM's mail from processing to allow multiple mail-from commands
  # per [RFC 2821](https://tools.ietf.org/html/rfc2821#section-4.1.1.2)
  def process_mail_from sender
    if @state.include? :mail_from
      @state -= [:mail_from, :rcpt, :data]

      receive_reset
    end

    super
  end

  def current_message
    @current_message ||= {}
  end

  def receive_reset
    log_transcript('command', 'client', 'RSET')
    log_transcript('response', 'server', '250 OK')

    @current_message = nil
    @data_started = false

    true
  end

  def get_server_capabilities
    # Advertise SMTP capabilities per RFC standards
    # SIZE: RFC 1870 - Message size extension
    # 8BITMIME: RFC 6152 - 8bit MIME transport
    # SMTPUTF8: RFC 6531 - UTF-8 support in SMTP
    ["8BITMIME", "SMTPUTF8"]
  end

  def receive_sender(sender)
    # Log the full MAIL FROM command with ESMTP parameters
    log_transcript('command', 'client', "MAIL FROM:<#{sender}>")

    # EventMachine SMTP advertises size extensions [https://tools.ietf.org/html/rfc1870]
    # and other SMTP parameters via the MAIL FROM command
    # Strip potential " SIZE=..." and "BODY=..." suffixes from senders
    sender_cleaned = sender.gsub(/ (?:SIZE|BODY)=\S+/i, "")

    log_transcript('response', 'server', '250 OK')

    current_message[:sender] = sender_cleaned
    # Store the original sender line to track if 8BIT was specified
    current_message[:sender_line] = sender_cleaned

    true
  end

  def receive_recipient(recipient)
    log_transcript('command', 'client', "RCPT TO:<#{recipient}>")

    current_message[:recipients] ||= []
    current_message[:recipients] << recipient

    log_transcript('response', 'server', '250 OK')

    true
  end

  def receive_data_chunk(lines)
    # Log DATA command on first chunk only
    if !@data_started
      @data_started = true
      log_transcript('command', 'client', 'DATA')
      log_transcript('response', 'server', '354 Start mail input; end with <CRLF>.<CRLF>')
    end

    current_message[:source] ||= +""

    lines.each do |line|
      current_message[:source] << line << "\r\n"
    end

    true
  end

  def receive_message
    message_size = current_message[:source].length
    log_transcript('data', 'client', "Message complete (#{message_size} bytes)")
    log_transcript('response', 'server', '250 OK: Message accepted')

    begin
      message_id = MailCatcher::Mail.add_message current_message
      @last_message_id = message_id
    rescue => e
      $stderr.puts "Error in add_message: #{e.message}"
      $stderr.puts e.backtrace.join("\n")
      message_id = nil
    end

    MailCatcher::Mail.delete_older_messages!

    # Don't save transcript here - save it when connection closes (in unbind)
    # This ensures "Connection closed" entry is included

    true
  rescue => exception
    log_transcript('error', 'server', "Exception: #{exception.class} - #{exception.message}")
    MailCatcher.log_exception("Error receiving message", @current_message, exception)

    # Don't save transcript here - save it when connection closes (in unbind)

    false
  ensure
    @current_message = nil
    @data_started = false
  end

  # Override to log EHLO/HELO command
  def receive_ehlo_domain(domain)
    log_transcript('command', 'client', "EHLO #{domain}")

    # Call parent to handle the EHLO response
    result = super

    # Log the capabilities after they're sent
    capabilities = get_server_capabilities
    capabilities_str = capabilities.map { |cap| "250-#{cap}" }.join("\r\n")
    # Replace first 250- with 250 followed by a space
    if capabilities_str.start_with?("250-")
      capabilities_str = "250 " + capabilities_str[4..-1]
    end
    log_transcript('response', 'server', capabilities_str)

    result
  end

  # Override to log STARTTLS command and TLS negotiation
  def process_starttls
    log_transcript('tls', 'client', 'STARTTLS')
    result = super

    # Log TLS info after negotiation
    if @tls_started
      begin
        protocol = get_cipher_protocol
        cipher = get_cipher_name
        log_transcript('tls', 'server', "TLS negotiation completed (#{protocol}, #{cipher})")
      rescue
        log_transcript('tls', 'server', "TLS negotiation completed")
      end
    end

    result
  end

  # Override to log AUTH attempts (without logging credentials)
  def receive_plain_auth(user, password)
    log_transcript('command', 'client', "AUTH PLAIN [credentials hidden]")
    result = super

    if result
      log_transcript('response', 'server', '235 2.7.0 Authentication successful')
    else
      log_transcript('response', 'server', '535 5.7.8 Authentication credentials invalid')
    end

    result
  end

  # Override to log unknown/invalid commands
  def process_unknown(command, data)
    log_transcript('command', 'client', "#{command} #{data}".strip)
    result = super

    log_transcript('response', 'server', '500 5.5.1 Command not recognized')

    result
  end
end

# Direct TLS (SMTPS) handler that starts TLS immediately on connection
class MailCatcher::SmtpTls < MailCatcher::Smtp
  def post_init
    # Increment connection count and set up connection info
    super

    # Log immediate TLS (SMTPS on port 1465)
    log_transcript('tls', 'server', 'Immediate TLS enabled (SMTPS)')

    # Start TLS immediately on connection for SMTPS (port 1465 behavior)
    # The @@parms hash with starttls_options is already set by configure_smtp_ssl!
    if defined?(@@parms) && @@parms[:starttls_options]
      start_tls(@@parms[:starttls_options])

      # Log TLS details after negotiation
      if @tls_started
        begin
          protocol = get_cipher_protocol
          cipher = get_cipher_name
          log_transcript('tls', 'server', "TLS negotiation completed (#{protocol}, #{cipher})")
        rescue
          # TLS info not available yet
        end
      end
    end
  end
end
