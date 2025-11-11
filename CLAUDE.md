# CLAUDE.md

This file provides guidance to AI assistants when working with code in this repository.

## Project Overview

**WinDAS (Windows Diagnostic Assessment Suite)** is a comprehensive Windows system diagnostics tool that collects detailed information about a Windows computer and generates an interactive HTML report. It's designed for IT support, system audits, troubleshooting, and documentation.

**Version:** 2.1.0 (Chocolate Milk)
**Language:** PowerShell 5.1+
**Requirements:** Windows 7+ (Windows 10/11 recommended), Administrator privileges recommended

## Common Commands

### Running WinDAS

```powershell
# Standard run (generates report in Reports/)
.\WinDAS.ps1

# Skip disk speed test for faster execution (~30s vs ~60s)
.\WinDAS.ps1 -SkipDiskTest

# Enable detailed logging to Logs/ directory
.\WinDAS.ps1 -Logs
```

### Using the PowerShell Module

```powershell
# Import module
Import-Module .\WinDAS.psm1

# Run locally on current computer (saves report to current directory)
Invoke-WinDAS

# Run locally with faster execution
Invoke-WinDAS -SkipDiskTest

# Save report to specific location
cd C:\Tickets\INC0012345
Invoke-WinDAS

# Run on remote computer
Invoke-WinDAS -ComputerName PC-12345

# Run on multiple computers
Invoke-WinDAS -ComputerName PC-001, PC-002, PC-003

# Check for updates
Update-WinDAS
```

### Remote Deployment (Direct Script)

```powershell
# Deploy and run on remote computer
.\Deploy-WinDAS.ps1 -ComputerName PC-12345 -Execute

# Deploy, run, retrieve report, and cleanup
.\Deploy-WinDAS.ps1 -ComputerName PC-12345 -Execute -RetrieveReport -Cleanup

# Deploy to multiple computers
"PC-12345", "PC-67890", "LAPTOP-001" | .\Deploy-WinDAS.ps1 -Execute -RetrieveReport -Cleanup
```

### Building the Report Template

```powershell
# Rebuild HTML template from modular source files
cd Source
.\Build-Template.ps1
cd ..

# Then test with full run
.\WinDAS.ps1
```

### Testing

```powershell
# Run specific collector in isolation (requires loading dependencies)
. .\Collectors\Common-Functions.ps1
. .\Collectors\Initialize-DataCollection.ps1
. .\Collectors\Get-HardwareData.ps1
$hwData = Get-HardwareData
$hwData | ConvertTo-Json -Depth 5
```

## Architecture

### High-Level Structure

WinDAS follows a **modular data collection architecture** with three main components:

1. **Main Orchestrator** (`WinDAS.ps1`) - Coordinates collection, manages parallel execution, generates final report
2. **Data Collectors** (`Collectors/`) - Specialized PowerShell modules that gather system information
3. **Report Template** (`Templates/`) - Interactive HTML report built from modular source files (`Source/`)

### Data Flow

```
WinDAS.ps1 (Main Orchestrator)
    ↓
Initialize-DataCollection.ps1 (Setup CIM session, cache)
    ↓
Get-CommonData.ps1 (Pre-fetch shared WMI classes)
    ↓
Parallel Execution via Background Jobs:
    ├─ Get-OSData.ps1
    ├─ Get-HardwareData.ps1
    ├─ Get-NetworkData.ps1
    ├─ Get-SoftwareData.ps1
    ├─ Get-PrinterData.ps1
    ├─ Get-DriverData.ps1
    ├─ Get-BrowserData.ps1
    └─ Get-EventData.ps1
    ↓
Aggregate Results into $systemData hashtable
    ↓
ConvertTo-Json (depth 10, compressed)
    ↓
Load Templates/report-template.html
    ↓
Replace {{SYSTEM_DATA}} and {{COMPUTER_NAME}} placeholders
    ↓
Save to Reports/WinDAS_Report_<ComputerName>_<Timestamp>.html
```

### Key Architectural Patterns

