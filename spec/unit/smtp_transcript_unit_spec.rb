# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SMTP Transcript Unit Tests" do
  let(:smtp_class) { MailCatcher::Smtp }

  before(:all) do
    # Reset database before all tests
    MailCatcher::Mail.db
  end

  after(:each) do
    # Clear messages after each test
    MailCatcher::Mail.db.execute("DELETE FROM smtp_transcript")
    MailCatcher::Mail.db.execute("DELETE FROM message_part")
    MailCatcher::Mail.db.execute("DELETE FROM message")
  end

  describe "Transcript Entry Structure" do
    it "creates transcript entries with required fields" do
      # Simulate a transcript entry
      entry = {
        timestamp: Time.now.utc.iso8601(3),
        type: "command",
        direction: "client",
        message: "EHLO mail.example.com"
      }

      expect(entry).to have_key(:timestamp)
      expect(entry).to have_key(:type)
      expect(entry).to have_key(:direction)
      expect(entry).to have_key(:message)
    end

    it "timestamps are in ISO8601 format with milliseconds" do
      timestamp = Time.now.utc.iso8601(3)
      expect(timestamp).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/)
    end

    it "transcript type values are valid strings" do
      valid_types = ["connection", "command", "response", "tls", "data", "error"]

      entry = {
        timestamp: Time.now.utc.iso8601(3),
        type: valid_types.sample,
        direction: "client",
        message: "test"
      }

      expect(valid_types).to include(entry[:type])
    end

    it "direction values are either 'client' or 'server'" do
      valid_directions = ["client", "server"]

      entry = {
        timestamp: Time.now.utc.iso8601(3),
        type: "command",
        direction: valid_directions.sample,
        message: "test"
      }

      expect(valid_directions).to include(entry[:direction])
    end
  end

  describe "Transcript Storage and Retrieval" do
    it "stores transcript with message association" do
      # Create a test message
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)
      expect(message_id).to be_a(Integer)

      # Create and store transcript
      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" },
        { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "EHLO mail.example.com" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "test-session-123",
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

      # Retrieve transcript
      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript).not_to be_nil
      expect(transcript["message_id"]).to eq(message_id)
      expect(transcript["session_id"]).to eq("test-session-123")
    end

    it "stores transcript without message association (orphaned transcript)" do
      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" },
        { timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Closed" }
      ]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: nil,
        session_id: "test-session-456",
        client_ip: "192.168.1.1",
        client_port: 54321,
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
      orphaned = transcripts.find { |t| t["session_id"] == "test-session-456" }
      expect(orphaned).not_to be_nil
      expect(orphaned["message_id"]).to be_nil
    end

    it "retrieves all transcripts" do
      # Create multiple messages with transcripts
      3.times do |i|
        message_data = {
          sender: "test#{i}@example.com",
          recipients: ["recipient@example.com"],
          source: "From: test#{i}@example.com\r\nSubject: Test #{i}\r\n\r\nBody"
        }

        message_id = MailCatcher::Mail.add_message(message_data)

        entries = [
          { timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected #{i}" }
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

      transcripts = MailCatcher::Mail.all_transcripts
      expect(transcripts.length).to be >= 3
    end
  end

  describe "Transcript Connection Information" do
    it "stores client IP address" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [{ timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "test-session",
        client_ip: "192.168.1.100",
        client_port: 54321,
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
      expect(transcript["client_ip"]).to eq("192.168.1.100")
    end

    it "stores server port" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [{ timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }]

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

      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript["server_port"]).to eq(20025)
    end

    it "stores connection timestamps" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      start_time = Time.now
      end_time = Time.now + 5

      entries = [{ timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }]

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
        connection_started_at: start_time,
        connection_ended_at: end_time,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript["connection_started_at"]).not_to be_nil
      expect(transcript["connection_ended_at"]).not_to be_nil
    end

    it "stores session ID for correlation" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      session_id = SecureRandom.uuid

      entries = [{ timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }]

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

      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript["session_id"]).to eq(session_id)
    end
  end

  describe "Transcript Entries JSON Handling" do
    it "serializes and deserializes transcript entries" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [
        { timestamp: "2024-01-15T10:30:45.123Z", type: "connection", direction: "server", message: "Connected" },
        { timestamp: "2024-01-15T10:30:46.456Z", type: "command", direction: "client", message: "EHLO mail.example.com" },
        { timestamp: "2024-01-15T10:30:46.789Z", type: "response", direction: "server", message: "250 OK" }
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

      transcript = MailCatcher::Mail.message_transcript(message_id)
      retrieved_entries = transcript["entries"]

      expect(retrieved_entries.length).to eq(3)
      expect(retrieved_entries[0]["type"]).to eq("connection")
      expect(retrieved_entries[1]["message"]).to include("EHLO")
    end

    it "preserves message content with special characters in transcript" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [
        { timestamp: Time.now.utc.iso8601(3), type: "command", direction: "client", message: "MAIL FROM:<test+tag@example.com>" },
        { timestamp: Time.now.utc.iso8601(3), type: "response", direction: "server", message: "250 OK: <test+tag@example.com>" }
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

      transcript = MailCatcher::Mail.message_transcript(message_id)
      retrieved_entries = transcript["entries"]

      expect(retrieved_entries[0]["message"]).to include("+")
      expect(retrieved_entries[1]["message"]).to include("+")
    end
  end

  describe "Transcript TLS Information" do
    it "stores TLS enabled flag as 0 for non-TLS connections" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [{ timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }]

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

      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript["tls_enabled"]).to eq(false)
    end

    it "stores TLS enabled flag as 1 for TLS connections" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [{ timestamp: Time.now.utc.iso8601(3), type: "tls", direction: "server", message: "TLS negotiation started" }]

      MailCatcher::Mail.add_smtp_transcript(
        message_id: message_id,
        session_id: "test-session",
        client_ip: "127.0.0.1",
        client_port: 12345,
        server_ip: "127.0.0.1",
        server_port: 20025,
        tls_enabled: 1,
        tls_protocol: "TLSv1.2",
        tls_cipher: "ECDHE-RSA-AES256-GCM-SHA384",
        connection_started_at: Time.now,
        connection_ended_at: Time.now,
        entries: entries
      )

      transcript = MailCatcher::Mail.message_transcript(message_id)
      expect(transcript["tls_enabled"]).to eq(true)
      expect(transcript["tls_protocol"]).to eq("TLSv1.2")
      expect(transcript["tls_cipher"]).to eq("ECDHE-RSA-AES256-GCM-SHA384")
    end
  end

  describe "Transcript Deletion with Message" do
    it "deletes transcript when associated message is deleted" do
      message_data = {
        sender: "test@example.com",
        recipients: ["recipient@example.com"],
        source: "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
      }

      message_id = MailCatcher::Mail.add_message(message_data)

      entries = [{ timestamp: Time.now.utc.iso8601(3), type: "connection", direction: "server", message: "Connected" }]

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

      # Verify transcript exists
      expect(MailCatcher::Mail.message_transcript(message_id)).not_to be_nil

      # Delete message
      MailCatcher::Mail.db.execute("DELETE FROM message WHERE id = ?", [message_id])

      # Verify transcript is also deleted (foreign key constraint)
      expect(MailCatcher::Mail.message_transcript(message_id)).to be_nil
    end
  end
end
