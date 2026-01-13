# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Parsed Data API", type: :feature do
  it "returns structured data from email" do
    deliver_example("verification_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/parsed.json"
    data = JSON.parse(page.text)

    expect(data).to be_a(Hash)
    expect(data).to have_key("verification_url")
    expect(data).to have_key("otp_code")
    expect(data).to have_key("reset_token")
    expect(data).to have_key("unsubscribe_link")
    expect(data).to have_key("all_links")
  end

  it "extracts verification URL from email" do
    deliver_example("verification_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/parsed.json"
    data = JSON.parse(page.text)

    expect(data["verification_url"]).not_to be_nil
    expect(data["verification_url"]).to include("verify?token=")
  end

  it "extracts OTP code from email" do
    deliver_example("verification_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/parsed.json"
    data = JSON.parse(page.text)

    expect(data["otp_code"]).not_to be_nil
    expect(data["otp_code"]).to eq("123456")
  end

  it "extracts reset token from password reset email" do
    deliver_example("password_reset")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/parsed.json"
    data = JSON.parse(page.text)

    expect(data["reset_token"]).not_to be_nil
    expect(data["reset_token"]).to include("reset?token=")
  end

  it "extracts unsubscribe link from List-Unsubscribe header" do
    deliver_example("newsletter_with_links")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/parsed.json"
    data = JSON.parse(page.text)

    expect(data["unsubscribe_link"]).not_to be_nil
    expect(data["unsubscribe_link"]).to include("unsubscribe")
  end

  it "includes all links in response" do
    deliver_example("newsletter_with_links")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/parsed.json"
    data = JSON.parse(page.text)

    expect(data["all_links"]).to be_a(Array)
    expect(data["all_links"].length).to be > 0
  end

  it "handles email without verification data gracefully" do
    deliver_example("plainmail")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/parsed.json"
    data = JSON.parse(page.text)

    # Should return hash with nil values for missing data
    expect(data).to be_a(Hash)
    expect(data["verification_url"]).to be_nil
    expect(data["otp_code"]).to be_nil
  end

  it "returns 404 for non-existent message" do
    page.driver.browser.execute_script(<<~JS
      window.parsedResult = fetch("/messages/999999/parsed.json").then(r => { window.parsedStatus = r.status; return r.text(); });
    JS
    )

    # Wait for async request
    sleep(0.5)

    status = page.evaluate_script("window.parsedStatus")
    expect(status).to eq(404)
  end

  it "returns proper content-type header" do
    deliver_example("verification_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    # Use fetch to get the response headers
    page.driver.browser.execute_script(<<~JS
      window.contentTypeResult = fetch("/messages/#{message_id}/parsed.json")
        .then(r => { window.contentType = r.headers.get("Content-Type"); return r.text(); })
        .then(d => { window.parsedData = d; });
    JS
    )

    # Wait for async request
    sleep(0.5)

    content_type = page.evaluate_script("window.contentType")
    expect(content_type).to include("application/json")
  end

  it "extracts first occurrence of each token type" do
    deliver_example("verification_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/parsed.json"
    data = JSON.parse(page.text)

    # Should contain a single otp_code, not an array
    expect(data["otp_code"]).to be_a(String)
  end

  it "comprehensive example with verification, reset, and links" do
    deliver_example("verification_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/parsed.json"
    data = JSON.parse(page.text)

    # This email has OTP and verification link
    expect(data["otp_code"]).to eq("123456")
    expect(data["verification_url"]).to include("verify?token=")
    expect(data["all_links"]).to be_a(Array)
  end
end