#### 1. Parallel Collection with Caching
- **Common data cached first**: `Get-CommonData.ps1` pre-fetches WMI classes like Win32_ComputerSystem, Win32_OperatingSystem, Win32_Processor
- **8 collectors run in parallel**: Using PowerShell background jobs (`Start-Job`)
- **Cache serialization**: CIM objects converted to PSCustomObjects for job serialization
- **Per-collector timeouts**: OS=300s, others=120s to prevent hangs

#### 2. Standardized Collector Structure
All collectors in `Collectors/` follow this pattern:

```powershell
function Get-<Category>Data {
    param([hashtable]$DataCache = $Global:DataCache)

    $data = [PSCustomObject]@{
        CollectedAt = Get-Date
        Summary = $null
        <Category-specific properties>
        HealthStatus = "Unknown"  # "Healthy", "Warning", or "Critical"
    }

    # Collection logic using Get-CachedData for shared WMI queries
    # Analysis logic
    # Health status determination

    return $data
}
```

#### 3. Modular Template Build System
The HTML report template is **built from source modules**, not edited directly:

- **Source files**: `Source/template-shell.html`, `Source/styles/*.css`, `Source/js/*.js`
- **Build script**: `Source/Build-Template.ps1` concatenates modules
- **Output**: `Templates/report-template.html` (~600KB, 13,440 lines, standalone)
- **Runtime injection**: WinDAS.ps1 replaces `{{SYSTEM_DATA}}` with JSON payload

**Never edit `Templates/report-template.html` directly** - it's a generated artifact. Always edit source files and rebuild.

## Critical Implementation Details

### Working with Collectors

#### Adding a New Collector

1. Create `Collectors/Get-NewCategoryData.ps1` following standard structure
2. Use `Get-CachedData` for shared WMI classes to avoid redundant queries
3. Return PSCustomObject with CollectedAt, Summary, HealthStatus properties
4. Add to parallel execution block in `WinDAS.ps1` (lines 315-545)
5. Update `$script:systemData` hashtable initialization (line 183)

#### Collector Performance Optimizations

- **Use cached data**: `$cachedOS = Get-CachedData -ClassName "Win32_OperatingSystem"`
- **Batch WMI queries**: Query once for all devices instead of per-device loops
- **Strategic skips**: Avoid slow operations that don't provide user value (e.g., driver store inventory takes 23s but unused)
- **Conditional collection**: Check prerequisites before expensive operations (e.g., admin check before Security event log query)

### Modifying the Report Template

#### Template Development Workflow

```powershell
# 1. Edit source files (NOT the built template)
notepad Source\js\tabs\02-hardware.js

# 2. Rebuild template
cd Source
.\Build-Template.ps1
cd ..

# 3. Test with full WinDAS run
.\WinDAS.ps1

# 4. Open generated report in Reports/ folder
```

#### Template Source Structure

- **`Source/template-shell.html`**: HTML structure with placeholders (`<!--CSS-->`, `<!--JS_CORE-->`, `<!--JS_TABS-->`)
- **`Source/styles/`**: 4 CSS modules (variables, base, components, layout)
- **`Source/js/utils.js`**: Shared utility functions (date formatting, escapeHtml, sortTable, etc.)
- **`Source/js/core.js`**: Initialization logic
- **`Source/js/tabs/`**: 8 tab loader modules (01-os.js through 08-events.js)

#### Adding a New Tab

1. Create `Source/js/tabs/09-newtab.js` with `loadNewTab()` function
2. Add tab button and content panel in `Source/template-shell.html`
3. Update `switchTab()` in `utils.js` to call `loadNewTab()`
4. Rebuild: `Source\Build-Template.ps1`
5. Update WinDAS.ps1 to collect new data category

### Common Pitfalls

1. **Editing built template directly**: Always edit source files and rebuild
2. **Not using Get-CachedData**: Results in redundant slow WMI queries
3. **Forgetting to rebuild template**: Changes won't appear until `Build-Template.ps1` runs
4. **Breaking parallel execution**: Ensure job scriptblocks have all dependencies (functions, variables)
5. **Not handling missing data**: Always check if data exists before rendering: `if (!data) { return; }`

## Data Collection Notes

### WMI/CIM Classes

WinDAS uses CIM (not legacy WMI) for better performance:

