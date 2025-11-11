# WinDAS Report Template

This directory contains the built HTML report template used by WinDAS to generate interactive diagnostic reports.

## 📄 Template File

**File:** `report-template.html`
- **Size:** ~599 KB (613,376 bytes)
- **Lines:** 13,440
- **Format:** Single standalone HTML file
- **Dependencies:** None (fully self-contained)

## 🎯 Purpose

The report template is a self-contained HTML file that:
1. **Receives data** from WinDAS collectors via placeholder injection
2. **Renders interactive dashboard** with tabbed navigation
3. **Displays diagnostic data** in organized, readable format
4. **Provides analysis tools** (search, sorting, filtering)
5. **Generates ticket notes** for support documentation

## 🏗️ Template Structure

### Single-File Architecture

The template is a **monolithic HTML file** containing:
- **HTML Structure** - Document layout and content containers
- **Embedded CSS** - Complete styling (13KB of CSS)
- **Embedded JavaScript** - Full functionality (1,100+ functions)
- **No External Dependencies** - Works offline, portable

### Key Components

#### 1. HTML Shell
- Semantic HTML5 structure
- WCAG AA compliant accessibility
- Tab-based navigation system
- Collapsible sections for data organization
- Responsive grid layouts

#### 2. CSS Styling (Embedded `<style>` block)
- **Dark theme** with high contrast (WCAG AA)
- **CSS Custom Properties** (variables) for theming
- **Responsive design** (desktop-optimized, mobile-aware)
- **Component styles** (cards, badges, tables, buttons)
- **Layout system** (grids, flexbox)
- **Animation effects** with reduced-motion support

**CSS Module Breakdown:**
- Variables: 20 lines (theme colors, RAG status colors)
- Base styles: 286 lines (resets, typography, body)
- Components: 212 lines (buttons, badges, cards, tables)
- Layout: 2,707 lines (grids, tabs, responsive rules)

#### 3. JavaScript Functionality (Embedded `<script>` block)
- **Core initialization** (40 lines)
- **Utility functions** (700 lines)
- **Tab loaders** (8,584 lines total)
  - OS Tab: 994 lines
  - Hardware Tab: 595 lines
  - Network Tab: 1,076 lines
  - Printers Tab: 20 lines (stub)
  - Software Tab: 324 lines
  - Drivers Tab: 1,923 lines
  - Browsers Tab: 522 lines
  - Events Tab: 2,390 lines

**Total JavaScript:** ~10,000 lines

## 🔄 How It Works

### Data Injection Process

**Step 1: WinDAS collects data**
```powershell
# Collectors run and return structured data
$osData = Get-OSData
$hardwareData = Get-HardwareData
# ... etc for all collectors
```

**Step 2: Data is serialized to JSON**
```powershell
$systemData = @{
    ComputerName = $env:COMPUTERNAME
    OS = $osData
    Hardware = $hardwareData
    Network = $networkData
    # ... all collector data
}
$jsonData = $systemData | ConvertTo-Json -Depth 10 -Compress
```

**Step 3: Template placeholders are replaced**
```powershell
$template = Get-Content "Templates\report-template.html" -Raw
$template = $template -replace '{{COMPUTER_NAME}}', $env:COMPUTERNAME
$template = $template -replace '{{SYSTEM_DATA}}', $jsonData
```

**Step 4: Final report is written**
```powershell
$reportPath = "Reports\WinDAS_Report_$computerName_$timestamp.html"
$template | Out-File $reportPath -Encoding UTF8
```

### Template Placeholders

The template contains **2 placeholders** that are replaced at runtime:

| Placeholder | Location | Replaced With | Purpose |
|-------------|----------|---------------|---------|
| `{{COMPUTER_NAME}}` | Line 6 (title tag) | Computer hostname | Browser title bar |
| `{{SYSTEM_DATA}}` | Line 3988 | JSON data object | JavaScript `systemData` variable |

**Example After Injection:**
```html
<title>WinDAS - PC-12345</title>
...
<script>
    window.systemData = {
        "ComputerName": "PC-12345",
        "OS": { ... },
        "Hardware": { ... }
    };
</script>
```

## 📊 Report Features

### Navigation System

#### Sticky Header
- Fixed position header with system name
- Always visible during scrolling
- Shows collection timestamp
- Quick reference to device identity

#### Tab Navigation
- **9 main tabs** with visual badges
- Badge counts show critical/warning issues
- Color-coded status indicators
- Keyboard navigation support
- Active tab highlighting
- Smooth transitions

