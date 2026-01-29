# MITRE ATT&CK - Moodle Integration for MISP

This integration provides two complementary approaches for linking MITRE ATT&CK techniques in MISP to training content in Moodle.

## Overview

Both approaches detect MITRE ATT&CK technique IDs (e.g., `T1234`, `T5678.001`) and generate links to Moodle's tag search page filtered by that technique ID. This allows security analysts to quickly access relevant training content while analyzing threat intelligence.

## Approach Comparison

| Feature | Option A: Client-Side Tooltip | Option B: Expansion Module |
|---------|------------------------------|----------------------------|
| **Location** | Browser (JavaScript) | Backend (Python) |
| **Activation** | Automatic on page load | Manual (right-click → Enrich) |
| **UI Integration** | Hover tooltip | Added to event attributes |
| **Performance** | Instant | Requires API call |
| **Data Persistence** | None (visual only) | Stored in MISP event |
| **Professional** | Good for quick reference | Better for formal analysis |
| **Use Case** | Quick lookups during analysis | Documenting training needs |

## Option A: Client-Side Tooltip (Automatic)

### What It Does
- Automatically scans all MISP pages for MITRE technique IDs
- Shows an interactive tooltip when hovering over any technique
- Provides a direct link to Moodle training content
- Works on tags, galaxy clusters, event attributes, etc.

### Implementation Files
- `custom-mitre-tooltip.js` - JavaScript tooltip logic
- `custom-mitre-tooltip.css` - Tooltip styling
- Injected into MISP via `Dockerfile.MispCustom`

### How to Use
1. Navigate to any MISP event or attribute containing MITRE techniques
2. Hover your mouse over any element containing a technique ID (e.g., `T1059.001`)
3. A tooltip appears showing the technique ID and "View in Moodle →" link
4. Click the link to open Moodle's tag search for that technique

### Configuration
The Moodle base URL is set to `http://localhost:8081` by default. To change it, add this to MISP's custom JS:

```javascript
window.MISP_MOODLE_URL = 'https://your-moodle-instance.com';
```

### Detected Elements
The tooltip automatically detects techniques in:
- Galaxy cluster tags (`.galaxy-cluster`, `.galaxyMatrix`)
- Regular event tags (`.tag`, `.eventTag`)
- Attribute tags (`.attributeTagContainer`)
- Galaxy matrix cells
- Any text containing technique patterns

## Option B: Expansion Module (Manual Enrichment)

### What It Does
- Analyzes attributes when you explicitly request enrichment
- Extracts MITRE techniques from attribute values, comments, and tags
- Creates new MISP link attributes for each detected technique:
  - **Competency page link**: Direct URL to Moodle competency detail page (via crucible block)
  - **Tag search link**: Direct URL to Moodle content tagged with the technique

### Implementation Files
- `/mnt/data/crucible/misp/misp-module-moodle/misp_module.py` - Enhanced expansion module

### How to Use
1. In MISP, navigate to an event with attributes
2. Right-click on a MITRE-related attribute (mitre-attack-pattern, galaxy-cluster, text, or comment)
3. Select "Enrich attribute" → "moodle"
4. The module will:
   - Scan the attribute value, comment, and attribute tags
   - **Also scan event-level tags** (including MITRE ATT&CK galaxy tags)
   - Extract all technique IDs (e.g., `T1566.002`)
   - Create new link attributes to Moodle
5. If no MITRE techniques are found, no enrichment is added

**Note:** The "moodle" enrichment option only appears on relevant attribute types, not on all attributes like IP addresses or domains.

**Important:** Even if the attribute's value doesn't contain technique IDs, the module will find techniques from the event's MITRE ATT&CK galaxy tags and create links for them.

### Example Workflow
**Scenario:** You have a MISP event about a phishing campaign with MITRE ATT&CK galaxy tags:
- Event tags: `misp-galaxy:mitre-attack-pattern="Phishing - T1566"`, `misp-galaxy:mitre-attack-pattern="User Execution - T1204"`
- Attribute: type=`text`, value=`Suspicious email from attacker@evil.com` (no T-codes in the value)

**Steps:**
1. Right-click on the text attribute
2. Select "Enrich attribute" → "moodle"
3. The module extracts T1566 and T1204 from the event's galaxy tags
4. Four new link attributes are created:
   - Moodle competency page for T1566
   - Moodle training content for T1566
   - Moodle competency page for T1204
   - Moodle training content for T1204

This allows you to quickly access training materials for any event tagged with MITRE techniques, regardless of whether the specific attribute mentions them.

### Supported Attribute Types
The enrichment action only appears on MITRE ATT&CK relevant attributes:
- `mitre-attack-pattern` - MITRE ATT&CK pattern attributes
- `galaxy-cluster` - Galaxy cluster attributes (includes MITRE)
- `text`, `comment` - Text fields that may contain technique IDs