- **Cached classes** (in Get-CommonData.ps1): Win32_ComputerSystem, Win32_OperatingSystem, Win32_Processor, Win32_PhysicalMemory, Win32_BIOS, Win32_BaseBoard, Win32_VideoController, Win32_DiskDrive, Win32_NetworkAdapter, Win32_Service, Win32_Product
- **Collector-specific queries**: Win32_LogicalDisk (OS), Win32_PnPEntity (Drivers), Win32_Battery (Hardware)

### PowerShell Cmdlets Used

- **Storage**: Get-PhysicalDisk, Get-StorageReliabilityCounter
- **Network**: Get-NetAdapter, Get-NetTCPConnection
- **Printer**: Get-Printer, Get-PrintJob, Get-PrinterDriver
- **Driver**: Get-PnpDevice, Get-PnpDeviceProperty
- **Event Logs**: Get-WinEvent with FilterHashtable
- **Security**: Get-MpComputerStatus (Windows Defender)

### Registry Locations

- **Software inventory**: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\WOW6432Node\...\Uninstall
- **Browser detection**: HKLM:\SOFTWARE\Clients\StartMenuInternet
- **Browser settings**: HKLM:\SOFTWARE\Policies\Google\Chrome, HKLM:\SOFTWARE\Policies\Microsoft\Edge

### Event Log Query Patterns

Always use time-based filtering and MaxEvents limits:

```powershell
$filter = @{
    LogName = 'System'
    Level = 1,2,3  # Critical, Error, Warning
    StartTime = (Get-Date).AddHours(-24)
}
Get-WinEvent -FilterHashtable $filter -MaxEvents 500 -ErrorAction SilentlyContinue
```

## Deployment Considerations

### Local Execution
- WinDAS runs entirely locally, no internet required
- Reports are standalone HTML files with embedded CSS/JS
- Can be run without admin but some data will be limited (event logs, services, etc.)

### Remote Deployment
- `Deploy-WinDAS.ps1` uses PowerShell remoting (WinRM must be enabled on target)
- Files copied to `C:\Temp\WinDAS` on remote computer
- Can execute, retrieve report, and cleanup automatically
- Supports pipeline input for batch deployments

### Report Distribution
- Generated reports are portable single-file HTML documents
- No external dependencies (all resources embedded)
- Can be emailed, shared via network, or opened from USB
- Opens in any modern browser without internet connection

## Testing and Debugging

### Enable Logging
```powershell
.\WinDAS.ps1 -Logs
# Log file created: Logs\WinDAS_<timestamp>.log
```

### Debugging Collectors
```powershell
# Run collector manually to test changes
$ErrorActionPreference = 'Continue'  # See errors
. .\Collectors\Common-Functions.ps1
. .\Collectors\Initialize-DataCollection.ps1
Initialize-DataCollection -ComputerName $env:COMPUTERNAME
. .\Collectors\Get-CommonData.ps1
Get-CommonData
. .\Collectors\Get-HardwareData.ps1
$hwData = Get-HardwareData -SkipDiskTest
$hwData | Format-List
```

### Browser Console Debugging
After generating a report:
1. Open in browser
2. Press F12 to open DevTools
3. Check Console tab for JavaScript errors
4. Use `console.log(window.systemData)` to inspect data structure

### Common Issues
- **Parallel execution not available**: Falls back to sequential collection (slower)
- **CIM session fails**: Collectors use direct CIM queries as fallback
- **Timeout errors**: Check per-collector timeout values in WinDAS.ps1 (lines 554-564)
- **Missing data in report**: Check collector logs for errors, verify admin privileges

## Performance Characteristics

### Typical Execution Times
- **With disk test**: 30-60 seconds total
  - Common data: 5-10s
  - Parallel collectors: 20-40s (longest: OS with update check)
  - Report generation: 1-2s
- **Without disk test** (`-SkipDiskTest`): 20-30 seconds

### Optimization Strategies Already Implemented
- Pre-caching shared WMI data (~40% time savings)
- Parallel execution (8 collectors run concurrently)
- Batch property queries for drivers (4N queries → 4 queries)
- Strategic skips (driver store inventory, excessive API calls)
- Per-collector timeouts to prevent hangs

## File Organization

