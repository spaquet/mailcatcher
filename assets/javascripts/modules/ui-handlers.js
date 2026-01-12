// UI event handlers (buttons, count, etc.)
window.MailCatcherUI = window.MailCatcherUI || {};

window.MailCatcherUI.initializeUIHandlers = function() {
  // Update email count display
  function updateEmailCount() {
    const count = document.querySelectorAll('#messages tbody tr').length;
    document.getElementById('emailCount').textContent = count === 1 ? '1 email' : count + ' emails';
  }

  // Setup button handlers
  const serverInfoBtn = document.getElementById('serverInfoBtn');
  if (serverInfoBtn) {
    serverInfoBtn.addEventListener('click', function(e) {
      e.preventDefault();
      window.location.href = new URL('server-info', document.baseURI).toString();
    });
  }

  const clearBtn = document.getElementById('clearBtn');
  if (clearBtn) {
    clearBtn.addEventListener('click', function(e) {
      e.preventDefault();
      if (window.MailCatcher && document.querySelectorAll('#messages tbody tr').length > 0) {
        const confirmText = 'You will lose all your received messages.\n\nAre you sure you want to clear all messages?';
        if (confirm(confirmText)) {
          window.MailCatcher.clearMessages();
          // Also send DELETE request
          fetch(new URL('messages', document.baseURI).toString(), { method: 'DELETE' });
        }
      }
    });
  }

  const quitBtn = document.getElementById('quitBtn');
  if (quitBtn) {
    quitBtn.addEventListener('click', function(e) {
      e.preventDefault();
      const confirmText = 'You will lose all your received messages.\n\nAre you sure you want to quit?';
      if (confirm(confirmText)) {
        if (window.MailCatcher) {
          window.MailCatcher.quitting = true;
        }
        fetch(new URL('', document.baseURI).toString(), { method: 'DELETE' });
      }
    });
  }

  // Monitor updates for email count
  const observer = new MutationObserver(() => updateEmailCount());
  const tbody = document.querySelector('#messages tbody');
  if (tbody) {
    observer.observe(tbody, { childList: true });
  }

  // Handle download button
  const downloadBtn = document.querySelector('.download-btn');
  if (downloadBtn) {
    downloadBtn.addEventListener('click', function(e) {
      e.preventDefault();
      if (window.MailCatcher) {
        const id = window.MailCatcher.selectedMessage();
        if (id) {
          window.location.href = `messages/${id}.eml`;
        }
      }
    });
  }

  // Handle copy source button
  const copySourceBtn = document.getElementById('copySourceBtn');
  if (copySourceBtn) {
    copySourceBtn.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      if (window.MailCatcher) {
        const id = window.MailCatcher.selectedMessage();
        if (id) {
          // Fetch the raw email source
          fetch(`messages/${id}.source`)
            .then(response => response.text())
            .then(sourceText => {
              // Copy to clipboard
              navigator.clipboard.writeText(sourceText)
                .then(() => {
                  // Show checkmark icon
                  const copyIcon = copySourceBtn.querySelector('.copy-icon');
                  const checkmarkIcon = copySourceBtn.querySelector('.checkmark-icon');

                  if (copyIcon && checkmarkIcon) {
                    copyIcon.style.display = 'none';
                    checkmarkIcon.style.display = 'block';

                    // Reset after 3 seconds
                    setTimeout(() => {
                      copyIcon.style.display = 'block';
                      checkmarkIcon.style.display = 'none';
                    }, 3000);
                  }

                  console.log('Email source copied to clipboard');
                })
                .catch(err => {
                  console.error('Failed to copy to clipboard:', err);
                  alert('Failed to copy email source to clipboard');
                });
            })
            .catch(err => {
              console.error('Failed to fetch email source:', err);
              alert('Failed to load email source');
            });
        }
      }
    });
  }

  // Initial count update
  updateEmailCount();
};
