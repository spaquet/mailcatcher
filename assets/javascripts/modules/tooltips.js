// Email signature and encryption tooltips
window.MailCatcherUI = window.MailCatcherUI || {};

window.MailCatcherUI.initializeSignatureTooltip = function() {
  const signatureInfoBtn = document.getElementById('signatureInfoBtn');
  let signatureTooltip = null;

  function getStatusBadgeClass(status) {
    if (!status) return 'neutral';
    return status === 'pass' ? 'pass' : status === 'fail' ? 'fail' : 'neutral';
  }

  function getStatusLabel(status) {
    if (!status) return 'Not checked';
    return status.charAt(0).toUpperCase() + status.slice(1);
  }

  function generateSignatureContent(authResults) {
    const dmarc = authResults?.dmarc;
    const dkim = authResults?.dkim;
    const spf = authResults?.spf;

    // Check if any auth data exists
    const hasAuthData = dmarc || dkim || spf;

    if (!hasAuthData) {
      return `
        <div class="signature-tooltip-content">
          <p style="color: #999; font-size: 12px;">No authentication headers found for this email.</p>
        </div>
      `;
    }

    return `
      <div class="signature-tooltip-content">
        ${dmarc ? `
          <h3>DMARC</h3>
          <div class="signature-tooltip-item">
            <span class="signature-status-badge ${getStatusBadgeClass(dmarc)}">
              ${getStatusLabel(dmarc)}
            </span>
          </div>
        ` : ''}
        ${dkim ? `
          <h3>DKIM</h3>
          <div class="signature-tooltip-item">
            <span class="signature-status-badge ${getStatusBadgeClass(dkim)}">
              ${getStatusLabel(dkim)}
            </span>
          </div>
        ` : ''}
        ${spf ? `
          <h3>SPF</h3>
          <div class="signature-tooltip-item">
            <span class="signature-status-badge ${getStatusBadgeClass(spf)}">
              ${getStatusLabel(spf)}
            </span>
          </div>
        ` : ''}
      </div>
    `;
  }

  if (signatureInfoBtn) {
    signatureInfoBtn.addEventListener('click', function(e) {
      e.preventDefault();
      if (window.MailCatcher) {
        const messageId = window.MailCatcher.selectedMessage();
        if (!messageId) return;

        // Destroy existing tooltip if any
        if (signatureTooltip) {
          signatureTooltip.destroy();
        }

        // Fetch message data
        fetch(new URL(`messages/${messageId}.json`, document.baseURI).toString())
          .then(response => response.json())
          .then(data => {
            const authResults = data.authentication_results || {};
            const content = generateSignatureContent(authResults);

            // Create tooltip with content
            signatureTooltip = tippy(signatureInfoBtn, {
              content: content,
              allowHTML: true,
              theme: 'light',
              placement: 'bottom-start',
              interactive: true,
              duration: [200, 150],
              arrow: true,
              trigger: 'manual',
              maxWidth: 360,
              onClickOutside: (instance) => {
                instance.hide();
              },
            });

            // Show tooltip
            signatureTooltip.show();
          })
          .catch(error => {
            console.error('Error fetching signature data:', error);
            const errorContent = `
              <div class="signature-tooltip-content">
                <p style="color: #999; font-size: 12px;">Error loading signature data.</p>
              </div>
            `;

            signatureTooltip = tippy(signatureInfoBtn, {
              content: errorContent,
              allowHTML: true,
              theme: 'light',
              placement: 'bottom-start',
              interactive: true,
              duration: [200, 150],
              arrow: true,
              trigger: 'manual',
              onClickOutside: (instance) => {
                instance.hide();
              },
            });

            signatureTooltip.show();
          });
      }
    });

    // Close tooltip when clicking elsewhere
    document.addEventListener('click', function(e) {
      // Check if this click is on the button
      if (signatureInfoBtn && signatureInfoBtn.contains(e.target)) return;

      // Check if this click is on a tippy-box
      if (e.target.closest('.tippy-box')) return;

      // Click is outside everything, hide tooltip
      if (signatureTooltip) {
        signatureTooltip.hide();
      }

      // Also ensure any visible tippy-box is hidden
      const visibleBoxes = document.querySelectorAll('.tippy-box[data-state="visible"]');
      visibleBoxes.forEach(box => {
        box.style.visibility = 'hidden';
        box.style.pointerEvents = 'none';
      });
    });
  }
};

