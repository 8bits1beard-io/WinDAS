#Requires -Version 5.1
<#
.SYNOPSIS
    WinDAS - Windows Diagnostic Assessment Suite Main Orchestrator

.DESCRIPTION
    Comprehensive Windows system analysis tool with parallel collection capabilities.
    Collects system health data including integrity assessment and generates an interactive HTML report.

.NOTES
    Author: Joshua Walderbach
    Version: 2.1.0

.PARAMETER Logs
    Enable detailed logging to file in the Logs directory

.PARAMETER SkipDiskTest
    Skip the disk speed test (100MB read/write benchmark) to improve performance on slow systems

.EXAMPLE
    .\WinDAS.ps1
    Runs complete analysis and opens report in default browser

.EXAMPLE
    .\WinDAS.ps1 -SkipDiskTest
    Runs analysis without the disk speed test for faster execution

.EXAMPLE
    .\WinDAS.ps1 -Logs
    Runs with detailed logging enabled
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Logs,  # Enable logging to file

    [Parameter(Mandatory=$false)]
    [switch]$SkipDiskTest,  # Skip the slow disk speed test in hardware collector

    [Parameter(Mandatory=$false)]
    [string]$OutputPath  # Custom output path for report (defaults to Reports folder in script root)
)

#region INITIALIZATION SECTION

# Set Global Preferences for cleaner output
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'

# Script timing
$script:StartTime = Get-Date
$script:ScriptRoot = $PSScriptRoot
$script:LoggingEnabled = $Logs

# Ensure Logs directory exists (always needed for run log)
if (-not (Test-Path "$PSScriptRoot\Logs")) {
    New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force | Out-Null
}

# Setup logging if enabled
if ($script:LoggingEnabled) {
    $script:LogFile = Join-Path $PSScriptRoot "Logs\WinDAS_$(Get-Date -Format 'yyyyMMddTHHmmss').log"
} else {
    $script:LogFile = $null
}

# Initialize run log tracking (always enabled)
$script:RunLog = [PSCustomObject]@{
    ComputerName = $env:COMPUTERNAME
    Date = (Get-Date).ToString('yyyy-MM-dd')
    Time = (Get-Date).ToString('HH:mm:ss')
    Collectors = @{}
    HTMLGeneration = $null
}

# Enhanced Logging function with verbose details
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "Main",
        [object]$Data = $null
    )
    
    # Always log to file if logging is enabled
    if ($script:LoggingEnabled -and $script:LogFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = "[$timestamp] [$Level] [$Component] $Message"
        
        # Add data details if provided
        if ($Data) {
            $dataString = $Data | ConvertTo-Json -Compress -Depth 3 -ErrorAction SilentlyContinue
            if ($dataString) {
                $logEntry += " | Data: $dataString"
            }
        }
        
        Add-Content -Path $script:LogFile -Value $logEntry -Force
    }
    
    # Console output based on level (simplified for user)
    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "DEBUG" { 
            if ($VerbosePreference -eq 'Continue') {
                Write-Verbose "${Component}: $Message"
            }
        }
        "VERBOSE" {
            # Only write to log file, not console
        }
        default { 
            if ($Level -ne "VERBOSE") {
                Write-Host $Message -ForegroundColor Cyan
            }
        }
    }
}

# Make logging function available globally for collectors
$Global:WriteLog = Get-Command Write-Log
$Global:LoggingEnabled = $script:LoggingEnabled

Write-Log "WinDAS Starting - Version 2.1.0 (Chocolate Milk)" "INFO"
Write-Log "Script Root: $script:ScriptRoot" "INFO"
if ($script:LoggingEnabled) {
    Write-Log "Log File: $script:LogFile" "INFO"
}

