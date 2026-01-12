# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Quit", type: :feature do
  it "quits cleanly via the Quit button" do
    # Quitting and cancelling ..
    dismiss_confirm do
      click_on "Quit"
    end

    # .. should not exit the process
    expect { Process.kill(0, @pid) }.not_to raise_error

    # Reload the page to be sure
    visit "/"
    # Wait for the websocket to be available after page reload
    begin
      Timeout.timeout(10) do
        loop do
          begin
            ready = page.evaluate_script("window.MailCatcher && window.MailCatcher.websocket && window.MailCatcher.websocket.readyState === 1")
            break if ready
          rescue Selenium::WebDriver::Error::JavaScriptError
            # JavaScript not ready yet
          end
          sleep 0.1
        end
      end
    rescue Timeout::Error
      # WebSocket might not be essential for this test, continue anyway
    end

    # Quitting and confirming ..
    accept_confirm "Are you sure you want to quit?" do
      click_on "Quit"
    end

    # .. should exit the process ..
    _, status = Process.wait2(@pid)

    expect(status).to be_exited
    expect(status).to be_success
  end

  it "quits cleanly on Ctrl+C" do
    # Sending a SIGINT (Ctrl+C) ...
    Process.kill(:SIGINT, @pid)

    # .. should cause the process to exit cleanly
    _, status = Process.wait2(@pid)

    expect(status).to be_exited
    expect(status).to be_success
  end
end
