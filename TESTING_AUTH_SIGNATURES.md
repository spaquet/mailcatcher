# Testing Email Signature Verification (DMARC, DKIM, SPF)

This document explains how to test the new email signature verification tooltip feature.

## Overview

Four new test emails have been added to the `examples/` directory with different authentication results:

1. **auth_all_pass** - All authentication methods pass (DMARC, DKIM, SPF)
2. **auth_mixed** - Mixed results (DMARC fails, DKIM and SPF pass)
3. **auth_partial_data** - Only SPF is checked (DMARC and DKIM not present)
4. **auth_all_fail** - All authentication methods fail

## How to Test

### 1. Start MailCatcher

```bash
cd /Users/spaquet/Sites/mailcatcher
bundle exec mailcatcher
```

This starts the MailCatcher server on `http://127.0.0.1:1080`

### 2. Send the Test Emails

In a new terminal, run the example email sender:

```bash
cd /Users/spaquet/Sites/mailcatcher
bundle exec ruby send_example_emails.rb
```

This will send all example emails, including the new authentication test emails. You should see:
```
...
[21/22] ✓ auth_all_pass
[22/22] ✓ auth_mixed
[23/24] ✓ auth_partial_data
[24/25] ✓ auth_all_fail
```

### 3. View the Emails in MailCatcher UI

1. Open `http://127.0.0.1:1080` in your browser
2. Click on one of the new authentication test emails in the left sidebar:
   - "Email with All Auth Methods Passing"
   - "Email with Mixed Auth Results"
   - "Email with Only SPF Authentication"
   - "Email with All Auth Methods Failing"

### 4. Test the Signature Info Button

1. When an email is selected, look at the message header (top right area)
2. You'll see a **shield icon button** (🛡️) next to the Download button
3. Click the shield icon to open the signature verification tooltip
4. The tooltip will display:
   - **DMARC** status (Pass/Fail/Not checked)
   - **DKIM** status (Pass/Fail/Not checked)
   - **SPF** status (Pass/Fail/Not checked)

## Visual Indicators

### Status Badges

- **Green badge (Pass)** - Authentication passed
- **Red badge (Fail)** - Authentication failed
- **Gray badge (Not checked)** - Authentication method not present in headers

## Expected Results

### Email: "Email with All Auth Methods Passing"
```
DMARC: Pass ✓
DKIM: Pass ✓
SPF: Pass ✓
```
All green badges - trusted email from verified sender.

### Email: "Email with Mixed Auth Results"
```
DMARC: Fail ✗
DKIM: Pass ✓
SPF: Pass ✓
```
Mixed badges - DMARC failed, but DKIM and SPF passed.

### Email: "Email with Only SPF Authentication"
```
DMARC: Not checked
DKIM: Not checked
SPF: Pass ✓
```
Only SPF available - server only performed SPF validation.

### Email: "Email with All Auth Methods Failing"
```
DMARC: Fail ✗
DKIM: Fail ✗
SPF: Fail ✗
```
All red badges - unverified email, use with caution.

## Implementation Details

### Backend

- **File**: `lib/mail_catcher/mail.rb`
- **Method**: `message_authentication_results(id)`
- Extracts the `Authentication-Results` header from email source
- Parses DMARC, DKIM, and SPF results
- Returns a hash with the results

### Frontend

- **File**: `views/index.erb`
- **Component**: Signature info button with shield icon
- **Library**: Tippy.js v6 for tooltip functionality
- Fetches authentication data via the `/messages/:id.json` API
- Displays results in a formatted tooltip

### API

- **Endpoint**: `GET /messages/:id.json`
- **New field**: `authentication_results`
- Returns object with `dmarc`, `dkim`, `spf` keys (values or nil)

## Troubleshooting

### Tooltip doesn't appear
- Make sure you've selected an email first
- Check browser console for any JavaScript errors
- Verify Tippy.js CDN is loading correctly

### No authentication data shown
- Some emails may not have authentication headers (expected behavior)
- The tooltip will show "No authentication headers found for this email"
- This is correct for emails without the `Authentication-Results` header

### Status badges show wrong colors
- Verify the email's `Authentication-Results` header contains `dmarc=`, `dkim=`, or `spf=` directives
- The parser is case-insensitive and looks for these exact patterns

## File Locations

- Test emails: `/Users/spaquet/Sites/mailcatcher/examples/auth_*`
- Test script: `/Users/spaquet/Sites/mailcatcher/send_example_emails.rb`
- Backend logic: `/Users/spaquet/Sites/mailcatcher/lib/mail_catcher/mail.rb`
- Frontend UI: `/Users/spaquet/Sites/mailcatcher/views/index.erb`
