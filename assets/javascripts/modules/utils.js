// Utility functions for MailCatcher UI
window.MailCatcherUI = window.MailCatcherUI || {};

// HTML escape utility
window.MailCatcherUI.escapeHtml = function(text) {
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  };
  return text.replace(/[&<>"']/g, m => map[m]);
};
