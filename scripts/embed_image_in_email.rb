#!/usr/bin/env ruby
# frozen_string_literal: true

require 'base64'

# This script helps embed an image into the mailcatcher_redesign email template

if ARGV.empty? || !File.exist?(ARGV[0])
  puts "Usage: ruby embed_image_in_email.rb <image_file_path>"
  puts "Example: ruby embed_image_in_email.rb ./path/to/mailcatcher-characters.png"
  exit 1
end

image_path = ARGV[0]
image_data = File.read(image_path)
encoded_image = Base64.strict_encode64(image_data)

# Format the base64 data with proper line breaks (76 chars per line for MIME)
formatted_image = encoded_image.scan(/.{1,76}/).join("\n")

puts "Base64 encoded image (ready to paste into examples/mailcatcher_redesign):"
puts "------==_mimepart_redesign_mailcatcher"
puts "Content-Type: image/png; name=\"mailcatcher-characters.png\""
puts "Content-Transfer-Encoding: base64"
puts "Content-Disposition: inline; filename=\"mailcatcher-characters.png\""
puts "Content-ID: <mailcatcher-characters>"
puts ""
puts formatted_image
puts ""
puts "------==_mimepart_redesign_mailcatcher--"
