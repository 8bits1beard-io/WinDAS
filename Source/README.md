# WinDAS Report Template - Modular Source Files

This directory contains the **modular source files** for the WinDAS HTML report template. The template has been refactored from a single 12,562-line monolithic HTML file into maintainable, organized modules for easier development and maintenance.

## 📁 Directory Structure

```
Source/
├── README.md                   # This file - Documentation
├── Build-Template.ps1          # Build script (concatenates modules into final template)
├── template-shell.html         # HTML skeleton with placeholders (849 lines)
│
├── styles/                     # CSS Modules (3,225 total lines)
│   ├── 01-variables.css        #   CSS custom properties & theme colors (20 lines)
│   ├── 02-base.css             #   Base styles, resets, typography (286 lines)
│   ├── 03-components.css       #   UI components (buttons, badges, cards) (212 lines)
│   └── 04-layout.css           #   Grids, responsive layouts, tabs (2,707 lines)
│
└── js/                         # JavaScript Modules (10,000+ total lines)
    ├── utils.js                #   Helper & utility functions (722 lines)
    ├── core.js                 #   Core initialization logic (40 lines)
    │
    └── tabs/                   # Tab Loader Modules
        ├── 01-os.js            #     Operating System tab (994 lines)
        ├── 02-hardware.js      #     Hardware tab (595 lines)
        ├── 03-network.js       #     Network tab (1,076 lines)
        ├── 04-printers-stub.js #     Printers tab (20 lines)
        ├── 05-software.js      #     Software tab (324 lines)
        ├── 06-drivers.js       #     Drivers tab (1,923 lines)
        ├── 07-browsers.js      #     Browsers tab (522 lines)
        └── 08-events.js        #     Events tab (2,390 lines)
```

---

## 🔨 Building the Template

### Quick Build

```powershell
cd Source
.\Build-Template.ps1
```

**Build Time:** ~2 seconds

**Output:** `Templates/report-template.html` (~599 KB, 13,440 lines)

### What the Build Script Does

The `Build-Template.ps1` script performs these steps:

1. **Reads HTML Shell**
   - Loads `template-shell.html` (HTML structure with placeholders)

2. **Concatenates CSS Modules** (in order)
   - `01-variables.css` → CSS custom properties
   - `02-base.css` → Base styles & resets
   - `03-components.css` → UI components
   - `04-layout.css` → Grids & responsive design
   - Wraps in `<style>` tags
   - Injects at `<!--CSS-->` placeholder

3. **Concatenates JavaScript Modules** (in order)
   - `utils.js` → Helper functions
   - `core.js` → Initialization code
   - All files from `tabs/*.js` → Tab loaders
   - Injects at `<!--JS_CORE-->` and `<!--JS_TABS-->` placeholders

4. **Writes Output**
   - Saves to `Templates/report-template.html`
   - UTF-8 encoding

5. **Validates Output**
   - Confirms all placeholders replaced
   - Checks for required functions
   - Verifies file size (~600 KB)
   - Reports line count (~13,440 lines)

### Build Output Statistics

```
Build Statistics:
  Lines: 13,440
  Size: 599 KB
```

### Build Validation

The script validates:
- ✅ All placeholders removed (`<!--CSS-->`, `<!--JS_CORE-->`, `<!--JS_TABS-->`)
- ✅ Required functions present:
  - `function loadOSTab`
  - `function loadHardwareTab`
  - `function formatNetDate`
  - `function escapeHtml`

---

## 📄 File Descriptions

### Build Script

#### `Build-Template.ps1`
**Lines:** 136
**Purpose:** Automated build system

**Functionality:**
- Reads template shell (HTML structure)
- Concatenates CSS files from `styles/` directory
- Concatenates JavaScript files from `js/` and `js/tabs/` directories
- Injects content at placeholder locations
- Validates output for completeness
- Reports build statistics

**Error Handling:**
- Checks if source files exist
- Validates placeholder injection
- Verifies required functions present
- Exit code 1 on validation failure

**Usage:**
```powershell
.\Build-Template.ps1
```

**Output:**
- `Templates/report-template.html` (overwrites if exists)
- Console output with build stats

---

### HTML Structure

#### `template-shell.html`
**Lines:** 849
**Purpose:** HTML skeleton and content structure

**Contains:**
- DOCTYPE and HTML5 metadata
- Accessibility features (skip links, ARIA labels)
- Keyboard help modal
- Sticky header and navigation structure
- Tab panel containers (empty, filled by JavaScript)
- Placeholder injection points:
  - `<!--CSS-->` - CSS injection point (line 7)
  - `<!--JS_CORE-->` - Core JavaScript (line 833)
  - `<!--JS_TABS-->` - Tab loaders (line 834)
  - `{{COMPUTER_NAME}}` - Runtime replacement (line 6)
  - `{{SYSTEM_DATA}}` - Runtime replacement (line 2 in script)

