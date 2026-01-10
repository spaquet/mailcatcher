# frozen_string_literal: true

require "spec_helper"

RSpec.describe "From and To Headers", type: :feature do
  def messages_element
    page.find("#messages")
  end

  def message_row_element
    messages_element.find(:xpath, ".//table/tbody/tr[1]")
  end

  def message_from_element
    message_row_element.find(:xpath, ".//td[3]")
  end

  def message_to_element
    message_row_element.find(:xpath, ".//td[4]")
  end

  it "displays the correct From and To when email headers contain names" do
    # Use promotional_email which has:
    # From: Deals <deals@retailer.com>
    # To: Subscriber <subscriber@email.com>
    deliver_example("promotional_email")

    # Do not reload, make sure that the message appears via websockets

    # Wait for the message to appear
    expect(page).to have_selector("#messages table tbody tr:first-of-type", text: "Exclusive 50% Off Sale")

    # The From column should show "Deals" (name in bold) and the email below
    from_text = message_from_element.text
    expect(from_text).to include("Deals")
    expect(from_text).to include("deals@retailer.com")

    # The To column should show "Subscriber" (name in bold) and the email below
    to_text = message_to_element.text
    expect(to_text).to include("Subscriber")
    expect(to_text).to include("subscriber@email.com")

    # Click the message to view details
    message_row_element.click

    # Check the metadata section also shows the correct From and To
    from_metadata = page.find("#message .metadata dd.from").text
    expect(from_metadata).to include("Deals")
    expect(from_metadata).to include("deals@retailer.com")

    to_metadata = page.find("#message .metadata dd.to").text
    expect(to_metadata).to include("Subscriber")
    expect(to_metadata).to include("subscriber@email.com")
  end

  it "displays correct From and To from plainmail which has different headers" do
    # plainmail has:
    # From: Me <me@sj26.com>
    # To: Blah <blah@blah.com>
    deliver_example("plainmail")

    # Do not reload, make sure that the message appears via websockets

    expect(page).to have_selector("#messages table tbody tr:first-of-type", text: "Plain mail")

    # The From column should show "Me" (name in bold) and the email below
    from_text = message_from_element.text
    expect(from_text).to include("Me")
    expect(from_text).to include("me@sj26.com")

    # The To column should show "Blah" (name in bold) and the email below
    to_text = message_to_element.text
    expect(to_text).to include("Blah")
    expect(to_text).to include("blah@blah.com")
  end
end
