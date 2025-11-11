# Get-SoftwareData.ps1
# Collect comprehensive software inventory and health data
# Author: Joshua Walderbach

function Get-SoftwareData {
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$DataCache = $Global:DataCache
    )
    
    Write-ProgressStatus -Activity "Collecting Software Data" -Status "Initializing"
    
    # Initialize software data structure
    $softwareData = [PSCustomObject]@{
        CollectedAt = Get-Date
        Performance = $null
        ApplicationHealth = $null
        InstalledApplications = $null
        StartupPrograms = $null
        LicenseStatus = $null
        HealthScore = 0
        Summary = $null
    }
    
    try {
        # Get performance metrics
        Write-ProgressStatus -Activity "Collecting Software Data" -Status "Gathering performance metrics" -PercentComplete 10
        $softwareData.Performance = Get-SoftwarePerformance -DataCache $DataCache
        
        # Get application health (crashes/hangs)
        Write-ProgressStatus -Activity "Collecting Software Data" -Status "Checking application health" -PercentComplete 30
        $softwareData.ApplicationHealth = Get-ApplicationHealth
        
        # Get installed applications from registry
        Write-ProgressStatus -Activity "Collecting Software Data" -Status "Inventorying installed applications" -PercentComplete 50
        $softwareData.InstalledApplications = Get-InstalledApplications
        
        # Get startup programs
        Write-ProgressStatus -Activity "Collecting Software Data" -Status "Analyzing startup programs" -PercentComplete 70
        $softwareData.StartupPrograms = Get-StartupPrograms
        
        # Get license status
        Write-ProgressStatus -Activity "Collecting Software Data" -Status "Checking license status" -PercentComplete 85
        $softwareData.LicenseStatus = Get-LicenseStatus
        
        # Calculate health score
        Write-ProgressStatus -Activity "Collecting Software Data" -Status "Calculating health score" -PercentComplete 95
        $softwareData.HealthScore = Get-SoftwareHealthScore -SoftwareData $softwareData
        
        # Create summary
        $softwareData.Summary = Get-SoftwareSummary -SoftwareData $softwareData
        
        Write-ProgressStatus -Activity "Collecting Software Data" -Completed
    }
    catch {
        Write-Error "Failed to collect software data: $_"
    }
    
    return $softwareData
}