**Available Tabs:**
1. **Dashboard** - System health overview
2. **Operating System** - OS info, updates, services, Defender
3. **Hardware** - CPU, RAM, storage, GPU, motherboard, battery
4. **Network** - Adapters, connectivity, configuration
5. **Printers** - Printer status, queues, spooler health
6. **Software** - Installed applications inventory
7. **Drivers** - Driver versions, problems, updates needed
8. **Browsers** - Browser versions, security settings, extensions
9. **Events** - Windows Event Log analysis, patterns
10. **Ticket Notes** - Pre-formatted support documentation

### Interactive Elements

#### Search Functionality
- Global search across all visible content
- Real-time filtering as you type
- Highlights matching text
- Clears on tab switch

#### Sortable Tables
- Click column headers to sort
- Ascending/descending toggle
- Visual sort indicators (▲ ▼)
- Maintains sort state per table
- Multi-column data support

#### Collapsible Sections
- Expand/collapse detailed information
- Keyboard accessible (Enter/Space)
- ARIA labels for screen readers
- Smooth animations (respects prefers-reduced-motion)
- Persistent state per section

#### Data Visualization

**Status Badges:**
- **Healthy** (Green): System operating normally
- **Warning** (Orange): Attention recommended
- **Critical** (Red): Immediate action required
- **Info** (Blue): Informational only
- **Unknown** (Gray): Status unavailable

**Metric Cards:**
- Large numeric displays
- Color-coded by status
- Contextual labels
- Sublabels for details

**Progress Indicators:**
- Visual bars for percentages
- Color changes at thresholds
- Numeric values displayed
- Space utilization metrics

**Charts & Graphs:**
- Memory usage visualization
- Disk space utilization
- CPU load indicators
- Network bandwidth displays

### Copy to Clipboard

**Ticket Notes Generation:**
- Click "Copy Ticket Notes" button
- Generates formatted text summary
- Includes critical issues
- System specifications
- Recommendations
- Copies to clipboard automatically
- Visual feedback (success/error)

**Ticket Notes Include:**
- Computer name & OS version
- Hardware summary (CPU, RAM, Storage)
- Critical issues by category
- Warning issues by category
- Network configuration
- Recent events
- Recommended actions

## 🎨 Theme & Styling

### Color Scheme (Dark Theme)

**Background Colors:**
- Primary: `#1a1a1a` (main background)
- Secondary: `#2d2d2d` (cards, header)
- Tertiary: `#3a3a3a` (metric cards, table headers)

**Text Colors:**
- Primary: `#e0e0e0` (main text)
- Secondary: `#b0b0b0` (labels)
- Muted: `#a8a8a8` (WCAG AA: 5.2:1 contrast)

**Accent Colors:**
- Accent: `#0071ce` (links, active states)
- Border: `#606060` (WCAG AA: 3.5:1 contrast)

**Status Colors (RAG):**
- Success: `#388E3C` (green)
- Warning: `#F57C00` (orange/amber)
- Danger: `#D32F2F` (red)
- Info: `#0071ce` (blue)

### Accessibility Features

**WCAG AA Compliance:**
- Contrast ratios meet 4.5:1 minimum
- Semantic HTML structure
- ARIA labels and roles
- Keyboard navigation support
- Focus indicators
- Screen reader friendly

**Reduced Motion Support:**
- Detects `prefers-reduced-motion` media query
- Disables animations for sensitive users
- Instant transitions when enabled
- Maintains functionality

**Responsive Design:**
- Desktop-optimized (1600px max-width)
- Mobile-aware grid layouts
- Touch-friendly button sizes (48px min)
- Flexible layouts adapt to screen size

## 🔧 Technical Details

### Browser Compatibility

**Supported Browsers:**
- Microsoft Edge (latest)
- Google Chrome (latest)
- Mozilla Firefox (latest)
- Safari (latest)
- Opera (latest)

**Minimum Requirements:**
- ES6 JavaScript support
- CSS Grid support
- CSS Custom Properties support
- Flexbox support
- LocalStorage (optional)

**Testing Performed On:**
- Windows 10/11 with Edge, Chrome, Firefox
- Offline mode (no internet required)
- High-DPI displays (scaling tested)

### Performance Characteristics

**Load Time:**
- Initial parse: <1 second
- Data injection: instant (no AJAX)
- Tab switching: <100ms
- Search: real-time (<50ms)

**Memory Usage:**
- Base HTML: ~600 KB
- Parsed DOM: ~2-5 MB
- JavaScript runtime: ~10-20 MB
- Total browser memory: ~50-100 MB

**Optimizations:**
- Single HTTP request (no dependencies)
- Embedded resources (no external loads)
- Efficient DOM manipulation
- Lazy rendering (tabs load on demand)
- Minimal reflows/repaints

### JavaScript Functions

**Core Functions:**
- `initializeReport()` - Entry point, sets up everything
- `switchTab(tabName)` - Tab navigation handler
- `loadTab(tabName)` - Lazy-loads tab content
- `updateTabProblems(healthData)` - Badge counts

