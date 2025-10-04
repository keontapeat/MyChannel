// Accessibility Enhancement System for MyChannel
class AccessibilityManager {
    constructor() {
        this.keyboardNavigation = true;
        this.highContrastMode = false;
        this.largeTextMode = false;
        this.reducedMotion = false;
        this.screenReaderMode = false;
        this.captionsEnabled = false;
        this.currentFocus = null;
        this.focusableElements = [];
        this.shortcuts = new Map();
        this.announcements = [];
        
        // Load user preferences
        this.loadPreferences();
        this.detectSystemPreferences();
    }

    init() {
        this.setupKeyboardNavigation();
        this.setupKeyboardShortcuts();
        this.setupFocusManagement();
        this.setupScreenReader();
        this.setupAccessibilityMenu();
        this.setupCaptionsSystem();
        this.applyUserPreferences();
        
        console.log('♿ Accessibility features initialized');
    }

    // Keyboard Navigation System
    setupKeyboardNavigation() {
        // Tab navigation enhancement
        document.addEventListener('keydown', (e) => {
            this.handleGlobalKeydown(e);
        });

        // Focus visible indicator
        document.addEventListener('focusin', (e) => {
            this.handleFocusIn(e);
        });

        document.addEventListener('focusout', (e) => {
            this.handleFocusOut(e);
        });

        // Update focusable elements list
        this.updateFocusableElements();
        
        // Watch for DOM changes
        const observer = new MutationObserver(() => {
            this.updateFocusableElements();
        });
        
        observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['tabindex', 'disabled', 'hidden']
        });
    }

    // Comprehensive Keyboard Shortcuts
    setupKeyboardShortcuts() {
        // Navigation shortcuts
        this.addShortcut('h', 'Go to Home', () => this.navigateToTab('home'));
        this.addShortcut('s', 'Go to Search', () => this.navigateToTab('search'));
        this.addShortcut('p', 'Go to Profile', () => this.navigateToTab('profile'));
        this.addShortcut('u', 'Upload/Create', () => this.openUploadModal());
        
        // Video player shortcuts
        this.addShortcut('Space', 'Play/Pause', (e) => this.togglePlayPause(e));
        this.addShortcut('ArrowLeft', 'Seek backward 10s', (e) => this.seekVideo(e, -10));
        this.addShortcut('ArrowRight', 'Seek forward 10s', (e) => this.seekVideo(e, 10));
        this.addShortcut('ArrowUp', 'Volume up', (e) => this.adjustVolume(e, 0.1));
        this.addShortcut('ArrowDown', 'Volume down', (e) => this.adjustVolume(e, -0.1));
        this.addShortcut('f', 'Fullscreen', () => this.toggleFullscreen());
        this.addShortcut('m', 'Mute/Unmute', () => this.toggleMute());
        this.addShortcut('c', 'Toggle Captions', () => this.toggleCaptions());
        
        // Search shortcuts
        this.addShortcut('/', 'Focus Search', (e) => this.focusSearch(e));
        this.addShortcut('Escape', 'Clear/Exit', (e) => this.handleEscape(e));
        
        // Accessibility shortcuts
        this.addShortcut('Alt+a', 'Accessibility Menu', (e) => this.toggleAccessibilityMenu(e));
        this.addShortcut('Alt+c', 'High Contrast', (e) => this.toggleHighContrast(e));
        this.addShortcut('Alt+t', 'Large Text', (e) => this.toggleLargeText(e));
        this.addShortcut('Alt+r', 'Reduced Motion', (e) => this.toggleReducedMotion(e));
        
        // Help shortcut
        this.addShortcut('?', 'Show Keyboard Shortcuts', (e) => this.showShortcutsHelp(e));
    }

    addShortcut(key, description, handler) {
        this.shortcuts.set(key.toLowerCase(), { description, handler });
    }

    handleGlobalKeydown(e) {
        // Don't interfere with form inputs
        if (e.target.matches('input, textarea, select, [contenteditable]')) {
            // Only handle specific shortcuts in inputs
            if (e.key === 'Escape') {
                e.target.blur();
                this.announce('Input cleared');
            }
            return;
        }

        const key = this.getShortcutKey(e);
        const shortcut = this.shortcuts.get(key);
        
        if (shortcut) {
            e.preventDefault();
            shortcut.handler(e);
            this.announce(`${shortcut.description} activated`);
        }

        // Special navigation keys
        if (e.key === 'Tab') {
            this.handleTabNavigation(e);
        }
    }

    getShortcutKey(e) {
        let key = e.key.toLowerCase();
        if (e.altKey) key = 'alt+' + key;
        if (e.ctrlKey || e.metaKey) key = 'ctrl+' + key;
        if (e.shiftKey) key = 'shift+' + key;
        return key;
    }

    // Focus Management
    setupFocusManagement() {
        // Skip links for screen readers
        this.addSkipLinks();
        
        // Focus trap for modals
        this.setupFocusTraps();
        
        // Focus restoration
        this.setupFocusRestoration();
    }

    addSkipLinks() {
        const skipLinks = document.createElement('div');
        skipLinks.className = 'skip-links';
        skipLinks.innerHTML = `
            <a href="#main-content" class="skip-link">Skip to main content</a>
            <a href="#navigation" class="skip-link">Skip to navigation</a>
            <a href="#search" class="skip-link">Skip to search</a>
        `;
        document.body.insertBefore(skipLinks, document.body.firstChild);
    }

    updateFocusableElements() {
        this.focusableElements = Array.from(document.querySelectorAll(
            'a[href], button:not([disabled]), input:not([disabled]), textarea:not([disabled]), ' +
            'select:not([disabled]), details, summary, iframe, object, embed, ' +
            '[contenteditable], [tabindex]:not([tabindex="-1"])'
        )).filter(el => {
            return el.offsetParent !== null && !el.hidden;
        });
    }

    handleFocusIn(e) {
        this.currentFocus = e.target;
        
        // Announce focused element to screen readers
        if (this.screenReaderMode) {
            const announcement = this.getFocusAnnouncement(e.target);
            if (announcement) {
                this.announce(announcement);
            }
        }
        
        // Ensure focus is visible
        this.ensureFocusVisible(e.target);
    }

    handleFocusOut(e) {
        // Clean up focus indicators
        e.target.classList.remove('focus-visible');
    }

    ensureFocusVisible(element) {
        element.classList.add('focus-visible');
        
        // Scroll into view if needed
        if (element.scrollIntoViewIfNeeded) {
            element.scrollIntoViewIfNeeded();
        } else {
            element.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        }
    }

    getFocusAnnouncement(element) {
        const tag = element.tagName.toLowerCase();
        const role = element.getAttribute('role');
        const label = element.getAttribute('aria-label') || 
                     element.getAttribute('alt') || 
                     element.textContent?.trim();
        
        if (role) return `${role}: ${label}`;
        
        switch (tag) {
            case 'button': return `Button: ${label}`;
            case 'a': return `Link: ${label}`;
            case 'input': return `${element.type} input: ${label}`;
            case 'select': return `Dropdown: ${label}`;
            default: return label;
        }
    }

    // Screen Reader Support
    setupScreenReader() {
        // Detect screen reader
        this.detectScreenReader();
        
        // ARIA live regions
        this.createLiveRegions();
        
        // Enhanced ARIA labels
        this.enhanceAriaLabels();
    }

    detectScreenReader() {
        // Check for common screen reader indicators
        this.screenReaderMode = !!(
            navigator.userAgent.includes('NVDA') ||
            navigator.userAgent.includes('JAWS') ||
            navigator.userAgent.includes('VoiceOver') ||
            window.speechSynthesis ||
            document.querySelector('[aria-live]')
        );
    }

    createLiveRegions() {
        // Polite announcements
        const politeRegion = document.createElement('div');
        politeRegion.id = 'aria-live-polite';
        politeRegion.setAttribute('aria-live', 'polite');
        politeRegion.setAttribute('aria-atomic', 'true');
        politeRegion.className = 'sr-only';
        document.body.appendChild(politeRegion);
        
        // Assertive announcements
        const assertiveRegion = document.createElement('div');
        assertiveRegion.id = 'aria-live-assertive';
        assertiveRegion.setAttribute('aria-live', 'assertive');
        assertiveRegion.setAttribute('aria-atomic', 'true');
        assertiveRegion.className = 'sr-only';
        document.body.appendChild(assertiveRegion);
    }

    announce(message, priority = 'polite') {
        const region = document.getElementById(`aria-live-${priority}`);
        if (region) {
            region.textContent = message;
            
            // Clear after announcement
            setTimeout(() => {
                region.textContent = '';
            }, 1000);
        }
        
        // Also log for debugging
        console.log(`🔊 Announced (${priority}):`, message);
    }

    // Captions System
    setupCaptionsSystem() {
        this.captionsContainer = document.createElement('div');
        this.captionsContainer.className = 'video-captions';
        this.captionsContainer.id = 'videoCaptions';
        
        // Add captions toggle to video controls
        this.addCaptionsToggle();
    }

    addCaptionsToggle() {
        // This would integrate with the video player
        const captionsBtn = document.createElement('button');
        captionsBtn.className = 'captions-toggle-btn';
        captionsBtn.innerHTML = '📝 CC';
        captionsBtn.setAttribute('aria-label', 'Toggle captions');
        captionsBtn.onclick = () => this.toggleCaptions();
        
        // Add to video controls (when video player is active)
        document.addEventListener('video-player-ready', () => {
            const controls = document.querySelector('.video-controls');
            if (controls) {
                controls.appendChild(captionsBtn);
            }
        });
    }

    toggleCaptions() {
        this.captionsEnabled = !this.captionsEnabled;
        this.savePreference('captionsEnabled', this.captionsEnabled);
        
        const captionsContainer = document.getElementById('videoCaptions');
        if (captionsContainer) {
            captionsContainer.style.display = this.captionsEnabled ? 'block' : 'none';
        }
        
        this.announce(`Captions ${this.captionsEnabled ? 'enabled' : 'disabled'}`);
    }

    // Accessibility Menu
    setupAccessibilityMenu() {
        const menu = document.createElement('div');
        menu.className = 'accessibility-menu';
        menu.id = 'accessibilityMenu';
        menu.innerHTML = `
            <div class="accessibility-menu-content">
                <h3>Accessibility Options</h3>
                
                <div class="accessibility-option">
                    <label>
                        <input type="checkbox" id="highContrastToggle" ${this.highContrastMode ? 'checked' : ''}>
                        High Contrast Mode
                    </label>
                </div>
                
                <div class="accessibility-option">
                    <label>
                        <input type="checkbox" id="largeTextToggle" ${this.largeTextMode ? 'checked' : ''}>
                        Large Text
                    </label>
                </div>
                
                <div class="accessibility-option">
                    <label>
                        <input type="checkbox" id="reducedMotionToggle" ${this.reducedMotion ? 'checked' : ''}>
                        Reduce Motion
                    </label>
                </div>
                
                <div class="accessibility-option">
                    <label>
                        <input type="checkbox" id="captionsToggle" ${this.captionsEnabled ? 'checked' : ''}>
                        Enable Captions
                    </label>
                </div>
                
                <div class="accessibility-actions">
                    <button onclick="accessibilityManager.showShortcutsHelp()">Keyboard Shortcuts</button>
                    <button onclick="accessibilityManager.resetPreferences()">Reset All</button>
                </div>
                
                <button class="close-btn" onclick="accessibilityManager.closeAccessibilityMenu()">×</button>
            </div>
        `;
        
        document.body.appendChild(menu);
        
        // Setup event listeners
        this.setupAccessibilityMenuEvents();
    }

    setupAccessibilityMenuEvents() {
        document.getElementById('highContrastToggle')?.addEventListener('change', (e) => {
            this.toggleHighContrast(e);
        });
        
        document.getElementById('largeTextToggle')?.addEventListener('change', (e) => {
            this.toggleLargeText(e);
        });
        
        document.getElementById('reducedMotionToggle')?.addEventListener('change', (e) => {
            this.toggleReducedMotion(e);
        });
        
        document.getElementById('captionsToggle')?.addEventListener('change', (e) => {
            this.toggleCaptions();
        });
    }

    // Accessibility Features
    toggleHighContrast(e) {
        if (e) e.preventDefault();
        this.highContrastMode = !this.highContrastMode;
        document.body.classList.toggle('high-contrast', this.highContrastMode);
        this.savePreference('highContrastMode', this.highContrastMode);
        this.announce(`High contrast mode ${this.highContrastMode ? 'enabled' : 'disabled'}`);
    }

    toggleLargeText(e) {
        if (e) e.preventDefault();
        this.largeTextMode = !this.largeTextMode;
        document.body.classList.toggle('large-text', this.largeTextMode);
        this.savePreference('largeTextMode', this.largeTextMode);
        this.announce(`Large text mode ${this.largeTextMode ? 'enabled' : 'disabled'}`);
    }

    toggleReducedMotion(e) {
        if (e) e.preventDefault();
        this.reducedMotion = !this.reducedMotion;
        document.body.classList.toggle('reduced-motion', this.reducedMotion);
        this.savePreference('reducedMotion', this.reducedMotion);
        this.announce(`Reduced motion ${this.reducedMotion ? 'enabled' : 'disabled'}`);
    }

    // Navigation Helpers
    navigateToTab(tabName) {
        if (typeof showTab === 'function') {
            showTab(tabName);
            this.announce(`Navigated to ${tabName}`);
        }
    }

    focusSearch(e) {
        if (e) e.preventDefault();
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            searchInput.focus();
            this.announce('Search focused');
        }
    }

    openUploadModal() {
        if (typeof openUploadModal === 'function') {
            openUploadModal();
            this.announce('Upload modal opened');
        }
    }

    // Video Player Integration
    togglePlayPause(e) {
        if (e) e.preventDefault();
        // This would integrate with your video player
        console.log('Toggle play/pause');
        this.announce('Video play/pause toggled');
    }

    seekVideo(e, seconds) {
        if (e) e.preventDefault();
        console.log(`Seek ${seconds > 0 ? 'forward' : 'backward'} ${Math.abs(seconds)} seconds`);
        this.announce(`Seeked ${seconds > 0 ? 'forward' : 'backward'} ${Math.abs(seconds)} seconds`);
    }

    adjustVolume(e, delta) {
        if (e) e.preventDefault();
        console.log(`Adjust volume by ${delta}`);
        this.announce(`Volume ${delta > 0 ? 'increased' : 'decreased'}`);
    }

    toggleFullscreen() {
        console.log('Toggle fullscreen');
        this.announce('Fullscreen toggled');
    }

    toggleMute() {
        console.log('Toggle mute');
        this.announce('Mute toggled');
    }

    // Help and Information
    showShortcutsHelp(e) {
        if (e) e.preventDefault();
        
        const helpModal = document.createElement('div');
        helpModal.className = 'shortcuts-help-modal';
        helpModal.innerHTML = `
            <div class="shortcuts-help-content">
                <h2>Keyboard Shortcuts</h2>
                <div class="shortcuts-grid">
                    ${Array.from(this.shortcuts.entries()).map(([key, shortcut]) => `
                        <div class="shortcut-item">
                            <kbd>${key.replace(/\+/g, ' + ')}</kbd>
                            <span>${shortcut.description}</span>
                        </div>
                    `).join('')}
                </div>
                <button class="close-btn" onclick="this.parentElement.parentElement.remove()">Close</button>
            </div>
        `;
        
        document.body.appendChild(helpModal);
        helpModal.querySelector('.close-btn').focus();
    }

    toggleAccessibilityMenu(e) {
        if (e) e.preventDefault();
        const menu = document.getElementById('accessibilityMenu');
        if (menu) {
            menu.style.display = menu.style.display === 'block' ? 'none' : 'block';
            if (menu.style.display === 'block') {
                menu.querySelector('input').focus();
            }
        }
    }

    closeAccessibilityMenu() {
        const menu = document.getElementById('accessibilityMenu');
        if (menu) {
            menu.style.display = 'none';
        }
    }

    handleEscape(e) {
        // Close any open modals or menus
        const openModals = document.querySelectorAll('.modal-overlay, .accessibility-menu[style*="block"], .shortcuts-help-modal');
        if (openModals.length > 0) {
            openModals.forEach(modal => {
                modal.style.display = 'none';
                modal.remove?.();
            });
            this.announce('Modal closed');
        } else {
            // Clear search if in search input
            const activeElement = document.activeElement;
            if (activeElement && activeElement.id === 'searchInput') {
                activeElement.value = '';
                this.announce('Search cleared');
            }
        }
    }

    // Preferences Management
    loadPreferences() {
        const prefs = JSON.parse(localStorage.getItem('accessibilityPreferences') || '{}');
        this.highContrastMode = prefs.highContrastMode || false;
        this.largeTextMode = prefs.largeTextMode || false;
        this.reducedMotion = prefs.reducedMotion || false;
        this.captionsEnabled = prefs.captionsEnabled || false;
    }

    savePreference(key, value) {
        const prefs = JSON.parse(localStorage.getItem('accessibilityPreferences') || '{}');
        prefs[key] = value;
        localStorage.setItem('accessibilityPreferences', JSON.stringify(prefs));
    }

    detectSystemPreferences() {
        // Detect system preferences
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
            this.reducedMotion = true;
        }
        
        if (window.matchMedia('(prefers-contrast: high)').matches) {
            this.highContrastMode = true;
        }
    }

    applyUserPreferences() {
        if (this.highContrastMode) {
            document.body.classList.add('high-contrast');
        }
        
        if (this.largeTextMode) {
            document.body.classList.add('large-text');
        }
        
        if (this.reducedMotion) {
            document.body.classList.add('reduced-motion');
        }
    }

    resetPreferences() {
        this.highContrastMode = false;
        this.largeTextMode = false;
        this.reducedMotion = false;
        this.captionsEnabled = false;
        
        document.body.classList.remove('high-contrast', 'large-text', 'reduced-motion');
        localStorage.removeItem('accessibilityPreferences');
        
        // Update UI
        document.getElementById('highContrastToggle').checked = false;
        document.getElementById('largeTextToggle').checked = false;
        document.getElementById('reducedMotionToggle').checked = false;
        document.getElementById('captionsToggle').checked = false;
        
        this.announce('Accessibility preferences reset');
    }
}

// Initialize accessibility manager
const accessibilityManager = new AccessibilityManager();

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => accessibilityManager.init());
} else {
    accessibilityManager.init();
}