This ensures the enrichment option only appears where it's relevant, reducing clutter in the MISP UI.

### Example Output
When enriching an attribute with value "Attack uses T1059.001 and T1566.002":

```json
{
  "results": [
    {
      "types": ["link"],
      "values": ["http://localhost:8081/blocks/crucible/competency.php?idnumber=T1059.001"],
      "comment": "Moodle competency page for MITRE ATT&CK T1059.001"
    },
    {
      "types": ["link"],
      "values": ["http://localhost:8081/tag/index.php?tag=T1059.001"],
      "comment": "Moodle training content tagged with MITRE ATT&CK T1059.001"
    },
    {
      "types": ["link"],
      "values": ["http://localhost:8081/blocks/crucible/competency.php?idnumber=T1566.002"],
      "comment": "Moodle competency page for MITRE ATT&CK T1566.002"
    },
    {
      "types": ["link"],
      "values": ["http://localhost:8081/tag/index.php?tag=T1566.002"],
      "comment": "Moodle training content tagged with MITRE ATT&CK T1566.002"
    }
  ]
}
```

**Result:** Each detected technique generates **2 link attributes** - one for the competency page and one for tagged content.

### Configuration in MISP

**Auto-Configuration (Default):**
The module is **automatically enabled** when MISP starts with the following default settings:
- `moodle_base_url`: `http://localhost:8081` (or value from `MOODLE_URL` environment variable)
- `include_competency_links`: `true`

**Customizing Moodle URL:**
To use a different Moodle instance URL, add it to your `.env/misp.env` file:
```bash
MOODLE_URL=https://moodle.staging.phl-imcite.net
```
This will be automatically configured when MISP starts.

**Manual Configuration (Optional):**
To customize settings:
1. Go to MISP → Administration → Server Settings & Maintenance → Plugin Settings
2. Find the "moodle" expansion module settings:

| Setting | Description | Default |
|---------|-------------|---------|
| `Plugin.Enrichment_moodle_enabled` | Enable/disable the module | `true` (auto-enabled) |
| `Plugin.Enrichment_moodle_moodle_base_url` | Base URL of your Moodle instance | `http://localhost:8081` |
| `Plugin.Enrichment_moodle_include_competency_links` | Include competency page links | `true` |

**Notes:**
- The module is auto-configured during MISP container startup (60 seconds after init)
- You can override these settings at any time through the MISP UI
- For `include_competency_links`: Set to `true`, `1`, or `yes` to include competency links; `false`, `0`, or `no` for only tag search links
- The configuration includes helpful descriptions visible in MISP's UI

### Testing the Module
Run the test script to verify functionality:

```bash
cd /mnt/data/crucible/misp/misp-module-moodle
python3 misp_module.py
```

This will run 6 test cases demonstrating:
1. Text attribute with no MITRE techniques (returns empty result)
2. MITRE technique detection with competency links enabled (2 links per technique)
3. MITRE technique detection from attribute tags (2 links per technique)
4. Multiple MITRE techniques in a single attribute (2 links × 3 techniques = 6 links)
5. MITRE technique detection with competency links disabled (1 link per technique)
6. **Event-level MITRE tags** - attribute value has no technique, but event has MITRE galaxy tags (2 links × 2 techniques = 4 links)

## Moodle Configuration

### Competency Framework Setup

The competency links require MITRE ATT&CK techniques to be configured as competencies in Moodle:

1. **Create/Import Competency Framework**:
   - Go to Site administration → Competencies → Competency frameworks
   - Create a framework named "MITRE ATT&CK"
   - For each technique, create a competency with:
     - **Name**: `T1234 - Technique Name`
     - **ID Number**: `T1234` (the technique code - this is critical!)
     - **Description**: Full technique description

2. **Link Competencies to Learning Content**:
   - In courses, link activities to their relevant competencies
   - This enables progress tracking and learning path visualization

3. **Crucible Block**:
   - The `moodle-block_crucible` plugin provides the `/blocks/crucible/competency.php` page
   - This page displays competency details when accessed via `?idnumber=T1234`

### Tag Configuration

For the tag search links to work, you also need to tag Moodle content with MITRE technique IDs.

#### Tagging Moodle Content
1. In Moodle, navigate to a course, activity, or resource
2. Click "Tags" in the settings
3. Add tags matching MITRE technique IDs: `T1059.001`, `T1566.002`, etc.
4. Save the content

#### Bulk Tagging
Use Moodle's bulk operations or the Tag Management page:
- Site administration → Appearance → Manage tags
- Add standard MITRE technique tags
- Apply to multiple courses/activities at once

## Technical Details

