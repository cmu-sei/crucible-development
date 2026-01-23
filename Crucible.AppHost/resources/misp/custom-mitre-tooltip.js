// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

/**
 * MISP Custom Script - MITRE ATT&CK Tooltip with Moodle Links
 *
 * This script adds interactive tooltips to MITRE ATT&CK technique tags and galaxy clusters
 * in the MISP interface. When hovering over a technique (e.g., T1234), a tooltip appears
 * with a link to the corresponding Moodle content tagged with that technique ID.
 */

(function() {
    'use strict';

    // Configuration - Moodle base URL (can be overridden via window.MISP_MOODLE_URL)
    const MOODLE_BASE_URL = window.MISP_MOODLE_URL || 'http://localhost:8081';

    // Regex to extract MITRE ATT&CK technique IDs (T followed by 4 digits, optional .### for sub-techniques)
    const MITRE_TECHNIQUE_REGEX = /\b(T\d{4}(?:\.\d{3})?)\b/i;

    /**
     * Create tooltip element
     */
    function createTooltip() {
        const tooltip = document.createElement('div');
        tooltip.id = 'mitre-moodle-tooltip';
        tooltip.className = 'mitre-moodle-tooltip hidden';
        tooltip.innerHTML = `
            <div class="tooltip-content">
                <strong class="tooltip-title"></strong>
                <a href="#" class="tooltip-link" target="_blank">
                    View in Moodle →
                </a>
            </div>
        `;
        document.body.appendChild(tooltip);
        return tooltip;
    }

    /**
     * Extract MITRE technique ID from text content
     */
    function extractTechniqueId(text) {
        const match = text.match(MITRE_TECHNIQUE_REGEX);
        return match ? match[1].toUpperCase() : null;
    }

    /**
     * Build Moodle URL for a given technique tag
     * Uses Moodle's tag search functionality
     */
    function buildMoodleUrl(techniqueId) {
        // Link to Moodle's tag index page filtered by the technique tag
        return `${MOODLE_BASE_URL}/tag/index.php?tag=${encodeURIComponent(techniqueId)}`;
    }

    /**
     * Show tooltip near the target element
     */
    function showTooltip(tooltip, target, techniqueId) {
        const rect = target.getBoundingClientRect();
        const tooltipTitle = tooltip.querySelector('.tooltip-title');
        const tooltipLink = tooltip.querySelector('.tooltip-link');

        // Update tooltip content
        tooltipTitle.textContent = techniqueId;
        tooltipLink.href = buildMoodleUrl(techniqueId);

        // Position tooltip
        tooltip.style.display = 'block';
        const tooltipRect = tooltip.getBoundingClientRect();
        let top = rect.bottom + window.scrollY + 8;
        let left = rect.left + window.scrollX + (rect.width / 2) - (tooltipRect.width / 2);

        // Keep tooltip within viewport
        if (left < 10) left = 10;
        if (left + tooltipRect.width > window.innerWidth - 10) {
            left = window.innerWidth - tooltipRect.width - 10;
        }

        // If tooltip would go below viewport, show it above the element
        if (top + tooltipRect.height > window.innerHeight + window.scrollY) {
            top = rect.top + window.scrollY - tooltipRect.height - 8;
        }

        tooltip.style.top = `${top}px`;
        tooltip.style.left = `${left}px`;
        tooltip.classList.remove('hidden');
    }

    /**
     * Hide tooltip
     */
    function hideTooltip(tooltip) {
        tooltip.classList.add('hidden');
    }

    /**
     * Attach tooltip handlers to an element
     */
    function attachTooltipHandlers(element, tooltip, techniqueId) {
        let hideTimeout;

        element.addEventListener('mouseenter', function() {
            clearTimeout(hideTimeout);
            showTooltip(tooltip, element, techniqueId);
        });

        element.addEventListener('mouseleave', function() {
            hideTimeout = setTimeout(() => hideTooltip(tooltip), 200);
        });

        // Keep tooltip visible when hovering over it
        tooltip.addEventListener('mouseenter', function() {
            clearTimeout(hideTimeout);
        });

        tooltip.addEventListener('mouseleave', function() {
            hideTooltip(tooltip);
        });
    }

    /**
     * Initialize tooltips for MITRE ATT&CK elements
     */
    function initializeMitreTooltips() {
        const tooltip = createTooltip();

        // Target different MISP UI elements where MITRE techniques appear
        const selectors = [
            // Galaxy cluster tags
            '.galaxyMatrix',
            '.galaxy-cluster',
            '.galaxy_cluster',
            // Regular tags
            '.tag',
            '.tagContainer .label',
            // Event tags
            '.eventTag',
            // Attribute tags
            '.attributeTagContainer .tag',
            // Generic spans that might contain technique IDs
            'span[title*="mitre-attack"]',
            'span[class*="mitre"]',
            // Galaxy matrix cells
            '.galaxy-matrix-cell',
            // Any link or span with MITRE technique pattern
            'a[href*="mitre-attack"]',
        ];

        // Process all potential MITRE elements
        function processElements() {
            selectors.forEach(selector => {
                const elements = document.querySelectorAll(selector);
                elements.forEach(element => {
                    // Skip if already processed
                    if (element.dataset.mitreTooltipProcessed) return;

                    const text = element.textContent || element.getAttribute('title') || '';
                    const techniqueId = extractTechniqueId(text);

                    if (techniqueId) {
                        element.dataset.mitreTooltipProcessed = 'true';
                        element.style.cursor = 'help';
                        element.classList.add('mitre-technique-element');
                        attachTooltipHandlers(element, tooltip, techniqueId);
                    }
                });
            });
        }

        // Initial processing
        processElements();

        // Re-process on DOM changes (for dynamically loaded content)
        const observer = new MutationObserver(function(mutations) {
            processElements();
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });

        console.log('[MISP-Moodle] MITRE ATT&CK tooltip integration loaded');
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initializeMitreTooltips);
    } else {
        initializeMitreTooltips();
    }

})();
