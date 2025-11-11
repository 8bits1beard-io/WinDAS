# WinDAS PowerShell Module
# Version: 2.1.0
# Simplifies remote deployment of WinDAS diagnostics

# Module-level variables
$script:ModuleVersion = "2.1.0"
$script:ModuleRoot = $PSScriptRoot

<#
.SYNOPSIS
    Runs WinDAS diagnostics on local or remote computers.

.DESCRIPTION
    Invoke-WinDAS simplifies running WinDAS diagnostics.

    When run WITHOUT a computer name, it executes WinDAS locally on the current machine.
    When run WITH a computer name, it deploys and runs WinDAS on remote computers.

    For remote computers, by default it will:
    - Deploy WinDAS to the remote computer
    - Execute the diagnostic scan
    - Retrieve the HTML report
    - Clean up files from the remote computer

.PARAMETER ComputerName
    The name or IP address of the remote computer(s) to diagnose.
    If omitted, runs WinDAS locally on the current computer.
    Accepts multiple computers and pipeline input.

.PARAMETER SkipDiskTest
    Skip the disk speed test for faster execution (~30s vs ~60s).

.PARAMETER NoExecute
    (Remote only) Deploy files only, don't run WinDAS. Use with -KeepFiles for manual execution.

.PARAMETER KeepFiles
    (Remote only) Don't clean up WinDAS files from remote computer after execution.

.EXAMPLE
    Invoke-WinDAS

    Runs WinDAS locally on the current computer.

.EXAMPLE
    Invoke-WinDAS -SkipDiskTest

    Runs WinDAS locally with faster execution (skips disk speed test).

.EXAMPLE
    Invoke-WinDAS -ComputerName PC-12345

    Runs full WinDAS diagnostic on remote PC-12345, retrieves report, and cleans up.

.EXAMPLE
    Invoke-WinDAS PC-12345 -SkipDiskTest

    Runs WinDAS on remote PC-12345 with faster execution (skips disk speed test).

.EXAMPLE
    "PC-001", "PC-002", "PC-003" | Invoke-WinDAS

    Runs WinDAS on multiple remote computers via pipeline.

.EXAMPLE
    Get-Content computers.txt | Invoke-WinDAS -SkipDiskTest

    Runs WinDAS on all computers listed in a text file.

.EXAMPLE
    Invoke-WinDAS PC-12345 -NoExecute -KeepFiles

    Deploys WinDAS files only to remote computer, doesn't execute. Useful for manual troubleshooting.

.NOTES
    Local execution: No special requirements
    Remote execution: Requires PowerShell remoting enabled on target computers
    Administrator privileges recommended for full diagnostic data.
#>
function Invoke-WinDAS {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $false,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Computer name or IP address to diagnose (omit for local execution)"
        )]
        [Alias('Computer', 'CN', 'Name', 'PSComputerName')]
        [string[]]$ComputerName,

        [Parameter(HelpMessage = "Skip disk speed test for faster execution")]
        [switch]$SkipDiskTest,

        [Parameter(HelpMessage = "Deploy files only, don't execute WinDAS (remote only)")]
        [switch]$NoExecute,

        [Parameter(HelpMessage = "Don't clean up files from remote computer (remote only)")]
        [switch]$KeepFiles
    )

    begin {
        Write-Host "`nWinDAS Module v$script:ModuleVersion" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan

        # Check if this is local execution
        $isLocal = -not $ComputerName

        if ($isLocal) {
            # Local execution - check for WinDAS.ps1
            $windasScript = Join-Path $script:ModuleRoot "WinDAS.ps1"
            if (-not (Test-Path $windasScript)) {
                Write-Error "WinDAS.ps1 not found at: $windasScript"
                Write-Error "Ensure the WinDAS module is in the correct directory."
                return
            }
        } else {
            # Remote execution - check for Deploy-WinDAS.ps1
            $deployScript = Join-Path $script:ModuleRoot "Deploy-WinDAS.ps1"
            if (-not (Test-Path $deployScript)) {
                Write-Error "Deploy-WinDAS.ps1 not found at: $deployScript"
                Write-Error "Ensure the WinDAS module is in the correct directory."
                return
            }
        }
    }

    process {
        # Local execution
        if (-not $ComputerName) {
            Write-Host "Running WinDAS locally on $env:COMPUTERNAME" -ForegroundColor Yellow

            $windasScript = Join-Path $script:ModuleRoot "WinDAS.ps1"

            # Use current directory as output path
            $currentPath = Get-Location | Select-Object -ExpandProperty Path

            try {
                if ($SkipDiskTest) {
                    & $windasScript -SkipDiskTest -OutputPath $currentPath
                } else {
                    & $windasScript -OutputPath $currentPath
                }
            }
            catch {
                Write-Error "Failed to execute WinDAS locally: $_"
            }

            return
        }

        # Remote execution
        foreach ($computer in $ComputerName) {
            Write-Host "Processing remote computer: $computer" -ForegroundColor Yellow

            $deployScript = Join-Path $script:ModuleRoot "Deploy-WinDAS.ps1"

            # Build parameter hashtable
            $params = @{
                ComputerName = $computer
                Execute = $true
                RetrieveReport = $true
                Cleanup = $true
            }

            # Apply user switches
            if ($NoExecute) {
                $params.Execute = $false
                $params.RetrieveReport = $false
            }

            if ($KeepFiles) {
                $params.Cleanup = $false
            }

            if ($SkipDiskTest) {
                $params.SkipDiskTest = $true
            }

            # Call Deploy-WinDAS.ps1
            try {
                & $deployScript @params
            }
            catch {
                Write-Error "Failed to process $computer : $_"
            }

            Write-Host ""
        }
    }

    end {
        if ($ComputerName) {
            Write-Host "WinDAS remote deployment complete!" -ForegroundColor Green
        } else {
            Write-Host "`nWinDAS local execution complete!" -ForegroundColor Green
        }
    }
}

