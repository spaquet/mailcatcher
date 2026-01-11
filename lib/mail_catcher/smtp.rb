# frozen_string_literal: true

require "eventmachine"

require "mail_catcher/mail"

class MailCatcher::Smtp < EventMachine::Protocols::SmtpServer
  @@active_connections = 0

  def self.connection_count
    @@active_connections
  end

  def post_init
    @@active_connections += 1
    super
  end

  def unbind
    @@active_connections -= 1
    super
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
    @current_message = nil

    true
  end

  def get_server_capabilities
    # Advertise SMTP capabilities per RFC standards
    # SIZE: RFC 1870 - Message size extension
    # 8BITMIME: RFC 6152 - 8bit MIME transport
    # SMTPUTF8: RFC 6531 - UTF-8 support in SMTP
    capabilities = super.to_a
    capabilities << "8BITMIME"
    capabilities << "SMTPUTF8"
    capabilities
  end

  def receive_sender(sender)
    # EventMachine SMTP advertises size extensions [https://tools.ietf.org/html/rfc1870]
    # and other SMTP parameters via the MAIL FROM command
    # Strip potential " SIZE=..." and "BODY=..." suffixes from senders
    sender = sender.gsub(/ (?:SIZE|BODY)=\S+/i, "")

    current_message[:sender] = sender
    # Store the original sender line to track if 8BIT was specified
    current_message[:sender_line] = sender

    true
  end

  def receive_recipient(recipient)
    current_message[:recipients] ||= []
    current_message[:recipients] << recipient

    true
  end

  def receive_data_chunk(lines)
    current_message[:source] ||= +""

    lines.each do |line|
      current_message[:source] << line << "\r\n"
    end

    true
  end

  def receive_message
    MailCatcher::Mail.add_message current_message
    MailCatcher::Mail.delete_older_messages!
    puts "==> SMTP: Received message from '#{current_message[:sender]}' (#{current_message[:source].length} bytes)"
    true
  rescue => exception
    MailCatcher.log_exception("Error receiving message", @current_message, exception)
    false
  ensure
    @current_message = nil
  end
end

# Direct TLS (SMTPS) handler that starts TLS immediately on connection
class MailCatcher::SmtpTls < MailCatcher::Smtp
  def post_init
    # Increment connection count
    super

    # Start TLS immediately on connection for SMTPS (port 1465 behavior)
    # The @@parms hash with starttls_options is already set by configure_smtp_ssl!
    if defined?(@@parms) && @@parms[:starttls_options]
      start_tls(@@parms[:starttls_options])
    end
  end
end
