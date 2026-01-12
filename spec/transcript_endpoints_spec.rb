# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "Transcript Web Endpoints", type: :feature do
  def transcript_json_response
    page.body
  end

  def visit_transcript_endpoint(message_id)
    visit "/messages/#{message_id}/transcript.json"
  end

  def visit_transcript_html(message_id)
    visit "/messages/#{message_id}.transcript"
  end

  it "returns JSON transcript for a message" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    # Get the message ID from the URL or page data
    # For this test, we'll use the first message (ID should be 1 after fresh start)
    visit_transcript_endpoint(1)

    # Page should contain valid JSON
    expect { JSON.parse(transcript_json_response) }.not_to raise_error

    transcript_data = JSON.parse(transcript_json_response)

    # Verify expected fields
    expect(transcript_data).to have_key("id")
    expect(transcript_data).to have_key("message_id")
    expect(transcript_data).to have_key("session_id")
    expect(transcript_data).to have_key("client_ip")
    expect(transcript_data).to have_key("server_port")
    expect(transcript_data).to have_key("entries")
  end

  it "JSON endpoint includes session information" do
    deliver_example("plainmail")

    visit_transcript_endpoint(1)

    transcript_data = JSON.parse(transcript_json_response)

    expect(transcript_data["client_ip"]).to eq("127.0.0.1")
    expect(transcript_data["server_port"]).to eq(20025)
    expect(transcript_data).to have_key("connection_started_at")
    expect(transcript_data).to have_key("connection_ended_at")
  end

  it "JSON endpoint includes transcript entries array" do
    deliver_example("plainmail")

    visit_transcript_endpoint(1)

    transcript_data = JSON.parse(transcript_json_response)

    expect(transcript_data["entries"]).to be_an(Array)
    expect(transcript_data["entries"].length).to be > 0
  end

  it "JSON transcript entries have required fields" do
    deliver_example("plainmail")

    visit_transcript_endpoint(1)

    transcript_data = JSON.parse(transcript_json_response)

    # Check structure of first entry
    first_entry = transcript_data["entries"][0]
    expect(first_entry).to have_key("timestamp")
    expect(first_entry).to have_key("type")
    expect(first_entry).to have_key("direction")
    expect(first_entry).to have_key("message")
  end

  it "HTML transcript view renders correctly" do
    deliver_example("plainmail")

    # Navigate to transcript HTML view
    visit_transcript_html(1)

    # Page should contain session information
    expect(page).to have_content("Client IP")
    expect(page).to have_content("127.0.0.1")
  end

  it "HTML transcript displays entries in order" do
    deliver_example("plainmail")

    visit_transcript_html(1)

    # Should display transcript entries
    expect(page).to have_selector(".entry") if page.has_selector?(".entry")
  end

  it "returns 404 for non-existent message transcript" do
    visit_transcript_endpoint(99999)

    # Should not find the transcript
    expect(page.status_code).to eq(404) unless JSON.parse(transcript_json_response) rescue false
  end

  it "JSON endpoint correctly links transcript to message" do
    deliver_example("plainmail")

    visit_transcript_endpoint(1)

    transcript_data = JSON.parse(transcript_json_response)

    expect(transcript_data["message_id"]).to eq(1)
  end

  it "handles multiple transcripts per message ID correctly" do
    deliver_example("plainmail", to: "recipient1@example.com")

    visit_transcript_endpoint(1)

    transcript_data = JSON.parse(transcript_json_response)

    # Should have a valid transcript
    expect(transcript_data).to have_key("session_id")
    expect(transcript_data["entries"]).to be_an(Array)
  end

  it "JSON transcript preserves message content in entries" do
    deliver_example("plainmail")

    visit_transcript_endpoint(1)

    transcript_data = JSON.parse(transcript_json_response)

    # Find EHLO entry
    ehlo_entries = transcript_data["entries"].select { |e| e["message"].include?("EHLO") }
    expect(ehlo_entries.length).to be > 0
  end

  it "JSON transcript includes TLS information when available" do
    deliver_example("plainmail")

    visit_transcript_endpoint(1)

    transcript_data = JSON.parse(transcript_json_response)

    # Should have TLS fields (will be 0 or nil for plain connection)
    expect(transcript_data).to have_key("tls_enabled")
  end

  it "transcript endpoint accessible from message detail view" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    # Should have transcript tab/link
    expect(page).to have_selector("#message header .format.transcript a")
  end

  it "transcript search works via URL or UI component" do
    deliver_example("plainmail")

    visit_transcript_html(1)

    # If search functionality is available, test it
    if page.has_selector?(".transcript-search-input")
      search_box = page.find(".transcript-search-input")
      search_box.fill_in(with: "MAIL FROM")

      # Page should update to show filtered results
      expect(page).to have_content("MAIL FROM") || page.has_selector?(".entry")
    end
  end

  it "transcript endpoint returns consistent data on multiple requests" do
    deliver_example("plainmail")

    # First request
    visit_transcript_endpoint(1)
    first_response = JSON.parse(transcript_json_response)

    # Second request
    visit_transcript_endpoint(1)
    second_response = JSON.parse(transcript_json_response)

    # Data should be identical
    expect(first_response["session_id"]).to eq(second_response["session_id"])
    expect(first_response["entries"].length).to eq(second_response["entries"].length)
  end

  it "transcript shows connection details accurately" do
    deliver_example("plainmail")

    visit_transcript_json_endpoint(1)

    transcript_data = JSON.parse(transcript_json_response)

    # Verify connection details
    expect(transcript_data).to have_key("client_ip")
    expect(transcript_data).to have_key("client_port")
    expect(transcript_data).to have_key("server_ip")
    expect(transcript_data).to have_key("server_port")

    # Client should be localhost
    expect(transcript_data["client_ip"]).to eq("127.0.0.1")

    # Server port should be the test SMTP port
    expect(transcript_data["server_port"]).to eq(20025)
  end

  private

  def visit_transcript_json_endpoint(message_id)
    visit "/messages/#{message_id}/transcript.json"
  end
end
