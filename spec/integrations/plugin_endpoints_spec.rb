# frozen_string_literal: true

require "spec_helper"

describe "Claude Plugin Endpoints", type: :feature do
  let(:default_from) { "sender@example.com" }
  let(:default_to) { "recipient@example.com" }

  before do
    MailCatcher::Mail.delete!
  end

  describe "GET /.well-known/ai-plugin.json" do
    it "returns valid plugin manifest" do
      visit "/.well-known/ai-plugin.json"
      content = page.text
      manifest = JSON.parse(content)

      expect(manifest).to have_key("schema_version")
      expect(manifest).to have_key("name_for_human")
      expect(manifest).to have_key("name_for_model")
      expect(manifest).to have_key("api")
      expect(manifest["api"]["type"]).to eq("openapi")
    end

    it "includes correct API URL" do
      visit "/.well-known/ai-plugin.json"
      manifest = JSON.parse(page.text)
      expect(manifest["api"]["url"]).to include("/plugin/openapi.json")
    end
  end

  describe "GET /plugin/openapi.json" do
    it "returns valid OpenAPI specification" do
      visit "/plugin/openapi.json"
      spec = JSON.parse(page.text)

      expect(spec).to have_key("openapi")
      expect(spec).to have_key("info")
      expect(spec).to have_key("paths")
      expect(spec["openapi"]).to eq("3.0.0")
    end

    it "includes all plugin endpoints" do
      visit "/plugin/openapi.json"
      spec = JSON.parse(page.text)
      paths = spec["paths"]

      expect(paths).to have_key("/plugin/search")
      expect(paths).to have_key("/plugin/message/{id}/latest")
      expect(paths).to have_key("/plugin/message/{id}/tokens")
      expect(paths).to have_key("/plugin/message/{id}/auth-info")
      expect(paths).to have_key("/plugin/message/{id}/preview")
      expect(paths).to have_key("/plugin/messages")
    end

    it "includes server information" do
      visit "/plugin/openapi.json"
      spec = JSON.parse(page.text)
      expect(spec["servers"]).to be_a(Array)
      expect(spec["servers"].first).to have_key("url")
    end
  end

  describe "POST /plugin/search" do
    before do
      deliver("From: #{default_from}\r\nTo: #{default_to}\r\nSubject: Test Email\r\n\r\nBody text",
              from: default_from, to: default_to)
    end

    it "returns search results" do
      visit "/plugin/search?query=Test"
      result = JSON.parse(page.text)

      expect(result).to have_key("count")
      expect(result).to have_key("messages")
      expect(result["count"]).to eq(1)
    end

    it "respects limit parameter" do
      deliver("From: #{default_from}\r\nTo: #{default_to}\r\nSubject: Email 2\r\n\r\nBody",
              from: default_from, to: default_to)

      visit "/plugin/search?query=Email&limit=1"
      result = JSON.parse(page.text)
      expect(result["count"]).to eq(1)
    end

    it "returns error when query parameter missing" do
      visit "/plugin/search"
      expect(page.status_code).to eq(400)
      result = JSON.parse(page.text)
      expect(result).to have_key("error")
    end

    it "returns formatted message data" do
      visit "/plugin/search?query=Test"
      result = JSON.parse(page.text)
      msg = result["messages"].first

      expect(msg).to have_key("id")
      expect(msg).to have_key("from")
      expect(msg).to have_key("to")
      expect(msg).to have_key("subject")
      expect(msg).to have_key("created_at")
    end
  end

  describe "GET /plugin/message/:id/latest" do
    before do
      deliver("From: #{default_from}\r\nTo: user1@example.com\r\nSubject: First\r\n\r\nBody",
              from: default_from, to: "user1@example.com")
    end

    it "returns latest message for recipient" do
      visit "/plugin/message/1/latest?recipient=user1@example.com"
      result = JSON.parse(page.text)

      expect(result).to have_key("id")
      expect(result).to have_key("subject")
      expect(result["subject"]).to eq("First")
    end

    it "returns error when recipient parameter missing" do
      visit "/plugin/message/1/latest"
      expect(page.status_code).to eq(400)
      result = JSON.parse(page.text)
      expect(result).to have_key("error")
    end

    it "filters by subject_contains" do
      deliver("From: #{default_from}\r\nTo: user1@example.com\r\nSubject: Reset Token\r\n\r\nBody",
              from: default_from, to: "user1@example.com")

      visit "/plugin/message/1/latest?recipient=user1@example.com&subject_contains=Reset"
      result = JSON.parse(page.text)
      expect(result["subject"]).to eq("Reset Token")
    end

    it "returns 404 when no matching message" do
      visit "/plugin/message/1/latest?recipient=nobody@example.com"
      expect(page.status_code).to eq(404)
    end
  end

  describe "GET /plugin/message/:id/tokens" do
    before do
      email_with_otp = "From: #{default_from}\r\nTo: #{default_to}\r\nSubject: OTP\r\n\r\nYour OTP: 123456"
      deliver(email_with_otp, from: default_from, to: default_to)
      @message_id = MailCatcher::Mail.messages.first["id"]
    end

    it "extracts OTP tokens" do
      visit "/plugin/message/#{@message_id}/tokens?kind=otp"
      result = JSON.parse(page.text)
      expect(result).to have_key("extracted")
      expect(result["extracted"]).to be_a(Array)
    end

    it "extracts all token types" do
      visit "/plugin/message/#{@message_id}/tokens?kind=all"
      result = JSON.parse(page.text)

      expect(result).to have_key("magic_links")
      expect(result).to have_key("otps")
      expect(result).to have_key("reset_tokens")
    end

    it "returns error for invalid kind" do
      visit "/plugin/message/#{@message_id}/tokens?kind=invalid"
      expect(page.status_code).to eq(400)
      result = JSON.parse(page.text)
      expect(result).to have_key("error")
    end

    it "returns 404 for non-existent message" do
      visit "/plugin/message/99999/tokens?kind=otp"
      expect(page.status_code).to eq(404)
    end
  end

  describe "GET /plugin/message/:id/auth-info" do
    before do
      email = "From: #{default_from}\r\nTo: #{default_to}\r\nSubject: Verify\r\n\r\nClick: https://example.com/verify?token=abc"
      deliver(email, from: default_from, to: default_to)
      @message_id = MailCatcher::Mail.messages.first["id"]
    end

    it "returns parsed auth information" do
      visit "/plugin/message/#{@message_id}/auth-info"
      result = JSON.parse(page.text)

      expect(result).to have_key("verification_url")
      expect(result).to have_key("otp_code")
      expect(result).to have_key("reset_token")
      expect(result).to have_key("unsubscribe_link")
      expect(result).to have_key("links_count")
    end

    it "returns 404 for non-existent message" do
      visit "/plugin/message/99999/auth-info"
      expect(page.status_code).to eq(404)
    end
  end

  describe "GET /plugin/message/:id/preview" do
    before do
      html_email = "From: #{default_from}\r\nTo: #{default_to}\r\nContent-Type: text/html\r\n\r\n<html><body>Hello</body></html>"
      deliver(html_email, from: default_from, to: default_to)
      @message_id = MailCatcher::Mail.messages.first["id"]
    end

    it "returns HTML preview" do
      visit "/plugin/message/#{@message_id}/preview"
      expect(page.text).to include("<html>")
      expect(page.text).to include("<body>")
    end

    it "includes viewport meta tag for mobile" do
      visit "/plugin/message/#{@message_id}/preview?mobile=true"
      expect(page.text).to include("viewport")
      expect(page.text).to include("device-width")
    end

    it "returns 404 when message has no HTML" do
      plain_email = "From: #{default_from}\r\nTo: #{default_to}\r\nSubject: Plain\r\n\r\nPlain text"
      deliver(plain_email, from: default_from, to: default_to)
      plain_msg_id = MailCatcher::Mail.messages.last["id"]

      visit "/plugin/message/#{plain_msg_id}/preview"
      expect(page.status_code).to eq(404)
    end
  end

  describe "DELETE /plugin/messages" do
    before do
      deliver("From: #{default_from}\r\nTo: #{default_to}\r\nSubject: Delete me\r\n\r\nBody",
              from: default_from, to: default_to)
    end

    it "deletes all messages" do
      expect(MailCatcher::Mail.messages.length).to eq(1)

      # Use JavaScript to make DELETE request
      page.evaluate_script(
        "fetch('/plugin/messages', {method: 'DELETE'})"
      )

      # Give it a moment to process
      sleep 0.1
      expect(MailCatcher::Mail.messages.length).to eq(0)
    end

    it "returns 204 No Content" do
      response_code = page.evaluate_script(
        "fetch('/plugin/messages', {method: 'DELETE'}).then(r => r.status)"
      )
      expect(response_code).to eq(204)
    end
  end

  describe "DELETE /plugin/message/:id" do
    before do
      deliver("From: #{default_from}\r\nTo: #{default_to}\r\nSubject: Delete me\r\n\r\nBody",
              from: default_from, to: default_to)
      @message_id = MailCatcher::Mail.messages.first["id"]
    end

    it "deletes specific message" do
      expect(MailCatcher::Mail.messages.length).to eq(1)

      page.evaluate_script(
        "fetch('/plugin/message/#{@message_id}', {method: 'DELETE'})"
      )

      sleep 0.1
      expect(MailCatcher::Mail.messages.length).to eq(0)
    end

    it "returns 404 for non-existent message" do
      response_code = page.evaluate_script(
        "fetch('/plugin/message/99999', {method: 'DELETE'}).then(r => r.status)"
      )
      expect(response_code).to eq(404)
    end
  end
end
