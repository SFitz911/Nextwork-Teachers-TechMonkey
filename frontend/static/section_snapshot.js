/**
 * Section Snapshot Extractor for 2-Teacher Live Classroom
 * 
 * This script extracts visible text, scroll position, and selected text
 * from the current webpage to send to the Coordinator API.
 * 
 * Usage:
 * 1. Include this script in your webpage
 * 2. Call window.extractSectionSnapshot() to get snapshot data
 * 3. Send to Coordinator API: POST /session/{id}/section
 */

(function() {
    'use strict';

    /**
     * Extract visible text from the page
     */
    function extractVisibleText() {
        const walker = document.createTreeWalker(
            document.body,
            NodeFilter.SHOW_TEXT,
            null,
            false
        );

        let visibleText = [];
        let node;

        while (node = walker.nextNode()) {
            const text = node.textContent.trim();
            if (text && isElementVisible(node.parentElement)) {
                visibleText.push(text);
            }
        }

        return visibleText.join('\n');
    }

    /**
     * Check if element is visible
     */
    function isElementVisible(element) {
        if (!element) return false;
        
        const style = window.getComputedStyle(element);
        if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
            return false;
        }

        const rect = element.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
    }

    /**
     * Get selected text
     */
    function getSelectedText() {
        const selection = window.getSelection();
        return selection.toString().trim();
    }

    /**
     * Get current scroll position
     */
    function getScrollPosition() {
        return {
            scrollY: window.scrollY || window.pageYOffset,
            scrollX: window.scrollX || window.pageXOffset
        };
    }

    /**
     * Get DOM digest (simple hash of visible content)
     */
    function getDOMDigest() {
        const visibleText = extractVisibleText();
        // Simple hash (in production, use crypto.subtle.digest)
        let hash = 0;
        for (let i = 0; i < visibleText.length; i++) {
            const char = visibleText.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash; // Convert to 32-bit integer
        }
        return `sha256:${Math.abs(hash).toString(16)}`;
    }

    /**
     * Extract full section snapshot
     */
    window.extractSectionSnapshot = function() {
        const scroll = getScrollPosition();
        const visibleText = extractVisibleText();
        const selectedText = getSelectedText();
        const domDigest = getDOMDigest();

        return {
            url: window.location.href,
            scrollY: scroll.scrollY,
            scrollX: scroll.scrollX,
            visibleText: visibleText,
            selectedText: selectedText,
            domDigest: domDigest,
            timestamp: new Date().toISOString()
        };
    };

    /**
     * Extract code blocks specifically (for technical content)
     */
    window.extractCodeBlocks = function() {
        const codeBlocks = Array.from(document.querySelectorAll('pre, code'));
        return codeBlocks
            .filter(block => isElementVisible(block))
            .map(block => ({
                text: block.textContent.trim(),
                language: block.className.match(/language-(\w+)/)?.[1] || 'unknown',
                selector: getSelector(block)
            }));
    };

    /**
     * Get CSS selector for element
     */
    function getSelector(element) {
        if (element.id) {
            return `#${element.id}`;
        }
        if (element.className) {
            const classes = element.className.split(' ').filter(c => c).join('.');
            if (classes) {
                return `${element.tagName.toLowerCase()}.${classes}`;
            }
        }
        return element.tagName.toLowerCase();
    }

    /**
     * Highlight element (for pointing at code)
     */
    window.highlightElement = function(selector) {
        const element = document.querySelector(selector);
        if (element) {
            element.style.outline = '3px solid #4CAF50';
            element.style.outlineOffset = '2px';
            setTimeout(() => {
                element.style.outline = '';
                element.style.outlineOffset = '';
            }, 3000);
        }
    };

    console.log('✅ Section Snapshot Extractor loaded');
    console.log('Usage: window.extractSectionSnapshot()');
})();
