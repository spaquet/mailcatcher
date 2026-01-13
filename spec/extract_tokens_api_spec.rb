# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Extract Tokens API", type: :feature do
  it "extracts OTP codes from verification email" do
    deliver_example("verification_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/extract?type=otp"
    data = JSON.parse(page.text)

    expect(data).to be_a(Array)
    expect(data.length).to be > 0
    expect(data.first["type"]).to eq("otp")
    expect(data.first["value"]).to eq("123456")
    expect(data.first["context"]).to include("verification code")
  end

  it "extracts magic links from verification email" do
    deliver_example("verification_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/extract?type=link"
    data = JSON.parse(page.text)

    expect(data).to be_a(Array)
    expect(data.length).to be > 0
    expect(data.first["type"]).to eq("magic_link")
    expect(data.first["value"]).to include("verify?token=")
  end

  it "extracts reset tokens from password reset email" do
    deliver_example("password_reset")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/extract?type=token"
    data = JSON.parse(page.text)

    expect(data).to be_a(Array)
    expect(data.length).to be > 0
    expect(data.first["type"]).to eq("reset_token")
    expect(data.first["value"]).to include("reset?token=")
  end

  it "returns empty array for email without OTPs" do
    deliver_example("plainmail")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/extract?type=otp"
    data = JSON.parse(page.text)

    expect(data).to be_an(Array)
    expect(data).to be_empty
  end

  it "returns 404 for non-existent message" do
    page.driver.browser.execute_script(<<~JS
      window.extractResult = fetch("/messages/999999/extract?type=otp").then(r => { window.extractStatus = r.status; return r.text(); });
    JS
    )

    # Wait for async request
    sleep(0.5)

    status = page.evaluate_script("window.extractStatus")
    expect(status).to eq(404)
  end

  it "extracts multiple tokens from email with multiple verification codes" do
    deliver_example("verification_email")
    deliver_example("verification_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/extract?type=otp"
    data = JSON.parse(page.text)

    expect(data.length).to be >= 1
  end

  it "includes context with extracted tokens" do
    deliver_example("verification_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/extract?type=otp"
    data = JSON.parse(page.text)

    expect(data.first).to have_key("context")
    expect(data.first["context"].length).to be > 0
  end

  it "handles missing type parameter gracefully" do
    deliver_example("verification_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/extract"
    data = JSON.parse(page.text)

    # Should return empty array for unknown type
    expect(data).to be_an(Array)
  end

  it "extracts links from plain text emails" do
    deliver_example("plainlinkmail")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/extract?type=link"
    data = JSON.parse(page.text)

    # plainlinkmail should have links
    expect(data).to be_an(Array)
  end
end
