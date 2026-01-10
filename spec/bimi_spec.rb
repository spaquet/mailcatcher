# frozen_string_literal: true

require "spec_helper"

RSpec.describe "BIMI Display", type: :feature do
  it "displays BIMI image when bimi_location is present" do
    deliver_example("bimi_email")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")
    page.find("#messages table tbody tr:first-of-type").click

    # Wait for AJAX to load full message data
    sleep(0.5)

    # Find the BIMI cell in the first message row
    bimi_cell = page.find("#messages tbody tr:first-of-type td.col-bimi")

    # Should have a BIMI image, not placeholder
    expect(bimi_cell).to have_selector("img.bimi-image[alt='BIMI']")
    expect(bimi_cell).to have_no_selector("svg.bimi-placeholder-icon")
  end

  it "displays placeholder icon when no BIMI is present" do
    deliver_example("plainmail")

    expect(page).to have_selector("#messages table tbody tr:first-of-type")

    # Wait for AJAX
    sleep(0.5)

    bimi_cell = page.find("#messages tbody tr:first-of-type td.col-bimi")

    # Should have placeholder, not image
    expect(bimi_cell).to have_selector("svg.bimi-placeholder-icon")
    expect(bimi_cell).to have_no_selector("img.bimi-image")
  end

  it "displays BIMI column header in message list" do
    expect(page).to have_selector("#messages th.col-bimi")
  end

  it "handles multiple emails with different BIMI states" do
    deliver_example("bimi_email")
    deliver_example("plainmail")

    sleep(1.0)

    rows = page.all("#messages tbody tr")
    expect(rows.length).to eq(2)

    # Messages are prepended (newest first), so:
    # rows[0] = plainmail (no BIMI)
    # rows[1] = bimi_email (has BIMI)

    # First row should have placeholder (plainmail)
    bimi_cell_1 = rows[0].find("td.col-bimi")
    expect(bimi_cell_1).to have_selector("svg.bimi-placeholder-icon")

    # Second row should have BIMI image (bimi_email)
    bimi_cell_2 = rows[1].find("td.col-bimi")
    expect(bimi_cell_2).to have_selector("img.bimi-image", wait: 5)
  end
end