**Tab Loader Functions:**
- `loadOperatingSystemTab()` - OS data rendering
- `loadHardwareTab()` - Hardware data rendering
- `loadNetworkTab()` - Network data rendering
- `loadPrintersTab()` - Printer data rendering
- `loadSoftwareTab()` - Software data rendering
- `loadDriversTab()` - Driver data rendering
- `loadBrowsersTab()` - Browser data rendering
- `loadEventsTab()` - Event log rendering
- `loadTicketNotesTab()` - Ticket notes generation

**Utility Functions:**
- `formatBytes(bytes)` - Human-readable sizes
- `formatDate(date)` - Consistent date formatting
- `getStatusClass(status)` - Status badge CSS classes
- `escapeHtml(str)` - XSS protection
- `sortTable(table, column, ascending)` - Table sorting
- `searchContent(query)` - Content filtering
- `toggleCollapsible(element)` - Section expand/collapse
- `copyToClipboard(text)` - Clipboard API wrapper

**Health Analysis:**
- `analyzeSystemHealth()` - Calculates overall health score
- `categorizeIssues()` - Groups problems by severity
- `generateRecommendations()` - Actionable remediation steps

## 🔨 Building the Template

### Source Files

The template is **built from modular source files** located in the `Source/` directory.

**DO NOT EDIT `report-template.html` DIRECTLY**

To make changes:

1. Edit source files in `Source/` directory
   - `Source/template-shell.html` (HTML structure)
   - `Source/styles/*.css` (CSS modules)
   - `Source/js/*.js` (JavaScript modules)

2. Run the build script:
   ```powershell
   cd Source
   .\Build-Template.ps1
   ```

3. The built template will be written to `Templates/report-template.html`

4. Test with WinDAS:
   ```powershell
   cd ..
   .\WinDAS.ps1
   ```

See `Source/README.md` for detailed build documentation.

### Build Process

**What Build-Template.ps1 Does:**

1. **Reads HTML shell** (`template-shell.html`)
2. **Concatenates CSS modules** in order:
   - 01-variables.css → CSS custom properties
   - 02-base.css → Base styles
   - 03-components.css → UI components
   - 04-layout.css → Grids & responsive
3. **Injects CSS** at `<!--CSS-->` placeholder
4. **Concatenates JS modules** in order:
   - utils.js → Helper functions
   - core.js → Initialization
   - tabs/*.js → All tab loaders
5. **Injects JavaScript** at `<!--JS_CORE-->` and `<!--JS_TABS-->` placeholders
6. **Writes output** to `Templates/report-template.html`
7. **Validates** placeholders removed, required functions exist

**Build Time:** ~2 seconds

**Output Validation:**
- Confirms all placeholders replaced
- Checks for required functions
- Verifies file size (~600 KB)
- Reports line count (~13,440 lines)

## 📦 Deployment

### Using the Template

**WinDAS.ps1 Usage:**
```powershell
# Load template
$template = Get-Content "Templates\report-template.html" -Raw

# Collect data from all collectors
$systemData = Collect-AllData

# Convert to JSON
$jsonData = $systemData | ConvertTo-Json -Depth 10 -Compress

# Replace placeholders
$report = $template -replace '{{COMPUTER_NAME}}', $env:COMPUTERNAME
$report = $report -replace '{{SYSTEM_DATA}}', $jsonData

# Write final report
$reportPath = "Reports\WinDAS_Report_$computerName_$timestamp.html"
$report | Out-File $reportPath -Encoding UTF8
```

### Report Distribution

**The generated report is:**
- ✅ **Portable** - Single HTML file
- ✅ **Standalone** - No external dependencies
- ✅ **Offline** - Works without internet
- ✅ **Shareable** - Email, USB, network share
- ✅ **Archive-friendly** - Self-contained documentation

**To Share a Report:**
1. Locate report in `Reports/` folder
2. Copy HTML file
3. Send via email, Teams, USB, etc.
4. Recipient opens in any web browser
5. All functionality works offline

## 🛠️ Customization

### Theme Customization

To customize colors, edit `Source/styles/01-variables.css`:

```css
:root {
    --bg-primary: #1a1a1a;      /* Main background */
    --bg-secondary: #2d2d2d;    /* Card backgrounds */
    --accent-color: #0071ce;    /* Blue */
    --success-color: #388E3C;   /* Green status */
    --warning-color: #F57C00;   /* Orange status */
    --danger-color: #D32F2F;    /* Red status */
}
```

Then rebuild with `Build-Template.ps1`.

### Adding New Tabs

To add a new tab:

1. **Create tab loader** in `Source/js/tabs/`:
   ```javascript
   // 09-newtab.js
   function loadNewTab() {
       const data = window.systemData.NewCategory;
       // Render logic here
   }
   ```

2. **Add HTML structure** in `Source/template-shell.html`:
   ```html
   <button class="tab-button" onclick="switchTab('newtab')">
       New Tab
   </button>
   <div id="newtab" class="tab-content">
       <!-- Tab content container -->
   </div>
   ```

3. **Update core.js** to register tab loader

4. **Rebuild** with `Build-Template.ps1`

5. **Update WinDAS.ps1** to collect new data category

### Modifying Existing Tabs

To modify a tab's rendering:

1. Edit corresponding file in `Source/js/tabs/`
2. Rebuild with `Build-Template.ps1`
3. Test with WinDAS.ps1

**Example - Modify Hardware Tab:**
```powershell
# Edit Source/js/tabs/02-hardware.js
notepad Source\js\tabs\02-hardware.js

