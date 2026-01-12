# Changelog

All notable changes to MailCatcher NG will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0] - 2026-01-12

### Added

- **SMTP Transcript Enhancements**: Improved transcript capture and storage
  - Connection closure entries now properly included in transcripts
  - Full conversation history from connection establishment to closure
  - Persistent database option with `--persistence` flag for storing messages in SQLite

- **Test Improvements**: Comprehensive test fixes and enhancements
  - Fixed JSON endpoint tests with proper response parsing
  - Added helper methods for Capybara/Selenium compatibility
  - Fixed HTML text matching with CSS text-transform considerations
  - Improved 404 error handling in tests

### Changed

- **Transcript Saving Logic**: Deferred transcript saving until connection close
  - Transcripts now save when connection closes (in `unbind` method)
  - Ensures "Connection closed" entry is captured in final transcript
  - Maintains message_id linkage when available

- **Database**: Changed from in-memory SQLite to optional persistent storage
  - New `determine_db_path` method for flexible storage configuration
  - In-memory by default, persistent when `--persistence` flag is used

### Fixed

- Connection closure not being recorded in SMTP transcripts
- Transcript entries not being preserved after message delivery
- JSON response parsing in Selenium/Capybara tests
- HTML text matching failures due to CSS text transformation

## [1.3.3] - 2026-01-12

### Added

- **Comprehensive Test Coverage**: Enhanced test suite for SMTP transcript and message handling
  - Full coverage for transcript creation and storage
  - Tests for message deletion and cleanup functionality
  - Edge case handling and validation tests

- **Server Info Page Redesign**: Complete redesign of server-info page with real-time monitoring
  - 2-column layout: left column for server info (compact), right column for server logs
  - Compact server configuration display (Network, SMTP, HTTP settings)
  - "Server Settings" placeholder block with Diagnostics button
  - "Back to Inbox" button moved to top of page
  - Display all SMTP/SMTPS logs in real-time with auto-refresh capability
  - Real-time log fetching via `/logs.json` API endpoint (1 second refresh)
  - Auto-refresh toggle button (ON/OFF) with intelligent resume
  - Searchable/filterable log display with same design as transcript view
  - Show session ID in each log entry with truncation (e.g., a89f3657...)
  - Tippy.js tooltip with full session ID and copy-to-clipboard button
  - Copy button shows checkmark feedback and resets after 2 seconds

### Changed

- Removed Active Connections section from UI
- Enhanced database query methods with `all_transcript_entries` for fetching full log details
- Updated `delete!` method to clear both messages and SMTP transcripts

### Technical Details

- New API endpoint: `/logs.json` for real-time log fetching
- Extended database access methods in `lib/mail_catcher/mail.rb` with `all_transcript_entries`
- Updated views/server-info.erb with new layout and real-time capabilities
- Added auto-refresh state management for log display
- Integrated Tippy.js for session ID tooltips with copy functionality

## [1.3.2] - 2026-01-12

### Added

- **Message List Sorting**: Add sorting/ordering functionality for message list
  - Sortable column headers for From, To, Subject, and Received date
  - Click headers to sort ascending (A→Z or oldest→newest)
  - Click again to sort descending (Z→A or newest→oldest)
  - Click different column to switch sort field
  - Visual indicators with up/down arrow icons showing active sort field and direction
  - Arrow icons highlight in blue when active
  - Full integration with existing search and attachment filter functionality

### Technical Details

- New sorting methods in MailCatcher class:
  - `setSortField()`: Handle sort field selection and direction toggling
  - `sortMessages()`: Reorder table rows based on selected column and direction
  - `getSortValue()`: Extract comparable values from table cells
  - `compareSortValues()`: Case-insensitive string comparison and date parsing
  - `updateSortIndicators()`: Manage visual indicators for active sort state
- Enhanced table header structure with dual SVG icons (up/down arrows)
- New CSS styling for sortable headers with hover and active states
- Sort state properties: `currentSortField` and `currentSortDirection`

## [1.3.1] - 2026-01-11

### Added

- **Code Modularization**: Refactored views/index.erb to separate CSS and JavaScript concerns
  - Extracted 1305 lines of inline CSS to `assets/stylesheets/mailcatcher.css`
  - Modularized 507 lines of JavaScript into focused ES6 modules in `assets/javascripts/modules/`
  - Created modular architecture: utils, resizer, ui-handlers, and tooltips modules
  - Maintained full backward compatibility with all existing features

### Changed

- **Improved Plain Text Email Display**:
  - Added styled background color (#f5f5f5) matching source tab aesthetic
  - Applied monospace font for better readability (Monaco, Courier New, Consolas)
  - Added proper padding (20px 28px) to match spacing in other tabs
  - Increased line-height to 1.6 for improved text readability
  - Set explicit text color for better contrast
- Updated views/index.erb from 1992 to 181 lines by extracting CSS and JavaScript
- Refactored JavaScript to use namespace pattern (window.MailCatcherUI) for modules
- Updated Rakefile with selective minification to support modern ES6+ syntax

### Technical Details

- New CSS file: `assets/stylesheets/mailcatcher.css` (extracted from index.erb)
- New JS entry point: `assets/javascripts/mailcatcher-ui.js` (Sprockets directives)
- New JS modules in `assets/javascripts/modules/`:
  - `utils.js`: HTML escaping utility
  - `resizer.js`: Message list resize functionality with localStorage persistence
  - `ui-handlers.js`: Button handlers, email count, download, copy source
  - `tooltips.js`: Signature and encryption information tooltips (Tippy.js)
- Enhanced Uglifier configuration with SelectiveUglifier class to skip modern syntax minification
- All 45 tests passing without any breaking changes

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

