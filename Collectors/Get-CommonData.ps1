# Get-CommonData.ps1
# Query common CIM classes once and cache the results
# Author: Joshua Walderbach

function Get-CommonData {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force
    )
    
    # Check if data collection is initialized
    if (-not (Test-DataCollection)) {
        Write-Error "Data collection not initialized. Run Initialize-DataCollection first."
        return $false
    }
    
    # Check if data already cached (unless Force specified)
    if (-not $Force -and $Global:DataCache.Collections.Count -gt 0) {
        Write-Verbose "Common data already cached. Use -Force to refresh."
        return $true
    }
    
    Write-Host "Collecting common system data..." -ForegroundColor Cyan
    
    # Define CIM classes to query
    $cimClasses = @(
        @{ Name = 'Win32_ComputerSystem'; Description = 'Computer System Information' }
        @{ Name = 'Win32_OperatingSystem'; Description = 'Operating System Information' }
        @{ Name = 'Win32_Processor'; Description = 'Processor Information' }
        @{ Name = 'Win32_PhysicalMemory'; Description = 'Physical Memory Modules' }
        @{ Name = 'Win32_LogicalDisk'; Description = 'Logical Disk Information' }
        @{ Name = 'Win32_NetworkAdapter'; Description = 'Network Adapters' }
        @{ Name = 'Win32_NetworkAdapterConfiguration'; Description = 'Network Configuration' }
        @{ Name = 'Win32_VideoController'; Description = 'Video Controllers' }
        @{ Name = 'Win32_BaseBoard'; Description = 'Motherboard Information' }
        @{ Name = 'Win32_BIOS'; Description = 'BIOS Information' }
        @{ Name = 'Win32_Service'; Description = 'Windows Services' }
        @{ Name = 'Win32_QuickFixEngineering'; Description = 'Windows Updates and Hotfixes' }
    )
    
    $totalClasses = $cimClasses.Count
    $currentClass = 0
    $failedQueries = @()
    
    foreach ($class in $cimClasses) {
        $currentClass++
        $percentComplete = [int](($currentClass / $totalClasses) * 100)
        
        Write-ProgressStatus -Activity "Collecting System Data" `
                           -Status "Querying $($class.Description)" `
                           -PercentComplete $percentComplete
        
        try {
            $startTime = Get-Date
            
            # Use CIM for all queries (WMI is deprecated)
            Write-Verbose "Using CIM to query $($class.Name)"
            
            # Try with session first, fall back to sessionless if needed
            if ($Global:CIMSession) {
                $data = Get-CimInstance -CimSession $Global:CIMSession -ClassName $class.Name -ErrorAction Stop
            } else {
                # Direct CIM query without session (works for local queries)
                $data = Get-CimInstance -ClassName $class.Name -ErrorAction Stop
            }
            
            $queryTime = (Get-Date) - $startTime
            
            # Store in cache
            $Global:DataCache.Collections[$class.Name] = @{
                Data = $data
                CollectedAt = Get-Date
                QueryTime = $queryTime.TotalMilliseconds
                RecordCount = if ($data) { @($data).Count } else { 0 }
                Description = $class.Description
            }
            
            Write-Verbose "Cached $($class.Name): $(@($data).Count) records in $([int]$queryTime.TotalMilliseconds)ms"
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Warning "Failed to query $($class.Name): $errorMsg"
            
            $failedQueries += @{
                ClassName = $class.Name
                Description = $class.Description
                Error = $errorMsg
                FailedAt = Get-Date
            }
            
            # Store empty result with error info
            $Global:DataCache.Collections[$class.Name] = @{
                Data = $null
                CollectedAt = Get-Date
                QueryTime = 0
                RecordCount = 0
                Description = $class.Description
                Error = $errorMsg
            }
        }
    }
    
    # Cache Installed Software from registry (expensive query used by multiple collectors)
    Write-Host "  Caching installed software..." -ForegroundColor Gray
    Write-ProgressStatus -Activity "Collecting System Data" -Status "Querying installed software..."
    
    try {
        $installedSoftware = @()
        $registryPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        
        foreach ($path in $registryPaths) {
            $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -and $_.DisplayName -ne '' } |
                Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, UninstallString, InstallLocation
            if ($apps) {
                $installedSoftware += $apps
            }
        }
        
        $Global:DataCache.Collections['InstalledSoftware'] = @{
            Data = $installedSoftware
            CollectedAt = Get-Date
            QueryTime = 0
            RecordCount = $installedSoftware.Count
            Description = 'Installed Software from Registry'
            Error = $null
        }
        Write-Host "    [OK] Cached $($installedSoftware.Count) installed programs" -ForegroundColor Green
    }
    catch {
        Write-Host "    [FAIL] Failed to cache installed software: $_" -ForegroundColor Yellow
        $Global:DataCache.Collections['InstalledSoftware'] = @{
            Data = $null
            Error = $_.ToString()
        }
    }
    
    Write-ProgressStatus -Activity "Collecting System Data" -Completed
    
    # Store collection summary
    $Global:DataCache.CollectionSummary = @{
        CompletedAt = Get-Date
        TotalClasses = $totalClasses
        SuccessfulQueries = $totalClasses - $failedQueries.Count
        FailedQueries = $failedQueries.Count
        FailedDetails = $failedQueries
        TotalRecords = ($Global:DataCache.Collections.Values | Where-Object { $_.Data } | ForEach-Object { $_.RecordCount } | Measure-Object -Sum).Sum
    }
    
    # Display summary
    Write-Host ""
    Write-Host "Data Collection Summary:" -ForegroundColor Green
    Write-Host "  Total Classes Queried: $totalClasses"
    Write-Host "  Successful: $($Global:DataCache.CollectionSummary.SuccessfulQueries)" -ForegroundColor Green
    
    if ($failedQueries.Count -gt 0) {
        Write-Host "  Failed: $($failedQueries.Count)" -ForegroundColor Yellow
        foreach ($failed in $failedQueries) {
            Write-Verbose "    - $($failed.ClassName): $($failed.Error)"
        }
    }
    
    Write-Host "  Total Records Cached: $($Global:DataCache.CollectionSummary.TotalRecords)"
    Write-Host ""
    
    return ($failedQueries.Count -eq 0)
}

