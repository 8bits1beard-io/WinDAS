#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Deploy WinDAS to remote computers via PowerShell remoting

.DESCRIPTION
    Automated deployment script that copies WinDAS to C:\Temp\WinDAS on remote computers.
    Uses PowerShell remoting (PSRemoting/WinRM) to transfer files and optionally execute WinDAS.

.PARAMETER ComputerName
    Name or IP address of the remote computer. Accepts multiple computers via pipeline or comma-separated.

.PARAMETER Credential
    PSCredential object for authentication. If not provided, uses current user context.

.PARAMETER Execute
    If specified, automatically runs WinDAS on the remote computer after deployment.

.PARAMETER SkipDiskTest
    If specified with -Execute, runs WinDAS with -SkipDiskTest parameter for faster execution.

.PARAMETER RetrieveReport
    If specified with -Execute, automatically copies the generated report back to local Reports folder.

.PARAMETER Cleanup
    If specified with -RetrieveReport, removes WinDAS from the remote computer after retrieving the report.

.PARAMETER Port
    WinRM port to use. Default is 5985 (HTTP). Use 5986 for HTTPS.

.PARAMETER UseSSL
    Use HTTPS (port 5986) for PSRemoting connection.

.PARAMETER DestinationPath
    Custom destination path on remote computer. Default is C:\Temp\WinDAS

.EXAMPLE
    .\Deploy-WinDAS.ps1 -ComputerName PC-12345
    Deploys WinDAS to PC-12345 at C:\Temp\WinDAS

.EXAMPLE
    .\Deploy-WinDAS.ps1 -ComputerName PC-12345 -Execute -RetrieveReport
    Deploys, executes WinDAS, and retrieves the report back to local machine

.EXAMPLE
    .\Deploy-WinDAS.ps1 -ComputerName PC-12345 -Execute -SkipDiskTest -RetrieveReport
    Deploys, executes with fast mode (no disk test), and retrieves report

.EXAMPLE
    .\Deploy-WinDAS.ps1 -ComputerName PC-12345 -Execute -RetrieveReport -Cleanup
    Deploys, executes, retrieves report, and removes WinDAS from remote computer

.EXAMPLE
    "PC-12345","PC-67890" | .\Deploy-WinDAS.ps1 -Execute
    Deploys and executes WinDAS on multiple computers

.EXAMPLE
    .\Deploy-WinDAS.ps1 -ComputerName PC-12345 -Credential (Get-Credential)
    Deploys using alternate credentials

.NOTES
    Author: Joshua Walderbach
    Version: 2.1.0
    Requirements:
    - PowerShell 5.1+
    - Administrator privileges
    - WinRM/PSRemoting enabled on target computers
    - Network connectivity to target computers
#>

[CmdletBinding(DefaultParameterSetName = 'Deploy')]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerName,

    [Parameter(Mandatory = $false)]
    [PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [switch]$Execute,

    [Parameter(Mandatory = $false)]
    [switch]$SkipDiskTest,

    [Parameter(Mandatory = $false)]
    [switch]$RetrieveReport,

    [Parameter(Mandatory = $false)]
    [switch]$Cleanup,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 65535)]
    [int]$Port = 5985,

    [Parameter(Mandatory = $false)]
    [switch]$UseSSL,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationPath = "C:\Temp\WinDAS"
)

