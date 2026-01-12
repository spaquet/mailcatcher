# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SMTP Edge Cases and Error Handling" do
  before(:all) do
    MailCatcher::Mail.db
  end

  after(:each) do
    MailCatcher::Mail.db.execute("DELETE FROM smtp_transcript")
    MailCatcher::Mail.db.execute("DELETE FROM message_part")
    MailCatcher::Mail.db.execute("DELETE FROM message")
  end

  describe "Empty and Minimal Messages" do
    it "handles empty message body" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Empty\r\n\r\n"
      }

      message_id = MailCatcher::Mail.add_message(message_data)
      expect(message_id).to be_a(Integer)

      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" },
        { timestamp: Time.now.utc.iso8601(3), type: "data", direction: "client", message: "Message complete (0 bytes)" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "empty-msg",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript).not_to be_nil
    end

    it "handles minimal message with only required headers" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nTo: recipient@example.com\r\n\r\nMinimal"
      }

      message_id = MailCatcher::Mail.add_message(message_data)
      expect(message_id).to be_a(Integer)

      entries = [{ timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "minimal",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript).not_to be_nil
    end

    it "handles transcript with no entries" do
      # This shouldn't normally happen, but we test graceful handling
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      # Try to store with empty entries - should still work
      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "empty-entries",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: []
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript).not_to be_nil
      retrieved_entries = transcript["entries"]
      expect(retrieved_entries).to eq([])
    end
  end

  describe "Special Characters and Encoding" do
    it "handles special characters in email addresses" do
      message_data = {
        sender: "user+tag@example.co.uk",
        recipients: ["recipient+2024@sub.example.com"],
        source: "From: user+tag@example.co.uk\r\nTo: recipient+2024@sub.example.com\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "MAIL FROM:<user+tag@example.co.uk>" },
        { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "RCPT TO:<recipient+2024@sub.example.com>" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "special-chars",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      retrieved_entries = transcript["entries"]
      expect(retrieved_entries[0]["message"]).to include("+")
    end

    it "handles quoted-printable encoded messages in transcript" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nContent-Transfer-Encoding: quoted-printable\r\n\r\nHello=20World"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "data", direction: "client", message: "Message complete (50 bytes)" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "quoted-printable",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript).not_to be_nil
    end

    it "handles base64 encoded messages in transcript" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nContent-Transfer-Encoding: base64\r\n\r\nSGVsbG8gV29ybGQ="
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "data", direction: "client", message: "Message complete (45 bytes)" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "base64",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript).not_to be_nil
    end

    it "handles UTF-8 characters in transcript messages" do
      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "EHLO café.example.com" },
        { timestamp: Time.now.utc.iso8601(3), type: "response", direction: "server", message: "250 Привет" }
      ]

      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: UTF-8\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "utf8-chars",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      retrieved_entries = transcript["entries"]
      expect(retrieved_entries[0]["message"]).to include("café")
    end
  end

  describe "Large Messages" do
    it "handles very large message sizes in transcript" do
      large_body = "X" * (1024 * 1024)  # 1MB message
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Large\r\n\r\n#{large_body}"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "data", direction: "client", message: "Message complete (1048576 bytes)" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "large-msg",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript).not_to be_nil
      retrieved_entries = transcript["entries"]
      expect(retrieved_entries[0]["message"]).to include("1048576")
    end

    it "handles large number of transcript entries" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Many entries\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      # Create 1000 transcript entries
      entries = (1..1000).map do |i|
        { timestamp: Time.now.utc.iso8601(3), type: "command", direction: i.even? ? "client" : "server", message: "Entry #{i}" }
      end

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "many-entries",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      retrieved_entries = transcript["entries"]
      expect(retrieved_entries.length).to eq(1000)
    end
  end

  describe "Multiple Recipients" do
    it "handles multiple recipients in transcript" do
      recipients = ["recipient1@example.com", "recipient2@example.com", "recipient3@example.com"]
      message_data = {
        sender: "test@example.com",
        recipients: recipients,
        source: "From: test@example.com\r\nSubject: Multi\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = recipients.map do |recipient|
        { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "RCPT TO:<#{recipient}>" }
      end

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "multi-rcpt",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      retrieved_entries = transcript["entries"]
      expect(retrieved_entries.length).to eq(3)

      recipients.each do |recipient|
        expect(retrieved_entries.any? { |e| e["message"].include?(recipient) }).to be_truthy
      end
    end
  end

  describe "Null and Missing Values" do
    it "handles nil TLS protocol and cipher" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [{ timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "no-tls",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript["tls_protocol"]).to be_nil
      expect(transcript["tls_cipher"]).to be_nil
    end

    it "handles transcript with nil message_id (orphaned)" do
      entries = [{ timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: nil,
        session_id: "orphaned",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcripts = MailCatcher::Mail.all_transcripts
      orphaned = transcripts.find { |t| t["session_id"] == "orphaned" }
      expect(orphaned).not_to be_nil
      expect(orphaned[:message_id]).to be_nil
    end
  end

  describe "Concurrent Connection Handling" do
    it "maintains separate transcripts for different session IDs" do
      session_ids = ["session-1", "session-2", "session-3"]

      session_ids.each do |session_id|
        message_data = {
          sender: "test@example.com",
          recipients: ["recipient@example.com"],
          source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
        }

        message_id = MailCatcher::Mail.add_message(message_data)

        entries = [
          { timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected from #{session_id}" }
        ]

        MailCatcher::Mail.add_smtp_transcript(
          message_id: message_id,
          session_id: session_id,
          client_ip: "127.0.0.1",
          client_port: 12345,
          server_ip: "127.0.0.1",
          server_port: 20025,
          tls_enabled: 0,
          tls_protocol: nil,
          tls_cipher: nil,
          connection_started_at: Time.now,
          connection_ended_at: Time.now,
          entries: entries
        )
      end

      transcripts = MailCatcher::Mail.all_transcripts
      found_sessions = transcripts.select { |t| session_ids.include?(t["session_id"]) }
      expect(found_sessions.length).to eq(3)

      # Verify each session is unique
      found_sessions.each do |transcript|
        expect(session_ids).to include(transcript["session_id"])
      end
    end
  end

  describe "Transcript Message Content Validation" do
    it "preserves newlines in transcript entries" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      # Entries with multiline capabilities response
      entries = [
        {
          timestamp: Time.now.utc.iso8601(3),
          type: "response",
          direction: "server",
          message: "250-8BITMIME\r\n250-SMTPUTF8\r\n250 OK"
        }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "multiline",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      retrieved_entries = transcript["entries"]
      expect(retrieved_entries[0]["message"]).to include("\r\n")
    end

    it "preserves empty messages in transcript" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      # Empty message in transcript
      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "empty-msg",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      retrieved_entries = transcript["entries"]
      expect(retrieved_entries[0]["message"]).to eq("")
    end
  end
end