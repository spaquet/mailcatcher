// ============================================
// MailCatcher NG - Footer Component
// ============================================

function injectFooter() {
    const footerHTML = `
        <!-- Footer -->
        <footer class="footer">
            <div class="container">
                <div class="footer-content">
                    <div class="footer-section">
                        <h4>MailCatcher NG</h4>
                        <p>Email testing made beautiful for developers.</p>
                    </div>
                    <div class="footer-section">
                        <h4>Quick Links</h4>
                        <ul>
                            <li><a href="index.html">Home</a></li>
                            <li><a href="install.html">Installation</a></li>
                            <li><a href="api.html">APIs</a></li>
                            <li><a href="claude.html">Claude Integration</a></li>
                        </ul>
                    </div>
                    <div class="footer-section">
                        <h4>Resources</h4>
                        <ul>
                            <li><a href="https://github.com/spaquet/mailcatcher">GitHub</a></li>
                            <li><a href="https://rubygems.org/gems/mailcatcher-ng">RubyGems</a></li>
                            <li><a href="https://hub.docker.com/r/stpaquet/alpinemailcatcher">Docker Hub</a></li>
                            <li><a href="https://github.com/sj26/mailcatcher">Original Project</a></li>
                        </ul>
                    </div>
                </div>
                <div class="footer-bottom">
                    <p>&copy; 2010-2026 Enhanced fork by Stéphane Paquet. MIT License.</p>
                </div>
            </div>
        </footer>
    `;

    // Find existing footer or create one
    let footer = document.querySelector('footer.footer');
    if (!footer) {
        // Insert footer before closing body tag
        document.body.insertAdjacentHTML('beforeend', footerHTML);
    }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectFooter);
} else {
    injectFooter();
}