BEGIN {
    # Script root and source files
    $ScriptRoot = $PSScriptRoot
    if (-not $ScriptRoot) {
        $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    # Validate source files exist
    Write-Host "`n=== WinDAS Remote Deployment Tool ===" -ForegroundColor Cyan
    Write-Host "Version 2.1.0 (Chocolate Milk) | Author: Joshua Walderbach`n" -ForegroundColor Gray

    Write-Host "[>] Validating source files..." -ForegroundColor Cyan

    $RequiredItems = @(
        @{Path = "$ScriptRoot\WinDAS.ps1"; Type = "File"; Description = "Main script"},
        @{Path = "$ScriptRoot\Collectors"; Type = "Directory"; Description = "Collectors folder"},
        @{Path = "$ScriptRoot\Templates"; Type = "Directory"; Description = "Templates folder"}
    )

    $ValidationFailed = $false
    foreach ($item in $RequiredItems) {
        if (Test-Path $item.Path) {
            Write-Host "  [OK] $($item.Description) found" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $($item.Description) not found: $($item.Path)" -ForegroundColor Red
            $ValidationFailed = $true
        }
    }

    if ($ValidationFailed) {
        Write-Host "`n[ERROR] Missing required files. Please run this script from the WinDAS root directory." -ForegroundColor Red
        exit 1
    }

    # Create local Reports directory if RetrieveReport is specified
    if ($RetrieveReport) {
        $LocalReportsPath = "$ScriptRoot\Reports"
        if (-not (Test-Path $LocalReportsPath)) {
            try {
                New-Item -ItemType Directory -Path $LocalReportsPath -Force | Out-Null
                Write-Host "  [OK] Local Reports directory created" -ForegroundColor Green
            } catch {
                Write-Host "  [WARN] Could not create local Reports directory: $_" -ForegroundColor Yellow
            }
        }
    }

    # Ensure Logs directory exists for deployment tracking
    $LocalLogsPath = "$ScriptRoot\Logs"
    if (-not (Test-Path $LocalLogsPath)) {
        try {
            New-Item -ItemType Directory -Path $LocalLogsPath -Force | Out-Null
        } catch {
            Write-Host "  [WARN] Could not create Logs directory: $_" -ForegroundColor Yellow
        }
    }

    # Deployment tracking log file (one per day)
    $Today = Get-Date -Format 'yyyy-MM-dd'
    $DeploymentLogPath = Join-Path $LocalLogsPath "deployed_to_$Today.json"

    # Helper function to log deployments
    function Write-DeploymentLog {
        param(
            [string]$ComputerName,
            [string]$LogPath
        )

        try {
            $timestamp = Get-Date
            $logEntry = [PSCustomObject]@{
                ComputerName = $ComputerName
                Date = $timestamp.ToString('yyyy-MM-dd')
                Time = $timestamp.ToString('HH:mm:ss')
            }

            # Read existing log or create new array
            if (Test-Path $LogPath) {
                $logContent = Get-Content $LogPath -Raw | ConvertFrom-Json
                if ($logContent -is [array]) {
                    $deployments = [System.Collections.ArrayList]@($logContent)
                } else {
                    $deployments = [System.Collections.ArrayList]@($logContent)
                }
            } else {
                $deployments = [System.Collections.ArrayList]@()
            }

            # Add new entry
            $null = $deployments.Add($logEntry)

            # Write back to file
            $deployments | ConvertTo-Json -Depth 3 | Set-Content $LogPath -Force
        } catch {
            Write-Host "  [WARN] Could not write to deployment log: $_" -ForegroundColor Yellow
        }
    }

    # Setup session options
    $SessionParams = @{
        ErrorAction = 'Stop'
    }

    if ($Credential) {
        $SessionParams['Credential'] = $Credential
    }

    if ($UseSSL) {
        $SessionParams['UseSSL'] = $true
        $SessionParams['Port'] = 5986
    } elseif ($Port -ne 5985) {
        $SessionParams['Port'] = $Port
    }

    Write-Host "`n[>] Deployment configuration:" -ForegroundColor Cyan
    Write-Host "    Destination: $DestinationPath" -ForegroundColor Gray
    Write-Host "    Execute WinDAS: $(if($Execute){'Yes'}else{'No'})" -ForegroundColor Gray
    Write-Host "    Skip Disk Test: $(if($SkipDiskTest){'Yes'}else{'No'})" -ForegroundColor Gray
    Write-Host "    Retrieve Report: $(if($RetrieveReport){'Yes'}else{'No'})" -ForegroundColor Gray
    Write-Host "    Cleanup After: $(if($Cleanup){'Yes'}else{'No'})" -ForegroundColor Gray
    Write-Host "    Use SSL: $(if($UseSSL){'Yes'}else{'No'})" -ForegroundColor Gray
    Write-Host "    Port: $($SessionParams['Port'])" -ForegroundColor Gray
    Write-Host ""

    # Statistics
    $Script:Stats = @{
        Total = 0
        Succeeded = 0
        Failed = 0
        Executed = 0
        Retrieved = 0
        CleanedUp = 0
    }

    # Track retrieved reports for opening later
    $Script:RetrievedReports = @()
}

PROCESS {
    foreach ($Computer in $ComputerName) {
        $Script:Stats.Total++

        Write-Host "===============================================================================" -ForegroundColor DarkGray
        Write-Host "Processing: $Computer" -ForegroundColor Cyan
        Write-Host "===============================================================================" -ForegroundColor DarkGray

        # Test connectivity
        Write-Host "`n[1/4] Testing connectivity..." -ForegroundColor Cyan
        if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
            Write-Host "  [FAIL] Computer $Computer is not reachable via ping" -ForegroundColor Red
            $Script:Stats.Failed++
            continue
        }
        Write-Host "  [OK] Computer is reachable" -ForegroundColor Green

        # Establish PS Session
        Write-Host "`n[2/4] Establishing PowerShell session..." -ForegroundColor Cyan
        try {
            $Session = New-PSSession -ComputerName $Computer @SessionParams
            Write-Host "  [OK] Session established (ID: $($Session.Id))" -ForegroundColor Green
        } catch {
            Write-Host "  [FAIL] Could not establish PS Session: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  [HELP] Ensure WinRM is enabled on $Computer" -ForegroundColor Yellow
            Write-Host "         Run on remote: Enable-PSRemoting -Force" -ForegroundColor Yellow
            $Script:Stats.Failed++
            continue
        }

        try {
            # Create destination directory
            Write-Host "`n[3/4] Creating destination directory..." -ForegroundColor Cyan
            Invoke-Command -Session $Session -ScriptBlock {
                param($DestPath)

                # Create directory structure
                if (Test-Path $DestPath) {
                    Write-Host "  [INFO] Destination already exists, will overwrite" -ForegroundColor Yellow
                    Remove-Item -Path $DestPath -Recurse -Force -ErrorAction SilentlyContinue
                }

                New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
                New-Item -ItemType Directory -Path "$DestPath\Collectors" -Force | Out-Null
                New-Item -ItemType Directory -Path "$DestPath\Templates" -Force | Out-Null
                New-Item -ItemType Directory -Path "$DestPath\Reports" -Force | Out-Null
                New-Item -ItemType Directory -Path "$DestPath\Logs" -Force | Out-Null

            } -ArgumentList $DestinationPath
            Write-Host "  [OK] Directory structure created at $DestinationPath" -ForegroundColor Green

            # Copy files
            Write-Host "`n[4/4] Copying WinDAS files..." -ForegroundColor Cyan

            # Copy main script
            Write-Host "  [>] Copying WinDAS.ps1..." -ForegroundColor Gray
            Copy-Item -Path "$ScriptRoot\WinDAS.ps1" -Destination $DestinationPath -ToSession $Session -Force

            # Copy Collectors
            Write-Host "  [>] Copying Collectors..." -ForegroundColor Gray
            $CollectorFiles = Get-ChildItem -Path "$ScriptRoot\Collectors\*.ps1"
            foreach ($file in $CollectorFiles) {
                Copy-Item -Path $file.FullName -Destination "$DestinationPath\Collectors\" -ToSession $Session -Force
            }

            # Copy Templates
            Write-Host "  [>] Copying Templates..." -ForegroundColor Gray
            $TemplateFiles = Get-ChildItem -Path "$ScriptRoot\Templates\*"
            foreach ($file in $TemplateFiles) {
                Copy-Item -Path $file.FullName -Destination "$DestinationPath\Templates\" -ToSession $Session -Force
            }

            Write-Host "  [OK] All files copied successfully" -ForegroundColor Green
            $Script:Stats.Succeeded++

            # Execute WinDAS if requested
            if ($Execute) {
                Write-Host "`n[EXEC] Running WinDAS on remote computer..." -ForegroundColor Cyan

                # Build command line arguments
                $WinDASArgs = "-ExecutionPolicy Bypass -File `"$DestinationPath\WinDAS.ps1`""
                if ($SkipDiskTest) {
                    $WinDASArgs += " -SkipDiskTest"
                }

                try {
                    $ExecutionResult = Invoke-Command -Session $Session -ScriptBlock {
                        param($DestPath, $Arguments)

                        $StartTime = Get-Date
                        Write-Host "  [>] Executing WinDAS..." -ForegroundColor Gray

                        # Execute WinDAS using Start-Process
                        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
                        $ProcessInfo.FileName = "powershell.exe"
                        $ProcessInfo.Arguments = $Arguments
                        $ProcessInfo.UseShellExecute = $false
                        $ProcessInfo.RedirectStandardOutput = $false
                        $ProcessInfo.RedirectStandardError = $false
                        $ProcessInfo.CreateNoWindow = $true
                        $ProcessInfo.WorkingDirectory = $DestPath

                        $Process = New-Object System.Diagnostics.Process
                        $Process.StartInfo = $ProcessInfo
                        $Process.Start() | Out-Null
                        $Process.WaitForExit()

                        $Duration = [math]::Round(((Get-Date) - $StartTime).TotalSeconds, 2)

                        return @{
                            ExitCode = $Process.ExitCode
                            Duration = $Duration
                        }
                    } -ArgumentList $DestinationPath, $WinDASArgs

                    if ($ExecutionResult.ExitCode -eq 0) {
                        Write-Host "  [OK] WinDAS executed successfully ($($ExecutionResult.Duration)s)" -ForegroundColor Green
                        $Script:Stats.Executed++
                    } else {
                        Write-Host "  [WARN] WinDAS exited with code $($ExecutionResult.ExitCode)" -ForegroundColor Yellow
                    }

                    # Retrieve report if requested
                    if ($RetrieveReport) {
                        Write-Host "`n[RETRIEVE] Copying report back to local machine..." -ForegroundColor Cyan

                        # Get the most recent report
                        $RemoteReport = Invoke-Command -Session $Session -ScriptBlock {
                            param($DestPath)
                            Get-ChildItem -Path "$DestPath\Reports\WinDAS_Report_*.html" -ErrorAction SilentlyContinue |
                                Sort-Object LastWriteTime -Descending |
                                Select-Object -First 1
                        } -ArgumentList $DestinationPath

                        if ($RemoteReport) {
                            $LocalReportPath = "$ScriptRoot\Reports\$($RemoteReport.Name)"
                            Copy-Item -Path $RemoteReport.FullName -Destination $LocalReportPath -FromSession $Session -Force
                            Write-Host "  [OK] Report retrieved: $($RemoteReport.Name)" -ForegroundColor Green
                            Write-Host "  [INFO] Saved to: $LocalReportPath" -ForegroundColor Cyan
                            $Script:Stats.Retrieved++

                            # Add to list of retrieved reports for opening later
                            $Script:RetrievedReports += $LocalReportPath

                            # Cleanup if requested
                            if ($Cleanup) {
                                Write-Host "`n[CLEANUP] Removing WinDAS from remote computer..." -ForegroundColor Cyan
                                try {
                                    Invoke-Command -Session $Session -ScriptBlock {
                                        param($DestPath)

                                        if (Test-Path $DestPath) {
                                            Remove-Item -Path $DestPath -Recurse -Force -ErrorAction Stop
                                            Write-Host "  [OK] WinDAS directory removed" -ForegroundColor Green
                                        } else {
                                            Write-Host "  [INFO] Directory already removed" -ForegroundColor Gray
                                        }
                                    } -ArgumentList $DestinationPath

                                    $Script:Stats.CleanedUp++
                                    Write-Host "  [OK] Cleanup completed successfully" -ForegroundColor Green
                                } catch {
                                    Write-Host "  [WARN] Cleanup failed: $($_.Exception.Message)" -ForegroundColor Yellow
                                    Write-Host "  [INFO] You may need to manually remove: $DestinationPath" -ForegroundColor Yellow
                                }
                            }
                        } else {
                            Write-Host "  [WARN] No report found in $DestinationPath\Reports\" -ForegroundColor Yellow
                        }
                    }

                } catch {
                    Write-Host "  [FAIL] Error executing WinDAS: $($_.Exception.Message)" -ForegroundColor Red
                }
            }

            Write-Host "`n[SUCCESS] Deployment to $Computer completed successfully" -ForegroundColor Green

            # Log successful deployment
            Write-DeploymentLog -ComputerName $Computer -LogPath $DeploymentLogPath

        } catch {
            Write-Host "`n[FAIL] Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
            $Script:Stats.Failed++
        } finally {
            # Clean up session
            if ($Session) {
                Remove-PSSession -Session $Session -ErrorAction SilentlyContinue
            }
        }

        Write-Host ""
    }
}

