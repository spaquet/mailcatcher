# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Links Extraction API", type: :feature do
  it "extracts all links from HTML email" do
    deliver_example("newsletter_with_links")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/links.json"
    data = JSON.parse(page.text)

    expect(data).to be_a(Array)
    expect(data.length).to be > 0
    expect(data.first).to have_key("href")
    expect(data.first).to have_key("text")
    expect(data.first).to have_key("is_verification")
    expect(data.first).to have_key("is_unsubscribe")
  end

  it "identifies verification links correctly" do
    deliver_example("verification_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/links.json"
    data = JSON.parse(page.text)

    verification_links = data.select { |link| link["is_verification"] }
    expect(verification_links.length).to be > 0
  end

  it "identifies unsubscribe links correctly" do
    deliver_example("newsletter_with_links")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/links.json"
    data = JSON.parse(page.text)

    unsubscribe_links = data.select { |link| link["is_unsubscribe"] }
    expect(unsubscribe_links.length).to be > 0
  end

  it "extracts links from HTML with proper anchor text" do
    deliver_example("newsletter_with_links")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/links.json"
    data = JSON.parse(page.text)

    # Check that some links have anchor text
    links_with_text = data.select { |link| link["text"] && !link["text"].empty? }
    expect(links_with_text.length).to be > 0
  end

  it "returns empty array for email without links" do
    deliver_example("plainmail")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/links.json"
    data = JSON.parse(page.text)

    expect(data).to be_an(Array)
    # plainmail has no links
    expect(data).to be_empty
  end

  it "returns 404 for non-existent message" do
    page.driver.browser.execute_script(<<~JS
      window.linksResult = fetch("/messages/999999/links.json").then(r => { window.linksStatus = r.status; return r.text(); });
    JS
    )

    # Wait for async request
    sleep(0.5)

    status = page.evaluate_script("window.linksStatus")
    expect(status).to eq(404)
  end

  it "extracts links from plain text emails" do
    deliver_example("plainlinkmail")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/links.json"
    data = JSON.parse(page.text)

    expect(data).to be_an(Array)
  end

  it "handles multiple links in email" do
    deliver_example("newsletter_with_links")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/links.json"
    data = JSON.parse(page.text)

    # Newsletter should have multiple links
    expect(data.length).to be >= 3
  end

  it "provides href URL for each link" do
    deliver_example("newsletter_with_links")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/links.json"
    data = JSON.parse(page.text)

    data.each do |link|
      expect(link["href"]).to match(/^https?:\/\//)
    end
  end

  it "classifies verification and regular links" do
    deliver_example("newsletter_with_links")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/links.json"
    data = JSON.parse(page.text)

    # Check that classification exists
    data.each do |link|
      expect([true, false]).to include(link["is_verification"])
      expect([true, false]).to include(link["is_unsubscribe"])
    end
  end
end
