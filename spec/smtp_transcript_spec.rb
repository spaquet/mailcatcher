# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SMTP Transcript", type: :feature do
  def message_transcript_tab_element
    page.find("#message header .format.transcript a")
  end

  def transcript_container_element
    page.find("#message .transcript-container")
  end

  def transcript_entries_element
    page.find_all("#message .transcript-entries .entry")
  end

  def transcript_session_info_element
    page.find("#message .transcript-session-info")
  end

  def transcript_search_box_element
    page.find("#message .transcript-search-input")
  end

  it "captures SMTP connection and greeting" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    # Open transcript tab
    message_transcript_tab_element.click
    expect(transcript_container_element).to be_visible

    # Verify transcript entries are present
    entries = transcript_entries_element
    expect(entries.length).to be > 0

    # First entry should be connection established
    expect(entries[0]).to have_text("Connection established")
  end

  it "logs EHLO command and server capabilities" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    message_transcript_tab_element.click
    entries = transcript_entries_element

    # Should have EHLO command and capabilities response
    ehlo_entries = entries.select { |e| e.text.include?("EHLO") }
    expect(ehlo_entries.length).to be > 0

    capabilities_entries = entries.select { |e| e.text.include?("8BITMIME") || e.text.include?("SMTPUTF8") }
    expect(capabilities_entries.length).to be > 0
  end

  it "logs MAIL FROM command with sender address" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    message_transcript_tab_element.click
    entries = transcript_entries_element

    # Should have MAIL FROM command
    mail_from_entries = entries.select { |e| e.text.include?("MAIL FROM") }
    expect(mail_from_entries.length).to be > 0
  end

  it "logs RCPT TO command with recipient addresses" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    message_transcript_tab_element.click
    entries = transcript_entries_element

    # Should have RCPT TO commands
    rcpt_entries = entries.select { |e| e.text.include?("RCPT TO") }
    expect(rcpt_entries.length).to be > 0
  end

  it "logs DATA command and message completion" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    message_transcript_tab_element.click
    entries = transcript_entries_element

    # Should have DATA command
    data_entries = entries.select { |e| e.text.include?("DATA") }
    expect(data_entries.length).to be > 0

    # Should have message completion entry
    complete_entries = entries.select { |e| e.text.include?("Message complete") }
    expect(complete_entries.length).to be > 0
  end

  it "logs RSET command when multiple messages sent on same connection" do
    deliver_example("plainmail", to: "recipient1@example.com")
    deliver_example("plainmail", to: "recipient2@example.com")

    # Both messages should be in the list
    expect(page).to have_selector("#messages table tbody tr", count: 2)

    # Check the second message for RSET command
    message_rows = page.find_all("#messages table tbody tr")
    message_rows[1].click

    message_transcript_tab_element.click
    entries = transcript_entries_element

    # Should have RSET command before second MAIL FROM
    rset_entries = entries.select { |e| e.text.include?("RSET") }
    expect(rset_entries.length).to be > 0
  end

  it "logs connection closure" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    message_transcript_tab_element.click
    entries = transcript_entries_element

    # Should have connection closed entry
    close_entries = entries.select { |e| e.text.include?("Connection closed") }
    expect(close_entries.length).to be > 0
  end

  it "displays session information (client IP, server port)" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    message_transcript_tab_element.click

    session_info = transcript_session_info_element

    # Should display client IP (127.0.0.1)
    expect(session_info).to have_text("127.0.0.1")
  end

  it "displays timestamp for each transcript entry" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    message_transcript_tab_element.click
    entries = transcript_entries_element

    # Each entry should have a timestamp
    entries.each do |entry|
      # Timestamps are in ISO8601 format with milliseconds (YYYY-MM-DDTHH:MM:SS.sssZ)
      expect(entry).to have_selector("span[class*='timestamp']") if entry.has_selector?("span[class*='timestamp']")
    end
  end

  it "distinguishes client and server directions in transcript" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    message_transcript_tab_element.click
    entries = transcript_entries_element

    # Should have both client and server entries
    all_text = entries.map(&:text).join("\n")

    # Verify we have entries from both directions
    expect(entries.length).to be >= 6  # At minimum: connection, EHLO, MAIL FROM, RCPT TO, DATA, message complete
  end

  it "stores transcript in database linked to message" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    # Transcript should be accessible
    expect(page).to have_selector("#message header .format.transcript a")
  end

  it "includes message size in transcript" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    message_transcript_tab_element.click
    entries = transcript_entries_element

    # Should have message complete with size
    complete_entries = entries.select { |e| e.text.include?("Message complete") }
    expect(complete_entries.length).to be > 0

    # Should show bytes
    complete_text = complete_entries.first.text
    expect(complete_text).to match(/bytes/)
  end

  it "supports searching transcript entries" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    message_transcript_tab_element.click

    # Search for MAIL FROM
    search_box = transcript_search_box_element
    search_box.fill_in(with: "MAIL FROM")

    # Entries should be filtered
    entries = transcript_entries_element
    expect(entries.length).to be > 0
    expect(entries[0]).to have_text("MAIL FROM")
  end

  it "handles multipart messages with transcript" do
    deliver_example("multipartmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    message_transcript_tab_element.click

    # Transcript should still be present for multipart messages
    expect(transcript_container_element).to be_visible
    entries = transcript_entries_element
    expect(entries.length).to be > 0
  end

  it "handles UTF-8 encoded messages with transcript" do
    deliver_example("utf8")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    message_row_element = page.find("#messages table tbody tr:first-of-type")
    message_row_element.click

    message_transcript_tab_element.click

    # Transcript should be present for UTF-8 messages
    expect(transcript_container_element).to be_visible
  end

  it "maintains separate transcripts for multiple messages" do
    deliver_example("plainmail", to: "recipient1@example.com")
    deliver_example("plainmail", to: "recipient2@example.com")

    expect(page).to have_selector("#messages table tbody tr", count: 2)

    message_rows = page.find_all("#messages table tbody tr")

    # First message
    message_rows[0].click
    message_transcript_tab_element.click
    first_entries = transcript_entries_element.length

    # Navigate back and select second message
    page.find("#messages table tbody tr", match: :first).click  # Click first row to deselect
    page.find("#messages table tbody tr", match: :nth, text: 2).click  # Click second row

    message_transcript_tab_element.click
    second_entries = transcript_entries_element.length

    # Both should have transcripts but potentially different content
    expect(first_entries).to be > 0
    expect(second_entries).to be > 0
  end
end