<#
.SYNOPSIS
    Checks for WinDAS updates and provides simple update instructions.

.DESCRIPTION
    Update-WinDAS checks if your local WinDAS is out of date compared to the
    latest version on GitHub. If updates are available, it provides simple
    copy-paste instructions to update.

.PARAMETER Force
    Skip the check and show update instructions immediately.

.EXAMPLE
    Update-WinDAS

    Checks for updates and shows instructions if updates are available.

.EXAMPLE
    Update-WinDAS -Force

    Shows update instructions without checking version.

.NOTES
    Requires Git to be installed and the WinDAS directory to be a Git repository.
#>
function Update-WinDAS {
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = "Show update instructions without checking version")]
        [switch]$Force
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "WinDAS Update Check" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Check if we're in a Git repository
    Push-Location $script:ModuleRoot
    $isGitRepo = Test-Path (Join-Path $script:ModuleRoot ".git")

    if (-not $isGitRepo) {
        Write-Warning "WinDAS is not in a Git repository."
        Write-Host "`nTo enable updates, clone WinDAS from Git:" -ForegroundColor Yellow
        Write-Host "  1. Open PowerShell" -ForegroundColor White
        Write-Host "  2. Navigate to your desired location: cd C:\Tools" -ForegroundColor White
        Write-Host "  3. Clone the repository (contact your admin for the Git URL)" -ForegroundColor White
        Pop-Location
        return
    }

    # Check if Git is available
    try {
        $null = git --version 2>$null
    }
    catch {
        Write-Warning "Git is not installed or not in PATH."
        Write-Host "`nTo update WinDAS, you need Git installed." -ForegroundColor Yellow
        Write-Host "Contact your IT administrator for assistance." -ForegroundColor Yellow
        Pop-Location
        return
    }

    if (-not $Force) {
        # Fetch latest changes (doesn't modify files)
        Write-Host "Checking for updates..." -ForegroundColor Cyan
        try {
            git fetch origin 2>&1 | Out-Null
        }
        catch {
            Write-Warning "Could not connect to Git server. Check network connection."
            Pop-Location
            return
        }

        # Check how many commits behind we are
        try {
            $behind = git rev-list HEAD..origin/main --count 2>$null
            if (-not $behind) { $behind = 0 }
        }
        catch {
            Write-Warning "Could not check version. Assuming update needed."
            $behind = 1
        }

        if ($behind -eq 0) {
            Write-Host "[OK] WinDAS is up to date!" -ForegroundColor Green
            Write-Host "  Current version: $script:ModuleVersion`n" -ForegroundColor Gray
            Pop-Location
            return
        }

        Write-Host "[!] Updates available! ($behind new update(s))" -ForegroundColor Yellow
    }

    # Show simple update instructions
    Write-Host "`n" -NoNewline
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "HOW TO UPDATE WINDAS" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

    Write-Host "`nFollow these steps:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. " -NoNewline -ForegroundColor Yellow
    Write-Host "Copy this command:" -ForegroundColor White
    Write-Host ""
    Write-Host "     cd `"$script:ModuleRoot`"" -ForegroundColor Green
    Write-Host ""

    Write-Host "  2. " -NoNewline -ForegroundColor Yellow
    Write-Host "Paste and press Enter in PowerShell" -ForegroundColor White
    Write-Host ""

    Write-Host "  3. " -NoNewline -ForegroundColor Yellow
    Write-Host "Copy this command:" -ForegroundColor White
    Write-Host ""
    Write-Host "     git pull" -ForegroundColor Green
    Write-Host ""

    Write-Host "  4. " -NoNewline -ForegroundColor Yellow
    Write-Host "Paste and press Enter in PowerShell" -ForegroundColor White
    Write-Host ""

    Write-Host "  5. " -NoNewline -ForegroundColor Yellow
    Write-Host "Reload the module:" -ForegroundColor White
    Write-Host ""
    Write-Host "     Import-Module WinDAS -Force" -ForegroundColor Green
    Write-Host ""

    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "`nThat's it! WinDAS will be updated.`n" -ForegroundColor Gray

    Pop-Location
}

# Module initialization
Write-Host "WinDAS Module v$script:ModuleVersion loaded" -ForegroundColor Green
Write-Host "Use 'Get-Help Invoke-WinDAS -Full' for usage information" -ForegroundColor Gray
Write-Host "Use 'Update-WinDAS' to check for updates`n" -ForegroundColor Gray

# Export module members
Export-ModuleMember -Function Invoke-WinDAS, Update-WinDAS
