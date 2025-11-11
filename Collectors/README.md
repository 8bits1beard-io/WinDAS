# WinDAS Data Collectors

This directory contains the modular data collection scripts for WinDAS. Each collector is responsible for gathering specific system information and follows a standardized structure.

## Table of Contents

- [Architecture](#architecture)
- [Common Functions](#common-functions)
- [Collector Details](#collector-details)
  - [Initialize-DataCollection](#initialize-datacollection)
  - [Get-CommonData](#get-commondata)
  - [Get-OSData](#get-osdata)
  - [Get-HardwareData](#get-hardwaredata)
  - [Get-NetworkData](#get-networkdata)
  - [Get-SoftwareData](#get-softwaredata)
  - [Get-DriverData](#get-driverdata)
  - [Get-BrowserData](#get-browserdata)
  - [Get-PrinterData](#get-printerdata)
  - [Get-EventData](#get-eventdata)
- [Data Collection Methods](#data-collection-methods)
- [Performance Optimization](#performance-optimization)

---

## Architecture

### Execution Flow

1. **Initialize-DataCollection.ps1** - Sets up CIM sessions and global cache
2. **Get-CommonData.ps1** - Pre-fetches commonly used WMI/CIM classes
3. **Parallel Execution** - 8 specialized collectors run concurrently
4. **Data Return** - Each collector returns structured PSCustomObject

### Standard Collector Structure

All collectors follow this pattern:

```powershell
function Get-<Category>Data {
    param([hashtable]$DataCache = $Global:DataCache)

    # Initialize data structure
    $data = [PSCustomObject]@{
        CollectedAt = Get-Date
        Summary = $null
        <Category-specific properties>
        HealthStatus = "Unknown"
    }

    # Collect data
    # Analyze data
    # Generate summary
    # Determine health status

    return $data
}
```

---

## Common Functions

**File:** `Common-Functions.ps1`

### Helper Functions

| Function | Purpose | Usage |
|----------|---------|-------|
| `Get-CachedData` | Retrieves pre-cached WMI/CIM data | Reduces redundant queries |
| `Get-StatusFromThreshold` | Converts numeric values to status | Standardizes health assessment |
| `Get-AgeInDays` | Calculates age from date | Used for drivers, updates, etc. |
| `ConvertTo-StandardStatus` | Normalizes status strings | Ensures consistent status values |
| `Write-ProgressStatus` | Updates progress display | User feedback during collection |
| `Write-CollectorLog` | Writes to collector log | Debugging and troubleshooting |
| `Test-Administrator` | Checks for admin privileges | Determines available data sources |

### Logging

- **Write-CollectorLog**: Writes timestamped entries to log file
  - Parameters: Message, Level (INFO/WARNING/ERROR), Component
  - Log location: `Logs/WinDAS_{Timestamp}.log`

---

## Collector Details

### Initialize-DataCollection

**Purpose:** Sets up the data collection environment

**Method:**
- Creates CIM session to local computer
- Initializes global data cache hashtable
- Establishes reusable connections for all collectors

**Data Structure:**
```powershell
$Global:DataCache = @{}
$Global:CimSession = New-CimSession
```

**Usage:** Called first by WinDAS.ps1 before any collector runs

---

### Get-CommonData

**Purpose:** Pre-fetches frequently accessed WMI/CIM classes

**Collection Method:**
- Single bulk query of common WMI classes
- Stores results in `$Global:DataCache`
- Reduces collection time by ~40%

**Cached Classes:**
| Class | Usage | Collectors Using |
|-------|-------|------------------|
| Win32_ComputerSystem | System info | OS, Hardware |
| Win32_OperatingSystem | OS details | OS, Hardware |
| Win32_Processor | CPU info | Hardware |
| Win32_PhysicalMemory | RAM modules | Hardware |
| Win32_BIOS | BIOS info | Hardware |
| Win32_BaseBoard | Motherboard | Hardware |
| Win32_VideoController | GPU info | Hardware |
| Win32_DiskDrive | Storage | Hardware |
| Win32_NetworkAdapter | Network | Network |
| Win32_Service | Services | OS, Printer |
| Win32_Product | Installed apps | Software |

**Performance:**
- Execution time: 5-10 seconds
- Cached data reused across all collectors
- Avoids 30+ redundant WMI queries

---

### Get-OSData

**Purpose:** Collects operating system health and configuration

**Data Collected:**

#### 1. System Information
- **Method:** WMI Win32_OperatingSystem, Win32_ComputerSystem
- **Metrics:**
  - OS Name, Version, Build Number
  - Architecture (32/64-bit)
  - Install Date & Age
  - System Manufacturer & Model
  - Computer Name & Domain
  - Last Boot Time & Uptime
  - Time Zone

#### 2. Windows Updates
- **Method:** Microsoft.Update.Session COM object
- **Metrics:**
  - Total installed updates
  - Recent updates (last 90 days)
  - Pending updates count
  - Failed update attempts
  - Last successful update date
  - Update source (WSUS/Windows Update)
  - Days since last update

#### 3. Disk Usage
- **Method:** WMI Win32_LogicalDisk
- **Metrics:**
  - Drive letter, label, filesystem
  - Total size, free space, used space
  - Percentage free
  - Status (Healthy/Warning/Critical based on free space)

#### 4. Windows Defender Status
- **Method:** Get-MpComputerStatus cmdlet
- **Metrics:**
  - Real-time protection status
  - Signature definitions (age, version)
  - Last scan time & type
  - Threat detection history
  - Quick/Full scan status

#### 5. System Performance
- **Method:** Performance counters
- **Metrics:**
  - Current CPU usage (%)
  - Available memory (GB)
  - Memory usage (%)
  - Disk queue length
  - Process count
  - Thread count

#### 6. Windows Services
- **Method:** WMI Win32_Service
- **Metrics:**
  - Critical services status (96 tracked)
  - Failed services
  - Stopped automatic services
  - Service startup type & state

#### 7. System Stability
- **Method:** Event logs (last 7 days)
- **Metrics:**
  - Unexpected shutdowns
  - Application crashes
  - System error count
  - Blue screen events (Event ID 41, 1001)
  - Stability score (0-100)

#### 8. Power Management
- **Method:** Registry and powercfg
- **Metrics:**
  - Active power plan
  - Fast Startup status
  - Hibernation enabled/disabled
  - Sleep settings

**Health Status Calculation:**
- **Critical:** Failed critical services, Defender disabled, <5% disk space
- **Warning:** Stopped services, old definitions, <15% disk space
- **Healthy:** All checks passed

---

### Get-HardwareData

**Purpose:** Collects comprehensive hardware inventory and health metrics

**Data Collected:**

#### 1. CPU Information
- **Method:** WMI Win32_Processor, Performance Counters
- **Metrics:**
  - Processor name, manufacturer, architecture
  - Core count, logical processor count
  - Clock speed (base & max)
  - Current utilization (%)
  - Cache sizes (L2, L3)
  - Virtualization support
  - Temperature (if available)
  - Throttling status

#### 2. Memory Information
- **Method:** WMI Win32_PhysicalMemory, Win32_OperatingSystem
- **Metrics:**
  - Total installed RAM (GB)
  - Available memory (GB)
  - Memory usage (%)
  - Module count
  - Individual module details:
    - Capacity, speed (MHz)
    - Manufacturer, part number
    - Form factor (DIMM, SODIMM)
    - Memory type (DDR3, DDR4, DDR5)
    - Location (slot)
  - Total slots vs. used slots
  - Status (Healthy/Warning/Critical based on usage)

#### 3. Storage Devices
- **Method:** Get-PhysicalDisk, Get-StorageReliabilityCounter, WMI Win32_LogicalDisk
- **Metrics:**
  - Per-device data:
    - Model, serial number, device ID
    - Media type (HDD/SSD/NVMe)
    - Bus type (SATA, NVMe, USB)
    - Capacity, used, free space (GB)
    - Percentage free
    - Health status, operational status
    - SMART attributes:
      - Temperature (°C)
      - Power-on hours/days
      - SSD wear level (%)
      - Read/write errors
      - Reallocated sectors
      - Max temperature
    - TRIM status (for SSDs):
      - Supported, enabled, status
    - Performance:
      - Read speed (MB/s) - measured or estimated
      - Write speed (MB/s) - measured or estimated
  - **Disk Speed Test** (optional, can skip with -SkipDiskTest):
    - Creates 100MB test file on system drive
    - Measures sequential read/write performance
    - Cleans up test file automatically
    - Falls back to estimates if test fails

#### 4. Graphics Devices
- **Method:** WMI Win32_VideoController
- **Metrics:**
  - GPU name, manufacturer
  - Driver version & date
  - VRAM size (GB) - handles >4GB correctly
  - Current resolution & refresh rate
  - Video processor
  - Architecture/connection type
  - Status
  - Digital signature verification

#### 5. System Board (Motherboard)
- **Method:** WMI Win32_BaseBoard, Win32_BIOS, Win32_ComputerSystem
- **Metrics:**
  - Computer manufacturer & model
  - Motherboard manufacturer, product, version
  - Serial number
  - BIOS:
    - Manufacturer, version
    - Release date & age (days)
  - Security features:
    - Boot mode (UEFI/Legacy)
    - Secure Boot status
    - TPM status & version (1.2/2.0)

#### 6. Power & Battery
- **Method:** WMI Win32_Battery, BatteryStatus (root/WMI), powercfg report
- **Metrics:**
  - Active power plan
  - Battery information (laptops):
    - Name, manufacturer, chemistry
    - Design capacity (mWh)
    - Full charge capacity (mWh)
    - Current charge (%)
    - Health percentage
    - Cycle count
    - Estimated runtime (minutes)
    - Status (charging/discharging/AC power)
    - Health status (Healthy/Warning/Critical)

#### 7. USB Devices
- **Method:** WMI Win32_USBController, Win32_PnPEntity
- **Metrics:**
  - Controller count
  - USB 3.0+ support detection
  - Connected device count
  - Error device count
  - Controller details (name, manufacturer, status)
  - Device list (up to 10 most recent)

#### 8. Audio Devices
- **Method:** WMI Win32_PnPEntity (AudioEndpoint class), Win32_SoundDevice
- **Metrics:**
  - Default playback device
  - Default recording device
  - Total audio devices
  - Error count
  - Per-device: name, type (playback/recording), status

**Health Score Calculation:**
- Weighted scoring (0-100):
  - Storage: 30% (critical/warning devices)
  - Memory: 25% (usage thresholds)
  - CPU: 20% (utilization, throttling)
  - Power: 15% (battery health for laptops)
  - Other: 10%

---

### Get-NetworkData

**Purpose:** Collects network configuration and connectivity information

**Data Collected:**

#### 1. Network Adapters
- **Method:** WMI Win32_NetworkAdapter, Win32_NetworkAdapterConfiguration
- **Metrics:**
  - Physical adapters only (excludes virtual)
  - Per-adapter data:
    - Name, manufacturer
    - Status (up/down)
    - Connection type (Ethernet/Wi-Fi)
    - Speed (Mbps/Gbps)
    - MAC address
    - IP addresses (IPv4, IPv6)
    - Subnet mask, gateway
    - DNS servers
    - DHCP enabled/disabled
    - DHCP server address
    - Link speed & duplex

#### 2. Active Connections
- **Method:** Get-NetTCPConnection
- **Metrics:**
  - Established connections
  - Listening ports
  - Connection state
  - Local/remote addresses
  - Process ID & name
  - Connection count by state

#### 3. Network Statistics
- **Method:** Performance counters
- **Metrics:**
  - Bytes sent/received
  - Current bandwidth usage
  - Packets sent/received
  - Network errors
  - Dropped packets

#### 4. Connectivity Tests
- **Method:** Test-NetConnection
- **Metrics:**
  - Internet connectivity (to 8.8.8.8)
  - DNS resolution test
  - Gateway reachability
  - Latency measurements
  - Packet loss

#### 5. Network Configuration
- **Method:** Registry, Get-DnsClientServerAddress
- **Metrics:**
  - DNS suffixes
  - WINS servers
  - Network location (Public/Private/Domain)
  - Network profiles
  - Firewall status per profile

**Health Status:**
- **Critical:** No connectivity, all adapters down
- **Warning:** Limited connectivity, DNS issues
- **Healthy:** Full connectivity

---

### Get-SoftwareData

**Purpose:** Inventories installed applications

**Data Collected:**

#### 1. Installed Applications
- **Method:** Registry (Uninstall keys) + WMI Win32_Product (fallback)
- **Sources:**
  - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`
  - `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall`
  - `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`
  - WMI Win32_Product (if registry incomplete)

- **Metrics per application:**
  - Display name
  - Version
  - Publisher
  - Install date & age (days)
  - Install location
  - Estimated size (MB)
  - Uninstall string
  - Architecture (32/64-bit)
  - System component flag

#### 2. Application Categories
- **Method:** Automatic categorization by publisher/name
- **Categories:**
  - Microsoft (OS components, Office, etc.)
  - Security (antivirus, firewall)
  - Productivity (Office suites, PDF readers)
  - Development (IDEs, SDKs)
  - Web Browsers
  - Media (players, editors)
  - System Tools
  - Other

#### 3. Application Analysis
- **Recent installations** (last 90 days)
- **Large applications** (>1GB)
- **Outdated applications** (>2 years old)
- **Duplicate applications** (same name, different versions)

**Health Status:**
- Based on outdated software count and security software presence

---

### Get-DriverData

**Purpose:** Inventories device drivers and identifies issues

**Data Collected:**

#### 1. PnP Devices
- **Method:** Get-PnpDevice, WMI Win32_PnPEntity
- **Filters:** Relevant device classes only:
  - Display, Network, DiskDrive, AudioEndpoint
  - Media, Monitor, USB, Bluetooth, Camera
  - Keyboard, Mouse, Storage Controllers
  - System devices (filtered to exclude legacy/virtual)

- **Metrics per device:**
  - Device name, ID, class
  - Status (OK/Error/Degraded)
  - Problem code (0-48)
  - Problem description with remediation
  - Manufacturer, service
  - Present status

**Problem Codes & Descriptions:**
- Code 1: Not configured correctly
- Code 3: Driver corrupted
- Code 10: Device cannot start
- Code 12: Resource conflict
- Code 22: Device disabled
- Code 28: Drivers not installed
- Code 31: Device not working properly
- Code 43: Device has reported problems
- 32+ additional codes with actionable remediation steps

#### 2. Driver Properties
- **Method:** Get-PnpDeviceProperty (batch query)
- **Optimization:** Retrieves all properties in 4 bulk queries instead of N*4
- **Metrics per driver:**
  - Driver version
  - Driver date & age (days)
  - Driver provider (Microsoft, OEM, etc.)
  - INF path
  - Update status (Current/Aging/Old/Very Old)

#### 3. Driver Signatures
- **Method:** WMI Win32_PnPSignedDriver
- **Metrics:**
  - Digital signature status
  - Signer (certificate authority)
  - INF name
  - Unsigned driver detection

#### 4. Driver Categories
- **Display:** Graphics adapters, monitors
- **Network:** Network adapters
- **Audio:** Sound devices, endpoints
- **Storage:** Disks, controllers, SCSI adapters
- **System:** Motherboard, processors
- **Other:** Everything else

#### 5. Driver Priority
- **Critical:** System, storage, network drivers
- **Important:** Display, audio drivers
- **Standard:** Other peripheral drivers

**Update Status Thresholds:**
- **Critical drivers:**
  - Very Old: >2 years
  - Old: >1 year
  - Aging: >6 months
- **Important drivers:**
  - Very Old: >2 years
  - Old: >1 year
  - Aging: >9 months
- **Standard drivers:**
  - Very Old: >3 years
  - Old: >2 years
  - Aging: >1 year

#### 6. Performance Impact Analysis
- **Method:** Event logs (Microsoft-Windows-Kernel-PnP)
- **Metrics:**
  - Driver errors (last 24 hours)
  - Error frequency by driver
  - Boot impact (if detectable)

#### 7. Recent Driver Changes
- **Method:** Event logs (Microsoft-Windows-UserPnp/DeviceInstall)
- **Metrics:**
  - Last 10 driver installations/updates
  - Success/failure status
  - Device identifier
  - Timestamp

**Health Status:**
- **Critical:** Missing drivers, very old critical drivers, >5 problem devices
- **Warning:** Problem devices, >5 outdated drivers, unsigned drivers
- **Healthy:** All drivers current and functional

**Performance Note:**
- Driver store inventory skipped (takes 23+ seconds, data unused)

---

### Get-BrowserData

**Purpose:** Inventories installed browsers and analyzes security configuration

**Data Collected:**

#### 1. Browser Detection
- **Method:** Filesystem checks + Registry
- **Browsers Detected:**
  - Microsoft Edge
  - Google Chrome
  - Mozilla Firefox
  - Opera
  - Brave
  - Vivaldi
  - Internet Explorer
  - Other registered browsers

**Detection Locations:**
- Standard Program Files paths
- User AppData paths
- Registry: `HKLM:\SOFTWARE\Clients\StartMenuInternet`

#### 2. Browser Versions
- **Method:** File version info + Vendor APIs
- **Live Version Check:**
  - Chrome: Google Version History API
  - Edge: Microsoft Edge Update API
  - Firefox: Mozilla Product Details API
- **Metrics:**
  - Installed version
  - Latest available version
  - Update required flag
  - Install date
  - Executable size
  - Digital signature validation
  - Certificate information

#### 3. Default Browser
- **Method:** Registry UserChoice
- **Location:** `HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice`

#### 4. Browser Profiles & Extensions

##### Chrome/Edge
- **Profile Path:**
  - Chrome: `%LOCALAPPDATA%\Google\Chrome\User Data\Default`
  - Edge: `%LOCALAPPDATA%\Microsoft\Edge\User Data\Default`
- **Extension Data:**
  - Extension ID, name, version
  - Description
  - Permissions analysis
  - Manifest parsing

##### Firefox
- **Profile Path:** `%APPDATA%\Mozilla\Firefox\Profiles\*.default*`
- **Extension Data:**
  - From extensions.json
  - Extension ID, name, version
  - Active status

#### 5. Cache Size
- **Locations:**
  - Chrome/Edge: Cache, Code Cache, Service Worker
  - Firefox: cache2, OfflineCache, storage
- **Method:** Recursive folder size calculation

#### 6. Security Settings

##### Chrome/Edge Detection
- **Method:** Group Policy + Preferences file
- **Policy Locations:**
  - `HKLM:\SOFTWARE\Policies\Google\Chrome`
  - `HKLM:\SOFTWARE\Policies\Microsoft\Edge`
- **Settings Detected:**
  - Safe Browsing (enabled/disabled)
  - Password Manager (enabled/disabled)
  - Autofill (enabled/disabled)
  - Tracking Prevention (enabled/disabled)
- **Priority:** Group Policy > User Preferences > Defaults

##### Firefox Detection
- **Method:** prefs.js and user.js parsing
- **Settings Detected:**
  - Safe Browsing
  - Password Manager
  - Tracking Protection
  - Privacy settings

#### 7. Auto-Update Status

##### Chrome
- **Method:** Group Policy, Services, Scheduled Tasks
- **Checks:**
  - UpdateDefault policy
  - GoogleUpdate service status
  - GoogleUpdateTaskMachine scheduled task
  - Local State file preferences

##### Edge
- **Method:** Similar to Chrome, plus Windows Update
- **Checks:**
  - EdgeUpdate policy
  - Edge Update services
  - MicrosoftEdgeUpdate scheduled tasks
  - Windows Update status (Win11)

##### Firefox
- **Method:** Group Policy, policies.json, prefs.js
- **Checks:**
  - DisableAppUpdate policy
  - Enterprise policies.json
  - app.update preferences
  - MozillaMaintenance service

#### 8. Security Issue Analysis
- **Outdated Browser Detection:**
  - Edge/Chrome: <v110 flagged
  - Firefox: <v100 flagged
- **Excessive Cache:** >5GB
- **Disabled Safe Browsing:** Critical issue
- **High-Permission Extensions:**
  - webRequest, webRequestBlocking, <all_urls>
  - Flagged for review

**Health Status:**
- **Critical:** Safe browsing disabled
- **Warning:** >2 security issues, >10GB cache
- **Healthy:** All checks passed

---

### Get-PrinterData

**Purpose:** Monitors printer status and print queue health

**Data Collected:**

#### 1. Printer Inventory
- **Method:** Get-Printer cmdlet
- **Metrics per printer:**
  - Name, status
  - Default printer flag
  - Shared printer flag & share name
  - Driver name
  - Port name
  - Location, comment
  - Type (Local/Network)
  - Network details:
    - Server name (for UNC paths)
    - IP address (for TCP/IP ports)
  - Job count
  - Configuration:
    - Print processor, datatype
    - Priority, keep printed jobs flag

**Printer Status Codes:**
- 0: Ready
- 1: Paused
- 2: Error
- 4: Paper Jam
- 5: Paper Out
- 8: Offline
- 11: Printing
- 18: Toner Low
- 21: User Intervention Required
- 22: Out of Memory
- 23: Door Open
- 131072: Driver Update Needed
- Additional codes (10-23, see function)

#### 2. Print Queue Status
- **Method:** Get-PrintJob per printer
- **Metrics per job:**
  - Job ID, document name
  - User name
  - Status, submitted time
  - Time in queue (minutes)
  - Size (MB)
  - Pages printed vs. total
  - Priority, position
  - Flags:
    - IsStuck (>60 minutes in queue)
    - IsLarge (>50MB)

#### 3. Print Spooler Health
- **Method:** WMI Win32_Service, Event logs
- **Metrics:**
  - Service status & state
  - Memory usage (MB)
  - Spool folder path & size (MB)
  - Recent crashes (48 hours)
  - Last restart time
  - Event log errors (last 5)

**Spool Folder:** `%windir%\System32\spool\PRINTERS`

#### 4. Printer Drivers
- **Method:** Get-PrinterDriver cmdlet
- **Metrics per driver:**
  - Name, version (major.minor)
  - Date & age (days)
  - Environment (x64, x86)
  - Provider, INF path
  - File paths (config, data, driver)
  - Print processor
  - Package-aware flag
  - Age status (Current/Normal/Old/Very Old)

**Driver Age Thresholds:**
- Very Old: >730 days (2 years)
- Old: >365 days (1 year)
- Normal: >180 days (6 months)
- Current: <180 days

#### 5. Network Printer Connectivity
- **Method:** Test-NetConnection
- **Metrics per network printer:**
  - Server/IP address
  - Port (445 for SMB)
  - Connection status (Connected/Failed/Unreachable)
  - Response time (ms)
  - Last test time

#### 6. Printer Issues Detection
- **Critical Issues:**
  - Spooler service stopped
  - >5 spooler crashes (48h)
  - >5GB spool folder size
  - All printers offline
  - Stuck print jobs (>60 min)
  - Printer errors (error status)

- **Warning Issues:**
  - 2-5 spooler crashes
  - >1GB spool folder size
  - Some printers offline
  - Slow queue (>30 min)
  - Very old drivers (>2 years)

**Health Status:**
- **Critical:** Spooler stopped, stuck jobs, all printers offline
- **Warning:** Some issues detected
- **Healthy:** All systems operational

---

### Get-EventData

**Purpose:** Analyzes Windows Event Logs for issues and patterns

**Data Collected:**

#### 1. Event Log Query
- **Time Range:** Last 24 hours (configurable)
- **Logs Queried:**
  - System log (always)
  - Application log (always)
  - Security log (if admin)

**Event Levels:**
- Level 1: Critical
- Level 2: Error
- Level 3: Warning

**Max Events:** 500 from System/Application, 100 from Security

#### 2. Event Categorization by Severity
- **Critical Events** (Level 1)
- **Error Events** (Level 2)
- **Warning Events** (Level 3)

**Top 50 events per severity level**

#### 3. Known Event Types
**Friendly Event Names:**
| Event ID | Name | Significance |
|----------|------|--------------|
| 41 | Unexpected Shutdown | System crash/BSOD |
| 1000 | Application Crash | App terminated unexpectedly |
| 1001 | Windows Error Reporting / BugCheck | BSOD/kernel crash |
| 1002 | Application Hang | App not responding |
| 1074 | System Shutdown/Restart | Planned shutdown |
| 4625 | Failed Login Attempt | Authentication failure |
| 4740 | Account Lockout | Brute force indicator |
| 4776 | Authentication Failure | Credential validation failed |
| 6005 | Event Log Service Started | System boot |
| 6006 | Event Log Service Stopped | Shutdown |
| 6008 | Previous Shutdown Was Unexpected | Crash recovery |
| 6013 | System Uptime | Time since boot |
| 7034 | Service Crashed Unexpectedly | Service failure |
| 7036 | Service State Changed | Service start/stop |
| 10016 | DCOM Permission Error | Permission issue |
| 19/20 | Windows Update Installed/Started | Update activity |

#### 4. Event Categories
- **SystemCrashes:** Events 41, 6008, 1001, 1074
- **ApplicationErrors:** Events 1000, 1002
- **ServiceIssues:** Events 7034, 7035, 7036
- **UpdateEvents:** Events 19, 20, 43, 44
- **SecurityEvents:** Events 4625, 4740, 4776
- **HardwareEvents:** Events 10016, 10028, 10029

**Top 20 events per category**

#### 5. Top Event Sources
- Groups events by ProviderName
- Top 10 sources by event count
- Identifies noisy components

#### 6. Pattern Analysis

##### Recurring Crashes
- **Detection:** >3 crash events in 24 hours
- **Events:** 41, 1000, 1001, 6008
- **Severity:** High
- **Recommendation:** Investigate driver/hardware issues

##### Authentication Failures
- **Detection:** >10 auth failures in 24 hours
- **Events:** 4625, 4776
- **Severity:** Medium
- **Analysis:** Checks if from single source (brute force)
- **Recommendation:** Review security policies

##### Service Instability
- **Detection:** >5 service crashes in 24 hours
- **Event:** 7034
- **Severity:** Medium
- **Analysis:** Identifies most-failing service
- **Recommendation:** Review service dependencies

##### DCOM Errors
- **Detection:** >20 DCOM errors in 24 hours
- **Events:** 10016, 10028, 10029
- **Severity:** Low
- **Recommendation:** Review DCOM permissions

##### Time-Based Patterns
- **Hourly clustering:** Detects if >30% events in one hour
- **After-hours activity:** Flags if >40% events outside 6AM-8PM

#### 7. BugCheck (BSOD) Detection
- **Method:** Query for Event ID 1001
- **Time Range:** Last 24 hours
- **Limit:** 10 most recent
- **Data:** Timestamp, message, relative time

#### 8. Relative Time Calculation
- <60 minutes: "X minutes ago"
- <24 hours: "X hours ago"
- ≥24 hours: "X days ago"

**Summary Statistics:**
- Total events collected
- Count by severity (Critical/Error/Warning)
- Time range queried
- Admin access available
- Has BugCheck events flag
- Has patterns detected flag
- Most recent critical event

**Performance:** ~5-15 seconds depending on event volume

---

## Data Collection Methods

### WMI/CIM Queries

**Primary Method:** CIM (Common Information Model) via CIM sessions

**Advantages:**
- Faster than legacy WMI
- More reliable
- Supports remote sessions
- Standards-based

**Common Classes Used:**
- Win32_ComputerSystem
- Win32_OperatingSystem
- Win32_Processor
- Win32_PhysicalMemory
- Win32_LogicalDisk
- Win32_NetworkAdapter
- Win32_Service
- Win32_Product

### PowerShell Cmdlets

**Modern cmdlets preferred when available:**
- Get-PnpDevice (driver data)
- Get-Printer / Get-PrintJob (printer data)
- Get-PhysicalDisk / Get-StorageReliabilityCounter (storage)
- Get-NetAdapter / Get-NetTCPConnection (network)
- Get-WinEvent (event logs)
- Get-MpComputerStatus (Windows Defender)

### Registry Queries

**Used for:**
- Software inventory (uninstall keys)
- Browser detection & settings
- Update configurations
- Security policies
- Service settings

**Locations:**
- HKLM:\SOFTWARE
- HKLM:\SYSTEM\CurrentControlSet
- HKCU:\SOFTWARE
- 32-bit keys: WOW6432Node

### Performance Counters

**Used for real-time metrics:**
- CPU utilization
- Memory usage
- Disk performance
- Network bandwidth

### Event Logs

**Method:** Get-WinEvent with FilterHashtable

**Optimizations:**
- Time-based filtering (last 24-48 hours)
- Event ID filtering
- Level filtering (Critical/Error/Warning only)
- MaxEvents limits

### COM Objects

**Used for:**
- Windows Update (Microsoft.Update.Session)
- Office detection
- Browser automation

### Vendor APIs

**Live browser version checks:**
- Chrome: https://versionhistory.googleapis.com/v1/chrome/platforms/win/channels/stable/versions
- Edge: https://edgeupdates.microsoft.com/api/products
- Firefox: https://product-details.mozilla.org/1.0/firefox_versions.json

**Timeout:** 5 seconds per API call

---

## Performance Optimization

### 1. Data Caching
- **Get-CommonData.ps1** pre-fetches shared WMI classes
- Single query → multiple collectors
- ~40% time savings

### 2. Parallel Execution
- 8 collectors run concurrently via background jobs
- Independent data sources
- No resource contention

### 3. Batch Queries
**Example:** Driver data
- Old method: 4 queries × N devices = 4N queries
- New method: 4 batch queries (all devices at once)
- **Performance:** 20-30 seconds → 3-5 seconds

### 4. Selective Filtering
**Example:** PnP devices
- Only query relevant device classes
- Exclude legacy/virtual devices
- Filter: 5000+ devices → 50-100 relevant devices

### 5. Strategic Skips
**Example:** Driver store inventory
- Takes 23+ seconds
- Data unused in reports
- Skipped entirely

### 6. Timeouts & Limits
- API calls: 5 second timeout
- Event queries: MaxEvents limits (50-500)
- Collector timeouts: 120-300 seconds
- Network tests: 10 second timeout

### 7. Efficient Data Structures
- Hashtable lookups (O(1) vs O(n))
- Pre-computed status mappings
- Cached calculations

### 8. Error Handling
- SilentlyContinue for non-critical failures
- Graceful fallbacks
- Continue on partial failures

### 9. Conditional Collection
- Admin checks before Security log queries
- Battery checks before battery data
- Network checks before connectivity tests

### 10. Optimized Disk Speed Test
- 100MB test file (vs 1GB+)
- Sequential read/write only
- Optional skip flag (-SkipDiskTest)
- Cleans up automatically

---

## Health Status Standardization

All collectors return a standardized health status:

- **Healthy:** All checks passed, system operating normally
- **Warning:** Non-critical issues detected, attention recommended
- **Critical:** Serious issues requiring immediate action
- **Unknown:** Unable to determine health status

**Status Calculation:**
1. Check for critical conditions (service stopped, disk full, etc.)
2. Check for warning conditions (aging components, errors, etc.)
3. Default to Healthy if no issues found

**Consistent Thresholds:**
- Disk space: <10% Critical, <20% Warning
- Memory usage: >90% Critical, >80% Warning
- Driver age: >2yr Critical drivers flagged
- Update age: >90 days Warning

---

## Error Handling

All collectors implement defensive error handling:

```powershell
try {
    # Collection logic
    Write-ProgressStatus -Activity "..." -Status "..." -PercentComplete X
} catch {
    Write-Error "Failed to collect data: $_"
    Write-CollectorLog -Message "Error: $_" -Level "ERROR" -Component "CollectorName"
}
```

**Fallback Strategy:**
1. Try primary method (CIM, cmdlet)
2. Fall back to secondary method (WMI, registry)
3. Return null/empty if all methods fail
4. Log failure for troubleshooting

**Graceful Degradation:**
- Partial data collection continues if one section fails
- Summary still generated with available data
- Health status marked as "Unknown" if critical data missing

---

## Adding New Collectors

To add a new collector:

1. **Create new file:** `Get-<Category>Data.ps1`
2. **Implement standard structure:**
   ```powershell
   function Get-<Category>Data {
       param([hashtable]$DataCache = $Global:DataCache)

       # Initialize
       $data = [PSCustomObject]@{
           CollectedAt = Get-Date
           Summary = $null
           HealthStatus = "Unknown"
       }

       # Collect
       # Analyze
       # Summarize

       return $data
   }
   ```
3. **Use helper functions:**
   - Get-CachedData for WMI
   - Write-ProgressStatus for updates
   - Write-CollectorLog for logging
   - Get-StatusFromThreshold for health
4. **Update WinDAS.ps1:**
   - Add to $collectors array
   - Add to parallel job execution
5. **Update report template** to display new data

---

## Troubleshooting

### Enable Logging
```powershell
.\WinDAS.ps1 -Logs
```
Log file: `Logs\WinDAS_{Timestamp}.log`

### Common Issues

**Slow Collection:**
- Use `-SkipDiskTest` to skip disk speed benchmark
- Check for slow WMI queries (restart WMI service)
- Review log for timeouts

**Missing Data:**
- Verify admin privileges (required for some data)
- Check WMI service status
- Review collector logs for errors

**Incomplete Results:**
- Check collector timeout (120-300s)
- Review background job errors
- Verify required PowerShell version (5.1+)

---

## Version History

**Version 2.1.0 (Chocolate Milk)**
- Modular architecture with separate collectors
- Parallel execution via background jobs
- Enhanced SMART data collection
- Browser security analysis
- Driver batch query optimization
- Pattern analysis in event logs
- Comprehensive health scoring

**Version 1.x**
- Monolithic collection script
- Sequential execution
- Basic data collection

---

## License

WinDAS - Windows Diagnostic Assessment Suite
Author: Joshua Walderbach
License: [Your License Here]

---

## Support

For issues, questions, or contributions, please refer to the main WinDAS documentation.
