# Preview Text Extraction

MailCatcher uses a 3-tier fallback system to extract email preview text for display in the inbox list. This document explains the system, why each tier exists, and how to use it.

## Overview

Email preview text (also called "preheader" or "preview pane text") is the brief summary shown next to or below the subject line in email clients. MailCatcher supports multiple ways to provide this preview text, using a priority-based fallback system.

## The 3-Tier Fallback System

### Tier 1: Preview-Text Header (De Facto Standard)

**What it is**: A custom email header field `Preview-Text` that explicitly specifies preview text.

**Format**:
```
Preview-Text: This is the preview text displayed in the inbox
```

**Why it exists**:
- Email clients increasingly recognize this de facto standard header
- Senders can explicitly control what preview text appears
- Provides the most reliable and predictable preview text
- Supported by clients like Gmail, Outlook, Apple Mail, and others

**Implementation**:
- Backend: `Mail.message_preview_text(id)` extracts from email headers
- Frontend: `fullMessage.preview_text` in JSON response
- Logic: Check if header exists and use its value if present

**RFC Status**: Not formally standardized, but widely adopted as a de facto standard

### Tier 2: HTML Body Preheader (Client Compatibility)

**What it is**: Hidden text at the beginning of an HTML email that email clients display as preview text.

**Format**:
```html
<html>
<body>
<!-- Hidden preheader text using display:none -->
<span style="display:none; font-size:0; line-height:0; max-height:0; overflow:hidden;">
This is preview text that email clients will extract
</span>

<!-- Rest of email content -->
<div class="email-content">
  ...
</div>
</body>
</html>
```

**Why it exists**:
- Legacy compatibility for email clients that don't recognize the Preview-Text header
- Email designers have been using this pattern for years
- Older email clients can still extract meaningful preview text
- Works across all email platforms

**Implementation**:
- Currently handled by `getEmailPreview()` which extracts the first ~100 characters
- Strips HTML tags to reveal hidden preheader text
- Falls back to regular body content if no hidden preheader is found

### Tier 3: First Content Lines (Fallback)

**What it is**: The first 100 characters of visible email content.

**Why it exists**:
- Fallback for emails without explicit preview metadata
- Provides at least some preview when senders haven't specified one
- Ensures all emails have some preview text

**Implementation**:
- `getEmailPreview()` extracts first 100 chars from email body
- Strips HTML tags for cleaner text
- Appends "..." if text exceeds 100 characters

## Code Implementation

### Backend

**File**: `lib/mail_catcher/mail.rb`

```ruby
def message_preview_text(id)
  source = message_source(id)
  return nil unless source

  # Extract Preview-Text header from email source (tier 1)
  source.each_line do |line|
    break if line.strip.empty?
    if line.match?(/^preview-text:\s*/i)
      value = line.sub(/^preview-text:\s*/i, '').strip
      return value unless value.empty?
    end
  end

  nil
end
```

**File**: `lib/mail_catcher/web/application.rb`

```ruby
get "/messages/:id.json" do
  id = params[:id].to_i
  if message = Mail.message(id)
    content_type :json
    JSON.generate(message.merge({
      "formats" => [...],
      "attachments" => Mail.message_attachments(id),
      "bimi_location" => Mail.message_bimi_location(id),
      "preview_text" => Mail.message_preview_text(id),  # Tier 1
      "authentication_results" => Mail.message_authentication_results(id),
    }))
  else
    not_found
  end
end
```

### Frontend

**File**: `assets/javascripts/mailcatcher.js.coffee`

```coffeescript
# Extract and display email preview using 3-tier fallback system
if fullMessage.preview_text
  # Tier 1: Preview-Text header from email metadata
  $preview.text(fullMessage.preview_text)
else
  # Tiers 2-3: Extract from email body (HTML preheader or first content lines)
  self.getEmailPreview(fullMessage, (previewText) ->
    $preview.text(previewText)
  )

getEmailPreview: (message, callback) ->
  # Extract email preview using tiers 2-3 of the preview text fallback system:
  # Tier 2: Extract preheader text from HTML body (hidden text at start)
  # Tier 3: Extract first 100 characters of email content (fallback)
  # ...
```