# Check for Administrator privileges
$script:isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $script:isAdmin) {
    Write-Host "`n⚠ WARNING: Running without Administrator privileges" -ForegroundColor Yellow
    Write-Host "  Some data collection may be limited or unavailable." -ForegroundColor Yellow
    Write-Host "  For complete analysis, run PowerShell as Administrator.`n" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

# Display Banner
function Show-Banner {
    Write-Host "`nWinDAS - Windows Diagnostic Assessment Suite v2.1.0" -ForegroundColor Cyan
    Write-Host "Author: Joshua Walderbach" -ForegroundColor Gray
    Write-Host ("=" * 50) -ForegroundColor DarkGray
    Write-Host "`nCollection started at: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')" -ForegroundColor Gray
    Write-Host "Computer: $env:COMPUTERNAME | User: $env:USERNAME | Admin: $(if($script:isAdmin){'Yes'}else{'No'})" -ForegroundColor Gray
    Write-Host ("=" * 50) -ForegroundColor DarkGray
    Write-Host ""
}

Clear-Host
Show-Banner

# Set Output Path - use custom path if provided, otherwise default to Reports folder
if ($OutputPath) {
    $script:OutputPath = $OutputPath
} else {
    $script:OutputPath = Join-Path $script:ScriptRoot "Reports"
}

# Create Output Directory if it doesn't exist
if (-not (Test-Path $script:OutputPath)) {
    try {
        New-Item -ItemType Directory -Path $script:OutputPath -Force | Out-Null
        Write-Host "[OK] Created output directory: $script:OutputPath" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Failed to create output directory: $_" -ForegroundColor Red
        Write-Host "    Exiting..." -ForegroundColor Red
        exit 1
    }
}

#endregion

#region SETUP SECTION

# Load All Collectors
Write-Host "`nLoading collector modules..." -ForegroundColor Cyan
$script:CollectorsPath = Join-Path $script:ScriptRoot "Collectors"
$collectorFiles = Get-ChildItem -Path "$script:CollectorsPath\*.ps1" -ErrorAction SilentlyContinue

if ($collectorFiles.Count -eq 0) {
    Write-Host "[FAIL] No collector files found in $script:CollectorsPath" -ForegroundColor Red
    exit 1
}

foreach ($file in $collectorFiles) {
    try {
        Write-Host "  [>] Loading $($file.Name)..." -ForegroundColor Gray -NoNewline
        . $file.FullName
        Write-Host "`r  [OK] Loaded $($file.Name)    " -ForegroundColor Green
    } catch {
        Write-Host "`r  [FAIL] Failed to load $($file.Name): $_" -ForegroundColor Red
    }
}

# Initialize Data Structure
$script:systemData = @{
    CollectionTimestamp = $script:StartTime.ToUniversalTime().ToString('o')  # For easy access by template
    Metadata = @{
        ComputerName = $env:COMPUTERNAME
        DomainName = $env:USERDNSDOMAIN
        UserName = $env:USERNAME
        IsAdmin = $script:isAdmin
        CollectionStartTime = $script:StartTime.ToString('yyyy-MM-ddTHH:mm:ss')
        CollectionTimestamp = $script:StartTime.ToUniversalTime().ToString('o')  # ISO 8601 format for JavaScript
        CollectionEndTime = $null
        CollectionDuration = $null
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        OSVersion = [System.Environment]::OSVersion.VersionString
        CollectorVersion = "2.1.0"
    }
    OS = @{}
    Hardware = @{}
    Network = @{}
    Software = @{}
    Drivers = @{}
    Browsers = @{}
    Printers = @{}
}

# Check for Parallel Support
Write-Host "`nChecking parallel execution support..." -ForegroundColor Cyan
$script:useParallel = $false

try {
    $testJob = Start-Job -ScriptBlock { "test" } -ErrorAction Stop
    $null = Wait-Job -Job $testJob -Timeout 2
    Remove-Job -Job $testJob -Force
    $script:useParallel = $true
    Write-Host "[OK] Parallel execution available" -ForegroundColor Green
} catch {
    Write-Host "[!] Parallel execution not available - will run sequentially" -ForegroundColor Yellow
}

#endregion

#region DATA COLLECTION SECTION

# Initialize CIM Session and Cache
Write-Host "`nInitializing data collection session..." -ForegroundColor Cyan
Write-Log "Initializing CIM session and cache" -Level "INFO" -Component "Main"
$script:cimAvailable = $true

$initResult = Initialize-DataCollection -ComputerName $env:COMPUTERNAME

if ($initResult.Success) {
    Write-Host "[OK] CIM session initialized successfully" -ForegroundColor Green
    Write-Log "CIM session initialized successfully" -Level "SUCCESS" -Component "Main"
} else {
    Write-Host "[!] CIM initialization failed - using direct CIM queries" -ForegroundColor Yellow
    Write-Log "CIM initialization failed - using direct CIM queries" -Level "WARNING" -Component "Main"
    if ($initResult.WinRMStatus) {
        Write-Host "    WinRM Status: $($initResult.WinRMStatus)" -ForegroundColor Gray
    }
    if ($initResult.WinRMDetails -and $initResult.WinRMDetails.ConfigError) {
        Write-Host "    Config: $($initResult.WinRMDetails.ConfigError)" -ForegroundColor Gray
    }
    $script:cimAvailable = $false
}

# Collect Common Data (Sequential - Required First)
Write-Host "`nPhase 1: Collecting common system data..." -ForegroundColor Cyan
Write-Log "Starting Phase 1: Common data collection" -Level "INFO" -Component "Main"
$commonStartTime = Get-Date

try {
    Get-CommonData
    $commonDuration = [math]::Round(((Get-Date) - $commonStartTime).TotalSeconds, 2)
    Write-Host "[OK] Common data collected ($commonDuration seconds)" -ForegroundColor Green
    Write-Log "Common data collected successfully in $commonDuration seconds" -Level "SUCCESS" -Component "Main"
} catch {
    Write-Host "[FAIL] Failed to collect common data: $_" -ForegroundColor Red
    Write-Host "    Some collectors may have limited functionality" -ForegroundColor Yellow
    Write-Log "Failed to collect common data: $_" -Level "ERROR" -Component "Main"
}

#endregion

#region PARALLEL COLLECTION IMPLEMENTATION

if ($script:useParallel) {
    Write-Host "`nPhase 2: Running parallel collection..." -ForegroundColor Cyan
    Write-Host "  Starting background jobs for all collectors..." -ForegroundColor Gray
    Write-Log "Starting Phase 2: Parallel collection with background jobs" -Level "INFO" -Component "Main"
    
    $jobs = @()
    $jobStartTime = Get-Date
    
    # Prepare cache collections for jobs (serialize the data)
    # Convert CIM objects to PSCustomObjects for proper serialization
    $cacheCollections = @{}
    if ($Global:DataCache -and $Global:DataCache.Collections) {
        foreach ($key in $Global:DataCache.Collections.Keys) {
            $cacheItem = $Global:DataCache.Collections[$key]
            
            # Get the actual data from the cache structure
            $collection = $cacheItem.Data
            
            if ($collection) {
                # Convert CIM instances to PSCustomObjects for serialization
                if ($collection -is [Array] -and $collection.Count -gt 0 -and $collection[0].CimClass) {
                    # This is a CIM instance collection, convert to PSCustomObject
                    $converted = @()
                    foreach ($item in $collection) {
                        $props = @{}
                        foreach ($prop in $item.CimInstanceProperties) {
                            $props[$prop.Name] = $prop.Value
                        }
                        $converted += [PSCustomObject]$props
                    }
                    $cacheCollections[$key] = $converted
                } else {
                    # Already a PSCustomObject or other serializable type
                    $cacheCollections[$key] = $collection
                }
            } else {
                # No data available (failed collection)
                $cacheCollections[$key] = $null
            }
        }
    }
    
    # Pass logging configuration to jobs
    $loggingConfig = @{
        Enabled = $script:LoggingEnabled
        LogFile = $script:LogFile
    }
    
    # Group A Jobs (Independent - No dependencies) 
    $jobs += Start-Job -Name "Network" -ScriptBlock {
        param($scriptRoot, $loggingConfig)
        $ErrorActionPreference = 'SilentlyContinue'
        
        # Setup logging in job context
        $Global:LoggingEnabled = $loggingConfig.Enabled
        if ($loggingConfig.Enabled) {
            $Global:WriteLog = {
                param($Message, $Level="INFO", $Component="Job", $Data=$null)
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                $logEntry = "[$timestamp] [$Level] [$Component] $Message"
                if ($Data) {
                    $dataString = $Data | ConvertTo-Json -Compress -Depth 3 -ErrorAction SilentlyContinue
                    if ($dataString) {
                        $logEntry += " | Data: $dataString"
                    }
                }
                Add-Content -Path $loggingConfig.LogFile -Value $logEntry -Force
            }
        }
        
        # Define stub functions for job context
        function Write-ProgressStatus {
            param(
                [string]$Activity,
                [string]$Status = "",
                [int]$PercentComplete = -1,
                [switch]$Completed,
                [string]$Component = "Collector"
            )
            # Silent in background jobs, but log if enabled
            if ($Global:LoggingEnabled -and $Global:WriteLog) {
                if ($Completed) {
                    & $Global:WriteLog -Message "$Activity - Completed" -Level "VERBOSE" -Component $Component
                } else {
                    $logMessage = $Activity
                    if ($Status) { $logMessage += " - $Status" }
                    if ($PercentComplete -ge 0) { $logMessage += " ($PercentComplete%)" }
                    & $Global:WriteLog -Message $logMessage -Level "VERBOSE" -Component $Component
                }
            }
        }
        
        function Get-CachedData {
            param([string]$ClassName)
            # Network collector will query directly instead of using cache
            # Return null to trigger direct queries
            return $null
        }
        
        # Load collector modules
        . (Join-Path $scriptRoot "Collectors\Common-Functions.ps1")
        . (Join-Path $scriptRoot "Collectors\Get-NetworkData.ps1")
        
        Get-NetworkData
    } -ArgumentList $script:ScriptRoot, $loggingConfig
    
    $jobs += Start-Job -Name "Browsers" -ScriptBlock {
        param($scriptRoot, $loggingConfig)
        $ErrorActionPreference = 'SilentlyContinue'
        
        # Setup logging in job context
        $Global:LoggingEnabled = $loggingConfig.Enabled
        if ($loggingConfig.Enabled) {
            $Global:WriteLog = {
                param($Message, $Level="INFO", $Component="Job", $Data=$null)
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                $logEntry = "[$timestamp] [$Level] [$Component] $Message"
                if ($Data) {
                    $dataString = $Data | ConvertTo-Json -Compress -Depth 3 -ErrorAction SilentlyContinue
                    if ($dataString) { $logEntry += " | Data: $dataString" }
                }
                Add-Content -Path $loggingConfig.LogFile -Value $logEntry -Force
            }
        }
        
        . (Join-Path $scriptRoot "Collectors\Common-Functions.ps1")
        . (Join-Path $scriptRoot "Collectors\Get-BrowserData.ps1")
        Get-BrowserData
    } -ArgumentList $script:ScriptRoot, $loggingConfig
    
    $jobs += Start-Job -Name "Events" -ScriptBlock {
        param($scriptRoot, $loggingConfig)
        $ErrorActionPreference = 'SilentlyContinue'
        
        # Setup logging in job context
        $Global:LoggingEnabled = $loggingConfig.Enabled
        if ($loggingConfig.Enabled) {
            $Global:WriteLog = {
                param($Message, $Level="INFO", $Component="Job", $Data=$null)
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                $logEntry = "[$timestamp] [$Level] [$Component] $Message"
                if ($Data) {
                    $dataString = $Data | ConvertTo-Json -Compress -Depth 3 -ErrorAction SilentlyContinue
                    if ($dataString) { $logEntry += " | Data: $dataString" }
                }
                Add-Content -Path $loggingConfig.LogFile -Value $logEntry -Force
            }
        }
        
        . (Join-Path $scriptRoot "Collectors\Common-Functions.ps1")
        . (Join-Path $scriptRoot "Collectors\Get-EventData.ps1")
        Get-EventData
    } -ArgumentList $script:ScriptRoot, $loggingConfig
    
    $jobs += Start-Job -Name "Printers" -ScriptBlock {
        param($scriptRoot)
        $ErrorActionPreference = 'SilentlyContinue'
        
        # Define Get-CachedData function
        function Get-CachedData {
            param([string]$ClassName)
            # Printers collector will query directly instead of using cache
            # Return null to trigger direct queries
            return $null
        }
        
        # Load collector modules
        . (Join-Path $scriptRoot "Collectors\Common-Functions.ps1")
        . (Join-Path $scriptRoot "Collectors\Get-PrinterData.ps1")
        
        Get-PrinterData
    } -ArgumentList $script:ScriptRoot
    
    # Group B Jobs (Cache-dependent but independent of each other)
    $jobs += Start-Job -Name "OS" -ScriptBlock {
        param($scriptRoot, $cacheCollections)
        $ErrorActionPreference = 'SilentlyContinue'
        
        $Global:DataCache = @{
            Collections = $cacheCollections
        }
        
        
        # Define Get-CachedData function
        function Get-CachedData {
            param([string]$ClassName)
            if ($Global:DataCache -and $Global:DataCache.Collections -and $Global:DataCache.Collections.ContainsKey($ClassName)) {
                return $Global:DataCache.Collections[$ClassName]
            }
            return $null
        }
        
        # Load collector modules
        . (Join-Path $scriptRoot "Collectors\Common-Functions.ps1")
        . (Join-Path $scriptRoot "Collectors\Get-OSData.ps1")
        
        Get-OSData
    } -ArgumentList $script:ScriptRoot, $cacheCollections
    
    $jobs += Start-Job -Name "Hardware" -ScriptBlock {
        param($scriptRoot, $cacheCollections, $skipDiskTest)
        $ErrorActionPreference = 'SilentlyContinue'

        $Global:DataCache = @{
            Collections = $cacheCollections
        }


        # Define Get-CachedData function
        function Get-CachedData {
            param([string]$ClassName)
            if ($Global:DataCache -and $Global:DataCache.Collections -and $Global:DataCache.Collections.ContainsKey($ClassName)) {
                # Check if it has .Data property or is the data itself
                $cached = $Global:DataCache.Collections[$ClassName]
                if ($cached -is [PSCustomObject] -and $cached.PSObject.Properties['Data']) {
                    return $cached.Data
                } else {
                    return $cached
                }
            }
            return $null
        }

        # Load collector modules
        . (Join-Path $scriptRoot "Collectors\Common-Functions.ps1")
        . (Join-Path $scriptRoot "Collectors\Get-HardwareData.ps1")

        Get-HardwareData -SkipDiskTest $skipDiskTest
    } -ArgumentList $script:ScriptRoot, $cacheCollections, $SkipDiskTest.IsPresent
    
    $jobs += Start-Job -Name "Software" -ScriptBlock {
        param($scriptRoot, $cacheCollections)
        $ErrorActionPreference = 'SilentlyContinue'
        
        $Global:DataCache = @{
            Collections = $cacheCollections
        }
        
        
        # Define Get-CachedData function
        function Get-CachedData {
            param([string]$ClassName)
            if ($Global:DataCache -and $Global:DataCache.Collections -and $Global:DataCache.Collections.ContainsKey($ClassName)) {
                return $Global:DataCache.Collections[$ClassName]
            }
            return $null
        }
        
        # Load collector modules
        . (Join-Path $scriptRoot "Collectors\Common-Functions.ps1")
        . (Join-Path $scriptRoot "Collectors\Get-SoftwareData.ps1")
        
        Get-SoftwareData
    } -ArgumentList $script:ScriptRoot, $cacheCollections
    
    $jobs += Start-Job -Name "Drivers" -ScriptBlock {
        param($scriptRoot, $cacheCollections)
        $ErrorActionPreference = 'SilentlyContinue'
        
        $Global:DataCache = @{
            Collections = $cacheCollections
        }
        
        
        # Define Get-CachedData function
        function Get-CachedData {
            param([string]$ClassName)
            if ($Global:DataCache -and $Global:DataCache.Collections -and $Global:DataCache.Collections.ContainsKey($ClassName)) {
                return $Global:DataCache.Collections[$ClassName]
            }
            return $null
        }
        
        # Load collector modules
        . (Join-Path $scriptRoot "Collectors\Common-Functions.ps1")
        . (Join-Path $scriptRoot "Collectors\Get-DriverData.ps1")
        
        Get-DriverData
    } -ArgumentList $script:ScriptRoot, $cacheCollections
    
    $totalJobsStarted = $jobs.Count
    Write-Log "[OK] Started $totalJobsStarted parallel collectors" "SUCCESS"
    foreach ($job in $jobs) {
        Write-Log "Started job: $($job.Name) (ID: $($job.Id))" "DEBUG"
    }
    
    # Monitor Job Progress
    # Define per-collector timeouts (seconds)
    $collectorTimeouts = @{
        'OS' = 300
        'Hardware' = 120
        'Network' = 120
        'Software' = 120
        'Printers' = 120
        'Drivers' = 120
        'Browsers' = 120
        'Events' = 120
    }
    $defaultTimeout = 120  # fallback for any unlisted collectors
    $completed = 0
    $failed = 0
    
    Write-Host "`n  Monitoring progress (per-collector timeouts: OS=300s, Others=120s)..." -ForegroundColor Gray
    
    $monitorStartTime = Get-Date
    $maxWaitTime = ($collectorTimeouts.Values | Measure-Object -Maximum).Maximum * $jobs.Count  # Total max wait time
    
    # Track which jobs have been stopped to avoid repeated messages
    $stoppedJobs = @{}
    
    # Track last status to avoid redundant displays
    $lastRunning = -1
    $lastCompleted = -1
    $lastFailed = -1
    
    while ($jobs | Where-Object { $_.State -eq 'Running' }) {
        # Check for global timeout
        if (((Get-Date) - $monitorStartTime).TotalSeconds -gt $maxWaitTime) {
            Write-Host "`n  [!] Global timeout reached - stopping all remaining jobs" -ForegroundColor Yellow
            $jobs | Where-Object { $_.State -eq 'Running' } | ForEach-Object {
                Stop-Job -Job $_ -Force
                Remove-Job -Job $_ -Force -ErrorAction SilentlyContinue
            }
            break
        }
        
        foreach ($job in ($jobs | Where-Object { $_.State -eq 'Running' })) {
            if ($job.PSBeginTime) {
                $runtime = ((Get-Date) - $job.PSBeginTime).TotalSeconds
                $jobTimeout = if ($collectorTimeouts.ContainsKey($job.Name)) { $collectorTimeouts[$job.Name] } else { $defaultTimeout }
                if ($runtime -gt $jobTimeout -and -not $stoppedJobs.ContainsKey($job.Id)) {
                    Write-Log "[!] $($job.Name) exceeded timeout after $([math]::Round($runtime, 2))s - stopping" "WARNING"
                    Stop-Job -Job $job -Force
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                    $stoppedJobs[$job.Id] = $true
                }
            }
        }
        
        # Track missing jobs before filtering
        $missingJobs = $jobs | Where-Object { -not (Get-Job -Id $_.Id -ErrorAction SilentlyContinue) }
        if ($missingJobs) {
            Write-Log "Missing jobs detected: $($missingJobs.Name -join ', ')" "WARNING" "Monitor"
        }

        # Refresh job list after potential removals
        $jobs = $jobs | Where-Object { Get-Job -Id $_.Id -ErrorAction SilentlyContinue }
        
        $runningCount = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
        $completedCount = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
        $failedCount = ($jobs | Where-Object { $_.State -eq 'Failed' -or $_.State -eq 'Stopped' }).Count
        
        # Only display when status changes
        if ($runningCount -ne $lastRunning -or $completedCount -ne $lastCompleted -or $failedCount -ne $lastFailed) {
            $totalTracked = $runningCount + $completedCount + $failedCount
            if ($totalTracked -lt $totalJobsStarted) {
                Write-Host "  [>] Running: $runningCount | Completed: $completedCount | Failed: $failedCount | Missing: $($totalJobsStarted - $totalTracked)" -ForegroundColor Yellow
            } else {
                Write-Host "  [>] Running: $runningCount | Completed: $completedCount | Failed: $failedCount" -ForegroundColor Cyan
            }
            $lastRunning = $runningCount
            $lastCompleted = $completedCount
            $lastFailed = $failedCount
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "  [OK] All jobs finished" -ForegroundColor Green
    
    # Collect Job Results
    Write-Host "`n  Collecting results..." -ForegroundColor Gray
    
    # Refresh job list to get only existing jobs
    $existingJobs = @()
    foreach ($job in $jobs) {
        if (Get-Job -Id $job.Id -ErrorAction SilentlyContinue) {
            $existingJobs += $job
        } else {
            # Job was removed due to timeout, mark as failed
            $script:systemData[$job.Name] = @{Error = "Collection timed out"}
            Write-Log "[FAIL] $($job.Name) timed out" "ERROR"
            $failed++
        }
    }
    
    foreach ($job in $existingJobs) {
        $jobName = $job.Name
        Write-Log "Processing job: $jobName (State: $($job.State))" "DEBUG"
        $runtime = if ($job.PSBeginTime) {
            [math]::Round(((Get-Date) - $job.PSBeginTime).TotalSeconds, 2)
        } else {
            "N/A"
        }

        try {
            if ($job.State -eq 'Completed') {
                $result = Receive-Job -Job $job -ErrorAction Stop
                if ($result) {
                    $script:systemData[$jobName] = $result
                    Write-Log "[OK] $jobName completed ($runtime seconds)" "SUCCESS"
                    $completed++
                    # Track in run log
                    $script:RunLog.Collectors[$jobName] = @{
                        Status = "Success"
                        Runtime = $runtime
                    }
                } else {
                    $script:systemData[$jobName] = @{Error = "No data returned"}
                    Write-Log "[!] $jobName returned no data ($runtime seconds)" "WARNING"
                    # Track in run log
                    $script:RunLog.Collectors[$jobName] = @{
                        Status = "Failed"
                        Runtime = $runtime
                    }
                }
            } else {
                $script:systemData[$jobName] = @{Error = "Collection failed or timed out"}
                Write-Log "[FAIL] $jobName failed ($runtime seconds)" "ERROR"
                $failed++
                # Track in run log
                $script:RunLog.Collectors[$jobName] = @{
                    Status = "Failed"
                    Runtime = $runtime
                }
            }
        } catch {
            $script:systemData[$jobName] = @{Error = "Collection error: $_"}
            Write-Log "[FAIL] $jobName error: $_ ($runtime seconds)" "ERROR"
            $failed++
            # Track in run log
            $script:RunLog.Collectors[$jobName] = @{
                Status = "Failed"
                Runtime = $runtime
            }
        }
    }
    
    # Clean up remaining jobs
    $existingJobs | Remove-Job -Force -ErrorAction SilentlyContinue
    
    
    $parallelDuration = [math]::Round(((Get-Date) - $jobStartTime).TotalSeconds, 2)
    Write-Host "`n  Parallel collection completed in $parallelDuration seconds" -ForegroundColor Cyan
    Write-Host "  Successful: $completed | Failed: $failed" -ForegroundColor $(if($failed -eq 0){'Green'}else{'Yellow'})
    
} else {
    #region FALLBACK SEQUENTIAL COLLECTION
    
    Write-Host "`nPhase 2: Running sequential collection..." -ForegroundColor Yellow
    
    $collectors = @(
        @{Name='OS'; Script={Get-OSData}},
        @{Name='Hardware'; Script={Get-HardwareData -SkipDiskTest $SkipDiskTest}},
        @{Name='Network'; Script={Get-NetworkData}},
        @{Name='Software'; Script={Get-SoftwareData}},
        @{Name='Printers'; Script={Get-PrinterData}},
        @{Name='Drivers'; Script={Get-DriverData}},
        @{Name='Browsers'; Script={Get-BrowserData}}
    )
    
    $completed = 0
    $failed = 0
    
    foreach ($collector in $collectors) {
        Write-Host "  [>] Collecting $($collector.Name) data..." -ForegroundColor Gray -NoNewline
        $collectorStart = Get-Date
        
        try {
            $result = & $collector.Script
            if ($result) {
                $script:systemData[$collector.Name] = $result
                $duration = [math]::Round(((Get-Date) - $collectorStart).TotalSeconds, 2)
                Write-Host "`r  [OK] $($collector.Name) completed ($duration seconds)    " -ForegroundColor Green
                $completed++
            } else {
                $script:systemData[$collector.Name] = @{Error = "No data returned"}
                Write-Host "`r  [!] $($collector.Name) returned no data    " -ForegroundColor Yellow
            }
        } catch {
            $script:systemData[$collector.Name] = @{Error = "Collection failed: $_"}
            Write-Host "`r  [FAIL] $($collector.Name) failed: $_    " -ForegroundColor Red
            $failed++
        }
    }
    
    Write-Host "`n  Sequential collection completed" -ForegroundColor Cyan
    Write-Host "  Successful: $completed | Failed: $failed" -ForegroundColor $(if($failed -eq 0){'Green'}else{'Yellow'})
    
    #endregion
}

#endregion

#region REPORT GENERATION SECTION

Write-Host "`nPhase 3: Generating report..." -ForegroundColor Cyan

# Add Final Metadata
$script:systemData.Metadata.CollectionEndTime = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
$script:systemData.Metadata.CollectionDuration = [math]::Round(((Get-Date) - $script:StartTime).TotalSeconds, 2)
$script:systemData.Metadata.CollectorsRun = 8
$script:systemData.Metadata.CollectorsSuccessful = $completed
$script:systemData.Metadata.CollectorsFailed = $failed

# Convert to JSON
Write-Host "  [>] Converting data to JSON..." -ForegroundColor Gray
try {
    $jsonData = $script:systemData | ConvertTo-Json -Depth 10 -Compress
    Write-Host "  [OK] Data serialized successfully" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Failed to serialize data: $_" -ForegroundColor Red
    exit 1
}

# Load and Process Template
$templatePath = Join-Path $script:ScriptRoot "Templates\report-template.html"
if (-not (Test-Path $templatePath)) {
    Write-Host "  [FAIL] Report template not found at: $templatePath" -ForegroundColor Red
    Write-Host "      Cannot generate report. Exiting..." -ForegroundColor Red
    exit 1
}

Write-Host "  [>] Loading report template..." -ForegroundColor Gray
try {
    $templateContent = Get-Content $templatePath -Raw -Encoding UTF8
    Write-Host "  [OK] Template loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Failed to load template: $_" -ForegroundColor Red
    exit 1
}

# Replace placeholders with data
$htmlContent = $templateContent -replace '{{SYSTEM_DATA}}', $jsonData
$htmlContent = $htmlContent -replace '{{COMPUTER_NAME}}', $env:COMPUTERNAME

# Save Report
$timestamp = Get-Date -Format 'yyyy-MM-ddTHHmmss'  # ISO 8601 basic format (no colons for Windows compatibility)
$computerName = $env:COMPUTERNAME

$outputFileName = "WinDAS_Report_${computerName}_${timestamp}.html"
$outputFile = Join-Path $script:OutputPath $outputFileName

Write-Host "  [>] Saving report..." -ForegroundColor Gray
try {
    $htmlContent | Out-File -FilePath $outputFile -Encoding UTF8
    Write-Host "  [OK] Report saved successfully" -ForegroundColor Green
    # Track HTML generation success
    $script:RunLog.HTMLGeneration = "Success"
} catch {
    Write-Host "  [FAIL] Failed to save report: $_" -ForegroundColor Red
    # Track HTML generation failure
    $script:RunLog.HTMLGeneration = "Failed"
    exit 1
}

#endregion

#region CLEANUP SECTION

Write-Host "`nPhase 4: Cleaning up..." -ForegroundColor Cyan

# Clean Up Resources
if ($Global:CIMSession) {
    try {
        Remove-CimSession -CimSession $Global:CIMSession -ErrorAction SilentlyContinue
        Write-Host "  [OK] CIM session closed" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Could not close CIM session" -ForegroundColor Yellow
    }
    $Global:CIMSession = $null
}

# Clear global variables
if ($Global:DataCache) {
    $Global:DataCache = $null
    Write-Host "  [OK] Cache cleared" -ForegroundColor Green
}

# Stop any remaining jobs
Get-Job | Where-Object { $_.Name -like "WinDAS*" } | Stop-Job -ErrorAction SilentlyContinue
Get-Job | Where-Object { $_.Name -like "WinDAS*" } | Remove-Job -Force -ErrorAction SilentlyContinue

#endregion

#region COMPLETION SUMMARY

$totalSeconds = [math]::Round(((Get-Date) - $script:StartTime).TotalSeconds, 2)
$fileSizeMB = [math]::Round((Get-Item $outputFile).Length / 1MB, 2)

Write-Host "`nWinDAS Collection Complete!" -ForegroundColor Green
Write-Host ("=" * 50) -ForegroundColor DarkGray
Write-Host "  Total Time:      $totalSeconds seconds" -ForegroundColor White
Write-Host "  Report Saved:    $outputFile" -ForegroundColor White
if ($script:LoggingEnabled -and $script:LogFile) {
    Write-Host "  Log File:        $script:LogFile" -ForegroundColor White
}
Write-Host "  File Size:       $fileSizeMB MB" -ForegroundColor White
Write-Host "  Collectors Run:  8" -ForegroundColor White
Write-Host "  Successful:      $completed" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "  Failed:          $failed" -ForegroundColor Yellow
}
Write-Host ""

Write-Log "WinDAS session complete - Report: $outputFile" "INFO"

# Write run log (always enabled)
try {
    $Today = Get-Date -Format 'yyyy-MM-dd'
    $RunLogPath = Join-Path $PSScriptRoot "Logs\ran_on_$Today.json"

    # Read existing log or create new array
    if (Test-Path $RunLogPath) {
        $logContent = Get-Content $RunLogPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        if ($logContent -is [array]) {
            $runHistory = [System.Collections.ArrayList]@($logContent)
        } else {
            $runHistory = [System.Collections.ArrayList]@($logContent)
        }
    } else {
        $runHistory = [System.Collections.ArrayList]@()
    }

    # Add current run
    $null = $runHistory.Add($script:RunLog)

    # Write to file
    $runHistory | ConvertTo-Json -Depth 5 | Set-Content $RunLogPath -Force
} catch {
    Write-Host "  [WARN] Could not write run log: $_" -ForegroundColor Yellow
}

Write-Host "`nThank you for using WinDAS!" -ForegroundColor Cyan
if ($script:LoggingEnabled -and $script:LogFile) {
    Write-Host "Log file saved to: $script:LogFile" -ForegroundColor Gray
}
Write-Host ""

#endregion

# Exit successfully
exit 0
