#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/smtp'
require 'fileutils'

# Configuration
SMTP_HOST = ENV['SMTP_HOST'] || '127.0.0.1'
SMTP_PORT = ENV['SMTP_PORT'] || 1025
EXAMPLES_DIR = File.expand_path('../examples', __FILE__)
FROM_ADDRESS = ENV['FROM_ADDRESS'] || 'test@example.com'
TO_ADDRESS = ENV['TO_ADDRESS'] || 'recipient@example.com'
DELAY = (ENV['DELAY'] || 1).to_i

# Get list of email files to send (exclude 'attachment' which is a binary file)
email_files = Dir.glob(File.join(EXAMPLES_DIR, '*')).select do |file|
  File.file?(file) && File.basename(file) != 'attachment' && File.basename(file) != 'attachmail'
end

if email_files.empty?
  puts "No email files found in #{EXAMPLES_DIR}"
  exit 1
end

puts "Sending #{email_files.length} example emails to #{SMTP_HOST}:#{SMTP_PORT}"
puts "=" * 60

email_files.sort.each_with_index do |file, index|
  filename = File.basename(file)

  begin
    # Read the email content
    content = File.read(file)

    # Create a message with a descriptive subject if one doesn't exist
    # This helps identify emails when they arrive in different order
    if content.include?("Subject:")
      message = content
    else
      # Create a simple email with subject
      subject = "[Example #{index + 1}/#{email_files.length}] #{filename}"
      message = <<~EMAIL
        From: #{FROM_ADDRESS}
        To: #{TO_ADDRESS}
        Subject: #{subject}
        Date: #{Time.now.rfc2822}

        #{content}
      EMAIL
    end

    # Send via SMTP
    Net::SMTP.start(SMTP_HOST, SMTP_PORT) do |smtp|
      smtp.send_message(message, FROM_ADDRESS, TO_ADDRESS)
    end

    puts "[#{index + 1}/#{email_files.length}] ✓ #{filename}"
    sleep(DELAY) if index < email_files.length - 1
  rescue => e
    puts "[#{index + 1}/#{email_files.length}] ✗ #{filename} - Error: #{e.message}"
  end
end

puts "=" * 60
puts "All emails sent!"
puts ""
puts "View them at: http://#{SMTP_HOST}:1080"
