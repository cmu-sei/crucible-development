/**
 * Crucible Training Resources Panel for MISP Event View
 *
 * Copyright 2026 Carnegie Mellon University. All Rights Reserved.
 * Released under a MIT (SEI)-style license.
 *
 * Injects a "Training Resources" section on MISP event pages that shows
 * clickable Moodle competency links for MITRE ATT&CK techniques found
 * in the event's galaxy tags. Dynamically checks Moodle to only show
 * techniques that have actual training content.
 */
(function () {
    'use strict';

    // Only run on event view pages.
    var body = document.body;
    if (!(body.dataset.controller === 'events' && body.dataset.action === 'view')) {
        return;
    }

    // Configuration — MOODLE_URL will be replaced at build time by customize_misp.sh.
    var MOODLE_URL = '%%MOODLE_URL%%';
    var COMPETENCY_FRAMEWORK = '%%COMPETENCY_FRAMEWORK%%';
    var TECHNIQUES_API = MOODLE_URL + '/blocks/crucible/api/techniques.php';

    /**
     * Extract technique IDs from all galaxy sections.
     * Galaxies load via AJAX, so we observe until they appear.
     *
     * ATT&CK techniques can appear under any galaxy type (Attack Pattern,
     * Threat Actor, Malware, Tool, etc.), so we scan all sections.
     * ID collisions with other frameworks (e.g., NICE T0080 vs ATT&CK)
     * are handled server-side by the competency framework filter on the
     * Moodle API.
     */
    function extractTechniques() {
        var techniques = {};
        var galaxyDiv = document.getElementById('galaxies_div');
        if (!galaxyDiv) return [];

        var allText = galaxyDiv.innerText || '';
        var matches = allText.match(/T\d{4}(?:\.\d{3})?/g);
        if (!matches) return [];

        matches.forEach(function (t) {
            techniques[t.toUpperCase()] = true;
        });
        return Object.keys(techniques).sort();
    }

    /**
     * Build and insert the training resources panel.
     */
    function renderPanel(techniques, moodleData) {
        var existing = document.getElementById('crucible_training_div');
        if (existing) existing.remove();

        var container = document.createElement('div');
        container.id = 'crucible_training_div';
        container.style.cssText = 'margin: 10px 0; padding: 0;';

        // Header matching MISP's section style.
        var header = document.createElement('span');
        header.className = 'title-section';
        header.innerHTML = '<i class="fa fa-graduation-cap"></i> Training Resources';
        container.appendChild(header);

        var content = document.createElement('div');
        content.style.cssText = 'padding: 10px; background: #f9f9f9; border: 1px solid #ddd; border-radius: 4px; margin-top: 5px;';

        if (techniques.length === 0) {
            content.innerHTML = '<em style="color:#555;">No MITRE ATT&CK techniques found in this event.</em>';
            container.appendChild(content);
            insertPanel(container);
            return;
        }

        // Separate into techniques with/without content.
        var withContent = [];
        var withoutContent = [];

        techniques.forEach(function (tid) {
            if (moodleData && moodleData[tid] === true) {
                withContent.push(tid);
            } else if (moodleData && moodleData[tid] === false) {
                withoutContent.push(tid);
            } else {
                // Moodle unreachable — show all as links.
                withContent.push(tid);
            }
        });

        if (withContent.length > 0) {
            var list = document.createElement('div');
            list.style.cssText = 'display:flex; flex-wrap:wrap; gap:6px; margin-bottom:8px;';
            withContent.forEach(function (tid) {
                var link = document.createElement('a');
                link.href = MOODLE_URL + '/blocks/crucible/competency.php?idnumber=' + tid +
                    (COMPETENCY_FRAMEWORK ? '&framework=' + encodeURIComponent(COMPETENCY_FRAMEWORK) : '');
                link.target = '_blank';
                link.rel = 'noopener';
                link.title = 'Moodle training for ' + tid;
                link.style.cssText = 'display:inline-block; padding:3px 8px; background:#ff8c00; color:#000; ' +
                    'border-radius:3px; text-decoration:none; font-size:12px; font-weight:bold;';
                link.textContent = tid;
                link.onmouseover = function() { this.style.background = '#e67e00'; };
                link.onmouseout = function() { this.style.background = '#ff8c00'; };
                list.appendChild(link);
            });
            content.appendChild(list);
        }

        if (withoutContent.length > 0) {
            var noContentDiv = document.createElement('div');
            noContentDiv.style.cssText = 'color:#555; font-size:11px; margin-top:4px;';
            noContentDiv.textContent = 'No training content yet: ' + withoutContent.join(', ');
            content.appendChild(noContentDiv);
        }

        var summary = document.createElement('div');
        summary.style.cssText = 'font-size:11px; color:#444; margin-top:6px; border-top:1px solid #ddd; padding-top:4px;';
        summary.textContent = techniques.length + ' technique' + (techniques.length > 1 ? 's' : '') +
            ' detected, ' + withContent.length + ' with training content';
        content.appendChild(summary);

        container.appendChild(content);
        insertPanel(container);
    }

    /**
     * Insert panel after the galaxies div.
     */
    function insertPanel(panel) {
        var galaxyDiv = document.getElementById('galaxies_div');
        if (galaxyDiv && galaxyDiv.parentNode) {
            galaxyDiv.parentNode.insertBefore(panel, galaxyDiv.nextSibling);
        }
    }

    /**
     * Check Moodle for which techniques have content, then render.
     */
    function checkMoodleAndRender(techniques) {
        if (techniques.length === 0) {
            renderPanel(techniques, null);
            return;
        }

        var url = TECHNIQUES_API + '?ids=' + techniques.join(',') +
            (COMPETENCY_FRAMEWORK ? '&framework=' + encodeURIComponent(COMPETENCY_FRAMEWORK) : '');
        var xhr = new XMLHttpRequest();
        xhr.open('GET', url, true);
        xhr.timeout = 5000;
        xhr.onload = function () {
            try {
                var data = JSON.parse(xhr.responseText);
                renderPanel(techniques, data.techniques || {});
            } catch (e) {
                // Moodle response unparseable — show all as links.
                renderPanel(techniques, null);
            }
        };
        xhr.onerror = function () {
            // Moodle unreachable — show all as links (graceful fallback).
            renderPanel(techniques, null);
        };
        xhr.ontimeout = xhr.onerror;
        xhr.send();
    }

    /**
     * Wait for galaxies to load (they're AJAX), then extract and render.
     */
    function init() {
        var galaxyDiv = document.getElementById('galaxies_div');
        if (!galaxyDiv) return;

        var attempts = 0;
        var maxAttempts = 30; // 15 seconds max wait.

        function tryExtract() {
            var techniques = extractTechniques();
            attempts++;

            if (techniques.length > 0 || attempts >= maxAttempts) {
                checkMoodleAndRender(techniques);
            } else {
                setTimeout(tryExtract, 500);
            }
        }

        // Also observe DOM changes in galaxies_div for dynamic loading.
        var observer = new MutationObserver(function () {
            var techniques = extractTechniques();
            if (techniques.length > 0) {
                observer.disconnect();
                checkMoodleAndRender(techniques);
            }
        });
        observer.observe(galaxyDiv, { childList: true, subtree: true });

        // Start polling as backup.
        tryExtract();
    }

    // Run when DOM is ready.
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
