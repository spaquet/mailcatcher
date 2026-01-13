# frozen_string_literal: true

require "spec_helper"
require "mail_catcher/integrations/mcp_tools"

describe MailCatcher::Integrations::MCPTools do
  let(:default_from) { "sender@example.com" }
  let(:default_to) { ["recipient@example.com"] }
  let(:subject) { "Test Email" }

  before do
    # Clear any existing messages
    MailCatcher::Mail.delete!
  end

  describe ".tool" do
    it "returns tool definition by name" do
      tool = described_class.tool(:search_messages)
      expect(tool).to be_a(Hash)
      expect(tool[:description]).not_to be_empty
      expect(tool[:input_schema]).to be_a(Hash)
    end

    it "returns nil for unknown tool" do
      tool = described_class.tool(:unknown_tool)
      expect(tool).to be_nil
    end
  end

  describe ".all_tools" do
    it "returns all tool definitions" do
      tools = described_class.all_tools
      expect(tools).to be_a(Hash)
      expect(tools.keys).to include(:search_messages, :extract_token_or_link, :delete_message)
    end

    it "has exactly 7 tools" do
      expect(described_class.all_tools.keys.length).to eq(7)
    end
  end

  describe ".tool_names" do
    it "returns array of tool names as strings" do
      names = described_class.tool_names
      expect(names).to be_a(Array)
      expect(names).to include("search_messages", "extract_token_or_link", "delete_message")
    end
  end

  describe ".call_tool - search_messages" do
    before do
      deliver("From: #{default_from}\r\nTo: #{default_to.join(', ')}\r\nSubject: Test Email\r\n\r\nBody text",
              from: default_from, to: default_to.first)
    end

    it "searches for messages by query" do
      result = described_class.call_tool(:search_messages, { "query" => "Test" })
      expect(result[:count]).to eq(1)
      expect(result[:messages]).to be_a(Array)
      expect(result[:messages].first[:subject]).to eq("Test Email")
    end

    it "respects limit parameter" do
      deliver("From: #{default_from}\r\nTo: #{default_to.join(', ')}\r\nSubject: Email 2\r\n\r\nBody",
              from: default_from, to: default_to.first)

      result = described_class.call_tool(:search_messages, { "query" => "Email", "limit" => 1 })
      expect(result[:count]).to eq(1)
    end

    it "returns empty results for no matches" do
      result = described_class.call_tool(:search_messages, { "query" => "Nonexistent" })
      expect(result[:count]).to eq(0)
      expect(result[:messages]).to be_empty
    end
  end

  describe ".call_tool - get_latest_message_for" do
    before do
      deliver("From: #{default_from}\r\nTo: user1@example.com\r\nSubject: First\r\n\r\nBody",
              from: default_from, to: "user1@example.com")
      sleep 0.1
      deliver("From: #{default_from}\r\nTo: user1@example.com\r\nSubject: Second\r\n\r\nBody",
              from: default_from, to: "user1@example.com")
    end

    it "returns latest message for recipient" do
      result = described_class.call_tool(:get_latest_message_for, { "recipient" => "user1@example.com" })
      expect(result[:found]).to eq(true)
      expect(result[:message]).to be_a(Hash)
      expect(result[:message][:subject]).to eq("Second")
    end

    it "filters by subject_contains" do
      result = described_class.call_tool(:get_latest_message_for, {
        "recipient" => "user1@example.com",
        "subject_contains" => "First"
      })
      expect(result[:found]).to eq(true)
      expect(result[:message][:subject]).to eq("First")
    end

    it "returns error when no matching message found" do
      result = described_class.call_tool(:get_latest_message_for, { "recipient" => "nobody@example.com" })
      expect(result[:found]).to eq(false)
      expect(result[:error]).not_to be_empty
    end
  end

  describe ".call_tool - extract_token_or_link" do
    before do
      email_with_otp = "From: #{default_from}\r\nTo: #{default_to.join(', ')}\r\nSubject: OTP\r\n\r\nYour OTP: 123456"
      deliver(email_with_otp, from: default_from, to: default_to.first)
      @message_id = MailCatcher::Mail.messages.first["id"]
    end

    it "extracts OTP codes" do
      result = described_class.call_tool(:extract_token_or_link, {
        "message_id" => @message_id,
        "kind" => "otp"
      })
      expect(result[:extracted]).to be_a(Array)
    end

    it "returns error for invalid kind" do
      result = described_class.call_tool(:extract_token_or_link, {
        "message_id" => @message_id,
        "kind" => "invalid"
      })
      expect(result[:error]).to include("Invalid kind")
    end

    it "extracts all types when kind is 'all'" do
      result = described_class.call_tool(:extract_token_or_link, {
        "message_id" => @message_id,
        "kind" => "all"
      })
      expect(result[:magic_links]).to be_a(Array)
      expect(result[:otps]).to be_a(Array)
      expect(result[:reset_tokens]).to be_a(Array)
    end

    it "returns error for non-existent message" do
      result = described_class.call_tool(:extract_token_or_link, {
        "message_id" => 99999,
        "kind" => "otp"
      })
      expect(result[:error]).to include("not found")
    end
  end

  describe ".call_tool - get_parsed_auth_info" do
    before do
      email = "From: #{default_from}\r\nTo: #{default_to.join(', ')}\r\nSubject: Auth\r\n\r\nClick here: https://example.com/verify?token=abc123"
      deliver(email, from: default_from, to: default_to.first)
      @message_id = MailCatcher::Mail.messages.first["id"]
    end

    it "returns parsed auth information" do
      result = described_class.call_tool(:get_parsed_auth_info, { "message_id" => @message_id })
      expect(result).to be_a(Hash)
      expect(result).to have_key(:verification_url)
      expect(result).to have_key(:otp_code)
      expect(result).to have_key(:reset_token)
      expect(result).to have_key(:unsubscribe_link)
      expect(result).to have_key(:links_count)
    end

    it "returns error for non-existent message" do
      result = described_class.call_tool(:get_parsed_auth_info, { "message_id" => 99999 })
      expect(result[:error]).to include("not found")
    end
  end

  describe ".call_tool - get_message_preview_html" do
    before do
      html_email = "From: #{default_from}\r\nTo: #{default_to.join(', ')}\r\nContent-Type: text/html\r\n\r\n<html><body>Hello</body></html>"
      deliver(html_email, from: default_from, to: default_to.first)
      @message_id = MailCatcher::Mail.messages.first["id"]
    end

    it "returns HTML preview" do
      result = described_class.call_tool(:get_message_preview_html, { "message_id" => @message_id })
      expect(result).to be_a(Hash)
      expect(result).to have_key(:html)
      expect(result[:html]).to include("<html>")
    end

    it "includes mobile viewport when mobile is true" do
      result = described_class.call_tool(:get_message_preview_html, {
        "message_id" => @message_id,
        "mobile" => true
      })
      expect(result[:mobile_optimized]).to eq(true)
      expect(result[:html]).to include("viewport")
    end

    it "returns error when message has no HTML" do
      plain_email = "From: #{default_from}\r\nTo: #{default_to.join(', ')}\r\nSubject: Plain\r\n\r\nPlain text"
      deliver(plain_email, from: default_from, to: default_to.first)
      plain_msg_id = MailCatcher::Mail.messages.last["id"]

      result = described_class.call_tool(:get_message_preview_html, { "message_id" => plain_msg_id })
      expect(result[:error]).to include("No HTML content found")
    end
  end

  describe ".call_tool - delete_message" do
    before do
      deliver("From: #{default_from}\r\nTo: #{default_to.join(', ')}\r\nSubject: Delete me\r\n\r\nBody",
              from: default_from, to: default_to.first)
      @message_id = MailCatcher::Mail.messages.first["id"]
    end

    it "deletes specific message" do
      result = described_class.call_tool(:delete_message, { "message_id" => @message_id })
      expect(result[:deleted]).to eq(true)
      expect(result[:message_id]).to eq(@message_id)
      expect(MailCatcher::Mail.message(@message_id)).to be_nil
    end

    it "returns error for non-existent message" do
      result = described_class.call_tool(:delete_message, { "message_id" => 99999 })
      expect(result[:error]).to include("not found")
    end
  end

  describe ".call_tool - clear_messages" do
    before do
      deliver("From: #{default_from}\r\nTo: #{default_to.join(', ')}\r\nSubject: First\r\n\r\nBody",
              from: default_from, to: default_to.first)
      deliver("From: #{default_from}\r\nTo: #{default_to.join(', ')}\r\nSubject: Second\r\n\r\nBody",
              from: default_from, to: default_to.first)
    end

    it "clears all messages" do
      expect(MailCatcher::Mail.messages.length).to eq(2)
      result = described_class.call_tool(:clear_messages, {})
      expect(result[:cleared]).to eq(true)
      expect(MailCatcher::Mail.messages.length).to eq(0)
    end
  end

  describe "error handling" do
    it "catches exceptions and returns error object" do
      result = described_class.call_tool(:search_messages, { "query" => nil })
      expect(result).to have_key(:error)
    end

    it "includes exception type in error response" do
      result = described_class.call_tool(:unknown_tool, {})
      expect(result[:type]).not_to be_empty
    end
  end
end