```
WinDAS/
├── WinDAS.ps1                      # Main orchestrator
├── Deploy-WinDAS.ps1               # Remote deployment script
├── Collectors/                     # Data collection modules
│   ├── Common-Functions.ps1        # Shared helper functions
│   ├── Initialize-DataCollection.ps1
│   ├── Get-CommonData.ps1          # Pre-fetch shared WMI classes
│   ├── Get-OSData.ps1
│   ├── Get-HardwareData.ps1
│   ├── Get-NetworkData.ps1
│   ├── Get-SoftwareData.ps1
│   ├── Get-PrinterData.ps1
│   ├── Get-DriverData.ps1
│   ├── Get-BrowserData.ps1
│   └── Get-EventData.ps1
├── Source/                         # Template source files (edit these!)
│   ├── Build-Template.ps1          # Template build script
│   ├── template-shell.html         # HTML structure
│   ├── styles/                     # CSS modules
│   │   ├── 01-variables.css
│   │   ├── 02-base.css
│   │   ├── 03-components.css
│   │   └── 04-layout.css
│   └── js/                         # JavaScript modules
│       ├── utils.js                # Utility functions
│       ├── core.js                 # Initialization
│       └── tabs/                   # Tab loader modules
│           ├── 01-os.js
│           ├── 02-hardware.js
│           ├── 03-network.js
│           ├── 04-printers-stub.js
│           ├── 05-software.js
│           ├── 06-drivers.js
│           ├── 07-browsers.js
│           └── 08-events.js
├── Templates/                      # Built template (generated artifact)
│   └── report-template.html        # DO NOT EDIT DIRECTLY
├── Reports/                        # Generated reports (created at runtime)
└── Logs/                           # Debug logs (when -Logs parameter used)
```

## Health Status System

All collectors return standardized health status:

- **"Healthy"**: All checks passed, system operating normally
- **"Warning"**: Non-critical issues detected, attention recommended
- **"Critical"**: Serious issues requiring immediate action
- **"Unknown"**: Unable to determine health status

### Common Thresholds
- Disk space: <10% Critical, <20% Warning
- Memory usage: >90% Critical, >80% Warning
- Driver age (critical drivers): >2yr flagged
- Windows updates: >90 days Warning
- Services: Failed critical services = Critical

## Important Constants

### Collector Timeouts (seconds)
- OS: 300
- Hardware: 120
- Network: 120
- Software: 120
- Printer: 120
- Driver: 120
- Browser: 120
- Event: 120

### Report Template
- Size: ~600 KB
- Lines: ~13,440
- Placeholders: `{{COMPUTER_NAME}}`, `{{SYSTEM_DATA}}`

### Output Paths
- Reports: `Reports/WinDAS_Report_{ComputerName}_{Timestamp}.html`
- Logs: `Logs/WinDAS_{Timestamp}.log` (when -Logs enabled)
- Remote deployment: `C:\Temp\WinDAS` on target computer

## Browser Compatibility

Generated reports work in:
- Microsoft Edge (latest)
- Google Chrome (latest)
- Mozilla Firefox (latest)
- Safari (latest)
- Opera (latest)

Requires: ES6 JavaScript, CSS Grid, CSS Custom Properties, Flexbox

## Accessibility

Reports are WCAG AA compliant:
- Minimum 4.5:1 contrast ratios
- Semantic HTML with ARIA labels
- Keyboard navigation (Arrow keys, Tab, Enter, Space)
- Screen reader support
- Respects `prefers-reduced-motion`
- Focus indicators for all interactive elements

## Security Considerations

- All data collection is local (no telemetry, no external API calls)
- Browser version checks use vendor APIs (optional, 5s timeout)
- XSS protection: All user-generated content escaped via `escapeHtml()` in template
- No credentials stored or transmitted
- Reports may contain sensitive system information (handle appropriately)

## Version Information

**Current Version**: 2.1.0 (Chocolate Milk)
- Modular architecture with parallel collection
- Enhanced report template with interactive features
- PowerShell module for simplified deployment
- Alphabetically sorted navigation menu
- Expanded container width (90%) for better desktop utilization
- Comprehensive health scoring and analysis
- Browser security analysis
- Driver batch query optimization
- Event log pattern detection
- Auto-update checker with simple instructions
