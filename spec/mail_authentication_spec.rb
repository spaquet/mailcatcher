# frozen_string_literal: true

require "spec_helper"
require "mail_catcher/mail"

RSpec.describe MailCatcher::Mail do
  describe ".message_authentication_results" do
    it "returns empty hash for email without authentication results header" do
      plain_email = File.read(File.expand_path("../../examples/plainmail", __FILE__))

      MailCatcher::Mail.add_message(sender: "from@example.com", recipients: ["to@example.com"], source: plain_email)
      id = MailCatcher::Mail.messages.last["id"]

      results = MailCatcher::Mail.message_authentication_results(id)

      expect(results).to be_a(Hash)
      expect(results[:dmarc]).to be_nil
      expect(results[:dkim]).to be_nil
      expect(results[:spf]).to be_nil
    end

    it "extracts all passing authentication results" do
      auth_email = File.read(File.expand_path("../../examples/auth_all_pass", __FILE__))

      MailCatcher::Mail.add_message(sender: "from@example.com", recipients: ["to@example.com"], source: auth_email)
      id = MailCatcher::Mail.messages.last["id"]

      results = MailCatcher::Mail.message_authentication_results(id)

      expect(results[:dmarc]).to eq("pass")
      expect(results[:dkim]).to eq("pass")
      expect(results[:spf]).to eq("pass")
    end

    it "extracts mixed authentication results" do
      auth_email = File.read(File.expand_path("../../examples/auth_mixed", __FILE__))

      MailCatcher::Mail.add_message(sender: "from@example.com", recipients: ["to@example.com"], source: auth_email)
      id = MailCatcher::Mail.messages.last["id"]

      results = MailCatcher::Mail.message_authentication_results(id)

      expect(results[:dmarc]).to eq("fail")
      expect(results[:dkim]).to eq("pass")
      expect(results[:spf]).to eq("pass")
    end

    it "extracts all failing authentication results" do
      auth_email = File.read(File.expand_path("../../examples/auth_all_fail", __FILE__))

      MailCatcher::Mail.add_message(sender: "from@example.com", recipients: ["to@example.com"], source: auth_email)
      id = MailCatcher::Mail.messages.last["id"]

      results = MailCatcher::Mail.message_authentication_results(id)

      expect(results[:dmarc]).to eq("fail")
      expect(results[:dkim]).to eq("fail")
      expect(results[:spf]).to eq("fail")
    end

    it "extracts partial authentication results" do
      auth_email = File.read(File.expand_path("../../examples/auth_partial_data", __FILE__))

      MailCatcher::Mail.add_message(sender: "from@example.com", recipients: ["to@example.com"], source: auth_email)
      id = MailCatcher::Mail.messages.last["id"]

      results = MailCatcher::Mail.message_authentication_results(id)

      expect(results[:dmarc]).to be_nil
      expect(results[:dkim]).to be_nil
      expect(results[:spf]).to eq("pass")
    end

    it "handles case-insensitive authentication header" do
      email_source = <<~EMAIL
        To: test@example.com
        From: sender@example.com
        Subject: Test
        Authentication-Results: example.com; dmarc=pass; dkim=PASS; spf=Pass
        Content-Type: text/plain

        Test email
      EMAIL

      MailCatcher::Mail.add_message(sender: "from@example.com", recipients: ["to@example.com"], source: email_source)
      id = MailCatcher::Mail.messages.last["id"]

      results = MailCatcher::Mail.message_authentication_results(id)

      expect(results[:dmarc]).to eq("pass")
      expect(results[:dkim]).to eq("pass")
      expect(results[:spf]).to eq("pass")
    end

    it "returns empty hash for non-existent message id" do
      results = MailCatcher::Mail.message_authentication_results(99999)

      expect(results).to eq({})
    end

    it "includes authentication results in message JSON API" do
      auth_email = File.read(File.expand_path("../../examples/auth_all_pass", __FILE__))

      MailCatcher::Mail.add_message(sender: "from@example.com", recipients: ["to@example.com"], source: auth_email)
      id = MailCatcher::Mail.messages.last["id"]

      message = MailCatcher::Mail.message(id)
      message_with_auth = message.merge({
        "authentication_results" => MailCatcher::Mail.message_authentication_results(id)
      })

      expect(message_with_auth["authentication_results"]).to be_a(Hash)
      expect(message_with_auth["authentication_results"][:dmarc]).to eq("pass")
      expect(message_with_auth["authentication_results"][:dkim]).to eq("pass")
      expect(message_with_auth["authentication_results"][:spf]).to eq("pass")
    end

    it "handles authentication header with multiple entries" do
      email_source = <<~EMAIL
        To: test@example.com
        From: sender@example.com
        Subject: Test
        Authentication-Results: mx.example.com;
                dmarc=pass (p=none dis=none) header.from=trusted.com;
                dkim=pass (2048-bit key; unprotected) header.d=trusted.com header.i=@trusted.com;
                spf=pass smtp.mailfrom=trusted.com
        Content-Type: text/plain

        Test email
      EMAIL

      MailCatcher::Mail.add_message(sender: "from@example.com", recipients: ["to@example.com"], source: email_source)
      id = MailCatcher::Mail.messages.last["id"]

      results = MailCatcher::Mail.message_authentication_results(id)

      expect(results[:dmarc]).to eq("pass")
      expect(results[:dkim]).to eq("pass")
      expect(results[:spf]).to eq("pass")
    end
  end
end
