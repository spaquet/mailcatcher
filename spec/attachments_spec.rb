# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Attachment Display", type: :feature do
  it "shows attachments section when email has attachments" do
    deliver_example("attachmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")
    page.find("#messages table tbody tr:first-of-type").click

    # Attachments column should be visible
    expect(page).to have_selector(".attachments-column", visible: true)
    expect(page).to have_selector(".attachments-list li")
  end

  it "hides attachments section when email has no attachments" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")
    page.find("#messages table tbody tr:first-of-type").click

    # Attachments column should be hidden
    expect(page).to have_no_selector(".attachments-column", visible: true)

    # Or verify it exists but is hidden
    expect(page).to have_selector(".attachments-column", visible: false)
  end

  it "correctly shows/hides attachments when switching between emails" do
    deliver_example("attachmail")
    deliver_example("plainmail")

    sleep(0.5)

    rows = page.all("#messages tbody tr")

    # Messages are prepended, so rows[0] is plainmail, rows[1] is attachmail
    # Click email with attachments
    rows[1].click
    sleep(0.5)
    expect(page).to have_selector(".attachments-column.visible", wait: 5)

    # Click email without attachments
    rows[0].click
    sleep(0.5)
    expect(page).to have_no_selector(".attachments-column.visible", wait: 5)
  end
end
