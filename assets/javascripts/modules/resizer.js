// Message list resizer functionality
window.MailCatcherUI = window.MailCatcherUI || {};

window.MailCatcherUI.initializeResizer = function() {
  const resizer = document.getElementById('resizer');
  const messagesSection = document.getElementById('messages');
  let isResizing = false;

  if (resizer && messagesSection) {
    resizer.addEventListener('mousedown', function(e) {
      e.preventDefault();
      isResizing = true;
      const startY = e.clientY;
      const startHeight = messagesSection.offsetHeight;

      const handleMouseMove = (e) => {
        if (!isResizing) return;
        const delta = e.clientY - startY;
        const newHeight = Math.max(150, startHeight + delta);
        messagesSection.style.flex = `0 0 ${newHeight}px`;
        localStorage.setItem('mailcatcherSeparatorHeight', newHeight);
      };

      const handleMouseUp = () => {
        isResizing = false;
        document.removeEventListener('mousemove', handleMouseMove);
        document.removeEventListener('mouseup', handleMouseUp);
      };

      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
    });
  }

  // Restore saved resizer position
  const savedHeight = localStorage.getItem('mailcatcherSeparatorHeight');
  if (savedHeight && messagesSection) {
    messagesSection.style.flex = `0 0 ${savedHeight}px`;
  }
};