END {
    Write-Host "===============================================================================" -ForegroundColor DarkGray
    Write-Host "Deployment Summary" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor DarkGray
    Write-Host "  Total Computers:    $($Script:Stats.Total)" -ForegroundColor White
    Write-Host "  Deployed:           $($Script:Stats.Succeeded)" -ForegroundColor Green
    Write-Host "  Failed:             $($Script:Stats.Failed)" -ForegroundColor $(if($Script:Stats.Failed -gt 0){'Red'}else{'Green'})
    if ($Execute) {
        Write-Host "  Executed:           $($Script:Stats.Executed)" -ForegroundColor Cyan
    }
    if ($RetrieveReport) {
        Write-Host "  Reports Retrieved:  $($Script:Stats.Retrieved)" -ForegroundColor Cyan
    }
    if ($Cleanup) {
        Write-Host "  Cleaned Up:         $($Script:Stats.CleanedUp)" -ForegroundColor Cyan
    }
    Write-Host "===============================================================================" -ForegroundColor DarkGray
    Write-Host ""

    if ($Script:Stats.Failed -eq 0) {
        Write-Host "All deployments completed successfully! " -ForegroundColor Green
    } else {
        Write-Host "Some deployments failed. See output above for details." -ForegroundColor Yellow
    }
    Write-Host ""

    # Prompt to open retrieved reports
    if ($Script:RetrievedReports.Count -gt 0) {
        Write-Host "===============================================================================" -ForegroundColor DarkGray
        Write-Host "Retrieved Reports ($($Script:RetrievedReports.Count))" -ForegroundColor Cyan
        Write-Host "===============================================================================" -ForegroundColor DarkGray

        foreach ($reportPath in $Script:RetrievedReports) {
            $fileName = Split-Path -Leaf $reportPath
            Write-Host "  - $fileName" -ForegroundColor White
        }
        Write-Host ""

        # Prompt user
        $response = Read-Host "Would you like to open the report(s) now? (Y/N)"

        if ($response -match '^[Yy]') {
            Write-Host ""
            foreach ($reportPath in $Script:RetrievedReports) {
                if (Test-Path $reportPath) {
                    Write-Host "  [>] Opening: $(Split-Path -Leaf $reportPath)" -ForegroundColor Cyan
                    try {
                        Start-Process $reportPath
                    } catch {
                        Write-Host "  [WARN] Could not open report: $_" -ForegroundColor Yellow
                    }
                }
            }
            Write-Host "  [OK] Report(s) opened in default browser" -ForegroundColor Green
        } else {
            Write-Host ("  Reports saved in: {0}" -f (Join-Path $ScriptRoot 'Reports')) -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($Script:Stats.Failed -eq 0) {
        exit 0
    } else {
        exit 1
    }
}