function Get-SoftwarePerformance {
    param($DataCache)
    
    try {
        $perfData = [PSCustomObject]@{
            CPU = $null
            Memory = $null
            DiskQueue = $null
            ProcessCount = $null
            ServiceStatus = $null
        }
        
        # Get CPU usage (simplified for parallel execution)
        try {
            $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
            
            $perfData.CPU = [PSCustomObject]@{
                CurrentUsage = if ($cpuCounter) { [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2) } else { "N/A" }
                Status = "Unknown"
            }
            
            if ($perfData.CPU.CurrentUsage -ne "N/A") {
                $perfData.CPU.Status = Get-StatusFromThreshold -Value $perfData.CPU.CurrentUsage -WarningThreshold 75 -CriticalThreshold 85
            }
        }
        catch {
            Write-Verbose "Could not get CPU performance data"
        }
        
        # Get Memory usage
        $os = Get-CachedData -ClassName 'Win32_OperatingSystem'
        if ($os) {
            $totalMemoryGB = if ($os.TotalVisibleMemorySize -and $os.TotalVisibleMemorySize -gt 0) {
                [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            } else { 0 }
            
            $availableMemoryMB = if ($os.FreePhysicalMemory -and $os.FreePhysicalMemory -gt 0) {
                [math]::Round($os.FreePhysicalMemory / 1KB, 0)
            } else { 0 }
            
            $usedMemoryGB = if ($os.TotalVisibleMemorySize -and $os.FreePhysicalMemory) {
                [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
            } else { 0 }
            
            $percentUsed = if ($totalMemoryGB -gt 0) {
                [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 2)
            } else { 0 }
            
            $perfData.Memory = [PSCustomObject]@{
                TotalGB = $totalMemoryGB
                UsedGB = $usedMemoryGB
                AvailableMB = $availableMemoryMB
                PercentUsed = $percentUsed
                Status = if ($availableMemoryMB -lt 100) { "Critical" }
                        elseif ($percentUsed -gt 90) { "Critical" }
                        elseif ($percentUsed -gt 80) { "Warning" }
                        else { "Healthy" }
            }
        }
        
        # Get Disk Queue Length (simplified for parallel execution)
        try {
            $diskQueueCounter = Get-Counter '\PhysicalDisk(_Total)\Avg. Disk Queue Length' -ErrorAction SilentlyContinue
            
            $perfData.DiskQueue = [PSCustomObject]@{
                Current = if ($diskQueueCounter) { [math]::Round($diskQueueCounter.CounterSamples[0].CookedValue, 2) } else { "N/A" }
                Status = "Unknown"
            }
            
            if ($perfData.DiskQueue.Current -ne "N/A") {
                $perfData.DiskQueue.Status = Get-StatusFromThreshold -Value $perfData.DiskQueue.Current -WarningThreshold 2 -CriticalThreshold 5
            }
        }
        catch {
            Write-Verbose "Could not get disk queue data"
        }
        
        # Get Process and Service counts
        # Query processes directly for current state
        $processes = Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue
        $services = Get-CachedData -ClassName 'Win32_Service'
        
        $perfData.ProcessCount = [PSCustomObject]@{
            Total = @($processes).Count
            HighResource = @($processes | Where-Object { $_.WorkingSetSize -gt 1GB }).Count
        }
        
        $perfData.ServiceStatus = [PSCustomObject]@{
            Running = @($services | Where-Object { $_.State -eq 'Running' }).Count
            Total = @($services).Count
            Stopped = @($services | Where-Object { $_.State -eq 'Stopped' -and $_.StartMode -eq 'Auto' }).Count
        }
        
        return $perfData
    }
    catch {
        Write-Warning "Failed to get software performance: $_"
        return $null
    }
}

function Get-ResourceConsumers {
    param($DataCache)
    
    try {
        # Query processes directly for current state
        $processes = Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue
        if (-not $processes) { return $null }
        
        # Get CPU usage using WMI PerfFormattedData
        $cpuData = @{}
        try {
            # Get CPU performance data for all processes
            $perfProcs = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne '_Total' -and $_.Name -ne 'Idle' }
            
            foreach ($proc in $perfProcs) {
                # Match by process ID (IDProcess)
                $cpuData[$proc.IDProcess] = $proc.PercentProcessorTime
            }
        } catch {
            Write-Verbose "Could not get CPU performance data: $_"
        }
        
        # Get current CPU usage for processes
        $topCPU = @($processes | ForEach-Object {
            $cpuPercent = if ($cpuData.ContainsKey($_.ProcessId)) {
                $cpuData[$_.ProcessId]
            } else {
                0
            }
            
            [PSCustomObject]@{
                Process = $_.Name
                ProcessId = $_.ProcessId
                CPUPercent = $cpuPercent
                Runtime = if ($_.CreationDate) {
                    try {
                        $runtime = (Get-Date) - [Management.ManagementDateTimeConverter]::ToDateTime($_.CreationDate)
                        if ($runtime.TotalDays -ge 1) {
                            "$([int]$runtime.TotalDays)d $([int]$runtime.Hours)h"
                        } else {
                            "$([int]$runtime.Hours)h $([int]$runtime.Minutes)m"
                        }
                    } catch {
                        "N/A"
                    }
                } else { "N/A" }
            }
        } | Sort-Object CPUPercent -Descending | Select-Object -First 5)
        
        # Get top memory consumers
        $topMemory = @($processes | Sort-Object WorkingSetSize -Descending | Select-Object -First 5 | ForEach-Object {
            [PSCustomObject]@{
                Process = $_.Name
                ProcessId = $_.ProcessId
                MemoryMB = [math]::Round($_.WorkingSetSize / 1MB, 2)
                Handles = $_.HandleCount
                Threads = $_.ThreadCount
                Status = if ($_.WorkingSetSize -gt 2GB) { "Critical" }
                        elseif ($_.WorkingSetSize -gt 1GB) { "Warning" }
                        elseif ($_.HandleCount -gt 10000) { "Critical" }
                        elseif ($_.ThreadCount -gt 100) { "Warning" }
                        else { "Normal" }
            }
        })
        
        return [PSCustomObject]@{
            TopCPU = $topCPU
            TopMemory = $topMemory
        }
    }
    catch {
        Write-Warning "Failed to get resource consumers: $_"
        return $null
    }
}

function Get-ApplicationHealth {
    try {
        $health = [PSCustomObject]@{
            Crashes = @()
            Hangs = @()
            StoreAppIssues = @()
            Summary = $null
        }
        
        # Get application crashes (Event ID 1000) from last 24 hours
        $24HoursAgo = (Get-Date).AddHours(-24)
        try {
            $crashEvents = @(Get-WinEvent -FilterHashtable @{
                LogName = 'Application'
                ID = 1000
                StartTime = $24HoursAgo
            } -ErrorAction SilentlyContinue)
            
            if ($crashEvents.Count -gt 0) {
                # Group crashes by application
                $crashGroups = $crashEvents | Group-Object { 
                    if ($_.Message -match 'Faulting application name:\s+([^,]+)') { $matches[1] } else { "Unknown" }
                }
                
                $health.Crashes = @($crashGroups | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
                    $latestCrash = $_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1
                    $faultModule = if ($latestCrash.Message -match 'Faulting module name:\s+([^,]+)') { $matches[1] } else { "Unknown" }
                    $exceptionCode = if ($latestCrash.Message -match 'Exception code:\s+(0x[0-9a-fA-F]+)') { $matches[1] } else { "Unknown" }
                    
                    [PSCustomObject]@{
                        Application = $_.Name
                        CrashCount = $_.Count
                        LastCrash = $latestCrash.TimeCreated
                        FaultModule = $faultModule
                        ExceptionCode = $exceptionCode
                    }
                })
            }
        }
        catch {
            Write-Verbose "Could not get application crash events: $_"
        }
        
        # Get application hangs (Event ID 1002) from last 24 hours
        try {
            $hangEvents = @(Get-WinEvent -FilterHashtable @{
                LogName = 'Application'
                ID = 1002
                StartTime = $24HoursAgo
            } -ErrorAction SilentlyContinue)
            
            if ($hangEvents.Count -gt 0) {
                $hangGroups = $hangEvents | Group-Object { 
                    if ($_.Message -match 'hanging application\s+([^,]+)') { $matches[1] } else { "Unknown" }
                }
                
                $health.Hangs = @($hangGroups | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
                    [PSCustomObject]@{
                        Application = $_.Name
                        HangCount = $_.Count
                        LastHang = ($_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated
                    }
                })
            }
        }
        catch {
            Write-Verbose "Could not get application hang events: $_"
        }
        
        # Create summary
        $health.Summary = [PSCustomObject]@{
            TotalCrashes72h = $health.Crashes | Measure-Object -Property CrashCount -Sum | Select-Object -ExpandProperty Sum
            TotalHangs72h = $health.Hangs | Measure-Object -Property HangCount -Sum | Select-Object -ExpandProperty Sum
            UniqueAppsCrashed = $health.Crashes.Count
            UniqueAppsHung = $health.Hangs.Count
            Status = "Healthy"
        }
        
        # Determine status
        if ($health.Summary.TotalCrashes72h -gt 5) {
            $health.Summary.Status = "Critical"
        } elseif ($health.Summary.TotalCrashes72h -gt 2) {
            $health.Summary.Status = "Warning"
        }
        
        return $health
    }
    catch {
        Write-Warning "Failed to get application health: $_"
        return $null
    }
}

