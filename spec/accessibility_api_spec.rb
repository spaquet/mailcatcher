# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Accessibility Score API", type: :feature do
  it "returns accessibility score for HTML email" do
    deliver_example("accessible_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/accessibility.json"
    data = JSON.parse(page.text)

    expect(data).to be_a(Hash)
    expect(data).to have_key("score")
    expect(data).to have_key("breakdown")
    expect(data).to have_key("recommendations")
  end

  it "returns score between 0 and 100" do
    deliver_example("accessible_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/accessibility.json"
    data = JSON.parse(page.text)

    expect(data["score"]).to be_between(0, 100)
  end

  it "scores accessible email higher than inaccessible email" do
    deliver_example("accessible_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    accessible_id = messages.first["id"]

    visit "/messages/#{accessible_id}/accessibility.json"
    accessible_data = JSON.parse(page.text)

    # Deliver poor accessibility email
    deliver_example("poor_accessibility_email")
    sleep(0.5)

    # Get all messages and find the poor accessibility one (should be the newest)
    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    # Find the poor_accessibility_email - it should have a different subject
    poor_message = messages.find { |m| m["subject"].include?("Poor") || m["id"] > accessible_id }
    poor_id = poor_message["id"]

    visit "/messages/#{poor_id}/accessibility.json"
    poor_data = JSON.parse(page.text)

    # Accessible email should score higher
    expect(accessible_data["score"]).to be > poor_data["score"]
  end

  it "checks for alt text in images" do
    deliver_example("accessible_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/accessibility.json"
    data = JSON.parse(page.text)

    expect(data["breakdown"]).to have_key("images_with_alt")
    expect(data["breakdown"]["images_with_alt"]).to be_between(0, 100)
  end

  it "checks for semantic HTML usage" do
    deliver_example("accessible_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/accessibility.json"
    data = JSON.parse(page.text)

    expect(data["breakdown"]).to have_key("semantic_html")
    expect([50, 100]).to include(data["breakdown"]["semantic_html"])
  end

  it "provides recommendations for improvement" do
    deliver_example("poor_accessibility_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/accessibility.json"
    data = JSON.parse(page.text)

    expect(data["recommendations"]).to be_a(Array)
    # Poor accessibility email should have recommendations
    expect(data["recommendations"].length).to be > 0
  end

  it "returns 0 score for plain text email without HTML" do
    deliver_example("plainmail")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/accessibility.json"
    data = JSON.parse(page.text)

    expect(data["score"]).to eq(0)
    expect(data).to have_key("error")
  end

  it "returns 404 for non-existent message" do
    page.driver.browser.execute_script(<<~JS
      window.accessResult = fetch("/messages/999999/accessibility.json").then(r => { window.accessStatus = r.status; return r.text(); });
    JS
    )

    # Wait for async request
    sleep(0.5)

    status = page.evaluate_script("window.accessStatus")
    expect(status).to eq(404)
  end

  it "high score for email with all alt text" do
    deliver_example("accessible_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/accessibility.json"
    data = JSON.parse(page.text)

    expect(data["breakdown"]["images_with_alt"]).to be >= 50
  end

  it "recommends adding semantic HTML tags when missing" do
    deliver_example("poor_accessibility_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/accessibility.json"
    data = JSON.parse(page.text)

    semantic_recommendation = data["recommendations"].any? { |r| r.include?("semantic HTML") }
    expect(semantic_recommendation).to be true
  end

  it "returns proper content-type header" do
    deliver_example("accessible_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    # Use fetch to get the response headers
    page.driver.browser.execute_script(<<~JS
      window.contentTypeResult = fetch("/messages/#{message_id}/accessibility.json")
        .then(r => { window.contentType = r.headers.get("Content-Type"); return r.text(); })
        .then(d => { window.accessData = d; });
    JS
    )

    # Wait for async request
    sleep(0.5)

    content_type = page.evaluate_script("window.contentType")
    expect(content_type).to include("application/json")
  end

  it "calculates average score from breakdown metrics" do
    deliver_example("accessible_email")
    sleep(0.5)

    messages = JSON.parse(page.evaluate_script("fetch('/messages').then(r => r.json()).then(d => JSON.stringify(d))"))
    message_id = messages.first["id"]

    visit "/messages/#{message_id}/accessibility.json"
    data = JSON.parse(page.text)

    # Score should be average of breakdown values
    expected_average = (data["breakdown"]["images_with_alt"] + data["breakdown"]["semantic_html"]) / 2.0
    expect(data["score"]).to eq(expected_average.round)
  end
end