### Technique ID Detection
Both approaches use the same regex pattern:
```
\b(T\d{4}(?:\.\d{3})?)\b
```

This matches:
- Main techniques: `T1234`
- Sub-techniques: `T1234.567`
- Case-insensitive

### Moodle URL Formats

The module generates two types of links:

**Competency Page** (via crucible block):
```
http://localhost:8081/blocks/crucible/competency.php?idnumber=T1234
```
This links directly to the competency detail page for the MITRE technique. The competency framework uses:
- **Name**: `T1234 - Technique Name`
- **ID Number**: `T1234` (the technique code)
- **Description**: Full technique description

**Tag Index Page**:
```
http://localhost:8081/tag/index.php?tag=T1234
```
This shows all content (courses, activities, resources) tagged with that technique.

## Deployment

### Building the Updated Image
After making changes to the module or Dockerfile, rebuild the MISP containers:

```bash
# Navigate to project root
cd /workspaces/crucible-development

# Stop existing containers
docker stop misp misp-modules

# Remove old containers to force rebuild
docker rm misp misp-modules

# Start MISP using Aspire (will rebuild containers)
# Select "MISP" launch configuration in VS Code Run and Debug
```

The custom entrypoint script will automatically:
1. Enable the Moodle module 60 seconds after MISP initializes
2. Set the default Moodle URL to `http://localhost:8081`
3. Enable competency links by default

### Verifying Installation

**Option A (Tooltip):**
1. Open browser developer console (F12)
2. Navigate to any MISP page
3. Look for: `[MISP-Moodle] MITRE ATT&CK tooltip integration loaded`
4. Inspect elements with `data-mitre-tooltip-processed="true"` attribute

**Option B (Module):**
1. In MISP: Administration → Server Settings & Maintenance → Diagnostics
2. Click "Check MISP modules"
3. Verify "moodle" module is listed and enabled
4. Check Plugin Settings to confirm auto-configuration:
   - `Plugin.Enrichment_moodle_enabled` should be `true`
   - `Plugin.Enrichment_moodle_moodle_base_url` should be `http://localhost:8081`
   - `Plugin.Enrichment_moodle_include_competency_links` should be `true`
5. Test by enriching an attribute

**Note:** If the module isn't auto-enabled, wait a minute after MISP starts, or check container logs:
```bash
docker logs misp | grep "Moodle MISP module"
```

## Troubleshooting

### Tooltip Not Appearing (Option A)
- Check browser console for JavaScript errors
- Verify custom JS/CSS files exist in MISP container:
  ```bash
  docker exec -it misp ls -l /var/www/MISP/app/webroot/js/custom-mitre-tooltip.js
  docker exec -it misp ls -l /var/www/MISP/app/webroot/css/custom-mitre-tooltip.css
  ```
- Verify injection in base layout:
  ```bash
  docker exec -it misp grep -A 2 "Custom MITRE" /var/www/MISP/app/View/Layouts/default.ctp
  ```

### Module Not Working (Option B)
- Check MISP modules service is running:
  ```bash
  docker ps | grep misp-modules
  ```
- Check module is mounted correctly:
  ```bash
  docker exec -it misp-modules ls -l /usr/local/lib/python3.9/site-packages/misp_modules/modules/expansion/moodle.py
  ```
- Check MISP modules logs:
  ```bash
  docker logs misp-modules
  ```
- Restart MISP modules:
  ```bash
  docker restart misp-modules
  ```

### Moodle Links Return 404
- Verify Moodle is running: `http://localhost:8081`
- Check that content is actually tagged with technique IDs
- Try the Moodle tag search manually:
  `http://localhost:8081/tag/index.php?tag=T1059`

## Recommended Workflow

**For Quick Analysis:** Use Option A (Tooltip)
- Hover over techniques during initial triage
- Quick reference without modifying events
- Good for training yourself while analyzing

**For Documentation:** Use Option B (Expansion Module)
- Enrich important attributes for team visibility
- Creates persistent links in MISP events
- Better for formal reporting and handoffs

**Best Practice:** Use both!
- Tooltip for personal reference during analysis
- Expansion module to document training needs for team

## Future Enhancements

Potential improvements:
- [ ] Show technique name and description in tooltip (requires MITRE API call)
- [ ] Display Moodle course titles in tooltip preview
- [ ] Support custom Moodle URL patterns (e.g., direct course links)
- [ ] Add configuration UI in MISP for Moodle integration
- [ ] Cache Moodle content to show available/unavailable courses
- [x] Integrate with Moodle competency framework (completed - uses crucible block)
- [ ] Track which techniques have training content vs. gaps
- [ ] Show competency completion status for users in tooltip

## License

Copyright 2025 Carnegie Mellon University. All Rights Reserved.
Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
