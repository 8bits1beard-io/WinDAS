# WinDAS - Windows Diagnostic Assessment Suite

**Version 2.1.0 (Chocolate Milk)**
*Comprehensive Windows system diagnostics and reporting tool*

WinDAS automatically collects detailed information about a Windows computer and generates an easy-to-read HTML report. Perfect for IT support, system audits, troubleshooting, and documentation.

---

## What Does WinDAS Collect?

WinDAS gathers comprehensive system information organized into clear categories:

### 🖥️ Operating System
- Windows version and edition
- Installation date and uptime
- Windows updates and patch status
- Running services and startup programs
- System integrity and health checks

### 🔧 Hardware
- Processor (CPU) details and performance
- Memory (RAM) configuration and usage
- Hard drives and storage devices
- BIOS/UEFI information
- Motherboard details
- Disk speed performance test

### 🌐 Network
- Network adapters and their status
- IP addresses and network configuration
- Wi-Fi and Ethernet connections
- DNS and gateway settings
- Network performance metrics

### 📦 Software
- All installed programs and applications
- Software versions and publishers
- Installation dates and sizes
- System and user applications

### 🎨 Drivers
- All device drivers installed on the system
- Driver versions and dates
- Driver digital signatures and publishers
- Problem drivers or missing signatures

### 🌍 Browsers
- Installed web browsers (Chrome, Firefox, Edge, etc.)
- Browser versions
- Installed browser extensions and add-ons

### 🖨️ Printers
- Installed printers and print queues
- Printer drivers and status
- Default printer configuration

### 📋 Event Logs
- Critical system errors
- Important warnings
- Recent system events
- Application crashes and issues

---

## Prerequisites

Before using WinDAS, ensure you have:

1. **Windows Computer** - Windows 7 or newer (Windows 10/11 recommended)
2. **PowerShell 5.1 or newer** - Included by default in Windows 10/11
3. **Administrator Rights** - For complete system information
   - You can run without admin, but some data may be limited

### For Remote Deployment

To deploy WinDAS to other computers, you'll also need:

1. **Network access** to the target computer
2. **PowerShell Remoting enabled** on the target computer
3. **Administrator credentials** for the target computer

---

## Getting Started

### Step 1: Download WinDAS

**Option A: Download ZIP** (Easiest for non-technical users)
1. Click the green **Code** button at the top of this page
2. Select **Download ZIP**
3. Extract the ZIP file to a folder (e.g., `C:\WinDAS`)

**Option B: Clone with Git** (If you have Git installed)
```powershell
git clone https://github.com/8bits1beard-io/WinDAS.git
cd WinDAS
```

### Step 2: Run WinDAS

1. **Open PowerShell as Administrator**
   - Press `Windows Key`
   - Type `PowerShell`
   - Right-click **Windows PowerShell**
   - Select **Run as Administrator**

2. **Navigate to the WinDAS folder**
   ```powershell
   cd C:\WinDAS
   ```
   *(Replace with your actual folder location)*

3. **Run the diagnostic**
   ```powershell
   .\WinDAS.ps1
   ```

4. **Wait for completion**
   - WinDAS will collect data (typically 30-60 seconds)
   - A progress indicator will show what's happening

5. **View your report**
   - The report will automatically open in your default web browser
   - Reports are saved in the `Reports` folder

### Quick Options

**Skip the disk speed test** (makes it run faster):
```powershell
.\WinDAS.ps1 -SkipDiskTest
```

**Save detailed logs** (for troubleshooting):
```powershell
.\WinDAS.ps1 -Logs
```

---

## Using the PowerShell Module (Recommended)

WinDAS includes a PowerShell module for simplified deployment. After one-time setup, you can run diagnostics from anywhere.

### Quick Setup

Navigate to your WinDAS directory and run:

```powershell
# Get the full path to WinDAS module (works from any install location)
$windasPath = Join-Path $PWD "WinDAS.psm1"
$profileLine = "Import-Module `"$windasPath`""

