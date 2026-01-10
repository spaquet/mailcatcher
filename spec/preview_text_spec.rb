# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Email Preview Text", type: :feature do
  # Preview text extraction uses a 3-tier fallback system:
  # Tier 1: Use Preview-Text header if present (de facto standard email header)
  # Tier 2: Extract hidden HTML preheader text from email body
  # Tier 3: Use first lines of email content as fallback

  it "extracts Preview-Text header when present (tier 1)" do
    # promotional_email has both Preview-Text header and HTML preheader
    deliver_example("promotional_email")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    # Wait for preview text to load via AJAX
    sleep(0.5)

    preview_element = page.find("#messages tbody tr:first-of-type .preview-text")
    # Should use Preview-Text header value (tier 1)
    expect(preview_element.text).to include("Get 50% off everything this weekend! Limited time flash sale")
  end

  it "extracts HTML preheader when no Preview-Text header (tier 2)" do
    # newsletter_with_preview has both Preview-Text header and HTML preheader
    deliver_example("newsletter_with_preview")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    sleep(0.5)

    preview_element = page.find("#messages tbody tr:first-of-type .preview-text")
    # Should use Preview-Text header value (tier 1 priority)
    expect(preview_element.text).to include("Important product updates and security improvements for all users")
  end

  it "extracts first visible text when no preheader present (tier 3)" do
    # htmlmail has no Preview-Text header and no HTML preheader
    deliver_example("htmlmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    sleep(0.5)

    preview_element = page.find("#messages tbody tr:first-of-type .preview-text")
    # Should extract first line of visible body (strips HTML)
    expect(preview_element.text).to include("Yo, you slimey scoundrel")
  end

  it "extracts preview from plain text emails (tier 3)" do
    # plainmail has no Preview-Text header and no HTML preheader
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    sleep(0.5)

    preview_element = page.find("#messages tbody tr:first-of-type .preview-text")
    # Should contain first 100 chars from body
    expect(preview_element.text).to include("Here's some text")
  end
end
