# frozen_string_literal: true

require "eventmachine"
require "fileutils"
require "json"
require "mail"
require "sqlite3"

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
        db.execute("CREATE INDEX IF NOT EXISTS idx_smtp_transcript_message_id ON smtp_transcript(message_id)")
        db.execute("CREATE INDEX IF NOT EXISTS idx_smtp_transcript_session_id ON smtp_transcript(session_id)")
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

  private

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
