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
- Creates new MISP attributes with:
  - `link` type: Direct URL to Moodle tag search
  - `text` type: Technique ID for documentation

### Implementation Files
- `/mnt/data/crucible/misp/misp-module-moodle/misp_module.py` - Enhanced expansion module

### How to Use
1. In MISP, navigate to an event with attributes
2. Right-click on an attribute containing MITRE technique references
3. Select "Enrich attribute" → "moodle"
4. The module will:
   - Scan the attribute value, comment, and tags
   - Extract all technique IDs (e.g., `T1566.002`)
   - Create new attributes with Moodle links

### Supported Attribute Types
- `ip-src`, `ip-dst` - IP addresses
- `domain`, `hostname` - Domain names
- `url` - URLs
- `text`, `comment` - Generic text fields
- `mitre-attack-pattern` - MITRE-specific types
- `galaxy-cluster` - Galaxy clusters

### Example Output
When enriching an attribute with value "Attack uses T1059.001 and T1566.002":

```json
{
  "results": [
    {
      "types": ["link"],
      "values": ["http://localhost:8081/tag/index.php?tag=T1059.001"],
      "comment": "Moodle training content for MITRE ATT&CK T1059.001"
    },
    {
      "types": ["text"],
      "values": ["MITRE ATT&CK Technique: T1059.001"],
      "comment": "Detected MITRE technique"
    },
    {
      "types": ["link"],
      "values": ["http://localhost:8081/tag/index.php?tag=T1566.002"],
      "comment": "Moodle training content for MITRE ATT&CK T1566.002"
    },
    {
      "types": ["text"],
      "values": ["MITRE ATT&CK Technique: T1566.002"],
      "comment": "Detected MITRE technique"
    }
  ]
}
```

### Configuration in MISP
1. Go to MISP → Administration → Server Settings & Maintenance → Plugin Settings
2. Find the "moodle" expansion module
3. Configure the `moodle_base_url` setting (default: `http://localhost:8081`)

### Testing the Module
Run the test script to verify functionality:

```bash
cd /mnt/data/crucible/misp/misp-module-moodle
python3 misp_module.py
```

This will run 4 test cases demonstrating technique detection.

## Moodle Tag Configuration

For both approaches to work effectively, you need to tag Moodle content with MITRE technique IDs.

### Tagging Moodle Content
1. In Moodle, navigate to a course, activity, or resource
2. Click "Tags" in the settings
3. Add tags matching MITRE technique IDs: `T1059.001`, `T1566.002`, etc.
4. Save the content

### Bulk Tagging
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

### Moodle URL Format
Links use Moodle's tag index page:
```
http://localhost:8081/tag/index.php?tag=T1234
```

This shows all content (courses, activities, resources) tagged with that technique.

## Deployment

### Building the Updated Image
After making changes, rebuild the MISP container:

```bash
# Navigate to project root
cd /workspaces/crucible-development

# Rebuild the MISP image (will use updated Dockerfile)
docker-compose build misp
# Or if using Aspire:
dotnet run --project Crucible.AppHost
```

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
4. Test by enriching an attribute

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
- [ ] Integrate with Moodle competency framework
- [ ] Track which techniques have training content vs. gaps

## License

Copyright 2025 Carnegie Mellon University. All Rights Reserved.
Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