# Rebuild
cd Source
.\Build-Template.ps1

# Test
cd ..
.\WinDAS.ps1
```

## 🐛 Troubleshooting

### Report Not Loading

**Symptoms:** Blank page or error message

**Solutions:**
1. Check browser console (F12) for JavaScript errors
2. Verify file size (~600 KB) - corrupted if much smaller
3. Open in different browser
4. Check file encoding (should be UTF-8)

### Missing Data in Report

**Symptoms:** Empty sections or "No data available"

**Causes:**
- Collector failed during data gathering
- JSON serialization error
- Template placeholder not replaced

**Solutions:**
1. Run WinDAS with `-Logs` parameter
2. Check `Logs/WinDAS_*.log` for errors
3. Verify `{{SYSTEM_DATA}}` placeholder was replaced
4. Check JSON is valid (not truncated)

### Tabs Not Switching

**Symptoms:** Clicking tabs does nothing

**Causes:**
- JavaScript error during initialization
- Tab loader function missing
- Duplicate IDs in HTML

**Solutions:**
1. Open browser console (F12)
2. Look for JavaScript errors
3. Verify `initializeReport()` called
4. Check tab button `onclick` handlers

### Styling Issues

**Symptoms:** Broken layout, wrong colors, missing styles

**Causes:**
- CSS not embedded properly
- Build script failed
- Browser caching old version

**Solutions:**
1. Hard refresh browser (Ctrl+F5)
2. Rebuild template with `Build-Template.ps1`
3. Check `<style>` block exists in HTML
4. Verify file size (~600 KB)

### Copy to Clipboard Not Working

**Symptoms:** Button click does nothing or shows error

**Causes:**
- Browser clipboard permissions
- HTTPS required (some browsers)
- JavaScript error in copy function

**Solutions:**
1. Grant clipboard permissions when prompted
2. Open file with `file://` protocol (some browsers restrict)
3. Use Ctrl+C after selecting text manually
4. Check browser console for errors

## 📈 Version History

### Version 2.1.0 (Chocolate Milk) - Current
- Modular source architecture
- Enhanced visual design with RAG colors
- Improved accessibility (WCAG AA)
- Ticket notes generation
- Health score dashboard
- Pattern analysis in event logs
- Browser security analysis
- Responsive grid layouts
- Sticky header navigation

### Version 1.x
- Monolithic HTML template
- Basic tab structure
- Dark theme
- Sortable tables
- Status badges

## 🔗 Related Documentation

- **Source Files**: See `Source/README.md` for modular build system
- **Collectors**: See `Collectors/README.md` for data collection details
- **Main Project**: See root `README.md` for WinDAS overview
- **Deployment**: See `Deploy-WinDAS.ps1` for remote execution

## 📝 Notes

**Important Points:**
- Template is **generated artifact** (built from `Source/`)
- Edit source files, not the template directly
- Always rebuild after changes
- Test changes with full WinDAS run
- Report files are **standalone** and portable

**Best Practices:**
- Keep template in version control
- Document custom modifications
- Test on multiple browsers
- Validate WCAG compliance after changes
- Maintain consistent coding style

## 💡 Tips

**For Developers:**
- Use browser DevTools to debug JavaScript
- Test with actual WinDAS data, not mock data
- Check console for errors during tab loading
- Use `console.log(window.systemData)` to inspect data
- Validate HTML/CSS with W3C validators

**For Users:**
- Reports work offline - save for later review
- Use search to quickly find specific information
- Sort tables to identify patterns
- Copy ticket notes for support tickets
- Share reports securely (may contain sensitive data)

---

**Template File:** `report-template.html`
**Size:** 599 KB
**Lines:** 13,440
**Last Built:** Auto-generated by Build-Template.ps1
**Maintainers:** WinDAS Development Team
