#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/smtp'
require 'fileutils'

# Configuration
SMTP_HOST = ENV['SMTP_HOST'] || '127.0.0.1'
SMTP_PORT = ENV['SMTP_PORT'] || 1025
EXAMPLES_DIR = File.expand_path('examples', __dir__)
FROM_ADDRESS = ENV['FROM_ADDRESS'] || 'test@example.com'
TO_ADDRESS = ENV['TO_ADDRESS'] || 'recipient@example.com'
DELAY = (ENV['DELAY'] || 1).to_i

# Define example emails to send (in order, excluding binary 'attachment' file)
example_names = [
  'mail',
  'plainmail',
  'plainlinkmail',
  'htmlmail',
  'xhtmlmail',
  'quoted_printable_htmlmail',
  'multipartmail',
  'multipartmail-with-utf8',
  'attachmail',
  'multiattachmail',
  'dotmail',
  'unknownmail',
  'breaking',
  'mailcatcher_redesign',          # Large email with full redesign content
  'bimi_email',                    # BIMI branded email
  'newsletter_with_preview',       # Newsletter with preview content
  'enterprise_branded_email',      # Enterprise branded email with BIMI
  'promotional_email',             # Promotional email with rich preview
  'auth_all_pass',                 # Email with all auth methods passing
  'auth_mixed',                    # Email with mixed auth results
  'auth_partial_data',             # Email with only SPF authentication
  'auth_all_fail',                 # Email with all auth methods failing
  '8bit-utf8-multipartmail',       # 8bit UTF-8 multipart email
  '8bit-utf8mail',                 # 8bit UTF-8 simple email
  'verification_email',            # New: Email with verification link and OTP
  'password_reset',                # New: Email with password reset token
  'newsletter_with_links',         # New: Newsletter with multiple links and List-Unsubscribe
  'accessible_email',              # New: Email with good accessibility practices
  'poor_accessibility_email'       # New: Email demonstrating accessibility issues
]

# Get list of email files to send
email_files = example_names.map do |name|
  file = File.join(EXAMPLES_DIR, name)
  File.exist?(file) ? file : nil
end.compact

if email_files.empty?
  puts "No email files found in #{EXAMPLES_DIR}"
  exit 1
end

puts "Sending #{email_files.length} example emails to #{SMTP_HOST}:#{SMTP_PORT}"
puts '=' * 60

email_files.sort.each_with_index do |file, index|
  filename = File.basename(file)

  begin
    # Read the email content
    content = File.read(file)

    # Create a message with a descriptive subject if one doesn't exist
    # This helps identify emails when they arrive in different order
    if content.include?('Subject:')
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
  rescue StandardError => e
    puts "[#{index + 1}/#{email_files.length}] ✗ #{filename} - Error: #{e.message}"
  end
end

puts '=' * 60
puts 'All emails sent!'
puts ''
puts "View them at: http://#{SMTP_HOST}:1080"