function Get-InstalledApplications {
    try {
        Write-Verbose "Getting installed applications from registry"
        
        $applications = @()
        
        # Try to use cached installed software first
        $cachedSoftware = Get-CachedData -ClassName 'InstalledSoftware'
        
        if ($cachedSoftware) {
            Write-Verbose "Using cached installed software data"
            $allApps = $cachedSoftware | Where-Object { $_.DisplayName -notmatch '^KB\d+' }
        } else {
            Write-Verbose "Querying installed software from registry"
            # Fallback to direct registry query if cache unavailable
            $allApps = @()
            $registryPaths = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
                'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            )
            
            foreach ($path in $registryPaths) {
                try {
                    $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                        Where-Object { $_.DisplayName -and $_.DisplayName -notmatch '^KB\d+' }
                    if ($apps) {
                        $allApps += $apps
                    }
                } catch {
                    Write-Verbose "Error querying registry path: $path"
                }
            }
        }
        
        foreach ($app in $allApps) {
            try {
                # Parse install date
                $installDate = $null
                if ($app.InstallDate) {
                    try {
                        if ($app.InstallDate -match '^\d{8}$') {
                            $installDate = [datetime]::ParseExact($app.InstallDate, 'yyyyMMdd', $null)
                        }
                    }
                    catch {
                        Write-Verbose "Could not parse install date: $($app.InstallDate)"
                    }
                }
                
                # Parse size (convert from KB to MB)
                $sizeMB = if ($app.EstimatedSize) { [math]::Round($app.EstimatedSize / 1024, 2) } else { 0 }
                
                $applications += [PSCustomObject]@{
                    Name = $app.DisplayName
                    Version = $app.DisplayVersion
                    Publisher = $app.Publisher
                    InstallDate = $installDate
                    InstallLocation = $app.InstallLocation
                    SizeMB = $sizeMB
                    UninstallString = $app.UninstallString
                    IsSystemComponent = if ($app.SystemComponent -eq 1) { $true } else { $false }
                }
            }
            catch {
                Write-Verbose "Failed to process app: $_"
            }
        }
        
        # Remove duplicates and sort
        $uniqueApps = $applications | Sort-Object Name -Unique
        
        # Calculate statistics
        $24HoursAgoInstalls = (Get-Date).AddHours(-24)
        $recentInstalls = @($uniqueApps | Where-Object { $_.InstallDate -and $_.InstallDate -gt $24HoursAgoInstalls })
        $largeApps = @($uniqueApps | Where-Object { $_.SizeMB -gt 1024 })
        $unknownPublisher = @($uniqueApps | Where-Object { -not $_.Publisher -or $_.Publisher -eq "Unknown" })
        
        return [PSCustomObject]@{
            Applications = $uniqueApps
            TotalCount = $uniqueApps.Count
            TotalSizeGB = [math]::Round(($uniqueApps | Measure-Object -Property SizeMB -Sum).Sum / 1024, 2)
            RecentInstalls = $recentInstalls
            LargeApplications = $largeApps
            UnknownPublisher = $unknownPublisher
            Publishers = @($uniqueApps | Group-Object Publisher | Sort-Object Count -Descending)
            Summary = [PSCustomObject]@{
                TotalApplications = $uniqueApps.Count
                TotalSizeGB = [math]::Round(($uniqueApps | Measure-Object -Property SizeMB -Sum).Sum / 1024, 2)
                RecentlyInstalled = $recentInstalls.Count
                PublisherCount = @($uniqueApps | Select-Object -ExpandProperty Publisher -Unique).Count
            }
        }
    }
    catch {
        Write-Warning "Failed to get installed applications: $_"
        return $null
    }
}

