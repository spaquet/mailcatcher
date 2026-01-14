// ============================================
// MailCatcher Documentation Site - Script
// ============================================

// Mobile Menu Toggle
function setupMobileMenu() {
    const menuToggle = document.getElementById('menuToggle');
    const navMenu = document.getElementById('navMenu');

    if (menuToggle && navMenu) {
        menuToggle.addEventListener('click', () => {
            menuToggle.classList.toggle('active');
            navMenu.classList.toggle('active');
            menuToggle.setAttribute('aria-expanded', menuToggle.classList.contains('active'));
        });

        // Close menu when a link is clicked
        navMenu.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', () => {
                menuToggle.classList.remove('active');
                navMenu.classList.remove('active');
                menuToggle.setAttribute('aria-expanded', 'false');
            });
        });

        // Close menu when clicking outside
        document.addEventListener('click', (e) => {
            if (!e.target.closest('.navbar')) {
                menuToggle.classList.remove('active');
                navMenu.classList.remove('active');
                menuToggle.setAttribute('aria-expanded', 'false');
            }
        });
    }
}

// Smooth scrolling for anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        const href = this.getAttribute('href');
        if (href !== '#' && document.querySelector(href)) {
            e.preventDefault();
            const target = document.querySelector(href);
            const offsetTop = target.offsetTop - 80;
            window.scrollTo({
                top: offsetTop,
                behavior: 'smooth'
            });
        }
    });
});

// Navigation active state on scroll
const navLinks = document.querySelectorAll('.nav-link');
const sections = document.querySelectorAll('[id^="features"]');

window.addEventListener('scroll', () => {
    let current = '';
    sections.forEach(section => {
        const sectionTop = section.offsetTop;
        const sectionHeight = section.clientHeight;
        if (scrollY >= sectionTop - 200) {
            current = section.getAttribute('id');
        }
    });

    navLinks.forEach(link => {
        link.classList.remove('active');
        if (link.getAttribute('href').slice(1) === current) {
            link.classList.add('active');
        }
    });
});

// Copy to clipboard for code examples
function setupCodeCopy() {
    const codeExamples = document.querySelectorAll('.code-example pre');

    codeExamples.forEach(pre => {
        // Create copy button
        const button = document.createElement('button');
        button.textContent = 'Copy';
        button.className = 'copy-btn';
        button.style.cssText = `
            position: absolute;
            top: 3.5rem;
            right: 1rem;
            padding: 0.5rem 1rem;
            background: rgba(236, 72, 153, 0.2);
            border: 1px solid rgba(236, 72, 153, 0.4);
            color: #ec4899;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.85rem;
            font-weight: 600;
            transition: all 150ms cubic-bezier(0.4, 0, 0.2, 1);
        `;

        // Add hover effect
        button.addEventListener('mouseover', () => {
            button.style.background = 'rgba(236, 72, 153, 0.3)';
            button.style.borderColor = 'rgba(236, 72, 153, 0.6)';
        });

        button.addEventListener('mouseout', () => {
            button.style.background = 'rgba(236, 72, 153, 0.2)';
            button.style.borderColor = 'rgba(236, 72, 153, 0.4)';
        });

        // Copy functionality
        button.addEventListener('click', () => {
            const code = pre.textContent;
            navigator.clipboard.writeText(code).then(() => {
                const originalText = button.textContent;
                button.textContent = 'Copied!';
                button.style.background = 'rgba(6, 182, 212, 0.2)';
                button.style.borderColor = 'rgba(6, 182, 212, 0.4)';
                button.style.color = '#06b6d4';

                setTimeout(() => {
                    button.textContent = originalText;
                    button.style.background = 'rgba(236, 72, 153, 0.2)';
                    button.style.borderColor = 'rgba(236, 72, 153, 0.4)';
                    button.style.color = '#ec4899';
                }, 2000);
            });
        });

        // Wrap pre in relative container
        pre.parentElement.style.position = 'relative';
        pre.parentElement.insertBefore(button, pre);
    });
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    setupMobileMenu();
    setupCodeCopy();

    // Footer is injected via footer.js
});

// Add scroll animation for elements
function observeElements() {
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    });

    document.querySelectorAll('.feature-card, .code-example').forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(20px)';
        el.style.transition = 'opacity 0.6s ease-out, transform 0.6s ease-out';
        observer.observe(el);
    });
}

// Initialize observer when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', observeElements);
} else {
    observeElements();
}

// Keyboard navigation for sections
document.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        const links = Array.from(document.querySelectorAll('a[href^="#"], a[href="install.html"]'));
        const currentIndex = links.findIndex(link => link === document.activeElement);

        if (currentIndex > -1) {
            let nextIndex = currentIndex;
            if (e.key === 'ArrowDown') {
                nextIndex = Math.min(currentIndex + 1, links.length - 1);
            } else {
                nextIndex = Math.max(currentIndex - 1, 0);
            }

            if (nextIndex !== currentIndex) {
                e.preventDefault();
                links[nextIndex].focus();
            }
        }
    }
});

// Track page views (for potential analytics)
function trackPageView() {
    const page = window.location.pathname;
    console.log('Page view:', page);
    // Analytics tracking can be added here
}

trackPageView();
