# Getting Started with WinDAS - For Technicians

**Simple step-by-step guide to get WinDAS running on your computer.**

---

## What is WinDAS?

WinDAS is a tool that scans a Windows computer and creates a detailed diagnostic report. You can use it to:
- Troubleshoot computer problems
- Document system configurations
- Check hardware and software status
- Generate reports for ServiceNow tickets

---

## First Time Setup (Do This Once)

### Step 1: Get WinDAS on Your Computer

**If you DON'T have Git installed:**

1. Contact your IT administrator or team lead to get access to the WinDAS repository
2. They will provide you with either:
   - A ZIP file to extract
   - Access to a shared network location
   - Instructions to clone from your internal Git server

**If you HAVE Git installed:**

1. Open PowerShell
2. Navigate to where you want WinDAS:
   ```powershell
   cd C:\Tools
   ```
   (Create the folder first if needed: `New-Item -Path C:\Tools -ItemType Directory`)

3. Clone WinDAS:
   ```powershell
   git clone [YOUR-INTERNAL-GIT-URL-HERE]
   ```
   *(Ask your team lead for the correct Git URL)*

4. Go into the WinDAS folder:
   ```powershell
   cd WinDAS
   ```

---

### Step 2: Enable PowerShell Scripts (One-Time)

**You only need to do this once on your computer.**

1. Open PowerShell **as Administrator**:
   - Press `Windows Key`
   - Type `PowerShell`
   - Right-click **Windows PowerShell**
   - Click **Run as Administrator**

2. Copy and paste this command:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. When asked "Do you want to change the execution policy?", type `Y` and press Enter

4. Close the Administrator PowerShell window

---

### Step 3: Set Up the WinDAS PowerShell Module (Optional but Recommended)

**This lets you run WinDAS from anywhere without navigating to the folder.**