## Testing

Tests are located in `spec/preview_text_spec.rb` and validate all three tiers:

1. **Tier 1 Test**: `promotional_email` - Has Preview-Text header and HTML preheader
2. **Tier 2 Test**: `newsletter_with_preview` - Has Preview-Text header and HTML preheader
3. **Tier 3 Tests**: `htmlmail`, `plainmail` - Have neither Preview-Text header nor HTML preheader

Run tests:
```bash
bundle exec rspec spec/preview_text_spec.rb
```

## Example Emails

### With Preview-Text Header and HTML Preheader

**File**: `examples/promotional_email`

```
To: Subscriber <subscriber@email.com>
From: Deals <deals@retailer.com>
Subject: Exclusive 50% Off Sale - This Weekend Only!
Preview-Text: Get 50% off everything this weekend! Limited time flash sale on electronics, fashion, and more.
Content-Type: text/html; charset=utf-8

<html>
<head>...</head>
<body>
<span style="display:none; font-size:0; line-height:0; max-height:0; overflow:hidden;">
Get 50% off everything this weekend! Limited time flash sale on electronics, fashion, and more.
</span>
<!-- Email content -->
</body>
</html>
```

### Without Preview Text

**File**: `examples/htmlmail`

Plain HTML email without Preview-Text header or hidden preheader - will use first visible content as preview.

## Priority and Fallback Logic

The selection logic is straightforward:

```
if Preview-Text header exists:
  use Preview-Text header value
else if email is HTML:
  extract first 100 chars from HTML body (may be hidden preheader)
else if email is plain text:
  extract first 100 chars from plain text
else:
  show empty preview
```

## Best Practices

### For Email Designers

1. **Include Preview-Text Header**: Always add the Preview-Text header for explicit control
   ```
   Preview-Text: Brief summary of email content
   ```

2. **Add HTML Preheader**: Include hidden preheader text for compatibility
   ```html
   <span style="display:none; font-size:0; line-height:0; max-height:0; overflow:hidden;">
   Same content as Preview-Text header
   </span>
   ```

3. **Keep it Brief**: Preview text is typically 45-150 characters
   - Desktop: ~50-100 characters visible
   - Mobile: ~35-50 characters visible

### For Developers

1. **Don't Assume a Single Method**: Always support all three tiers
2. **Test All Scenarios**: Include tests for emails with and without preview text
3. **Preserve HTML Preheader**: Don't remove or modify hidden elements unnecessarily

## Browser/Client Compatibility

| Tier | Gmail | Outlook | Apple Mail | Other Clients |
|------|-------|---------|------------|---------------|
| Preview-Text Header | ✓ | ✓ | ✓ | Most modern clients |
| HTML Preheader | ✓ | ✓ | ✓ | Most clients |
| First Content Line | ✓ | ✓ | ✓ | All clients |

## Troubleshooting

### Preview Text Not Showing

1. **Check Preview-Text Header**: Verify it's formatted correctly
   ```
   Preview-Text: Your preview text here
   ```

2. **Check HTML Preheader**: Ensure hidden text is properly formatted
   - Use `display:none`, `font-size:0`, `line-height:0`, `max-height:0`, `overflow:hidden`
   - Place immediately after `<body>` tag

3. **Check Email Format**: Verify email contains HTML or plain text content

4. **Check Email Client**: Some clients may have user settings that disable preview text

## References

- [Campaign Monitor - The Ultimate Guide to Preview Text](https://www.campaignmonitor.com/)
- [Litmus - Email Client Support for Preview Text](https://www.litmus.com/)
- [Email Markup - Preview Text Header Usage](https://www.emailonacid.com/)
