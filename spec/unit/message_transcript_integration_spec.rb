# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Message-Transcript Integration" do
  before(:all) do
    MailCatcher::Mail.db
  end

  after(:each) do
    MailCatcher::Mail.db.execute("DELETE FROM smtp_transcript")
    MailCatcher::Mail.db.execute("DELETE FROM message_part")
    MailCatcher::Mail.db.execute("DELETE FROM message")
  end

  describe "Message and Transcript Association" do
    it "creates transcript associated with message" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      # Verify message exists
      message = MailCatcher::Mail.message(message_id)
      expect(message).not_to be_nil

      # Create transcript for this message
      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "test-session",
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

      # Verify transcript is associated
      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript).not_to be_nil
      expect(transcripttranscript["message_id["message_id"]).to eq(message_id)
    end

    it "retrieves correct transcript for specific message" do
      # Create two messages with different transcripts
      message_ids = []
      session_ids = []

      2.times do |i|
        message_data = {
          sender: "test#{i}@example.com",
          recipients: ["recipient@example.com"],
          source: "From: test#{i}@example.com\r\nSubject: Test #{i}\r\n\r\nBody"
        }

        message_id = MailCatcher::Mail.add_message(message_data)
        message_ids << message_id

        session_id = "session-#{i}"
        session_ids << session_id

        entries = [
          { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "MAIL FROM:<test#{i}@example.com>" }
        ]

        MailCatcher::Mail.add_smtp_transcript(
          message_id: message_id,
          session_id: session_id,
          client_ip: "127.0.0.1",
          client_port: 12345 + i,
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

      # Verify each message has correct transcript
      transcript1 = MailCatcher::Mail.message_transcript(message_ids[0])
      transcript2 = MailCatcher::Mail.message_transcript(message_ids[1])

      expect(transcripttranscript1[:["session_id]).to eq(session_ids[0])
      expect(transcripttranscript2[:["session_id]).to eq(session_ids[1])

      # Verify they're different
      expect(transcripttranscript1[:["session_id]).not_to eq(transcripttranscript2[:["session_id])
    end

    it "maintains message properties while storing transcript" do
      message_data = {
        sender: "sender@example.com",
        recipients: ["recipient@example.com"],
        subject: "Test Subject",
        source: "From: sender@example.com\r\nTo: recipient@example.com\r\nSubject: Test Subject\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      # Store transcript
      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "test",
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

      # Verify message data is unchanged
      message = MailCatcher::Mail.message(message_id)
      expect(message[:sender]).to eq("sender@example.com")
      expect(message[:recipients]).to eq(["recipient@example.com"])
    end
  end

  describe "Multiple Transcripts Per Connection" do
    it "handles multiple messages in single SMTP session" do
      session_id = SecureRandom.uuid

      # Create two messages sent in same session
      message_ids = []

      2.times do |i|
        message_data = {
          sender: "test@example.com",
          recipients: ["recipient#{i}@example.com"],
          source: "From: test@example.com\r\nSubject: Message #{i}\r\n\r\nBody #{i}"
        }

        message_id = MailCatcher::Mail.add_message(message_data)
        message_ids << message_id

        # Same session_id for both
        entries = [
          { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "MAIL FROM:<test@example.com>" },
          { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "RCPT TO:<recipient#{i}@example.com>" }
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

      # Find all transcripts with this session_id
      transcripts = MailCatcher::Mail.all_transcripts
      session_transcripts = transcripts.select { |t| t["session_id"] == session_id }

      expect(session_transcripts.length).to eq(2)

      # Each should have different message_id
      message_ids_from_transcripts = session_transcripts.map { |t| t[:message_id] }
      expect(message_ids_from_transcripts).to match_array(message_ids)
    end
  end

  describe "Transcript Deletion with Message" do
    it "automatically deletes transcript when message is deleted" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      # Create transcript
      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "test",
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

      # Verify transcript exists
      transcript_before = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript_before).not_to be_nil

      # Delete message
      MailCatcher::Mail.db.execute("DELETE FROM message WHERE id = ?", [message_id])

      # Verify transcript is also deleted
      transcript_after = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript_after).to be_nil
    end

    it "preserves orphaned transcripts (without message_id)" do
      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }
      ]

      # Create orphaned transcript
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
      orphaned = transcripts.find { |t| t[:session_id] == "orphaned" }
      expect(orphaned).not_to be_nil

      # Orphaned should still exist even if we delete some messages
      MailCatcher::Mail.db.execute("DELETE FROM message")

      transcripts_after = MailCatcher::Mail.all_transcripts
      orphaned_after = transcripts_after.find { |t| t[:session_id] == "orphaned" }
      expect(orphaned_after).not_to be_nil
    end
  end

  describe "Message and Transcript Timing" do
    it "stores connection start and end times" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      start_time = Time.now.utc
      sleep 0.1
      end_time = Time.now.utc

      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "timing-test",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 0,
        tls_protocol: nil,
        tls_cipher: nil,
        connection_started_at: start_time,
        connection_ended_at: end_time,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)

      # Connection duration should be positive
      expect(transcripttranscript["connection_ended_at["connection_ended_at"]).to be >= transcripttranscript["connection_started_at["connection_started_at"]
    end

    it "records message creation timestamp in database" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      before_creation = Time.now
      message_id = MailCatcher::Mail.add_message(message_data)
      after_creation = Time.now

      message = MailCatcher::Mail.message(message_id)

      # Message should have created_at timestamp
      expect(message).to have_key("created_at")
    end
  end

  describe "Transcript Content Validation" do
    it "preserves SMTP commands in transcript entries" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "EHLO mail.example.com" },
        { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "MAIL FROM:<test@example.com>" },
        { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "RCPT TO:<recipient@example.com>" },
        { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "DATA" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "commands",
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
      retrieved_entries = transcripttranscript["entries["entries"]

      # Verify all commands are present
      commands = retrieved_entries.map { |e| e["message"] }
      expect(commands).to include("EHLO mail.example.com")
      expect(commands).to include("MAIL FROM:<test@example.com>")
      expect(commands).to include("RCPT TO:<recipient@example.com>")
      expect(commands).to include("DATA")
    end

    it "preserves server responses in transcript" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "response", direction: "server", message: "220 mail.example.com ESMTP" },
        { timestamp: Time.now.utc.iso8601(3), type: "response", direction: "server", message: "250-mail.example.com Hello" },
        { timestamp: Time.now.utc.iso8601(3), type: "response", direction: "server", message: "250 OK" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "responses",
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
      retrieved_entries = transcripttranscript["entries["entries"]

      # Verify responses are present
      responses = retrieved_entries.map { |e| e["message"] }
      expect(responses).to include("220 mail.example.com ESMTP")
      expect(responses[0]).to include("220")  # First response code
    end
  end

  describe "All Transcripts Query" do
    it "returns all stored transcripts" do
      # Create 5 messages with transcripts
      5.times do |i|
        message_data = {
          sender: "test#{i}@example.com",
          recipients: ["recipient@example.com"],
          source: "From: test#{i}@example.com\r\nSubject: Test #{i}\r\n\r\nBody"
        }

        message_id = MailCatcher::Mail.add_message(message_data)

        entries = [
          { timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }
        ]

        MailCatcher::Mail.add_smtp_transcript(
          message_id: message_id,
          session_id: "session-#{i}",
          client_ip: "127.0.0.1",
          client_port: 12345 + i,
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

      all_transcripts = MailCatcher::Mail.all_transcripts
      expect(all_transcripts.length).to be >= 5
    end
  end
end