# Create profile if it doesn't exist
if (-not (Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force
}

# Add the import line if not already there
if ((Get-Content $PROFILE -ErrorAction SilentlyContinue) -notcontains $profileLine) {
    Add-Content -Path $PROFILE -Value "`n$profileLine"
}

# Load it now
Import-Module $windasPath
```

### Using the Module

**Run diagnostics locally on current computer:**
```powershell
Invoke-WinDAS
```
*Report will be saved in your current directory*

**Run locally with faster execution:**
```powershell
Invoke-WinDAS -SkipDiskTest
```

**Run diagnostics on a remote computer:**
```powershell
Invoke-WinDAS -ComputerName PC-12345
```
*Report will be retrieved to your current directory*

**Run on multiple computers:**
```powershell
Invoke-WinDAS -ComputerName PC-001, PC-002, PC-003
```

**Skip disk test for faster execution (remote):**
```powershell
Invoke-WinDAS PC-12345 -SkipDiskTest
```

**Check for updates:**
```powershell
Update-WinDAS
```

**Tip:** Navigate to where you want the report saved before running:
```powershell
cd C:\ServiceNow\INC0012345
Invoke-WinDAS
# Report saved to C:\ServiceNow\INC0012345\WinDAS_Report_*.html
```

See [GETTING-STARTED.md](GETTING-STARTED.md) for complete setup instructions.

---

## Deploying to Another Computer (Without Module)

You can also run WinDAS on remote computers without the module using Deploy-WinDAS.ps1.

### Prerequisites for Remote Deployment

1. **On the target computer**, enable PowerShell Remoting:
   - Open PowerShell as Administrator
   - Run: `Enable-PSRemoting -Force`

### Basic Deployment

**Deploy and run on a remote computer:**
```powershell
.\Deploy-WinDAS.ps1 -ComputerName PC-12345 -Execute
```

**Deploy, run, and retrieve the report:**
```powershell
.\Deploy-WinDAS.ps1 -ComputerName PC-12345 -Execute -RetrieveReport
```

**Deploy, run, retrieve, and cleanup (recommended):**
```powershell
.\Deploy-WinDAS.ps1 -ComputerName PC-12345 -Execute -RetrieveReport -Cleanup
```

**Deploy to multiple computers:**
```powershell
"PC-12345", "PC-67890", "LAPTOP-001" | .\Deploy-WinDAS.ps1 -Execute -RetrieveReport -Cleanup
```

### Deployment Options

| Option | Description |
|--------|-------------|
| `-ComputerName PC-NAME` | Target computer name or IP address |
| `-Execute` | Automatically run WinDAS after deploying |
| `-SkipDiskTest` | Skip disk speed test (faster) |
| `-RetrieveReport` | Copy the report back to your computer |
| `-Cleanup` | Remove WinDAS from remote computer after retrieving report |
| `-Credential` | Use alternate credentials: `-Credential (Get-Credential)` |

---

## Understanding the Report

After WinDAS completes, you'll get an HTML report that you can:
- **Open in any web browser** (Chrome, Edge, Firefox, etc.)
- **Email or share** - it's a single standalone file
- **Archive for records** - great for documentation
- **Compare over time** - track system changes

The report includes:
- **Interactive tabs** - click to switch between categories
- **Search functionality** - find specific information quickly
- **Color-coded status** - quickly identify issues
- **Detailed tables** - comprehensive data in organized tables
- **Summary cards** - key metrics at a glance

### Converting to PDF

If you need the report in an alternative format (for sharing where HTML isn't optimal), you can easily convert it to PDF:

1. Open the WinDAS report in Chrome or Edge
2. Press `Ctrl+P` (Print)
3. Select "Save as PDF" as the destination
4. Click Save

The PDF will contain all report content, though interactive features (tabs, search, sorting) will not be functional.

---

## Output Files

### Reports
Location: `Reports/`

File format: `WinDAS_Report_{ComputerName}_{Timestamp}.html`

Example: `WinDAS_Report_DESKTOP-ABC123_2025-10-10T143022.html`

### Logs (Optional)
Location: `Logs/` (only when using `-Logs` parameter)

File format: `WinDAS_{Timestamp}.log`

---

## Troubleshooting

### "Cannot run scripts" error

If you see a script execution error, run this command once:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Running without Administrator

WinDAS will run without admin rights, but some information may be unavailable:
- Certain system services
- Some driver details
- Detailed event logs

For complete data, always run as Administrator.

### Remote Deployment Fails

If deployment to another computer fails:
1. Verify the computer is reachable: `Test-Connection PC-NAME`
2. Ensure PowerShell Remoting is enabled on the target
3. Check Windows Firewall settings
4. Verify you have admin rights on the target computer

---

## System Requirements

### Minimum
- Windows 7 or newer
- PowerShell 5.1
- 100 MB free disk space
- 2 GB RAM

### Recommended
- Windows 10 or Windows 11
- PowerShell 5.1 or newer
- Administrator privileges
- 500 MB free disk space
- 4 GB RAM

---

## Privacy & Security

- **No data leaves your network** - WinDAS runs completely locally
- **No internet required** - works in air-gapped environments
- **No telemetry** - we don't collect any information
- **Open source** - you can review all code in this repository
- **Standalone reports** - HTML files contain no external dependencies

---

## Frequently Asked Questions

**Q: Does WinDAS require an internet connection?**
A: No, WinDAS works completely offline.

**Q: How long does a scan take?**
A: Typically 30-60 seconds. Use `-SkipDiskTest` for faster scans (~20 seconds).

**Q: Can I schedule WinDAS to run automatically?**
A: Yes, you can use Windows Task Scheduler to run WinDAS on a schedule.

**Q: Is WinDAS safe to run?**
A: Yes, WinDAS only reads information - it never modifies your system.

**Q: Can I run WinDAS on servers?**
A: Yes, WinDAS works on Windows Server editions.

**Q: How do I update WinDAS?**
A: Download the latest version from this repository and replace your existing files.

---

## Support

- **Issues**: Report bugs or request features via [GitHub Issues](https://github.com/8bits1beard-io/WinDAS/issues)
- **Author**: Joshua Walderbach

---

## License

See [LICENSE](LICENSE) file for details.

---

## Version History

- **2.1.0 (Chocolate Milk)** - Current version
  - PowerShell module for simplified deployment (`Invoke-WinDAS`)
  - Alphabetically sorted navigation menu
  - Expanded container width to 90% for better desktop utilization
  - Auto-update checker with simple instructions
  - Comprehensive getting started documentation

- **2.0.0 (Chocolate Milk)**
  - Modular template system
  - Improved parallel data collection
  - Enhanced report generation

---

**Made with ❤️ for IT professionals and system administrators**