window.MailCatcherUI.initializeEncryptionTooltip = function() {
  const encryptionInfoBtn = document.getElementById('encryptionInfoBtn');
  let encryptionTooltip = null;

  function generateEncryptionContent(encryptionData) {
    const smime = encryptionData?.smime;
    const pgp = encryptionData?.pgp;

    // Check if any encryption data exists
    const hasEncryptionData = smime || pgp;

    if (!hasEncryptionData) {
      return `
        <div class="encryption-tooltip-content">
          <p class="encryption-no-data">No encryption or signature information found for this email.</p>
        </div>
      `;
    }

    let content = '<div class="encryption-tooltip-content">';

    if (smime) {
      content += `
        <h3>S/MIME</h3>
        ${smime.certificate ? `
          <div class="encryption-info-item">
            <span class="encryption-info-label">Certificate:</span>
            <span class="encryption-info-value">${window.MailCatcherUI.escapeHtml(smime.certificate.substring(0, 40))}...</span>
          </div>
          <button class="encryption-copy-button" data-copy-type="smime-cert" data-value="${window.MailCatcherUI.escapeHtml(smime.certificate)}">
            <svg fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 7.5V6.108c0-1.135.845-2.098 1.976-2.192.373-.03.748-.057 1.123-.08M15.75 18H18a2.25 2.25 0 0 0 2.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 0 0-1.123-.08M15.75 18.75v-1.875a3.375 3.375 0 0 0-3.375-3.375h-1.5a1.125 1.125 0 0 1-1.125-1.125v-1.5A3.375 3.375 0 0 0 6.375 7.5H5.25m11.9-3.664A2.251 2.251 0 0 0 15 2.25h-1.5a2.251 2.251 0 0 0-2.15 1.586m5.8 0c.065.21.1.433.1.664v.75h-6V4.5c0-.231.035-.454.1-.664M6.75 7.5H4.875c-.621 0-1.125.504-1.125 1.125v12c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V16.5a9 9 0 0 0-9-9Z"></path>
            </svg>
            Copy Certificate
          </button>
        ` : ''}
        ${smime.signature ? `
          <div class="encryption-info-item">
            <span class="encryption-info-label">Signature:</span>
            <span class="encryption-info-value">${window.MailCatcherUI.escapeHtml(smime.signature.substring(0, 40))}...</span>
          </div>
          <button class="encryption-copy-button" data-copy-type="smime-sig" data-value="${window.MailCatcherUI.escapeHtml(smime.signature)}">
            <svg fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 7.5V6.108c0-1.135.845-2.098 1.976-2.192.373-.03.748-.057 1.123-.08M15.75 18H18a2.25 2.25 0 0 0 2.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 0 0-1.123-.08M15.75 18.75v-1.875a3.375 3.375 0 0 0-3.375-3.375h-1.5a1.125 1.125 0 0 1-1.125-1.125v-1.5A3.375 3.375 0 0 0 6.375 7.5H5.25m11.9-3.664A2.251 2.251 0 0 0 15 2.25h-1.5a2.251 2.251 0 0 0-2.15 1.586m5.8 0c.065.21.1.433.1.664v.75h-6V4.5c0-.231.035-.454.1-.664M6.75 7.5H4.875c-.621 0-1.125.504-1.125 1.125v12c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V16.5a9 9 0 0 0-9-9Z"></path>
            </svg>
            Copy Signature
          </button>
        ` : ''}
      `;
    }

    if (pgp) {
      content += `
        <h3>OpenPGP</h3>
        ${pgp.key ? `
          <div class="encryption-info-item">
            <span class="encryption-info-label">Key:</span>
            <span class="encryption-info-value">${window.MailCatcherUI.escapeHtml(pgp.key.substring(0, 40))}...</span>
          </div>
          <button class="encryption-copy-button" data-copy-type="pgp-key" data-value="${window.MailCatcherUI.escapeHtml(pgp.key)}">
            <svg fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 7.5V6.108c0-1.135.845-2.098 1.976-2.192.373-.03.748-.057 1.123-.08M15.75 18H18a2.25 2.25 0 0 0 2.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 0 0-1.123-.08M15.75 18.75v-1.875a3.375 3.375 0 0 0-3.375-3.375h-1.5a1.125 1.125 0 0 1-1.125-1.125v-1.5A3.375 3.375 0 0 0 6.375 7.5H5.25m11.9-3.664A2.251 2.251 0 0 0 15 2.25h-1.5a2.251 2.251 0 0 0-2.15 1.586m5.8 0c.065.21.1.433.1.664v.75h-6V4.5c0-.231.035-.454.1-.664M6.75 7.5H4.875c-.621 0-1.125.504-1.125 1.125v12c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V16.5a9 9 0 0 0-9-9Z"></path>
            </svg>
            Copy Key
          </button>
        ` : ''}
        ${pgp.signature ? `
          <div class="encryption-info-item">
            <span class="encryption-info-label">Signature:</span>
            <span class="encryption-info-value">${window.MailCatcherUI.escapeHtml(pgp.signature.substring(0, 40))}...</span>
          </div>
          <button class="encryption-copy-button" data-copy-type="pgp-sig" data-value="${window.MailCatcherUI.escapeHtml(pgp.signature)}">
            <svg fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 7.5V6.108c0-1.135.845-2.098 1.976-2.192.373-.03.748-.057 1.123-.08M15.75 18H18a2.25 2.25 0 0 0 2.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 0 0-1.123-.08M15.75 18.75v-1.875a3.375 3.375 0 0 0-3.375-3.375h-1.5a1.125 1.125 0 0 1-1.125-1.125v-1.5A3.375 3.375 0 0 0 6.375 7.5H5.25m11.9-3.664A2.251 2.251 0 0 0 15 2.25h-1.5a2.251 2.251 0 0 0-2.15 1.586m5.8 0c.065.21.1.433.1.664v.75h-6V4.5c0-.231.035-.454.1-.664M6.75 7.5H4.875c-.621 0-1.125.504-1.125 1.125v12c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V16.5a9 9 0 0 0-9-9Z"></path>
            </svg>
            Copy Signature
          </button>
        ` : ''}
      `;
    }

    content += '</div>';
    return content;
  }

  if (encryptionInfoBtn) {
    encryptionInfoBtn.addEventListener('click', function(e) {
      e.preventDefault();
      if (window.MailCatcher) {
        const messageId = window.MailCatcher.selectedMessage();
        if (!messageId) return;

        // Destroy existing tooltip if any
        if (encryptionTooltip) {
          encryptionTooltip.destroy();
        }

        // Fetch message data
        fetch(new URL(`messages/${messageId}.json`, document.baseURI).toString())
          .then(response => response.json())
          .then(data => {
            const encryptionData = data.encryption_data || {};
            const content = generateEncryptionContent(encryptionData);

            // Create tooltip with content
            encryptionTooltip = tippy(encryptionInfoBtn, {
              content: content,
              allowHTML: true,
              theme: 'light',
              placement: 'bottom-start',
              interactive: true,
              duration: [200, 150],
              arrow: true,
              trigger: 'manual',
              maxWidth: 400,
              onClickOutside: (instance) => {
                instance.hide();
              },
            });

            // Show tooltip
            encryptionTooltip.show();

            // Setup copy button handlers
            const copyButtons = document.querySelectorAll('.encryption-copy-button');
            copyButtons.forEach(btn => {
              btn.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();

                const value = this.getAttribute('data-value');
                const copyType = this.getAttribute('data-copy-type');

                // Copy to clipboard
                navigator.clipboard.writeText(value).then(() => {
                  // Show success state
                  const originalHTML = this.innerHTML;
                  const originalClass = this.className;

                  this.classList.add('copied');
                  this.innerHTML = `
                    <svg fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M11.35 3.836c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 0 0 .75-.75 2.25 2.25 0 0 0-.1-.664m-5.8 0A2.251 2.251 0 0 1 13.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m8.9-4.414c.376.023.75.05 1.124.08 1.131.094 1.976 1.057 1.976 2.192V16.5A2.25 2.25 0 0 1 18 18.75h-2.25m-7.5-10.5H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V18.75m-7.5-10.5h6.375c.621 0 1.125.504 1.125 1.125v9.375m-8.25-3 1.5 1.5 3-3.75"></path>
                    </svg>
                    Copied!
                  `;

                  // Reset after 3 seconds
                  setTimeout(() => {
                    this.className = originalClass;
                    this.innerHTML = originalHTML;
                  }, 3000);
                }).catch(err => {
                  console.error('Failed to copy to clipboard:', err);
                });
              });
            });
          })
          .catch(error => {
            console.error('Error fetching encryption data:', error);
            const errorContent = `
              <div class="encryption-tooltip-content">
                <p class="encryption-no-data">Error loading encryption data.</p>
              </div>
            `;

            encryptionTooltip = tippy(encryptionInfoBtn, {
              content: errorContent,
              allowHTML: true,
              theme: 'light',
              placement: 'bottom-start',
              interactive: true,
              duration: [200, 150],
              arrow: true,
              trigger: 'manual',
              onClickOutside: (instance) => {
                instance.hide();
              },
            });

            encryptionTooltip.show();
          });
      }
    });

    // Close tooltip when clicking elsewhere
    document.addEventListener('click', function(e) {
      // Check if this click is on the button
      if (encryptionInfoBtn && encryptionInfoBtn.contains(e.target)) return;

      // Check if this click is on a tippy-box
      if (e.target.closest('.tippy-box')) return;

      // Click is outside everything, hide tooltip
      if (encryptionTooltip) {
        encryptionTooltip.hide();
      }
    });
  }
};
