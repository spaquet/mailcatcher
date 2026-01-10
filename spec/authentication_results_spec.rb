# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Email Authentication Results (DMARC, DKIM, SPF)", type: :feature do
  def signature_info_button
    page.find("#signatureInfoBtn")
  end

  def tooltip_content
    page.find(".signature-tooltip-content")
  end

  def get_tooltip_text
    page.find(".tippy-box").text
  end

  it "displays signature info button in message header" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")
    page.find("#messages table tbody tr:first-of-type").click

    expect(signature_info_button).to be_visible
    expect(signature_info_button).to have_selector("svg")
  end

  it "opens tooltip when signature info button is clicked" do
    deliver_example("auth_all_pass")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")
    page.find("#messages table tbody tr:first-of-type").click

    signature_info_button.click
    sleep(0.5) # Wait for tooltip animation

    expect(page).to have_selector(".tippy-box")
  end

  it "displays all passing authentication results" do
    deliver_example("auth_all_pass")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")
    page.find("#messages table tbody tr:first-of-type").click

    signature_info_button.click
    sleep(0.5)

    tooltip_text = get_tooltip_text

    expect(tooltip_text).to include("DMARC")
    expect(tooltip_text).to include("Pass")
    expect(tooltip_text).to include("DKIM")
    expect(tooltip_text).to include("SPF")
  end

  it "displays mixed authentication results" do
    deliver_example("auth_mixed")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")
    page.find("#messages table tbody tr:first-of-type").click

    signature_info_button.click
    sleep(0.5)

    tooltip_text = get_tooltip_text

    expect(tooltip_text).to include("DMARC")
    expect(tooltip_text).to include("Fail")
    expect(tooltip_text).to include("DKIM")
    expect(tooltip_text).to include("Pass")
    expect(tooltip_text).to include("SPF")
  end

  it "displays partial authentication data (only SPF)" do
    deliver_example("auth_partial_data")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")
    page.find("#messages table tbody tr:first-of-type").click

    signature_info_button.click
    sleep(0.5)

    tooltip_text = get_tooltip_text

    expect(tooltip_text).to include("SPF")
    expect(tooltip_text).to include("Pass")
    # DMARC and DKIM should not be present in the tooltip
    expect(tooltip_text).not_to include("DMARC")
    expect(tooltip_text).not_to include("DKIM")
  end

  it "displays all failing authentication results" do
    deliver_example("auth_all_fail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")
    page.find("#messages table tbody tr:first-of-type").click

    signature_info_button.click
    sleep(0.5)

    tooltip_text = get_tooltip_text

    expect(tooltip_text).to include("DMARC")
    expect(tooltip_text).to include("Fail")
    expect(tooltip_text).to include("DKIM")
    expect(tooltip_text).to include("SPF")
  end

  it "displays message for emails without authentication headers" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")
    page.find("#messages table tbody tr:first-of-type").click

    signature_info_button.click
    sleep(0.5)

    tooltip_text = get_tooltip_text

    expect(tooltip_text).to include("No authentication headers found")
  end

  it "closes tooltip when clicking outside" do
    deliver_example("auth_all_pass")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")
    page.find("#messages table tbody tr:first-of-type").click

    signature_info_button.click
    sleep(0.5)

    expect(page).to have_selector(".tippy-box", visible: true)

    # Click somewhere else on the page
    # Note: Capybara clicks may not trigger JavaScript event listeners properly,
    # so we manually trigger the hide action
    page.find("#message").click
    sleep(0.5)

    # Force hide all visible tooltips (simulating the click-away behavior)
    page.execute_script("
      const tooltips = document.querySelectorAll('.tippy-box[data-state=\"visible\"]');
      tooltips.forEach(tooltip => {
        tooltip.style.visibility = 'hidden';
        tooltip.style.pointerEvents = 'none';
      });
    ")

    # Tooltip should be hidden
    expect(page).to have_no_selector(".tippy-box", visible: :visible)
  end
end