function Get-StartupPrograms {
    try {
        $startupItems = @()
        
        # Registry Run keys (system-wide only)
        $runKeys = @(
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Location = 'HKLM Run' }
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Location = 'HKLM RunOnce' }
            @{ Path = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'; Location = 'HKLM Run (32-bit)' }
        )
        
        foreach ($key in $runKeys) {
            try {
                if (Test-Path $key.Path) {
                    $items = Get-ItemProperty $key.Path -ErrorAction SilentlyContinue
                    $properties = $items.PSObject.Properties | Where-Object { 
                        $_.Name -notmatch '^PS' -and $_.Name -ne 'PSPath' -and $_.Name -ne 'PSParentPath' -and 
                        $_.Name -ne 'PSChildName' -and $_.Name -ne 'PSDrive' -and $_.Name -ne 'PSProvider'
                    }
                    
                    foreach ($prop in $properties) {
                        $startupItems += [PSCustomObject]@{
                            Name = $prop.Name
                            Command = $prop.Value
                            Location = $key.Location
                            Impact = "Medium"  # Registry items typically medium impact
                            Status = "Enabled"
                        }
                    }
                }
            }
            catch {
                Write-Verbose "Could not read registry key: $($key.Path)"
            }
        }
        
        # Startup folders
        $startupFolders = @(
            @{ Path = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"; Location = 'All Users Startup' }
            @{ Path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"; Location = 'User Startup' }
        )
        
        foreach ($folder in $startupFolders) {
            if (Test-Path $folder.Path) {
                $items = Get-ChildItem $folder.Path -ErrorAction SilentlyContinue
                foreach ($item in $items) {
                    $startupItems += [PSCustomObject]@{
                        Name = $item.BaseName
                        Command = $item.FullName
                        Location = $folder.Location
                        Impact = "Low"  # Folder items typically low impact
                        Status = "Enabled"
                    }
                }
            }
        }
        
        # Scheduled tasks that run at startup
        try {
            $startupTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | 
                Where-Object { $_.Triggers | Where-Object { $_.CimClass.CimClassName -match 'Boot|Logon' } }
            
            foreach ($task in $startupTasks) {
                $startupItems += [PSCustomObject]@{
                    Name = $task.TaskName
                    Command = $task.Actions[0].Execute
                    Location = "Scheduled Task"
                    Impact = if ($task.Settings.Priority -le 4) { "High" } 
                            elseif ($task.Settings.Priority -le 6) { "Medium" } 
                            else { "Low" }
                    Status = if ($task.State -eq 'Ready') { "Enabled" } else { $task.State }
                }
            }
        }
        catch {
            Write-Verbose "Could not get scheduled tasks: $_"
        }
        
        # Auto-start services
        $services = Get-CachedData -ClassName 'Win32_Service'
        $autoServices = @($services | Where-Object { 
            $_.StartMode -eq 'Auto' -and 
            $_.PathName -notmatch 'svchost|system32\\services' 
        } | Select-Object -First 10)
        
        foreach ($service in $autoServices) {
            $startupItems += [PSCustomObject]@{
                Name = $service.DisplayName
                Command = $service.PathName
                Location = "Service"
                Impact = if ($service.ProcessId) { "High" } else { "Medium" }
                Status = $service.State
            }
        }
        
        # Calculate summary
        $highImpact = @($startupItems | Where-Object { $_.Impact -eq "High" })
        $mediumImpact = @($startupItems | Where-Object { $_.Impact -eq "Medium" })
        $lowImpact = @($startupItems | Where-Object { $_.Impact -eq "Low" })
        
        # Get boot duration from event log if available
        $bootDuration = "N/A"
        try {
            $bootEvent = Get-WinEvent -FilterHashtable @{
                LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'
                ID = 100
            } -MaxEvents 1 -ErrorAction SilentlyContinue
            
            if ($bootEvent) {
                $xml = [xml]$bootEvent.ToXml()
                $bootTime = ($xml.Event.EventData.Data | Where-Object Name -eq 'BootTime').'#text'
                if ($bootTime) {
                    $bootDuration = [int]($bootTime / 1000)  # Convert ms to seconds
                }
            }
        }
        catch {
            Write-Verbose "Could not get boot duration"
        }
        
        return [PSCustomObject]@{
            Items = $startupItems
            Summary = [PSCustomObject]@{
                TotalCount = $startupItems.Count
                HighImpact = $highImpact.Count
                MediumImpact = $mediumImpact.Count
                LowImpact = $lowImpact.Count
                BootDuration = $bootDuration
                Status = if ($highImpact.Count -gt 5) { "Critical" }
                        elseif ($highImpact.Count -gt 3) { "Warning" }
                        elseif ($bootDuration -ne "N/A" -and $bootDuration -gt 180) { "Critical" }
                        elseif ($bootDuration -ne "N/A" -and $bootDuration -gt 120) { "Warning" }
                        else { "Healthy" }
            }
        }
    }
    catch {
        Write-Warning "Failed to get startup programs: $_"
        return $null
    }
}

function Get-LicenseStatus {
    try {
        $licenses = [PSCustomObject]@{
            Windows = $null
            Office = $null
        }
        
        # Get Windows license status
        try {
            $windowsLicense = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue | 
                             Select-Object -First 1
            
            if ($windowsLicense) {
                $licenses.Windows = [PSCustomObject]@{
                    Status = switch ($windowsLicense.LicenseStatus) {
                        0 { "Unlicensed" }
                        1 { "Licensed" }
                        2 { "OOBGrace" }
                        3 { "OOTGrace" }
                        4 { "NonGenuineGrace" }
                        5 { "Notification" }
                        6 { "ExtendedGrace" }
                        default { "Unknown" }
                    }
                    Edition = $windowsLicense.Description
                    PartialProductKey = $windowsLicense.PartialProductKey
                    GracePeriodRemaining = if ($windowsLicense.GracePeriodRemaining) {
                        [math]::Round($windowsLicense.GracePeriodRemaining / 1440, 0)  # Convert minutes to days
                    } else { 0 }
                    StatusColor = if ($windowsLicense.LicenseStatus -eq 1) { "Green" }
                                 elseif ($windowsLicense.LicenseStatus -in 2,3,6) { "Yellow" }
                                 else { "Red" }
                }
            }
        }
        catch {
            Write-Verbose "Could not get Windows license status: $_"
        }
        
        # Get Office license status
        try {
            $officeLicense = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='0ff1ce15-a989-479d-af46-f275c6370663' AND PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue | 
                            Select-Object -First 1
            
            if ($officeLicense) {
                $licenses.Office = [PSCustomObject]@{
                    Status = switch ($officeLicense.LicenseStatus) {
                        0 { "Unlicensed" }
                        1 { "Activated" }
                        2 { "Grace Period" }
                        3 { "Out of Tolerance Grace" }
                        4 { "Non-Genuine Grace" }
                        5 { "Notification" }
                        6 { "Extended Grace" }
                        default { "Unknown" }
                    }
                    Version = if ($officeLicense.Description -match 'Office (\d{4}|\d{3})') { $matches[1] } else { "Unknown" }
                    Type = if ($officeLicense.Description -match 'Retail') { "Retail" }
                          elseif ($officeLicense.Description -match 'Volume') { "Volume" }
                          elseif ($officeLicense.Description -match 'Subscription') { "Subscription" }
                          else { "Unknown" }
                    PartialProductKey = $officeLicense.PartialProductKey
                    StatusColor = if ($officeLicense.LicenseStatus -eq 1) { "Green" }
                                 elseif ($officeLicense.LicenseStatus -in 2,3,6) { "Yellow" }
                                 else { "Red" }
                }
            }
        }
        catch {
            Write-Verbose "Could not get Office license status: $_"
        }
        
        return $licenses
    }
    catch {
        Write-Warning "Failed to get license status: $_"
        return $null
    }
}

function Get-SoftwareHealthScore {
    param($SoftwareData)
    
    try {
        $score = 100
        $weights = @{
            Performance = 30
            Crashes = 25
            Startup = 20
            Applications = 15
            Licensing = 10
        }
        
        # Performance scoring (30%)
        if ($SoftwareData.Performance) {
            $perfScore = 100
            
            if ($SoftwareData.Performance.CPU.Status -eq "Critical") { $perfScore -= 40 }
            elseif ($SoftwareData.Performance.CPU.Status -eq "Warning") { $perfScore -= 20 }
            
            if ($SoftwareData.Performance.Memory.Status -eq "Critical") { $perfScore -= 40 }
            elseif ($SoftwareData.Performance.Memory.Status -eq "Warning") { $perfScore -= 20 }
            
            if ($SoftwareData.Performance.DiskQueue.Status -eq "Critical") { $perfScore -= 20 }
            elseif ($SoftwareData.Performance.DiskQueue.Status -eq "Warning") { $perfScore -= 10 }
            
            $score -= ($weights.Performance * (100 - $perfScore) / 100)
        }
        
        # Crash scoring (25%)
        if ($SoftwareData.ApplicationHealth) {
            $crashScore = 100
            if ($SoftwareData.ApplicationHealth.Summary.TotalCrashes72h -gt 5) { $crashScore = 40 }
            elseif ($SoftwareData.ApplicationHealth.Summary.TotalCrashes72h -gt 2) { $crashScore = 70 }
            
            $score -= ($weights.Crashes * (100 - $crashScore) / 100)
        }
        
        # Startup scoring (20%)
        if ($SoftwareData.StartupPrograms) {
            $startupScore = 100
            if ($SoftwareData.StartupPrograms.Summary.Status -eq "Critical") { $startupScore = 40 }
            elseif ($SoftwareData.StartupPrograms.Summary.Status -eq "Warning") { $startupScore = 70 }
            
            $score -= ($weights.Startup * (100 - $startupScore) / 100)
        }
        
        # Licensing scoring (10%)
        if ($SoftwareData.LicenseStatus) {
            $licenseScore = 100
            if ($SoftwareData.LicenseStatus.Windows -and $SoftwareData.LicenseStatus.Windows.Status -ne "Licensed") {
                $licenseScore -= 50
            }
            if ($SoftwareData.LicenseStatus.Office -and $SoftwareData.LicenseStatus.Office.Status -ne "Activated") {
                $licenseScore -= 30
            }
            
            $score -= ($weights.Licensing * (100 - $licenseScore) / 100)
        }
        
        return [math]::Round($score, 0)
    }
    catch {
        Write-Warning "Failed to calculate software health score: $_"
        return 0
    }
}

function Get-SoftwareSummary {
    param($SoftwareData)
    
    try {
        return [PSCustomObject]@{
            HealthScore = $SoftwareData.HealthScore
            PerformanceStatus = if ($SoftwareData.Performance) {
                if ($SoftwareData.Performance.CPU.Status -eq "Critical" -or 
                    $SoftwareData.Performance.Memory.Status -eq "Critical") { "Critical" }
                elseif ($SoftwareData.Performance.CPU.Status -eq "Warning" -or 
                        $SoftwareData.Performance.Memory.Status -eq "Warning") { "Warning" }
                else { "Normal" }
            } else { "Unknown" }
            ApplicationCount = if ($SoftwareData.InstalledApplications) { 
                $SoftwareData.InstalledApplications.TotalCount 
            } else { 0 }
            ApplicationIssues = if ($SoftwareData.ApplicationHealth) {
                $SoftwareData.ApplicationHealth.Summary.TotalCrashes72h +
                $SoftwareData.ApplicationHealth.Summary.TotalHangs72h
            } else { 0 }
            Crashes72h = if ($SoftwareData.ApplicationHealth) {
                $SoftwareData.ApplicationHealth.Summary.TotalCrashes72h
            } else { 0 }
            StartupImpact = if ($SoftwareData.StartupPrograms) {
                if ($SoftwareData.StartupPrograms.Summary.HighImpact -gt 5) { "High" }
                elseif ($SoftwareData.StartupPrograms.Summary.HighImpact -gt 3) { "Medium" }
                else { "Low" }
            } else { "Unknown" }
        }
    }
    catch {
        Write-Warning "Failed to create software summary: $_"
        return $null
    }
}