**Structure:**
1. **Head Section**
   - Meta tags, title, CSS placeholder
2. **Skip Links** (WCAG accessibility)
   - Skip to main content
   - Skip to navigation
3. **Keyboard Help Modal**
   - Shortcut reference
   - Accessibility instructions
4. **Sticky Header Wrapper**
   - Header with system name
   - Tab navigation bar (9 tabs)
5. **Main Container**
   - Tab content panels (10 tabs):
     - Operating System
     - Hardware
     - Network
     - Printers
     - Software
     - Drivers
     - Browsers
     - Events
     - Ticket Notes
6. **Script Section**
   - JavaScript placeholders
7. **Footer**
   - Version and author info

**Key Features:**
- Semantic HTML5 elements
- ARIA roles and labels
- Responsive meta viewport
- No inline styles or scripts (injected during build)

---

### CSS Modules

#### `01-variables.css`
**Lines:** 20
**Purpose:** CSS custom properties for theming

**Defines:**
- Color scheme (dark theme)
  - Background colors (primary, secondary, tertiary)
  - Text colors (primary, secondary, muted)
  - Border color
  - Accent color (Blue #0071ce)
- Status colors (RAG)
  - Success: #388E3C (green)
  - Warning: #F57C00 (orange)
  - Danger: #D32F2F (red)
  - Info: #0071ce (blue)
- Shadow definitions
  - Standard shadow
  - Card shadow

**WCAG Compliance:**
- Text-muted: 5.2:1 contrast ratio (WCAG AA)
- Border-color: 3.5:1 contrast ratio (WCAG AA)

**Usage:**
```css
background: var(--bg-primary);
color: var(--text-primary);
border: 1px solid var(--border-color);
```

---

#### `02-base.css`
**Lines:** 286
**Purpose:** Base styles, resets, and typography

**Includes:**
- **CSS Reset**
  - Box-sizing: border-box
  - Margin/padding reset
  - Remove default styles

- **Body Styles**
  - Font family (system font stack)
  - Background and text colors
  - Line height (1.6)
  - Smooth transitions

- **Container**
  - Max-width: 1600px (desktop-optimized)
  - Centered with auto margins
  - Padding: 20px
  - Top padding: 200px (for sticky header)

- **Typography**
  - Heading styles (h1-h6)
  - Paragraph spacing
  - Link styles
  - Code/pre formatting

- **Sticky Header Wrapper**
  - Fixed position (top: 0)
  - z-index: 1000
  - Box shadow
  - Background color

- **Header Styles**
  - Header content layout
  - Title styling
  - Timestamp formatting
  - Badge styles

- **Footer**
  - Footer layout
  - Content centering

**Features:**
- Smooth transitions (0.3s ease)
- Focus outlines for accessibility
- System font stack for performance

---

#### `03-components.css`
**Lines:** 212
**Purpose:** Reusable UI components

**Components:**

1. **Cards**
   - Card container
   - Card header
   - Card title
   - Card content
   - Dashboard card variant
   - Metric card variant

2. **Status Badges**
   - Base badge style
   - Status variants:
     - `.status-healthy` (green)
     - `.status-warning` (orange)
     - `.status-critical` (red)
     - `.status-info` (blue)
     - `.status-unknown` (gray)
   - Alias classes (status-ok, status-error)

3. **Metric Cards**
   - Grid layout
   - Value display (large numbers)
   - Label styling
   - Sublabel formatting
   - Color-coded by status

4. **Buttons**
   - Base button styles
   - Tab buttons
   - Active states
   - Hover effects
   - Badge indicators on buttons

5. **Collapsible Sections**
   - Header button
   - Icon rotation animation
   - Content container
   - Collapsed state
   - Smooth transitions

6. **Search**
   - Search container
   - Input styling
   - Focus states

**Features:**
- Consistent spacing
- Hover/focus states
- Transition animations
- Color-coded status indicators

---

#### `04-layout.css`
**Lines:** 2,707
**Purpose:** Grid layouts, responsive design, tab system

**Major Sections:**

1. **Tab Navigation** (Lines 1-273)
   - Tab button container
   - Tab button styles
   - Active tab styling
   - Hover effects
   - Badge positioning on tabs
   - Badge pulse animation
   - Keyboard focus indicators

2. **Tab Content** (Lines 274-321)
   - Tab panel display logic
   - Fade-in animation
   - Active state
   - Reduced motion support

3. **Tables** (Lines 488-583)
   - Responsive table wrapper
   - Table styling
   - Header styles (sticky)
   - Sort indicators
   - Zebra striping
   - Hover effects
   - Sortable headers

4. **Grid Layouts** (Lines 584-662)
   - Base grid system
   - Grid variants:
     - `.grid-2` (2 columns)
     - `.grid-3` (auto-fit, 280px min)
     - `.grid-4` (4 columns)
     - `.grid-5` (auto-fit, 200px min)
     - `.grid-6` (auto-fit, 180px min)
   - Three-column grid for OS tab
   - Metric grid

5. **Tier Separators** (Lines 663-694)
   - Visual section dividers
   - Tier 1: Critical Triage
   - Tier 2: Diagnostic Detail
   - Tier 3: Advanced Information

6. **Health Banners** (Lines 695-832)
   - Health status indicators
   - Color-coded backgrounds
   - Icon styling
   - Recommendations list

7. **Tab-Specific Layouts** (Lines 833-2707)
   - OS tab layout
   - Hardware tab layout
   - Network tab layout
   - Printers tab layout
   - Software tab layout
   - Drivers tab layout
   - Browsers tab layout
   - Events tab layout
   - Ticket notes layout

8. **Responsive Design** (Lines vary)
   - Mobile breakpoints
   - Tablet breakpoints
   - Desktop optimizations
   - Touch-friendly sizing (48px minimum)

**Features:**
- CSS Grid and Flexbox
- Responsive layouts
- Sticky headers
- Smooth animations
- Accessibility support
- Print styles (optimized for printing)

---

### JavaScript Modules

#### `utils.js`
**Lines:** 722
**Purpose:** Helper functions and utilities used across all tabs

**Function Categories:**

1. **Date Formatting** (Lines 4-69)
   - `parseNetDate(dateValue)` - Parse .NET JSON dates
   - `formatNetDate(dateValue, defaultText)` - Format .NET dates to ISO
   - `formatDateISO(date)` - Convert to ISO 8601 format
   - `formatTimeAgo(date)` - Relative time (e.g., "2 hours ago")

2. **Initialization** (Lines 72-86)
   - `DOMContentLoaded` event handler
   - Calls `loadSystemData()`
   - Initializes event listeners
   - Health dashboard initialization (commented out)

3. **Tab Management** (Lines 90-144)
   - `switchTab(tabName)` - Switch between tabs
   - Updates ARIA states
   - Manages tab panel visibility
   - Announces to screen readers
   - Loads tab-specific content

4. **Accessibility** (Lines 146-313)
   - `announceToScreenReader(message)` - Screen reader announcements
   - `handleTabKeyDown(e)` - Arrow key navigation
   - `showKeyboardHelp()` - Keyboard shortcuts modal
   - `closeKeyboardHelp()` - Close help modal
   - `trapFocusInModal(e)` - Focus trap for modal
   - `scrollToNextSection()` - J key navigation
   - `scrollToPreviousSection()` - K key navigation
   - Global keyboard shortcuts (?, Ctrl+/, Esc, J, K)

5. **UI Interactions** (Lines 444-520)
   - `toggleCollapsible(button)` - Expand/collapse sections
   - `toggleDriverCategory(categoryId)` - Show/hide driver categories
   - `sortTable(tableId, columnIndex)` - Generic table sorting
   - `sortApplicationsTable(columnIndex)` - Application-specific sorting

6. **Reliability Analysis** (Lines 522-666)
   - `getReliabilityColor(index)` - Color for reliability score
   - `getReliabilityDescription(index)` - Score description
   - `getDetailedReliabilityAnalysis()` - In-depth analysis with:
     - Issue detection (BSOD, crashes, shutdowns)
     - Root cause analysis
     - DCOM error pattern recognition
     - Service failure tracking
     - Contextual recommendations
     - Configuration Manager error analysis

7. **Security** (Lines 712-721)
   - `escapeHtml(unsafe)` - XSS protection
   - Sanitizes user-generated content
   - Prevents script injection

**Key Features:**
- Comprehensive error handling
- WCAG AAA accessibility support
- Keyboard navigation
- Focus management
- Screen reader support
- Smooth animations with `prefers-reduced-motion` respect

---

#### `core.js`
**Lines:** 40
**Purpose:** Core initialization and system data loading

**Functions:**

1. **System Data Initialization**
   - Waits for DOM ready
   - Loads system data from `window.systemData`
   - Initializes first tab (Operating System)

2. **Main Entry Point**
   - Calls tab loaders
   - Sets up event listeners
   - Initializes health dashboard

**Data Flow:**
```javascript
window.systemData = {{SYSTEM_DATA}};  // Injected by WinDAS.ps1
↓
DOMContentLoaded fires
↓
loadSystemData() called
↓
Populate header (computer name, timestamp)
↓
Load active tab content
```

---

### Tab Loader Modules

Each tab loader is responsible for rendering data for its specific section. All loaders follow a similar pattern:

#### Pattern Structure
```javascript
function load[TabName]Tab() {
    const data = window.systemData.[Category];

    // Validate data exists
    if (!data) {
        // Show "No data available" message
        return;
    }

    // Build HTML content
    let html = '';

    // Render sections:
    // 1. Health banner
    // 2. Summary dashboard
    // 3. Detailed information

    // Inject into DOM
    document.getElementById('[container]').innerHTML = html;

    // Post-processing (attach event listeners, etc.)
}
```

---

#### `01-os.js`
**Lines:** 994
**Purpose:** Operating System tab rendering

**Sections Rendered:**
1. **Health Banner** - Overall OS status
2. **Windows Version & Uptime** - OS info, boot time
3. **Windows Update** - Update status, pending updates
4. **Disk Space** - All drives with usage bars
5. **Critical Services** - Windows service status
6. **Boot Performance** - Fast startup, boot time
7. **System Integrity** - SFC status
8. **Resource Utilization** - CPU, memory, processes
9. **Stability Metrics** - Crashes, uptime, reliability score
10. **Security Status** - Windows Defender, firewall
11. **Windows Features** - Optional features status
12. **User Profile** - Current user info
13. **Activation** - Windows license status
14. **Locale & Regional Settings** - Time zone, formats
15. **Domain & Authentication** - Domain membership
16. **Reliability Monitor** - Detailed reliability analysis
17. **Virtual Memory** - Page file configuration
18. **Intune/MDM** - Mobile device management status
19. **Group Policy** - Applied policies

**Key Functions:**
- `loadOSTab()` - Main entry point
- `renderOSHealthBanner()` - Status banner
- `renderWindowsUpdateSection()` - Update status
- `renderDiskSpaceSection()` - Disk usage with bars
- `renderCriticalServicesSection()` - Service table
- `calculateReliabilityScore()` - Stability scoring

**Features:**
- Three-column responsive layout (Tier 1)
- Collapsible sections for details
- Color-coded status indicators
- Progress bars for disk usage
- Detailed reliability analysis with specific recommendations

---

#### `02-hardware.js`
**Lines:** 595
**Purpose:** Hardware tab rendering

**Sections Rendered:**
1. **Health Banner** - Overall hardware status
2. **Health Dashboard** - Summary metrics
3. **Active Performance** - Real-time resource usage
4. **Storage Health** - Disk status, SMART data, TRIM status
5. **Memory Configuration** - RAM modules, usage
6. **CPU Details** - Processor info, specs
7. **GPU Details** - Graphics cards, VRAM
8. **System Board** - Motherboard, BIOS, TPM
9. **Peripherals** - USB, audio devices
10. **Power** - Power plan, battery (if laptop)

**Key Functions:**
- `loadHardwareTab()` - Main entry point
- `renderHardwareHealthBanner()` - Status banner
- `renderStorageHealthSection()` - Storage with SMART
- `renderMemoryConfigSection()` - RAM details
- `renderCPUSection()` - Processor info
- `renderBatterySection()` - Battery health (laptops)

**Features:**
- SMART data interpretation
- Disk speed test results
- TRIM status for SSDs
- Battery health percentage
- TPM version detection
- GPU VRAM detection (handles >4GB correctly)

---

#### `03-network.js`
**Lines:** 1,076
**Purpose:** Network tab rendering

**Sections Rendered:**
1. **Health Banner** - Network status
2. **Status Dashboard** - Connectivity summary
3. **Connectivity Tests** - Internet, DNS, gateway
4. **Active Adapters** - Network interfaces with IP config
5. **Firewall & Security** - Windows Firewall status
6. **DNS Configuration** - DNS servers, suffixes
7. **Routing Table** - Network routes

**Key Functions:**
- `loadNetworkTab()` - Main entry point
- `renderNetworkHealthBanner()` - Status banner
- `renderConnectivityTests()` - Test results
- `renderActiveAdapters()` - Adapter table
- `renderFirewallSection()` - Firewall profiles
- `renderDNSConfig()` - DNS settings
- `renderRoutingTable()` - Route list

**Features:**
- Connectivity test results with latency
- IP configuration (IPv4/IPv6)
- DHCP status
- DNS server list
- Gateway information
- Firewall profile status (Domain, Private, Public)

---

#### `04-printers-stub.js`
**Lines:** 20
**Purpose:** Printers tab rendering (stub/placeholder)

**Note:** This is a minimal implementation. Full printer support may be added in future versions.

**Sections:**
1. **Health Banner** - Printer status
2. **Status Dashboard** - Printer count
3. **Critical Issues** - Spooler/queue problems
4. **Installed Printers** - Printer list
5. **Print Queue** - Active print jobs
6. **Drivers** - Printer drivers
7. **Spooler Config** - Spooler service

**Status:** Stub implementation (basic functionality)

---

#### `05-software.js`
**Lines:** 324
**Purpose:** Software tab rendering

**Sections Rendered:**
1. **Health Banner** - Software status
2. **Status Dashboard** - App count, categories
3. **Health Issues** - Outdated apps, duplicates
4. **Installed Applications** - Sortable table
5. **Startup Programs** - Auto-start apps
6. **Performance Metrics** - App performance data
7. **License Status** - License compliance

**Key Functions:**
- `loadSoftwareTab()` - Main entry point
- `renderSoftwareHealthBanner()` - Status banner
- `renderInstalledApplications()` - Application table
- `renderStartupPrograms()` - Startup list
- `sortApplicationsTable(columnIndex)` - Sort apps

**Features:**
- Sortable application table (name, publisher, version, date, size)
- Application categorization
- Install date tracking
- Size in MB/GB
- Architecture detection (32/64-bit)
- Duplicate detection

---

#### `06-drivers.js`
**Lines:** 1,923 (LARGEST MODULE)
**Purpose:** Drivers tab rendering

**Sections Rendered:**
1. **Health Banner** - Driver status
2. **Driver Status** - Critical issues, problem devices
3. **Driver Overview** - Statistics and categories
4. **Categories** - Drivers by type (Display, Network, Audio, Storage, System, Other)
5. **Recent Changes** - Driver installations/updates
6. **Performance Impact** - Driver-related errors

**Key Functions:**
- `loadDriversTab()` - Main entry point
- `renderDriverHealthBanner()` - Status banner
- `renderCriticalDriverIssues()` - Problem devices with codes
- `renderDriverOverview()` - Summary statistics
- `renderDriverCategories()` - Categorized driver lists
- `renderDriverDetails()` - Individual driver info
- `getDeviceProblemDescription()` - Error code explanations
- `getDriverAgeColor()` - Color-code by age

**Problem Code Handling:**
- All 48 Windows device problem codes
- Detailed descriptions
- Actionable remediation steps
- Examples:
  - Code 1: Not configured correctly
  - Code 10: Cannot start
  - Code 28: Drivers not installed
  - Code 43: Device has reported problems

**Features:**
- Comprehensive problem code documentation
- Driver age color-coding
- Category-based organization
- Batch query optimization
- Update status (Current/Aging/Old/Very Old)
- Priority levels (Critical/Important/Standard)
- Recent changes timeline
- Performance impact analysis

---

#### `07-browsers.js`
**Lines:** 522
**Purpose:** Browsers tab rendering

**Sections Rendered:**
1. **Health Banner** - Browser status
2. **Version Compliance** - Installed browsers with versions
3. **Auto-Update Status** - Update service status
4. **Installation Details** - Install paths, sizes, signatures
5. **Registry Configuration** - Browser registry settings
6. **Extensions** - Installed extensions/add-ons
7. **System-Wide Settings** - Default browser, policies
8. **Browser Comparison** - Feature matrix

**Key Functions:**
- `loadBrowsersTab()` - Main entry point
- `renderBrowserHealthBanner()` - Status banner
- `renderBrowserVersionCompliance()` - Version table
- `renderAutoUpdateStatus()` - Update services
- `renderExtensions()` - Extension lists
- `renderBrowserComparison()` - Comparison matrix

**Features:**
- Live version checking (compares installed vs. latest)
- Auto-update service detection
- Security settings analysis
- Extension permissions audit
- Digital signature verification
- Cache size reporting
- Default browser detection

---

#### `08-events.js`
**Lines:** 2,390 (SECOND LARGEST MODULE)
**Purpose:** Events tab rendering

**Sections Rendered:**
1. **Health Banner** - Event log status
2. **System Health** - Event count dashboard
3. **Critical Issues** - Urgent events requiring action
4. **Pattern Analysis** - Detected event patterns
5. **Event Overview** - Statistics by severity
6. **Timeline** - Recent critical events
7. **Detailed Logs** - Full event listings

**Key Functions:**
- `loadEventsTab()` - Main entry point
- `renderEventHealthBanner()` - Status banner
- `renderEventHealthDashboard()` - Metrics
- `renderCriticalIssues()` - Urgent events
- `renderPatternAnalysis()` - Pattern detection
- `renderEventTimeline()` - Timeline view
- `renderDetailedEvents()` - Event tables
- `categorizeEventSeverity()` - Event classification
- `detectEventPatterns()` - Pattern recognition

**Pattern Detection:**
- Recurring crashes (>3 in 48h)
- Authentication failures (>10)
- Service instability (>5 crashes)
- DCOM errors (>20)
- Time-based clustering
- After-hours activity detection

**Event Categories:**
- System Crashes (ID 41, 6008, 1001, 1074)
- Application Errors (ID 1000, 1002)
- Service Issues (ID 7034, 7035, 7036)
- Update Events (ID 19, 20, 43, 44)
- Security Events (ID 4625, 4740, 4776)
- Hardware Events (ID 10016, 10028, 10029)

**Features:**
- Event search functionality
- Timeline visualization
- Pattern recognition algorithms
- Severity classification (Critical/Error/Warning)
- Event ID friendly names
- Relative time display
- Root cause analysis
- Actionable recommendations
- BugCheck (BSOD) detection

---

## ✏️ Making Changes

### Workflow for Editing

**1. Edit Source Files**
```powershell
# Edit CSS
notepad Source\styles\02-base.css

# Edit JavaScript
notepad Source\js\utils.js

# Edit HTML structure
notepad Source\template-shell.html
```

**2. Rebuild Template**
```powershell
cd Source
.\Build-Template.ps1
```

**3. Test Changes**
```powershell
cd ..
.\WinDAS.ps1
```

**4. Open Generated Report**
- Check `Reports\` folder
- Open HTML file in browser
- Test all tabs
- Check browser console (F12) for errors

**5. Commit Changes**
```bash
git add Source/
git commit -m "Description of changes"
```

---

### Common Editing Scenarios

#### Changing Theme Colors

**File:** `Source/styles/01-variables.css`

```css
:root {
    --accent-color: #0071ce;  /* Change this */
    --success-color: #388E3C;  /* Or this */
}
```

Then rebuild: `.\Build-Template.ps1`

---

#### Adding a New Tab

**Step 1:** Create tab loader in `Source/js/tabs/`
```javascript
// 09-newtab.js
function loadNewTab() {
    const data = window.systemData.NewCategory;

    if (!data) {
        document.getElementById('newtab').innerHTML =
            '<div class="card"><p>No data available</p></div>';
        return;
    }

    // Render logic here
    let html = '<div class="card">';
    html += '<h2>New Tab Content</h2>';
    html += '</div>';

    document.getElementById('newtab').innerHTML = html;
}
```

**Step 2:** Add HTML container in `template-shell.html`
```html
<!-- Add button in tab nav -->
<button class="tab-button" onclick="switchTab('newtab')">
    New Tab
    <span class="tab-problem-count hidden" id="newtabBadge">0</span>
</button>

<!-- Add content panel -->
<div id="newtab" class="tab-content">
    <!-- Populated by JavaScript -->
</div>
```

**Step 3:** Update `core.js` to load tab

**Step 4:** Rebuild and test

---

#### Modifying Existing Tab

**Example:** Modify Hardware Tab

**File:** `Source/js/tabs/02-hardware.js`

1. Find function (e.g., `renderStorageHealthSection()`)
2. Edit HTML generation
3. Save file
4. Rebuild: `.\Build-Template.ps1`
5. Test: `.\WinDAS.ps1`

---

#### Adding New Utility Function

**File:** `Source/js/utils.js`

```javascript
// Add new function at end of file
function myNewHelperFunction(param) {
    // Implementation
    return result;
}
```

Then use in any tab loader:
```javascript
const result = myNewHelperFunction(data);
```

---

#### Fixing a Bug

**Example:** Fix sorting issue in Software tab

1. **Locate bug** in `Source/js/tabs/05-software.js`
2. **Fix code** in source file
3. **Rebuild:** `.\Build-Template.ps1`
4. **Test:** Generate report and verify fix
5. **Commit:** `git commit -m "Fix: Corrected sorting in software tab"`

---

## 📦 Deployment

### Built Template Usage

The built template (`Templates/report-template.html`) is used by `WinDAS.ps1`:

```powershell
# WinDAS.ps1 loads the template
$template = Get-Content "Templates\report-template.html" -Raw

# Replaces placeholders
$template = $template -replace '{{COMPUTER_NAME}}', $env:COMPUTERNAME
$template = $template -replace '{{SYSTEM_DATA}}', $jsonData

# Writes final report
$template | Out-File $reportPath -Encoding UTF8
```

### What Gets Deployed

**Source files:** Stay in repository (for development)
**Built template:** Gets deployed with WinDAS
**Generated reports:** Created at runtime with actual data

---

## 🎯 Benefits of Modular Structure

### Before (Monolithic)
- ❌ 12,562 lines in one file
- ❌ Hard to find specific code
- ❌ Risk of breaking unrelated tabs
- ❌ Difficult code reviews (massive diffs)
- ❌ No way to test individual functions
- ❌ Merge conflicts on every change
- ❌ Slow editor performance (large file)

### After (Modular)
- ✅ Largest file: 2,707 lines (layout.css)
- ✅ Each tab in its own file (200-2,400 lines)
- ✅ Changes isolated to specific modules
- ✅ Git diffs show only changed files
- ✅ Easier to unit test (future enhancement)
- ✅ Better organization and maintainability
- ✅ Multiple developers can work simultaneously
- ✅ Fast editor performance
- ✅ Clear separation of concerns

---

## 📊 Module Size Reference

| Module | Lines | Purpose |
|--------|-------|---------|
| **HTML** | | |
| template-shell.html | 849 | HTML structure |
| **CSS Total** | **3,225** | **All styling** |
| 01-variables.css | 20 | Theme colors, constants |
| 02-base.css | 286 | Resets, typography, basics |
| 03-components.css | 212 | Buttons, badges, cards, tables |
| 04-layout.css | 2,707 | Grids, responsive, tabs |
| **JavaScript Total** | **10,000+** | **All functionality** |
| utils.js | 722 | Helper functions |
| core.js | 40 | Initialization |
| **Tab Loaders** | | |
| 01-os.js | 994 | Operating system |
| 02-hardware.js | 595 | Hardware information |
| 03-network.js | 1,076 | Network configuration |
| 04-printers-stub.js | 20 | Printer status (stub) |
| 05-software.js | 324 | Software inventory |
| 06-drivers.js | 1,923 | Driver information |
| 07-browsers.js | 522 | Browser data |
| 08-events.js | 2,390 | Event log analysis |
| **Build Output** | **~13,440** | **Final template** |

---

## 🔄 Development Workflow

### Typical Development Cycle

```
1. Edit source file
   ↓
2. Run Build-Template.ps1
   ↓
3. Run WinDAS.ps1 (generates report)
   ↓
4. Open report in browser
   ↓
5. Test functionality
   ↓
6. Check browser console for errors
   ↓
7. If issues: Return to step 1
   ↓
8. If working: Commit changes
```

### Testing Checklist

After making changes:

- [ ] Build completes without errors
- [ ] All tabs load without JavaScript errors
- [ ] Check browser console (F12) for warnings
- [ ] Test tab switching
- [ ] Test sortable tables
- [ ] Test collapsible sections
- [ ] Test search functionality
- [ ] Test keyboard navigation
- [ ] Verify responsive design (resize window)
- [ ] Check print preview (Ctrl+P)
- [ ] Verify accessibility (screen reader test if possible)

---

## 🐛 Troubleshooting

### Build Failures

**Problem:** Build script fails with "Placeholder still exists"

**Solution:**
- Check that template-shell.html has placeholder comments exactly:
  - `<!--CSS-->`
  - `<!--JS_CORE-->`
  - `<!--JS_TABS-->`
- No extra spaces or characters

---

**Problem:** Missing functions error

**Solution:**
- Verify all source files exist in correct locations
- Check for typos in function names
- Ensure no syntax errors in source files

---

### Runtime Errors

**Problem:** JavaScript errors in browser console

**Solution:**
1. Open browser DevTools (F12)
2. Check Console tab for errors
3. Note file name and line number
4. Find corresponding source file
5. Fix error
6. Rebuild and test

---

**Problem:** Tab doesn't load or shows empty

**Solution:**
1. Check if tab loader function exists (e.g., `loadOSTab`)
2. Verify function is called in `switchTab()`
3. Check if `window.systemData` has expected data
4. Add `console.log` statements to debug
5. Rebuild after changes

---

**Problem:** Styling looks wrong

**Solution:**
1. Check if CSS was properly injected (view page source)
2. Look for `<style>` tag with CSS content
3. Verify CSS variables are defined
4. Check for CSS syntax errors
5. Clear browser cache (Ctrl+F5)

---

**Problem:** Changes not appearing

**Solution:**
- Ensure you ran `Build-Template.ps1` after editing
- Check you're opening the **new** report (check timestamp)
- Clear browser cache (Ctrl+Shift+Delete)
- Do hard refresh (Ctrl+F5)

---

## 🚀 Future Enhancements

With modular structure, we can now easily:

- ✅ **Add unit tests** for individual functions
- ✅ **Implement hot-reload** during development
- ✅ **Add CSS/JS minification** for production
- ✅ **Include source maps** for debugging
- ✅ **Automate builds** on commit (git hooks)
- ✅ **Split large tabs** into sub-modules (e.g., Events tab)
- ✅ **Create component library** for reusable elements
- ✅ **Add linting** (ESLint, Stylelint)
- ✅ **Performance profiling** per module
- ✅ **A/B testing** different layouts

---

## 📝 Best Practices

### Code Organization

1. **One responsibility per function**
   - Functions should do one thing well
   - Break large functions into smaller helpers

2. **Consistent naming**
   - Tab loaders: `load[TabName]Tab()`
   - Render functions: `render[Section]Section()`
   - Helper functions: descriptive names

3. **Comment complex logic**
   - Explain why, not what
   - Document non-obvious behavior
   - Add function documentation

4. **Error handling**
   - Check if data exists before using
   - Provide fallback values
   - Show user-friendly messages

5. **Accessibility**
   - Use semantic HTML
   - Add ARIA labels
   - Support keyboard navigation
   - Respect `prefers-reduced-motion`

### CSS Best Practices

1. **Use CSS variables** for colors and spacing
2. **Follow BEM naming** (Block__Element--Modifier)
3. **Mobile-first** responsive design
4. **Avoid !important** (except for utilities)
5. **Group related styles** together

### JavaScript Best Practices

1. **Avoid global variables** (except `window.systemData`)
2. **Use const/let** instead of var
3. **Escape user input** with `escapeHtml()`
4. **Check for null/undefined** before accessing properties
5. **Use arrow functions** for callbacks

---

## 📅 Version History

### Version 2.1.0 (Chocolate Milk) - Current
- **2024-10-07**: Initial modularization
  - Split 12,562-line monolithic file
  - Created build system (Build-Template.ps1)
  - Extracted 4 CSS modules, 10 JS modules
  - Validated identical output to original
  - Improved maintainability dramatically

### Version 1.x
- **2024-09**: Original monolithic template
  - Single 12,562-line HTML file
  - All CSS/JS embedded
  - Difficult to maintain

---

## 📚 Additional Documentation

- **Main Project**: See `/README.md` for WinDAS overview
- **Collectors**: See `/Collectors/README.md` for data collection
- **Templates**: See `/Templates/README.md` for final template usage
- **Deployment**: See `/Deploy-WinDAS.ps1` for remote execution

---

## 💡 Tips for Developers

### Quick Navigation

**Find a function:**
```powershell
# Search all JS files
Select-String -Path "Source\js\*.js" -Pattern "function myFunction"
```

**Find CSS class:**
```powershell
# Search all CSS files
Select-String -Path "Source\styles\*.css" -Pattern ".my-class"
```

### Debugging Tips

1. **Use console.log liberally during development**
   ```javascript
   console.log('Data:', data);
   console.log('Rendering section...');
   ```

2. **Check systemData structure**
   ```javascript
   console.log('Available data:', window.systemData);
   ```

3. **Validate HTML output**
   - Right-click → Inspect Element
   - Check if HTML was generated correctly

4. **Test in multiple browsers**
   - Edge, Chrome, Firefox
   - Check for browser-specific issues

### Performance Tips

1. **Minimize DOM manipulation**
   - Build HTML string, inject once
   - Avoid repeated `innerHTML` assignments

2. **Lazy load tabs**
   - Only render when user clicks tab
   - Don't render all tabs on page load

3. **Efficient selectors**
   - Use IDs when possible
   - Cache DOM queries
   - Avoid complex selectors

---

## 🆘 Getting Help

### Resources

1. **Check browser console** (F12) for errors
2. **Review build output** for validation warnings
3. **Test with sample data** to isolate issues
4. **Compare with working version** to find differences

### Reporting Issues

When reporting a bug:
1. Specify which source file has the issue
2. Include error messages from browser console
3. Describe steps to reproduce
4. Mention browser and version
5. Attach relevant code snippet

---

**Maintainers:** WinDAS Development Team
**Author:** Joshua Walderbach
**Last Updated:** 2025-10-21
**Version:** 2.1.0 (Chocolate Milk)

---

*This modular architecture makes WinDAS template development smooth and tasty, just like chocolate milk!* 🥛
