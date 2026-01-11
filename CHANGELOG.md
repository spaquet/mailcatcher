# Changelog

All notable changes to MailCatcher NG will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- **1.3.1**: Code refactoring for index.erb to improve maintainability and reduce complexity
- **1.3.2**: Add sorting/ordering functionality for message list by To, From, Subject, and received date
- **1.3.3**: Add comprehensive test coverage for SMTP transcript and message handling features

## [1.3.0] - 2026-01-11

### Added
- **SMTP Transcript Feature**: Complete protocol-level logging for all SMTP and SMTPS connections
  - Log every SMTP command and server response with millisecond-precision timestamps
  - Capture full connection details (client/server IP addresses and ports)
  - Track TLS/SSL session information including protocol version and cipher suite
  - Generate unique session IDs for each SMTP connection for easier debugging
  - Store complete transcript as JSON in SQLite database, automatically linked to each email
  - Web UI "Transcript" tab displaying formatted SMTP session logs
  - Search/filter functionality for transcript entries to find specific commands or responses
  - Color-coded entry types (connection, command, response, TLS, data, error) for visual scanning
  - Direction indicators (→ for client, ← for server) to clearly show message flow

### Changed
- Updated version to 1.3.0 to reflect major feature addition

### Technical Details
- New SQLite table `smtp_transcript` with foreign key relationship to messages
- New API endpoint `/messages/:id.transcript` for HTML transcript display
- New API endpoint `/messages/:id/transcript.json` for JSON data access
- New ERB template `views/transcript.erb` for transcript rendering
- Extended SMTP server logging in `lib/mail_catcher/smtp.rb` to capture all protocol events
- Added database schema and access methods in `lib/mail_catcher/mail.rb`
- Web API now includes "transcript" in message formats array

## [1.2.0] - 2026-01-10

### Added
- **Modern UI Redesign**: Complete redesign of the MailCatcher web interface
  - Responsive flexbox-based layout that adapts to different screen sizes
  - Improved visual hierarchy with better typography and spacing
  - Professional color scheme with better contrast and readability
  - Smooth transitions and hover effects for better user experience

- **Enhanced Email Display**: Better formatting and presentation of received emails
  - Tabbed interface for switching between HTML, Plain Text, and Source views
  - Improved syntax highlighting for email source code
  - Better handling of multipart emails and MIME types
  - Enhanced attachment display with file type icons and metadata

- **Message Management**: Improved message handling and organization
  - Real-time email count display
  - Better message selection and navigation
  - Improved handling of large email bodies
  - More efficient message storage and retrieval

- **WebSocket Integration**: Real-time updates for email delivery
  - Live message list updates without page refresh
  - Real-time notification of new emails using WebSocket
  - Connection status indicator with automatic reconnection

- **Authentication Information Display**: Enhanced email authentication visualization
  - Display SPF, DKIM, and DMARC authentication results
  - Show BIMI (Brand Indicators for Message Identification) location
  - S/MIME and PGP encryption detection and display
  - Detailed authentication header parsing

- **Performance Improvements**:
  - Optimized SQLite queries with proper indexing
  - Efficient asset loading and caching
  - Improved JavaScript event handling
  - Better memory management for large email lists

### Changed
- Updated version to 1.2.0
- Significantly refactored views/index.erb for modern responsive design
- Updated CoffeeScript for better UI interactions
- Improved CSS organization and maintainability

### Fixed
- Better handling of special characters in email addresses
- Improved stability with large attachments
- Fixed UI issues with very long email subjects
- Improved mobile browser compatibility

---

## Notes on Future Versions

### Version 1.3.1
Expected improvements to `views/index.erb`:
- Extract inline styles to separate CSS sections
- Modularize template for better readability
- Improve template logic organization
- Optimize rendering performance

### Version 1.3.2
Message list ordering features:
- Sort messages by recipient (To field)
- Sort messages by sender (From field)
- Sort messages by subject line
- Sort messages by received date (ascending/descending)
- Persist user's sort preference in browser storage

### Version 1.3.3
Testing infrastructure:
- Add unit tests for SMTP transcript functionality
- Add integration tests for message handling
- Add UI tests for transcript display
- Improve test coverage for edge cases
- Add performance benchmarks