function Get-CachedData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClassName
    )
    
    if (-not $Global:DataCache -or -not $Global:DataCache.Collections) {
        Write-Warning "No cached data available. Run Get-CommonData first."
        return $null
    }
    
    if ($Global:DataCache.Collections.ContainsKey($ClassName)) {
        $cached = $Global:DataCache.Collections[$ClassName]
        
        if ($cached.Error) {
            Write-Warning "Cached data for $ClassName contains error: $($cached.Error)"
        }
        
        Write-Verbose "Retrieved cached $ClassName data: $($cached.RecordCount) records from $($cached.CollectedAt)"
        return $cached.Data
    }
    else {
        Write-Warning "No cached data found for $ClassName"
        return $null
    }
}

function Show-CacheStatus {
    [CmdletBinding()]
    param()
    
    if (-not $Global:DataCache) {
        Write-Host "Data cache not initialized" -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "Data Cache Status" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    Write-Host "Initialized: $($Global:DataCache.InitializedAt)"
    Write-Host "Computer: $($Global:DataCache.ComputerName)"
    
    if ($Global:CIMSession) {
        Write-Host "Mode: CIM Session" -ForegroundColor Green
    }
    else {
        Write-Host "Mode: Direct CIM Queries" -ForegroundColor Yellow
    }
    
    if ($Global:DataCache.Collections) {
        Write-Host ""
        Write-Host "Cached Classes:" -ForegroundColor Cyan
        
        foreach ($key in $Global:DataCache.Collections.Keys | Sort-Object) {
            $item = $Global:DataCache.Collections[$key]
            $status = if ($item.Error) { "Critical" } elseif ($item.RecordCount -eq 0) { "Warning" } else { "Healthy" }
            $statusColor = switch ($status) {
                "Critical" { "Red" }
                "Warning" { "Yellow" }
                default { "Green" }
            }
            
            Write-Host ("  {0,-40} {1,8} records  [{2}]" -f $key, $item.RecordCount, $status) -ForegroundColor $statusColor
        }
        
        if ($Global:DataCache.CollectionSummary) {
            Write-Host ""
            Write-Host "Summary:" -ForegroundColor Cyan
            Write-Host "  Last Collection: $($Global:DataCache.CollectionSummary.CompletedAt)"
            Write-Host "  Total Records: $($Global:DataCache.CollectionSummary.TotalRecords)"
            Write-Host "  Success Rate: $($Global:DataCache.CollectionSummary.SuccessfulQueries)/$($Global:DataCache.CollectionSummary.TotalClasses)"
        }
    }
    else {
        Write-Host "No data collected yet" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function Clear-CachedData {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ClassName
    )
    
    if (-not $Global:DataCache) {
        Write-Warning "Data cache not initialized"
        return
    }
    
    if ($ClassName) {
        if ($Global:DataCache.Collections.ContainsKey($ClassName)) {
            $Global:DataCache.Collections.Remove($ClassName)
            Write-Host "Cleared cache for $ClassName" -ForegroundColor Yellow
        }
        else {
            Write-Warning "No cached data found for $ClassName"
        }
    }
    else {
        $Global:DataCache.Collections = @{}
        $Global:DataCache.CollectionSummary = $null
        Write-Host "Cleared all cached data" -ForegroundColor Yellow
    }
}

function Get-SystemIssues {
    <#
    .SYNOPSIS
    Analyzes system data and returns standardized issue format for ticket notes
    
    .DESCRIPTION
    Aggregates issues from all system data collectors and returns them in a standardized format
    suitable for display in ticket notes and reporting systems
    
    .PARAMETER AllData
    The complete system data object containing all collected information
    
    .EXAMPLE
    $issues = Get-SystemIssues -AllData $systemData
    
    .NOTES
    Returns issues sorted by severity (CRITICAL, WARNING, INFO) then by description
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AllData
    )
    
    $issues = @()
    
    try {
        Write-Verbose "Analyzing system data for issues..."
        
        # Check OS issues
        if ($AllData.OS) {
            # Windows Update checks
            if ($AllData.OS.WindowsUpdate -and $AllData.OS.WindowsUpdate.DaysSinceUpdate) {
                if ($AllData.OS.WindowsUpdate.DaysSinceUpdate -gt 30) {
                    $issues += @{
                        Severity = 'CRITICAL'
                        Category = 'Updates'
                        Description = "Windows Updates overdue by $($AllData.OS.WindowsUpdate.DaysSinceUpdate) days"
                    }
                }
                elseif ($AllData.OS.WindowsUpdate.DaysSinceUpdate -gt 14) {
                    $issues += @{
                        Severity = 'WARNING'
                        Category = 'Updates'
                        Description = "Windows Updates overdue by $($AllData.OS.WindowsUpdate.DaysSinceUpdate) days"
                    }
                }
            }
            
            # Pending reboot check
            if ($AllData.OS.PendingReboot -eq $true) {
                $issues += @{
                    Severity = 'WARNING'
                    Category = 'System'
                    Description = "System reboot required"
                }
            }
            
            # Event log errors
            if ($AllData.OS.Events) {
                if ($AllData.OS.Events.SystemErrors24h -gt 10) {
                    $issues += @{
                        Severity = 'WARNING'
                        Category = 'Events'
                        Description = "$($AllData.OS.Events.SystemErrors24h) system errors in last 24 hours"
                    }
                }
                
                if ($AllData.OS.Events.ApplicationErrors24h -gt 20) {
                    $issues += @{
                        Severity = 'WARNING'
                        Category = 'Events'
                        Description = "$($AllData.OS.Events.ApplicationErrors24h) application errors in last 24 hours"
                    }
                }
                
                if ($AllData.OS.Events.BlueScreens24h -gt 0) {
                    $issues += @{
                        Severity = 'CRITICAL'
                        Category = 'Stability'
                        Description = "$($AllData.OS.Events.BlueScreens24h) blue screen errors in last 24 hours"
                    }
                }
            }
            
            # Critical services check
            if ($AllData.OS.Services) {
                $criticalServices = @('RpcSs','EventLog','Winmgmt','Dhcp','Dnscache','wuauserv','BITS','CryptSvc','TrustedInstaller')
                foreach ($service in $AllData.OS.Services) {
                    if ($service.Name -in $criticalServices -and $service.Status -ne 'Running') {
                        $issues += @{
                            Severity = 'WARNING'
                            Category = 'Services'
                            Description = "Critical service '$($service.DisplayName)' is $($service.Status.ToLower())"
                        }
                    }
                }
            }
            
            # Security checks
            if ($AllData.OS.Security) {
                if ($AllData.OS.Security.WindowsDefender -eq 'Disabled') {
                    $issues += @{
                        Severity = 'CRITICAL'
                        Category = 'Security'
                        Description = "Windows Defender is disabled"
                    }
                }
                
                if ($AllData.OS.Security.Firewall -eq 'Disabled') {
                    $issues += @{
                        Severity = 'WARNING'
                        Category = 'Security'
                        Description = "Windows Firewall is disabled"
                    }
                }
            }
        }
        
        # Check Hardware issues
        if ($AllData.Hardware) {
            # Disk space checks
            if ($AllData.Hardware.Storage -and $AllData.Hardware.Storage.Disks) {
                foreach ($disk in $AllData.Hardware.Storage.Disks) {
                    if ($disk.FreeSpacePercent -lt 5) {
                        $issues += @{
                            Severity = 'CRITICAL'
                            Category = 'Storage'
                            Description = "Drive $($disk.Letter) critically low on space: $([math]::Round($disk.FreeSpaceGB, 1)) GB free ($($disk.FreeSpacePercent)%)"
                        }
                    }
                    elseif ($disk.FreeSpacePercent -lt 15) {
                        $issues += @{
                            Severity = 'WARNING'
                            Category = 'Storage'
                            Description = "Drive $($disk.Letter) low on space: $([math]::Round($disk.FreeSpaceGB, 1)) GB free ($($disk.FreeSpacePercent)%)"
                        }
                    }
                }
            }
            
            # Memory usage check
            if ($AllData.Hardware.Memory -and $AllData.Hardware.Memory.PercentUsed) {
                if ($AllData.Hardware.Memory.PercentUsed -gt 95) {
                    $issues += @{
                        Severity = 'CRITICAL'
                        Category = 'Memory'
                        Description = "Memory usage critical at $($AllData.Hardware.Memory.PercentUsed)%"
                    }
                }
                elseif ($AllData.Hardware.Memory.PercentUsed -gt 85) {
                    $issues += @{
                        Severity = 'WARNING'
                        Category = 'Memory'
                        Description = "Memory usage high at $($AllData.Hardware.Memory.PercentUsed)%"
                    }
                }
            }
            
            # CPU temperature check (if available)
            if ($AllData.Hardware.CPU -and $AllData.Hardware.CPU.Temperature) {
                if ($AllData.Hardware.CPU.Temperature -gt 85) {
                    $issues += @{
                        Severity = 'WARNING'
                        Category = 'Temperature'
                        Description = "CPU temperature high at $($AllData.Hardware.CPU.Temperature)°C"
                    }
                }
            }
        }
        
        # Check Software issues
        if ($AllData.Software) {
            # Application crashes
            if ($AllData.Software.Crashes -and $AllData.Software.Crashes.Last24Hours -gt 5) {
                $issues += @{
                    Severity = 'WARNING'
                    Category = 'Stability'
                    Description = "$($AllData.Software.Crashes.Last24Hours) application crashes in last 24 hours"
                }
            }
            
            # Hung applications
            if ($AllData.Software.Processes) {
                $hungProcesses = $AllData.Software.Processes | Where-Object { $_.Status -eq 'Not Responding' }
                if ($hungProcesses) {
                    $issues += @{
                        Severity = 'INFO'
                        Category = 'Performance'
                        Description = "$($hungProcesses.Count) applications not responding"
                    }
                }
            }
        }
        
        # Check Network issues
        if ($AllData.Network) {
            # Network adapter status
            if ($AllData.Network.Adapters) {
                $downAdapters = $AllData.Network.Adapters | Where-Object { $_.Status -eq 'Disconnected' -and $_.Type -ne 'Bluetooth' }
                if ($downAdapters) {
                    foreach ($adapter in $downAdapters) {
                        $issues += @{
                            Severity = 'INFO'
                            Category = 'Network'
                            Description = "Network adapter '$($adapter.Name)' is disconnected"
                        }
                    }
                }
            }
            
            # Connectivity issues
            if ($AllData.Network.Connectivity) {
                if ($AllData.Network.Connectivity.InternetAccess -eq $false) {
                    $issues += @{
                        Severity = 'WARNING'
                        Category = 'Network'
                        Description = "No internet connectivity detected"
                    }
                }
                
                if ($AllData.Network.Connectivity.DNSResolution -eq $false) {
                    $issues += @{
                        Severity = 'WARNING'
                        Category = 'Network'
                        Description = "DNS resolution failure detected"
                    }
                }
            }
        }
        
        # Check Printer issues
        if ($AllData.Printers -and $AllData.Printers.Devices) {
            $errorPrinters = $AllData.Printers.Devices | Where-Object { $_.Status -like '*Error*' -or $_.Status -like '*Offline*' }
            foreach ($printer in $errorPrinters) {
                $issues += @{
                    Severity = 'INFO'
                    Category = 'Printers'
                    Description = "Printer '$($printer.Name)' status: $($printer.Status)"
                }
            }
        }
        
        # Check Driver issues
        if ($AllData.Drivers -and $AllData.Drivers.ProblemDevices) {
            foreach ($device in $AllData.Drivers.ProblemDevices) {
                $severityLevel = switch ($device.ProblemCode) {
                    { $_ -in @(1, 10, 12, 18, 22) } { 'CRITICAL' }  # Device not working, failed to start, insufficient resources
                    { $_ -in @(28, 31, 37, 43, 45) } { 'WARNING' }   # Driver not installed, unknown device, driver issues
                    default { 'INFO' }
                }
                
                $issues += @{
                    Severity = $severityLevel
                    Category = 'Drivers'
                    Description = "Device '$($device.Name)' has problem code $($device.ProblemCode)"
                }
            }
        }
        
        Write-Verbose "Found $($issues.Count) system issues"
        
    }
    catch {
        Write-Error "Failed to analyze system issues: $($_.Exception.Message)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
    }
    
    # Sort issues by severity (Critical first, then Warning, then Info) and then by description
    return $issues | Sort-Object @{
        Expression = {
            switch($_.Severity) {
                'CRITICAL' { 1 }
                'WARNING' { 2 }
                'INFO' { 3 }
                default { 4 }
            }
        }
    }, Description
}

function Add-TicketNotesData {
    <#
    .SYNOPSIS
    Adds ticket notes data to the system data collection
    
    .DESCRIPTION
    Analyzes all collected system data and adds standardized issue information
    suitable for ticket notes and reporting systems
    
    .PARAMETER SystemData
    The system data hashtable to add ticket notes information to
    
    .EXAMPLE
    Add-TicketNotesData -SystemData $systemData
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$SystemData
    )
    
    try {
        Write-Verbose "Generating ticket notes data..."
        
        # Get all issues
        $allIssues = Get-SystemIssues -AllData $SystemData
        
        # Add ticket notes section to system data
        $SystemData.TicketNotes = @{
            Issues = $allIssues
            IssueCount = @{
                Total = $allIssues.Count
                Critical = ($allIssues | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
                Warning = ($allIssues | Where-Object { $_.Severity -eq 'WARNING' }).Count
                Info = ($allIssues | Where-Object { $_.Severity -eq 'INFO' }).Count
            }
            Categories = ($allIssues | Group-Object Category | ForEach-Object { 
                @{ 
                    Name = $_.Name
                    Count = $_.Count
                    Issues = $_.Group
                } 
            })
            GeneratedAt = Get-Date
            Summary = "Found $($allIssues.Count) issues: $((($allIssues | Where-Object { $_.Severity -eq 'CRITICAL' }).Count)) critical, $((($allIssues | Where-Object { $_.Severity -eq 'WARNING' }).Count)) warnings, $((($allIssues | Where-Object { $_.Severity -eq 'INFO' }).Count)) informational"
        }
        
        Write-Verbose "Added ticket notes data: $($allIssues.Count) issues identified"
        
    }
    catch {
        Write-Error "Failed to add ticket notes data: $($_.Exception.Message)"
        
        # Add empty ticket notes data on error
        $SystemData.TicketNotes = @{
            Issues = @()
            IssueCount = @{ Total = 0; Critical = 0; Warning = 0; Info = 0 }
            Categories = @()
            GeneratedAt = Get-Date
            Summary = "Error generating ticket notes"
            Error = $_.Exception.Message
        }
    }
}