1. Open a regular PowerShell window (doesn't need to be Administrator)

2. Navigate to the WinDAS folder:
   ```powershell
   cd WinDAS
   ```
   (Or wherever you cloned/extracted it)

3. Run this setup command:
   ```powershell
   # Get the full path to WinDAS module
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

   Write-Host "Setup complete! Module will auto-load in new PowerShell sessions." -ForegroundColor Green
   ```

4. **Close and reopen PowerShell** - the module will load automatically from wherever you installed it

---

## How to Use WinDAS

Now that you're set up, here's how to use WinDAS:

### Option 1: Using the PowerShell Module (Easiest)

**If you completed Step 3 above**, you can run WinDAS from any PowerShell window:

```powershell
# Run diagnostics locally on current computer
Invoke-WinDAS
```

That's it! The report will be saved in your current directory.

**More examples:**
```powershell
# Run locally with faster execution (skip disk test)
Invoke-WinDAS -SkipDiskTest

# Run diagnostics on a remote computer
Invoke-WinDAS -ComputerName PC-12345

# Skip disk test on remote (faster, ~30 seconds instead of ~60)
Invoke-WinDAS PC-12345 -SkipDiskTest

# Run on multiple computers
Invoke-WinDAS PC-001, PC-002, PC-003

# Run on computers from a file
Get-Content C:\computers.txt | Invoke-WinDAS
```

**Pro Tip:** Navigate to where you want the report before running:
```powershell
# Save to your Desktop
cd ~\Desktop
Invoke-WinDAS

# Save to a ticket folder
cd C:\ServiceNow\INC0012345
Invoke-WinDAS
```

---

### Option 2: Using the Scripts Directly

**If you skipped Step 3**, you need to import the module manually each time, or use the scripts directly.

**Method 2A: Import module each session**
1. Open PowerShell
2. Navigate to WinDAS folder and import:
   ```powershell
   cd path\to\WinDAS
   Import-Module .\WinDAS.psm1

   # Now you can use Invoke-WinDAS from anywhere
   Invoke-WinDAS PC-12345
   ```

**Method 2B: Run scripts directly**
1. Navigate to WinDAS folder:
   ```powershell
   cd path\to\WinDAS
   ```

2. Run the scripts:
   ```powershell
   # Scan local computer
   .\WinDAS.ps1

   # Scan remote computer
   .\Deploy-WinDAS.ps1 -ComputerName PC-12345 -Execute -RetrieveReport -Cleanup
   ```

---

## Where Are the Reports?

**When using Invoke-WinDAS (recommended):**
Reports are saved in **your current directory** (wherever you ran the command).

**When running WinDAS.ps1 directly:**
Reports are saved in:
```
C:\GitHub\Walmart\WinDAS\Reports\
```

**File name format:**
```
WinDAS_Report_[ComputerName]_[Date-Time].html
```

**Example:**
```
WinDAS_Report_PC-12345_2025-10-21T143022.html
```

**To open a report:** Just double-click the `.html` file - it opens in your web browser.

### Converting to PDF

If you need the report in an alternative format (for sharing where HTML isn't optimal), you can easily convert it to PDF:

1. Open the WinDAS report in Chrome or Edge
2. Press `Ctrl+P` (Print)
3. Select "Save as PDF" as the destination
4. Click Save

The PDF will contain all report content, though interactive features (tabs, search, sorting) will not be functional.

---

## Updating WinDAS

**If you set up the PowerShell module:**

1. Open PowerShell
2. Run:
   ```powershell
   Update-WinDAS
   ```

3. Follow the simple copy-paste instructions shown on screen

**If you're using scripts directly:**

1. Open PowerShell
2. Navigate to WinDAS:
   ```powershell
   cd C:\Tools\WinDAS
   ```

3. Pull the latest updates:
   ```powershell
   git pull
   ```

---

## Quick Reference Card

**Copy this for your notes:**

| Task | Command |
|------|---------|
| **Run on local computer** | `Invoke-WinDAS` |
| **Run locally (faster)** | `Invoke-WinDAS -SkipDiskTest` |
| **Run on remote computer** | `Invoke-WinDAS PC-12345` |
| **Run remote (faster)** | `Invoke-WinDAS PC-12345 -SkipDiskTest` |
| **Run on multiple computers** | `Invoke-WinDAS PC-001, PC-002, PC-003` |
| **Check for updates** | `Update-WinDAS` |
| **Get help** | `Get-Help Invoke-WinDAS -Full` |
| **Save to Desktop** | `cd ~\Desktop; Invoke-WinDAS` |
| **Save to ticket folder** | `cd C:\Tickets\INC123; Invoke-WinDAS` |

---

## Troubleshooting

### "Module not found" when I open PowerShell

**Solution:** The module path might be wrong. Check if WinDAS is really at `C:\Tools\WinDAS`:

```powershell
Test-Path C:\Tools\WinDAS\WinDAS.psm1
```

If it returns `False`, your WinDAS is somewhere else. Find where it is, then edit your profile:

```powershell
notepad $PROFILE
```

Change the path to match where WinDAS actually is.

---

### "Access is denied" when running on remote computer

**Solution:** You need administrator rights on the target computer. Either:
- Use your admin credentials
- Contact the computer's owner
- Use `-Credential` parameter:
  ```powershell
  Invoke-WinDAS PC-12345 -Credential (Get-Credential)
  ```

---

### "WinRM cannot complete the operation"

**Solution:** PowerShell Remoting isn't enabled on the target computer. You need to:
- Remote into the computer manually
- Open PowerShell as Administrator
- Run: `Enable-PSRemoting -Force`

Or contact your network admin to enable it remotely.

---

### "The term 'Invoke-WinDAS' is not recognized"

**Solution:** The module isn't loaded. Run:
```powershell
Import-Module C:\Tools\WinDAS\WinDAS.psm1
```

If this works, the module wasn't added to your profile correctly. Redo Step 3.

---

### "Cannot run scripts" error

**Solution:** PowerShell script execution isn't enabled. Run PowerShell **as Administrator** and run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Type `Y` and press Enter.

---

## Need More Help?

- **Detailed module instructions:** See `MODULE-SETUP.md`
- **All WinDAS features:** See `README.md`
- **Ask your team lead** or IT support

---

## Summary Checklist

Before your first use, make sure you've done:

- [ ] Obtained WinDAS (Git clone or ZIP extract)
- [ ] Enabled PowerShell script execution (`Set-ExecutionPolicy`)
- [ ] Set up the PowerShell module (optional but recommended)
- [ ] Tested it: `Invoke-WinDAS -ComputerName [a-test-computer]`

**Once these are done, you're ready to go!** 🎉

---

**Questions? Contact your team lead or WinDAS administrator.**
