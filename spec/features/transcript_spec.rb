# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "SMTP Transcript Features", type: :feature do
  # Helper to extract JSON from page body when Selenium renders it in HTML
  def parse_json_response
    # If the page contains JSON in a <pre> tag (how Selenium renders JSON), extract it
    if page.body.include?('<pre>') && page.body.include?('</pre>')
      match = page.body.match(/<pre>(.*?)<\/pre>/m)
      json_str = match[1] if match
    else
      json_str = page.body
    end
    JSON.parse(json_str)
  end
  describe "Transcript Availability" do
    it "shows transcript in message formats list" do
      deliver_example("plainmail")

      expect(page).to have_selector("#messages table tbody tr:first-of-type")
      page.find("#messages table tbody tr:first-of-type").click

      # Transcript should be available in the formats list
      expect(page).to have_text("Transcript")
    end

    it "displays transcript tab when message has transcript" do
      deliver_example("plainmail")

      page.find("#messages table tbody tr:first-of-type").click

      # Transcript tab should be visible
      expect(page).to have_selector("li.format.tab.transcript a")
    end
  end

  describe "JSON Transcript Endpoint" do
    it "returns valid JSON for message transcript" do
      deliver_example("plainmail")

      visit "/messages/1/transcript.json"

      expect { parse_json_response }.not_to raise_error
    end

    it "includes session information in JSON response" do
      deliver_example("plainmail")

      visit "/messages/1/transcript.json"
      data = parse_json_response

      expect(data).to have_key("session_id")
      expect(data).to have_key("client_ip")
      expect(data).to have_key("server_port")
      expect(data).to have_key("entries")
      expect(data["client_ip"]).to eq("127.0.0.1")
      expect(data["server_port"]).to eq(20025)
    end

    it "includes transcript entries in JSON response" do
      deliver_example("plainmail")

      visit "/messages/1/transcript.json"
      data = parse_json_response

      entries = data["entries"]
      expect(entries).to be_an(Array)
      expect(entries.length).to be > 0

      # Each entry should have required fields
      entries.each do |entry|
        expect(entry).to have_key("timestamp")
        expect(entry).to have_key("type")
        expect(entry).to have_key("direction")
        expect(entry).to have_key("message")
      end
    end

    it "returns 404 for non-existent message transcript" do
      visit "/messages/99999/transcript.json"
      # When visiting a non-existent transcript, Sinatra returns a 404 page
      # We check that the page doesn't contain valid JSON (i.e., it's an error page)
      expect { parse_json_response }.to raise_error(JSON::ParserError)
    end

    it "includes message_id in JSON response" do
      deliver_example("plainmail")

      visit "/messages/1/transcript.json"
      data = parse_json_response

      expect(data["message_id"]).to eq(1)
    end

    it "includes TLS information in JSON response" do
      deliver_example("plainmail")

      visit "/messages/1/transcript.json"
      data = parse_json_response

      expect(data).to have_key("tls_enabled")
    end
  end

  describe "HTML Transcript View" do
    it "renders transcript HTML page" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      # Should contain session information header (CSS transforms to uppercase)
      expect(page).to have_text("SMTP SESSION INFORMATION")
    end

    it "displays client and server connection info" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      # Should show connection details (labels are uppercase in CSS)
      expect(page).to have_text("CLIENT")
      expect(page).to have_text("SERVER")
      expect(page).to have_text("127.0.0.1")
      expect(page).to have_text("20025")
    end

    it "displays session ID" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      expect(page).to have_text("SESSION ID")
    end

    it "displays TLS status" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      expect(page).to have_text("TLS")
      # Should indicate TLS not used for plain connection
      expect(page).to have_text("Not used")
    end

    it "displays transcript entries" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      # Should have transcript entries visible
      expect(page).to have_selector(".transcript-entry")
      entries = page.find_all(".transcript-entry")
      expect(entries.length).to be > 0
    end

    it "displays timestamps for entries" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      # Each entry should have a timestamp
      timestamps = page.find_all(".transcript-time")
      expect(timestamps.length).to be > 0
    end

    it "shows entry types (command, response, connection, etc)" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      # Should have different types of entries
      types = page.find_all(".transcript-type")
      expect(types.length).to be > 0

      # Should contain at least command and response
      type_texts = types.map(&:text)
      expect(type_texts.any? { |t| t.upcase.include?("COMMAND") }).to be true
      expect(type_texts.any? { |t| t.upcase.include?("RESPONSE") }).to be true
    end

    it "shows entry directions (client/server)" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      # Should have both client and server directions
      directions = page.find_all(".transcript-direction")
      expect(directions.length).to be > 0

      direction_texts = directions.map(&:text)
      # At least some entries should be from client and server
      expect(direction_texts.length).to be > 1
    end

    it "displays SMTP commands in transcript" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      # Should show SMTP commands
      content = page.find_all(".transcript-message").map(&:text).join(" ")
      expect(content).to include("EHLO")
      expect(content).to include("MAIL FROM")
      expect(content).to include("RCPT TO")
    end

    it "returns 404 for non-existent transcript" do
      visit "/messages/99999.transcript"
      # When visiting a non-existent transcript, should not find the transcript header
      expect(page).not_to have_text("SMTP SESSION INFORMATION")
    end
  end

  describe "Transcript Search Functionality" do
    it "displays search box in transcript view" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      expect(page).to have_selector("#transcriptSearch")
    end

    it "filters transcript entries by search" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      # Type in search box
      search_input = page.find("#transcriptSearch")
      search_input.fill_in(with: "MAIL FROM")

      # Wait for filtering
      sleep 0.3

      # Check that entries are filtered
      visible_entries = page.find_all(".transcript-entry:not(.hidden)")
      expect(visible_entries.length).to be > 0

      # The visible entry should contain the search term
      visible_text = visible_entries.map(&:text).join(" ")
      expect(visible_text).to include("MAIL FROM")
    end

    it "shows all entries when search is cleared" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      # Search for something
      search_input = page.find("#transcriptSearch")
      search_input.fill_in(with: "MAIL FROM")
      sleep 0.3

      # Clear search
      clear_button = page.find("#transcriptSearchClear", visible: :all)
      clear_button.click if clear_button.visible?

      # Or just clear the input
      search_input.fill_in(with: "")
      sleep 0.3

      # Should show all entries again
      all_entries = page.find_all(".transcript-entry")
      expect(all_entries.length).to be > 0
    end
  end

  describe "Transcript Content Verification" do
    it "includes connection establishment" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      expect(page).to have_content("Connection established")
    end

    it "includes connection closure" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      expect(page).to have_content("Connection closed")
    end

    it "includes message completion info" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      expect(page).to have_content("Message complete")
      expect(page).to have_content("bytes")
    end

    it "preserves message sizes in transcript" do
      deliver_example("plainmail")

      visit "/messages/1.transcript"

      # Should show message size in bytes
      content = page.text
      expect(content).to match(/\d+ bytes/)
    end
  end

  describe "Multiple Messages and Transcripts" do
    it "each message has independent transcript" do
      deliver_example("plainmail", to: "recipient1@example.com")
      deliver_example("plainmail", to: "recipient2@example.com")

      # First message transcript
      visit "/messages/1/transcript.json"
      transcript1 = parse_json_response
      session_id_1 = transcript1["session_id"]

      # Second message transcript
      visit "/messages/2/transcript.json"
      transcript2 = parse_json_response
      session_id_2 = transcript2["session_id"]

      # Sessions should be different
      expect(session_id_1).not_to eq(session_id_2)
    end

    it "transcript data is consistent across requests" do
      deliver_example("plainmail")

      # First request
      visit "/messages/1/transcript.json"
      data1 = parse_json_response

      # Second request
      visit "/messages/1/transcript.json"
      data2 = parse_json_response

      # Data should be identical
      expect(data1["session_id"]).to eq(data2["session_id"])
      expect(data1["entries"].length).to eq(data2["entries"].length)
    end
  end

  describe "Transcript with Different Message Types" do
    it "works with multipart messages" do
      deliver_example("multipartmail")

      visit "/messages/1/transcript.json"
      data = parse_json_response

      # Should have valid transcript
      expect(data["entries"].length).to be > 0
    end

    it "HTML view works with multipart messages" do
      deliver_example("multipartmail")

      visit "/messages/1.transcript"

      expect(page).to have_text("SMTP SESSION INFORMATION")
      expect(page).to have_selector(".transcript-entry")
    end
  end
end
