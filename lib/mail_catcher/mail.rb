# frozen_string_literal: true

require "eventmachine"
require "fileutils"
require "json"
require "mail"
require "nokogiri"
require "sqlite3"
require "uri"

module MailCatcher::Mail extend self
  def db
    @__db ||= begin
      db_path = determine_db_path
      SQLite3::Database.new(db_path, :type_translation => true).tap do |db|
        db.execute(<<-SQL)
          CREATE TABLE IF NOT EXISTS message (
            id INTEGER PRIMARY KEY ASC,
            sender TEXT,
            recipients TEXT,
            subject TEXT,
            source BLOB,
            size TEXT,
            type TEXT,
            created_at DATETIME DEFAULT CURRENT_DATETIME
          )
        SQL
        db.execute(<<-SQL)
          CREATE TABLE IF NOT EXISTS message_part (
            id INTEGER PRIMARY KEY ASC,
            message_id INTEGER NOT NULL,
            cid TEXT,
            type TEXT,
            is_attachment INTEGER,
            filename TEXT,
            charset TEXT,
            body BLOB,
            size INTEGER,
            created_at DATETIME DEFAULT CURRENT_DATETIME,
            FOREIGN KEY (message_id) REFERENCES message (id) ON DELETE CASCADE
          )
        SQL
        db.execute(<<-SQL)
          CREATE TABLE IF NOT EXISTS smtp_transcript (
            id INTEGER PRIMARY KEY ASC,
            message_id INTEGER,
            session_id TEXT NOT NULL,
            client_ip TEXT,
            client_port INTEGER,
            server_ip TEXT,
            server_port INTEGER,
            tls_enabled INTEGER DEFAULT 0,
            tls_protocol TEXT,
            tls_cipher TEXT,
            connection_started_at DATETIME,
            connection_ended_at DATETIME,
            entries TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_DATETIME,
            FOREIGN KEY (message_id) REFERENCES message (id) ON DELETE CASCADE
          )
        SQL
        db.execute(<<-SQL)
          CREATE TABLE IF NOT EXISTS websocket_connection (
            id INTEGER PRIMARY KEY ASC,
            session_id TEXT NOT NULL,
            client_ip TEXT,
            opened_at DATETIME,
            closed_at DATETIME,
            last_ping_at DATETIME,
            last_pong_at DATETIME,
            ping_count INTEGER DEFAULT 0,
            pong_count INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_DATETIME,
            updated_at DATETIME DEFAULT CURRENT_DATETIME
          )
        SQL
        db.execute("CREATE INDEX IF NOT EXISTS idx_smtp_transcript_message_id ON smtp_transcript(message_id)")
        db.execute("CREATE INDEX IF NOT EXISTS idx_smtp_transcript_session_id ON smtp_transcript(session_id)")
        db.execute("CREATE INDEX IF NOT EXISTS idx_websocket_connection_session_id ON websocket_connection(session_id)")
        db.execute("PRAGMA foreign_keys = ON")
      end
    end
  end

  def determine_db_path
    if MailCatcher.options && MailCatcher.options[:persistence]
      # Use a persistent SQLite file in the user's home directory
      db_dir = File.expand_path('~/.mailcatcher')
      FileUtils.mkdir_p(db_dir) unless Dir.exist?(db_dir)
      File.join(db_dir, 'mailcatcher.db')
    else
      # Use in-memory database
      ':memory:'
    end
  end

  def add_message(message)
    @add_message_query ||= db.prepare("INSERT INTO message (sender, recipients, subject, source, type, size, created_at) VALUES (?, ?, ?, ?, ?, ?, datetime('now'))")

    mail = Mail.new(message[:source])
    @add_message_query.execute(message[:sender], JSON.generate(message[:recipients]), mail.subject, message[:source], mail.mime_type || "text/plain", message[:source].length)
    message_id = db.last_insert_row_id
    parts = mail.all_parts
    parts = [mail] if parts.empty?
    parts.each do |part|
      body = part.body.to_s
      # Only parts have CIDs, not mail
      cid = part.cid if part.respond_to? :cid
      add_message_part(message_id, cid, part.mime_type || "text/plain", part.attachment? ? 1 : 0, part.filename, part.charset, body, body.length)
    end

    EventMachine.next_tick do
      message = MailCatcher::Mail.message message_id
      MailCatcher::Bus.push(type: "add", message: message)
    end

    message_id
  end

  def add_message_part(*args)
    @add_message_part_query ||= db.prepare "INSERT INTO message_part (message_id, cid, type, is_attachment, filename, charset, body, size, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))"
    @add_message_part_query.execute(*args)
  end

  def latest_created_at
    @latest_created_at_query ||= db.prepare "SELECT created_at FROM message ORDER BY created_at DESC LIMIT 1"
    @latest_created_at_query.execute.next
  end

  def messages
    @messages_query ||= db.prepare "SELECT id, sender, recipients, subject, size, created_at FROM message ORDER BY created_at, id ASC"
    @messages_query.execute.map do |row|
      Hash[@messages_query.columns.zip(row)].tap do |message|
        message["recipients"] &&= JSON.parse(message["recipients"])
      end
    end
  end

  def search_messages(query: nil, has_attachments: nil, from_date: nil, to_date: nil)
    # Build dynamic SQL query with filters
    sql = "SELECT DISTINCT m.id, m.sender, m.recipients, m.subject, m.size, m.created_at FROM message m"
    params = []
    where_clauses = []

    # Determine if we need to join with message_part table
    needs_join = (query && !query.strip.empty?) || has_attachments.is_a?(TrueClass)

    # Join with message_part table if needed
    if needs_join
      sql += " LEFT JOIN message_part mp ON m.id = mp.message_id"
    end

    # Add search filters - search across subject, sender, and recipients (always available)
    # Also search body if we have the JOIN
    if query && !query.strip.empty?
      q = "%#{query}%"
      if needs_join
        where_clauses << "(m.subject LIKE ? OR m.sender LIKE ? OR m.recipients LIKE ? OR mp.body LIKE ?)"
        params.concat([q, q, q, q])
      else
        where_clauses << "(m.subject LIKE ? OR m.sender LIKE ? OR m.recipients LIKE ?)"
        params.concat([q, q, q])
      end
    end

    # Add attachment filter
    if has_attachments.is_a?(TrueClass)
      where_clauses << "(mp.is_attachment = 1)"
    end

    # Add date range filters
    if from_date
      where_clauses << "(m.created_at >= ?)"
      params << from_date
    end

    if to_date
      where_clauses << "(m.created_at <= ?)"
      params << to_date
    end

    # Combine where clauses
    sql += " WHERE #{where_clauses.join(' AND ')}" if where_clauses.any?

    sql += " ORDER BY m.created_at, m.id ASC"

    db.prepare(sql).execute(*params).map do |row|
      columns = ["id", "sender", "recipients", "subject", "size", "created_at"]
      Hash[columns.zip(row)].tap do |message|
        message["recipients"] &&= JSON.parse(message["recipients"])
      end
    end
  end

  def message(id)
    @message_query ||= db.prepare "SELECT id, sender, recipients, subject, size, type, created_at FROM message WHERE id = ? LIMIT 1"
    row = @message_query.execute(id).next
    row && Hash[@message_query.columns.zip(row)].tap do |message|
      message["recipients"] &&= JSON.parse(message["recipients"])
    end
  end

  def message_source(id)
    @message_source_query ||= db.prepare "SELECT source FROM message WHERE id = ? LIMIT 1"
    row = @message_source_query.execute(id).next
    row && row.first
  end

  def message_bimi_location(id)
    source = message_source(id)
    return nil unless source

    # Extract BIMI-Location header from email source
    # Headers are case-insensitive
    source.each_line do |line|
      # Stop at first blank line (end of headers)
      break if line.strip.empty?
      # Match BIMI-Location header (case-insensitive)
      if line.match?(/^bimi-location:\s*/i)
        # Extract the value and clean it up
        value = line.sub(/^bimi-location:\s*/i, '').strip
        return value unless value.empty?
      end
    end

    nil
  end

  def message_preview_text(id)
    source = message_source(id)
    return nil unless source

    # Extract Preview-Text header from email source (tier 1 of preview text extraction)
    # This is a de facto standard header (not formal RFC) used by email clients
    # to display preview/preheader text in the inbox preview pane
    source.each_line do |line|
      # Stop at first blank line (end of headers)
      break if line.strip.empty?
      # Match Preview-Text header (case-insensitive)
      if line.match?(/^preview-text:\s*/i)
        # Extract the value and clean it up
        value = line.sub(/^preview-text:\s*/i, '').strip
        return value unless value.empty?
      end
    end

    nil
  end

  def message_from(id)
    source = message_source(id)
    return nil unless source

    # Extract From header from email source
    source.each_line do |line|
      # Stop at first blank line (end of headers)
      break if line.strip.empty?
      # Match From header (case-insensitive)
      if line.match?(/^from:\s*/i)
        # Extract the value and handle multi-line headers
        value = line.sub(/^from:\s*/i, '').strip

        # Continue reading continuation lines (lines starting with whitespace)
        lines = source.lines
        line_index = lines.index { |l| l.match?(/^from:\s*/i) }
        next_index = line_index + 1 if line_index
        while next_index && next_index < lines.length && lines[next_index].match?(/^\s+/)
          value += " " + lines[next_index].strip
          next_index += 1
        end

        return value unless value.empty?
      end
    end

    nil
  end

  def message_to(id)
    source = message_source(id)
    return nil unless source

    # Extract To header from email source
    source.each_line do |line|
      # Stop at first blank line (end of headers)
      break if line.strip.empty?
      # Match To header (case-insensitive)
      if line.match?(/^to:\s*/i)
        # Extract the value and handle multi-line headers
        value = line.sub(/^to:\s*/i, '').strip

        # Continue reading continuation lines (lines starting with whitespace)
        lines = source.lines
        line_index = lines.index { |l| l.match?(/^to:\s*/i) }
        next_index = line_index + 1 if line_index
        while next_index && next_index < lines.length && lines[next_index].match?(/^\s+/)
          value += " " + lines[next_index].strip
          next_index += 1
        end

        return value unless value.empty?
      end
    end

    nil
  end

  def message_authentication_results(id)
    source = message_source(id)
    return {} unless source

    auth_results = {
      dmarc: nil,
      dkim: nil,
      spf: nil
    }

    lines = source.lines
    lines.each_with_index do |line, index|
      break if line.strip.empty?

      # Authentication-Results header contains DMARC, DKIM, and SPF info
      if line.match?(/^authentication-results:\s*/i)
        # Extract the value and handle multi-line headers
        value = line.sub(/^authentication-results:\s*/i, '').strip

        # Continue reading continuation lines (lines starting with whitespace)
        next_index = index + 1
        while next_index < lines.length && lines[next_index].match?(/^\s+/)
          value += " " + lines[next_index].strip
          next_index += 1
        end

        auth_results = parse_authentication_results(value)
        break
      end
    end

    auth_results
  end

  def message_has_html?(id)
    @message_has_html_query ||= db.prepare "SELECT 1 FROM message_part WHERE message_id = ? AND is_attachment = 0 AND type IN ('application/xhtml+xml', 'text/html') LIMIT 1"
    (!!@message_has_html_query.execute(id).next) || ["text/html", "application/xhtml+xml"].include?(message(id)["type"])
  end

  def message_has_plain?(id)
    @message_has_plain_query ||= db.prepare "SELECT 1 FROM message_part WHERE message_id = ? AND is_attachment = 0 AND type = 'text/plain' LIMIT 1"
    (!!@message_has_plain_query.execute(id).next) || message(id)["type"] == "text/plain"
  end

  def message_parts(id)
    @message_parts_query ||= db.prepare "SELECT cid, type, filename, size FROM message_part WHERE message_id = ? ORDER BY filename ASC"
    @message_parts_query.execute(id).map do |row|
      Hash[@message_parts_query.columns.zip(row)]
    end
  end

  def message_attachments(id)
    @message_attachments_query ||= db.prepare "SELECT cid, type, filename, size FROM message_part WHERE message_id = ? AND is_attachment = 1 ORDER BY filename ASC"
    @message_attachments_query.execute(id).map do |row|
      Hash[@message_attachments_query.columns.zip(row)]
    end
  end

  def message_part(message_id, part_id)
    @message_part_query ||= db.prepare "SELECT * FROM message_part WHERE message_id = ? AND id = ? LIMIT 1"
    row = @message_part_query.execute(message_id, part_id).next
    row && Hash[@message_part_query.columns.zip(row)]
  end

  def message_part_type(message_id, part_type)
    @message_part_type_query ||= db.prepare "SELECT * FROM message_part WHERE message_id = ? AND type = ? AND is_attachment = 0 LIMIT 1"
    row = @message_part_type_query.execute(message_id, part_type).next
    row && Hash[@message_part_type_query.columns.zip(row)]
  end

  def message_part_html(message_id)
    part = message_part_type(message_id, "text/html")
    part ||= message_part_type(message_id, "application/xhtml+xml")
    part ||= begin
      message = message(message_id)
      message if message and ["text/html", "application/xhtml+xml"].include? message["type"]
    end
  end

  def message_part_plain(message_id)
    message_part_type message_id, "text/plain"
  end

  def message_part_cid(message_id, cid)
    @message_part_cid_query ||= db.prepare "SELECT * FROM message_part WHERE message_id = ?"
    @message_part_cid_query.execute(message_id).map do |row|
      Hash[@message_part_cid_query.columns.zip(row)]
    end.find do |part|
      part["cid"] == cid
    end
  end

  def delete!
    @delete_all_messages_query ||= db.prepare "DELETE FROM message"
    @delete_all_transcripts_query ||= db.prepare "DELETE FROM smtp_transcript"

    @delete_all_messages_query.execute
    @delete_all_transcripts_query.execute

    EventMachine.next_tick do
      MailCatcher::Bus.push(type: "clear")
    end
  end

  def delete_message!(message_id)
    @delete_messages_query ||= db.prepare "DELETE FROM message WHERE id = ?"
    @delete_messages_query.execute(message_id)

    EventMachine.next_tick do
      MailCatcher::Bus.push(type: "remove", id: message_id)
    end
  end

  def delete_older_messages!(count = MailCatcher.options[:messages_limit])
    return if count.nil?
    @older_messages_query ||= db.prepare "SELECT id FROM message WHERE id NOT IN (SELECT id FROM message ORDER BY created_at DESC LIMIT ?)"
    @older_messages_query.execute(count).map do |row|
      Hash[@older_messages_query.columns.zip(row)]
    end.each do |message|
      delete_message!(message["id"])
    end
  end

  def extract_tokens(id, type:)
    html_part = message_part_html(id)
    plain_part = message_part_plain(id)

    content = [html_part&.dig('body'), plain_part&.dig('body')].compact.join("\n")

    case type
    when 'link' then extract_magic_links(content)
    when 'otp' then extract_otps(content)
    when 'token' then extract_reset_tokens(content)
    else []
    end
  end

  def extract_all_links(id)
    links = []

    if html_part = message_part_html(id)
      links += extract_links_from_html(html_part['body'])
    end

    if plain_part = message_part_plain(id)
      links += extract_links_from_plain(plain_part['body'])
    end

    links
  end

  def parse_message_structured(id)
    # Extract unsubscribe from List-Unsubscribe header
    source = message_source(id)
    unsubscribe_link = nil

    if source
      unsubscribe_header = source.lines.find { |l| l.match?(/^List-Unsubscribe:/i) }
      unsubscribe_link = unsubscribe_header&.match(/<(https?:\/\/[^>]+)>/)&.[](1)
    end

    {
      verification_url: extract_tokens(id, type: 'link').first&.dig(:value),
      otp_code: extract_tokens(id, type: 'otp').first&.dig(:value),
      reset_token: extract_tokens(id, type: 'token').first&.dig(:value),
      unsubscribe_link: unsubscribe_link,
      all_links: extract_all_links(id)
    }
  end

  def accessibility_score(id)
    html_part = message_part_html(id)
    return { score: 0, error: 'No HTML part found' } unless html_part

    doc = Nokogiri::HTML(html_part['body'])

    alt_text_data = check_alt_text_detailed(doc)
    semantic_data = check_semantic_html_detailed(doc)
    links_data = check_links_detailed(doc)

    scores = {
      images_with_alt: alt_text_data[:score],
      semantic_html: semantic_data[:score],
      links_with_text: links_data[:score]
    }

    total_score = (scores.values.sum / scores.size.to_f).round

    {
      score: total_score,
      breakdown: scores,
      findings: {
        images: alt_text_data[:findings],
        semantic: semantic_data[:findings],
        links: links_data[:findings]
      },
      recommendations: generate_recommendations(scores)
    }
  end

  def forward_message(id)
    return { error: 'SMTP not configured' } unless forward_smtp_configured?

    message = message(id)
    source = message_source(id)
    recipients = JSON.parse(message['recipients'])

    require 'net/smtp'

    Net::SMTP.start(
      MailCatcher.options[:forward_smtp_host],
      MailCatcher.options[:forward_smtp_port] || 587,
      'localhost',
      MailCatcher.options[:forward_smtp_user],
      MailCatcher.options[:forward_smtp_password],
      :plain
    ) do |smtp|
      smtp.send_message(source, message['sender'], recipients)
    end

    {
      success: true,
      forwarded_to: recipients,
      forwarded_at: Time.now.utc.iso8601
    }
  rescue => e
    { error: e.message }
  end

  def message_encryption_data(id)
    source = message_source(id)
    return {} unless source

    encryption_data = {
      smime: nil,
      pgp: nil
    }

    lines = source.lines
    lines.each_with_index do |line, index|
      break if line.strip.empty?

      # Check for S/MIME certificate headers
      if line.match?(/^x-certificate:/i)
        value = line.sub(/^x-certificate:\s*/i, '').strip
        # Handle multi-line headers
        next_index = index + 1
        while next_index < lines.length && lines[next_index].match?(/^\s+/)
          value += lines[next_index].strip
          next_index += 1
        end
        encryption_data[:smime] = { certificate: value } if value.present?
      end

      # Check for S/MIME signature headers
      if line.match?(/^x-smime-signature:/i)
        value = line.sub(/^x-smime-signature:\s*/i, '').strip
        # Handle multi-line headers
        next_index = index + 1
        while next_index < lines.length && lines[next_index].match?(/^\s+/)
          value += lines[next_index].strip
          next_index += 1
        end
        if encryption_data[:smime].nil?
          encryption_data[:smime] = { signature: value }
        else
          encryption_data[:smime][:signature] = value
        end
      end

      # Check for PGP key or signature headers
      if line.match?(/^x-pgp-key:/i)
        value = line.sub(/^x-pgp-key:\s*/i, '').strip
        # Handle multi-line headers
        next_index = index + 1
        while next_index < lines.length && lines[next_index].match?(/^\s+/)
          value += lines[next_index].strip
          next_index += 1
        end
        encryption_data[:pgp] = { key: value } if value.present?
      end

      # Check for PGP signature headers
      if line.match?(/^x-pgp-signature:/i)
        value = line.sub(/^x-pgp-signature:\s*/i, '').strip
        # Handle multi-line headers
        next_index = index + 1
        while next_index < lines.length && lines[next_index].match?(/^\s+/)
          value += lines[next_index].strip
          next_index += 1
        end
        if encryption_data[:pgp].nil?
          encryption_data[:pgp] = { signature: value }
        else
          encryption_data[:pgp][:signature] = value
        end
      end
    end

    encryption_data
  end

  def add_smtp_transcript(params)
    @add_smtp_transcript_query ||= db.prepare(<<-SQL)
      INSERT INTO smtp_transcript (
        message_id, session_id, client_ip, client_port,
        server_ip, server_port, tls_enabled, tls_protocol,
        tls_cipher, connection_started_at, connection_ended_at,
        entries, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
    SQL

    @add_smtp_transcript_query.execute(
      params[:message_id],
      params[:session_id],
      params[:client_ip],
      params[:client_port],
      params[:server_ip],
      params[:server_port],
      params[:tls_enabled],
      params[:tls_protocol],
      params[:tls_cipher],
      params[:connection_started_at]&.utc&.iso8601,
      params[:connection_ended_at]&.utc&.iso8601,
      JSON.generate(params[:entries])
    )
  end

  def message_transcript(message_id)
    @message_transcript_query ||= db.prepare(<<-SQL)
      SELECT id, message_id, session_id, client_ip, client_port,
             server_ip, server_port, tls_enabled, tls_protocol,
             tls_cipher, connection_started_at, connection_ended_at,
             entries, created_at
      FROM smtp_transcript
      WHERE message_id = ?
      ORDER BY created_at DESC
      LIMIT 1
    SQL

    row = @message_transcript_query.execute(message_id).next
    return nil unless row

    result = Hash[@message_transcript_query.columns.zip(row)]
    result['entries'] = JSON.parse(result['entries']) if result['entries']
    result['tls_enabled'] = result['tls_enabled'] == 1
    result
  end

  def all_transcripts
    @all_transcripts_query ||= db.prepare(<<-SQL)
      SELECT id, message_id, session_id, client_ip,
             connection_started_at, tls_enabled
      FROM smtp_transcript
      ORDER BY created_at DESC
    SQL

    @all_transcripts_query.execute.map do |row|
      Hash[@all_transcripts_query.columns.zip(row)]
    end
  end

  def all_transcript_entries
    @all_transcript_entries_query ||= db.prepare(<<-SQL)
      SELECT id, message_id, session_id, client_ip, client_port,
             server_ip, server_port, tls_enabled, tls_protocol,
             tls_cipher, connection_started_at, connection_ended_at,
             entries, created_at
      FROM smtp_transcript
      ORDER BY created_at DESC
    SQL

    @all_transcript_entries_query.execute.map do |row|
      result = Hash[@all_transcript_entries_query.columns.zip(row)]
      result['entries'] = JSON.parse(result['entries']) if result['entries']
      result['tls_enabled'] = result['tls_enabled'] == 1
      result
    end
  end

  def create_websocket_connection(session_id, client_ip)
    @create_ws_connection_query ||= db.prepare(<<-SQL)
      INSERT INTO websocket_connection (session_id, client_ip, opened_at, created_at, updated_at)
      VALUES (?, ?, datetime('now'), datetime('now'), datetime('now'))
    SQL
    @create_ws_connection_query.execute(session_id, client_ip)
    db.last_insert_row_id
  end

  def close_websocket_connection(session_id)
    @close_ws_connection_query ||= db.prepare(<<-SQL)
      UPDATE websocket_connection
      SET closed_at = datetime('now'), updated_at = datetime('now')
      WHERE session_id = ? AND closed_at IS NULL
    SQL
    @close_ws_connection_query.execute(session_id)
  end

  def record_websocket_ping(session_id)
    @record_ping_query ||= db.prepare(<<-SQL)
      UPDATE websocket_connection
      SET last_ping_at = datetime('now'), ping_count = ping_count + 1, updated_at = datetime('now')
      WHERE session_id = ? AND closed_at IS NULL
    SQL
    @record_ping_query.execute(session_id)
  end

  def record_websocket_pong(session_id)
    @record_pong_query ||= db.prepare(<<-SQL)
      UPDATE websocket_connection
      SET last_pong_at = datetime('now'), pong_count = pong_count + 1, updated_at = datetime('now')
      WHERE session_id = ? AND closed_at IS NULL
    SQL
    @record_pong_query.execute(session_id)
  end

  private

  def extract_magic_links(content)
    # Extract URLs with common token parameters: token, verify, confirmation, magic
    # Use non-capturing group (?:...) so scan returns the full match
    pattern = %r{https?://[^\s<>]+[?&](?:token|verify|confirmation|magic)=[a-zA-Z0-9_\-.~%]+}i
    content.scan(pattern).compact.map do |url|
      # Extract surrounding context (50 chars before and after)
      start_pos = content.index(url)
      if start_pos
        context_start = [0, start_pos - 50].max
        context_end = [content.length, start_pos + url.length + 50].min
        context = content[context_start...context_end].strip

        {
          type: 'magic_link',
          value: url,
          context: context
        }
      end
    end.compact
  end

  def extract_otps(content)
    # Extract 6-digit OTP codes, preferring those near keywords
    pattern = /\b(\d{6})\b/
    results = []

    content.scan(pattern).each do |match|
      otp = match[0]
      start_pos = content.index(otp)
      context_start = [0, start_pos - 50].max
      context_end = [content.length, start_pos + otp.length + 50].min
      context = content[context_start...context_end].strip

      # Check if near keywords: code, otp, verification, confirm, pin
      if context.match?(/code|otp|verification|confirm|pin/i)
        results << {
          type: 'otp',
          value: otp,
          context: context
        }
      end
    end

    results
  end

  def extract_reset_tokens(content)
    # Extract reset token URLs
    pattern = %r{https?://[^\s<>]*reset[^\s<>]*[?&]token=[a-zA-Z0-9_\-.~%]+}i
    content.scan(pattern).map do |url|
      start_pos = content.index(url)
      context_start = [0, start_pos - 50].max
      context_end = [content.length, start_pos + url.length + 50].min
      context = content[context_start...context_end].strip

      {
        type: 'reset_token',
        value: url,
        context: context
      }
    end
  end

  def extract_links_from_html(html)
    doc = Nokogiri::HTML(html)
    doc.css('a[href]').map do |link|
      href = link['href']
      {
        href: href,
        text: link.text.strip,
        is_verification: href.match?(/verify|confirm|token|magic|activate/i),
        is_unsubscribe: href.match?(/unsubscribe|opt-out|remove/i)
      }
    end
  end

  def extract_links_from_plain(text)
    text.scan(URI.regexp(['http', 'https'])).map do |match|
      url = match[0]
      {
        href: url,
        text: url,
        is_verification: url.match?(/verify|confirm|token|magic|activate/i),
        is_unsubscribe: url.match?(/unsubscribe|opt-out|remove/i)
      }
    end
  end

  def check_alt_text_detailed(doc)
    images = doc.css('img')
    return { score: 100, findings: { total: 0, with_alt: 0, without_alt: [] } } if images.empty?

    with_alt = images.select { |img| img['alt'] && !img['alt'].strip.empty? }
    without_alt = images.reject { |img| img['alt'] && !img['alt'].strip.empty? }

    findings = {
      total: images.size,
      with_alt: with_alt.size,
      without_alt: without_alt.map { |img| { src: img['src'], alt_missing: img['alt'].nil? } }
    }

    score = (with_alt.size.to_f / images.size * 100).round

    { score: score, findings: findings }
  end

  def check_semantic_html_detailed(doc)
    semantic_tags = doc.css('header, nav, main, article, section, footer, aside')
    has_semantic = semantic_tags.any?

    findings = {
      has_semantic_tags: has_semantic,
      found_tags: semantic_tags.map(&:name).uniq
    }

    score = has_semantic ? 100 : 50

    { score: score, findings: findings }
  end

  def check_links_detailed(doc)
    links = doc.css('a')
    return { score: 100, findings: { total: 0, with_text: 0, without_text: [] } } if links.empty?

    with_text = links.select { |a| !a.text.strip.empty? || (a['aria-label'] && !a['aria-label'].empty?) }
    without_text = links.reject { |a| !a.text.strip.empty? || (a['aria-label'] && !a['aria-label'].empty?) }

    findings = {
      total: links.size,
      with_text: with_text.size,
      without_text: without_text.map { |a| { href: a['href'], text_empty: a.text.strip.empty? } }
    }

    score = (with_text.size.to_f / links.size * 100).round

    { score: score, findings: findings }
  end

  def check_alt_text(doc)
    images = doc.css('img')
    return 100 if images.empty?

    with_alt = images.select { |img| img['alt'] && !img['alt'].strip.empty? }
    (with_alt.size.to_f / images.size * 100).round
  end

  def check_semantic_html(doc)
    semantic_tags = doc.css('header, nav, main, article, section, footer, aside')
    semantic_tags.any? ? 100 : 50
  end

  def generate_recommendations(scores)
    recs = []
    recs << "Add alt text to all images" if scores[:images_with_alt] < 100
    recs << "Use semantic HTML tags (header, main, article, section)" if scores[:semantic_html] < 100
    recs << "Ensure all links have descriptive text or aria-label" if scores[:links_with_text] < 100
    recs
  end

  def forward_smtp_configured?
    MailCatcher.options[:forward_smtp_host] &&
      MailCatcher.options[:forward_smtp_port]
  end

  def parse_authentication_results(auth_header)
    results = {
      dmarc: nil,
      dkim: nil,
      spf: nil
    }

    # Parse DMARC result
    if auth_header.match?(/dmarc=/i)
      dmarc_match = auth_header.match(/dmarc=(\w+)/i)
      results[:dmarc] = dmarc_match[1].downcase if dmarc_match
    end

    # Parse DKIM result
    if auth_header.match?(/dkim=/i)
      dkim_match = auth_header.match(/dkim=(\w+)/i)
      results[:dkim] = dkim_match[1].downcase if dkim_match
    end

    # Parse SPF result
    if auth_header.match?(/spf=/i)
      spf_match = auth_header.match(/spf=(\w+)/i)
      results[:spf] = spf_match[1].downcase if spf_match
    end

    results
  end
end
