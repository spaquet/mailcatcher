//= require modules/utils
//= require modules/resizer
//= require modules/ui-handlers
//= require modules/tooltips

// Initialize all UI components on page load
document.addEventListener('DOMContentLoaded', function() {
  // Initialize UI components in order
  window.MailCatcherUI.initializeResizer();
  window.MailCatcherUI.initializeUIHandlers();
  window.MailCatcherUI.initializeSignatureTooltip();
  window.MailCatcherUI.initializeEncryptionTooltip();

  console.log('[MailCatcher] UI components initialized');
});
