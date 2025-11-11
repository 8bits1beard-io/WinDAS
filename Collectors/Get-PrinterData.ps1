# Get-PrinterData.ps1
# Collect comprehensive printer and print queue data
# Author: Joshua Walderbach

function Get-PrinterData {
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$DataCache = $Global:DataCache
    )
    
    Write-ProgressStatus -Activity "Collecting Printer Data" -Status "Initializing"
    
    # Initialize printer data structure
    $printerData = [PSCustomObject]@{
        CollectedAt = Get-Date
        Summary = $null
        Printers = @()
        PrintQueue = @()
        SpoolerHealth = $null
        PrinterDrivers = @()
        NetworkPrinters = @()
        Issues = @()
        HealthStatus = "Unknown"
    }
    
    try {
        # Get printer inventory
        Write-ProgressStatus -Activity "Collecting Printer Data" -Status "Getting printer inventory" -PercentComplete 10
        $printers = Get-PrinterInventory
        $printerData.Printers = $printers
        
        # Get print job queue status
        Write-ProgressStatus -Activity "Collecting Printer Data" -Status "Checking print queues" -PercentComplete 30
        $printerData.PrintQueue = Get-PrintQueueStatus -Printers $printers
        
        # Get spooler health
        Write-ProgressStatus -Activity "Collecting Printer Data" -Status "Checking spooler service" -PercentComplete 50
        $printerData.SpoolerHealth = Get-SpoolerHealth -DataCache $DataCache
        
        # Get printer drivers
        Write-ProgressStatus -Activity "Collecting Printer Data" -Status "Getting printer drivers" -PercentComplete 60
        $printerData.PrinterDrivers = Get-PrinterDriverInfo
        
        # Check network printers
        Write-ProgressStatus -Activity "Collecting Printer Data" -Status "Testing network printers" -PercentComplete 75
        $printerData.NetworkPrinters = Get-NetworkPrinterStatus -Printers $printers
        
        # Identify issues
        Write-ProgressStatus -Activity "Collecting Printer Data" -Status "Analyzing printer issues" -PercentComplete 85
        $printerData.Issues = Get-PrinterIssues -PrinterData $printerData
        
        # Create summary
        Write-ProgressStatus -Activity "Collecting Printer Data" -Status "Creating summary" -PercentComplete 95
        $printerData.Summary = Get-PrinterSummary -PrinterData $printerData
        
        # Determine health status
        $printerData.HealthStatus = Get-PrinterHealthStatus -PrinterData $printerData
        
        Write-ProgressStatus -Activity "Collecting Printer Data" -Completed
    }
    catch {
        Write-Error "Failed to collect printer data: $_"
    }
    
    return $printerData
}

function Get-PrinterInventory {
    try {
        $installedPrinters = @()
        
        # Get all printers using Get-Printer (faster than CIM)
        $printers = Get-Printer -ErrorAction SilentlyContinue
        
        if (-not $printers) {
            Write-Verbose "No printers found"
            return @()
        }
        
        foreach ($printer in $printers) {
            # Map printer status to readable format
            $status = Get-PrinterStatusText -PrinterStatus $printer.PrinterStatus
            
            # Determine if printer is network or local
            $isNetwork = $false
            $serverName = $null
            $ipAddress = $null
            
            if ($printer.PortName) {
                if ($printer.PortName -match '^\\\\(.+?)\\' -or $printer.PortName -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
                    $isNetwork = $true
                    if ($printer.PortName -match '^\\\\(.+?)\\') {
                        $serverName = $matches[1]
                    } elseif ($printer.PortName -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
                        $ipAddress = $printer.PortName
                    }
                }
            }
            
            $printerInfo = [PSCustomObject]@{
                Name = $printer.Name
                Status = $status
                PrinterStatus = $printer.PrinterStatus
                IsDefault = $printer.Default
                IsShared = $printer.Shared
                ShareName = $printer.ShareName
                DriverName = $printer.DriverName
                PortName = $printer.PortName
                Location = $printer.Location
                Comment = $printer.Comment
                IsNetwork = $isNetwork
                ServerName = $serverName
                IPAddress = $ipAddress
                Type = if ($isNetwork) { "Network" } else { "Local" }
                JobCount = $printer.JobCount
                PrintProcessor = $printer.PrintProcessor
                Datatype = $printer.Datatype
                Priority = $printer.Priority
                KeepPrintedJobs = $printer.KeepPrintedJobs
            }
            
            $installedPrinters += $printerInfo
        }
        
        return $installedPrinters
    }
    catch {
        Write-Warning "Failed to get printer inventory: $_"
        return @()
    }
}

function Get-PrinterStatusText {
    param([int]$PrinterStatus)
    
    switch ($PrinterStatus) {
        0 { return "Ready" }
        1 { return "Paused" }
        2 { return "Error" }
        3 { return "Pending Deletion" }
        4 { return "Paper Jam" }
        5 { return "Paper Out" }
        6 { return "Manual Feed" }
        7 { return "Paper Problem" }
        8 { return "Offline" }
        9 { return "IO Active" }
        10 { return "Busy" }
        11 { return "Printing" }
        12 { return "Output Bin Full" }
        13 { return "Not Available" }
        14 { return "Waiting" }
        15 { return "Processing" }
        16 { return "Initializing" }
        17 { return "Warming Up" }
        18 { return "Toner Low" }
        19 { return "No Toner" }
        20 { return "Page Punt" }
        21 { return "User Intervention Required" }
        22 { return "Out of Memory" }
        23 { return "Door Open" }
        131072 { return "Driver Update Needed" }
        default { return "Unknown ($PrinterStatus)" }
    }
}

function Get-PrintQueueStatus {
    param($Printers)
    
    try {
        $allJobs = @()
        
        foreach ($printer in $Printers) {
            try {
                # Get print jobs for this printer
                $jobs = Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue
                
                foreach ($job in $jobs) {
                    $timeInQueue = if ($job.SubmittedTime) {
                        (Get-Date) - $job.SubmittedTime
                    } else { $null }
                    
                    $jobInfo = [PSCustomObject]@{
                        PrinterName = $printer.Name
                        JobId = $job.Id
                        DocumentName = $job.DocumentName
                        UserName = $job.UserName
                        Status = $job.JobStatus
                        SubmittedTime = $job.SubmittedTime
                        TimeInQueue = $timeInQueue
                        TimeInQueueMinutes = if ($timeInQueue) { [math]::Round($timeInQueue.TotalMinutes, 2) } else { 0 }
                        Size = $job.Size
                        SizeMB = if ($job.Size) { [math]::Round($job.Size / 1MB, 2) } else { 0 }
                        PagesPrinted = $job.PagesPrinted
                        TotalPages = $job.TotalPages
                        Priority = $job.Priority
                        Position = $job.Position
                        IsStuck = if ($timeInQueue -and $timeInQueue.TotalMinutes -gt 60) { $true } else { $false }
                        IsLarge = if ($job.Size -and $job.Size -gt 50MB) { $true } else { $false }
                    }
                    
                    $allJobs += $jobInfo
                }
            }
            catch {
                Write-Verbose "Could not get jobs for printer $($printer.Name): $_"
            }
        }
        
        # Sort by time in queue (oldest first)
        return $allJobs | Sort-Object TimeInQueueMinutes -Descending
    }
    catch {
        Write-Warning "Failed to get print queue status: $_"
        return @()
    }
}

function Get-SpoolerHealth {
    param($DataCache)
    
    try {
        $spoolerHealth = [PSCustomObject]@{
            ServiceStatus = "Unknown"
            ServiceState = $null
            MemoryUsageMB = 0
            SpoolFolderPath = "$env:windir\System32\spool\PRINTERS"
            SpoolFolderSizeMB = 0
            RecentCrashes = 0
            LastRestartTime = $null
            EventLogErrors = @()
        }
        
        # Get spooler service status - try cache first, then direct query
        $services = Get-CachedData -ClassName 'Win32_Service'
        $spooler = $services | Where-Object { $_.Name -eq 'Spooler' }
        
        # If not found in cache, query directly
        if (-not $spooler) {
            try {
                $spooler = Get-Service -Name 'Spooler' -ErrorAction SilentlyContinue
                if ($spooler) {
                    # Convert Get-Service output to match expected properties
                    $spoolerHealth.ServiceStatus = $spooler.Status.ToString()
                    $spoolerHealth.ServiceState = if ($spooler.Status -eq 'Running') { 'OK' } else { 'Stopped' }
                }
            }
            catch {
                Write-Verbose "Failed to query Spooler service directly: $_"
            }
        }
        else {
            $spoolerHealth.ServiceStatus = $spooler.State
            $spoolerHealth.ServiceState = $spooler.Status
            
            # Get process memory if running
            if ($spooler.State -eq 'Running' -and $spooler.ProcessId) {
                # Query process directly for current memory usage
                $spoolerProcess = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($spooler.ProcessId)" -ErrorAction SilentlyContinue
                if ($spoolerProcess) {
                    $spoolerHealth.MemoryUsageMB = [math]::Round($spoolerProcess.WorkingSetSize / 1MB, 2)
                }
            }
        }
        
        # Calculate spool folder size
        if (Test-Path $spoolerHealth.SpoolFolderPath) {
            try {
                $spoolSize = (Get-ChildItem $spoolerHealth.SpoolFolderPath -Recurse -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                $spoolerHealth.SpoolFolderSizeMB = if ($spoolSize) { [math]::Round($spoolSize / 1MB, 2) } else { 0 }
            }
            catch {
                Write-Verbose "Could not calculate spool folder size: $_"
            }
        }
        
        # Check for recent spooler crashes in event log
        try {
            $24HoursAgo = (Get-Date).AddHours(-24)
            $spoolerEvents = @(Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                ProviderName = 'Service Control Manager'
                StartTime = $24HoursAgo
            } -ErrorAction SilentlyContinue | Where-Object {
                $_.Message -like "*Print Spooler*" -and $_.Level -le 3
            })
            
            $spoolerHealth.RecentCrashes = @($spoolerEvents | Where-Object { 
                $_.Message -like "*terminated unexpectedly*" -or $_.Message -like "*failed*" 
            }).Count
            
            # Get last restart time
            $lastStart = $spoolerEvents | Where-Object { 
                $_.Message -like "*Print Spooler*entered the running state*" 
            } | Select-Object -First 1
            
            if ($lastStart) {
                $spoolerHealth.LastRestartTime = $lastStart.TimeCreated
            }
            
            # Get recent errors
            $spoolerHealth.EventLogErrors = @($spoolerEvents | Where-Object { $_.Level -le 2 } |
                                             Select-Object -First 5 | ForEach-Object {
                [PSCustomObject]@{
                    TimeCreated = $_.TimeCreated
                    Level = $_.LevelDisplayName
                    Message = ($_.Message -split "`n")[0]
                }
            })
        }
        catch {
            Write-Verbose "Could not get spooler event log data: $_"
        }
        
        return $spoolerHealth
    }
    catch {
        Write-Warning "Failed to get spooler health: $_"
        return $null
    }
}

function Get-PrinterDriverInfo {
    try {
        $drivers = @()
        
        # Get printer drivers using Get-PrinterDriver
        $printerDrivers = Get-PrinterDriver -ErrorAction SilentlyContinue
        
        foreach ($driver in $printerDrivers) {
            $driverAge = if ($driver.Date) {
                Get-AgeInDays -StartDate $driver.Date
            } else { $null }
            
            $drivers += [PSCustomObject]@{
                Name = $driver.Name
                Version = if ($driver.MajorVersion) { "$($driver.MajorVersion).$($driver.MinorVersion)" } else { "Unknown" }
                Date = $driver.Date
                AgeInDays = $driverAge
                Environment = $driver.PrinterEnvironment
                Provider = $driver.Provider
                InfPath = $driver.InfPath
                ConfigFile = $driver.ConfigFile
                DataFile = $driver.DataFile
                DriverPath = $driver.DriverPath
                PrintProcessor = $driver.PrintProcessor
                IsPackageAware = $driver.IsPackageAware
                AgeStatus = if ($driverAge) {
                    if ($driverAge -gt 730) { "Very Old" }
                    elseif ($driverAge -gt 365) { "Old" }
                    elseif ($driverAge -gt 180) { "Normal" }
                    else { "Current" }
                } else { "Unknown" }
            }
        }
        
        # Sort by age (oldest first)
        return $drivers | Sort-Object AgeInDays -Descending
    }
    catch {
        Write-Warning "Failed to get printer driver info: $_"
        return @()
    }
}

function Get-NetworkPrinterStatus {
    param($Printers)
    
    try {
        $networkPrinters = @()
        
        foreach ($printer in ($Printers | Where-Object IsNetwork)) {
            $connectivity = [PSCustomObject]@{
                PrinterName = $printer.Name
                ServerName = $printer.ServerName
                IPAddress = $printer.IPAddress
                Port = $printer.PortName
                ConnectionStatus = "Unknown"
                ResponseTime = $null
                LastTestTime = Get-Date
            }
            
            # Test connectivity
            $targetHost = if ($printer.IPAddress) { $printer.IPAddress } else { $printer.ServerName }
            
            if ($targetHost) {
                try {
                    Write-Verbose "Testing connectivity to $targetHost"
                    
                    # Suppress known errors and test connection
                    $testResult = Test-NetConnection -ComputerName $targetHost -Port 445 `
                                                    -WarningAction SilentlyContinue `
                                                    -ErrorAction SilentlyContinue 2>$null
                    
                    if ($testResult) {
                        $connectivity.ConnectionStatus = if ($testResult.TcpTestSucceeded) { "Connected" } else { "Failed" }
                        
                        if ($testResult.PingReplyDetails -and $testResult.PingReplyDetails.RoundtripTime) {
                            $connectivity.ResponseTime = "$($testResult.PingReplyDetails.RoundtripTime)ms"
                        }
                    } else {
                        $connectivity.ConnectionStatus = "Unreachable"
                    }
                }
                catch {
                    Write-Verbose "Connection test failed for $targetHost : $_"
                    $connectivity.ConnectionStatus = "Error"
                }
            }
            
            $networkPrinters += $connectivity
        }
        
        return $networkPrinters
    }
    catch {
        Write-Warning "Failed to get network printer status: $_"
        return @()
    }
}

function Get-PrinterIssues {
    param($PrinterData)
    
    try {
        $issues = @()
        
        # Check spooler status
        if ($PrinterData.SpoolerHealth) {
            if ($PrinterData.SpoolerHealth.ServiceStatus -ne 'Running') {
                $issues += [PSCustomObject]@{
                    Severity = "Critical"
                    Category = "Spooler"
                    Issue = "Print Spooler Stopped"
                    Description = "The print spooler service is not running"
                    Recommendation = "Start the Print Spooler service"
                }
            }
            
            if ($PrinterData.SpoolerHealth.RecentCrashes -gt 5) {
                $issues += [PSCustomObject]@{
                    Severity = "Critical"
                    Category = "Spooler"
                    Issue = "Frequent Spooler Crashes"
                    Description = "$($PrinterData.SpoolerHealth.RecentCrashes) crashes in last 48 hours"
                    Recommendation = "Investigate spooler stability issues"
                }
            } elseif ($PrinterData.SpoolerHealth.RecentCrashes -gt 2) {
                $issues += [PSCustomObject]@{
                    Severity = "Warning"
                    Category = "Spooler"
                    Issue = "Spooler Crashes Detected"
                    Description = "$($PrinterData.SpoolerHealth.RecentCrashes) crashes in last 48 hours"
                    Recommendation = "Monitor spooler stability"
                }
            }
            
            if ($PrinterData.SpoolerHealth.SpoolFolderSizeMB -gt 5120) {
                $issues += [PSCustomObject]@{
                    Severity = "Critical"
                    Category = "Spooler"
                    Issue = "Excessive Spool Folder Size"
                    Description = "Spool folder is $($PrinterData.SpoolerHealth.SpoolFolderSizeMB) MB"
                    Recommendation = "Clear old print jobs from spool folder"
                }
            } elseif ($PrinterData.SpoolerHealth.SpoolFolderSizeMB -gt 1024) {
                $issues += [PSCustomObject]@{
                    Severity = "Warning"
                    Category = "Spooler"
                    Issue = "Large Spool Folder"
                    Description = "Spool folder is $($PrinterData.SpoolerHealth.SpoolFolderSizeMB) MB"
                    Recommendation = "Consider clearing spool folder"
                }
            }
        }
        
        # Check for offline printers
        $offlinePrinters = @($PrinterData.Printers | Where-Object { $_.Status -eq "Offline" })
        if ($offlinePrinters.Count -eq $PrinterData.Printers.Count -and $PrinterData.Printers.Count -gt 0) {
            $issues += [PSCustomObject]@{
                Severity = "Critical"
                Category = "Printers"
                Issue = "All Printers Offline"
                Description = "All $($offlinePrinters.Count) printers are offline"
                Recommendation = "Check printer connections and power"
            }
        } elseif ($offlinePrinters.Count -gt 0) {
            $issues += [PSCustomObject]@{
                Severity = "Warning"
                Category = "Printers"
                Issue = "Printers Offline"
                Description = "$($offlinePrinters.Count) printer(s) offline: $($offlinePrinters.Name -join ', ')"
                Recommendation = "Check printer connections"
            }
        }
        
        # Check for stuck jobs
        $stuckJobs = @($PrinterData.PrintQueue | Where-Object IsStuck)
        if ($stuckJobs.Count -gt 0) {
            $issues += [PSCustomObject]@{
                Severity = "Critical"
                Category = "Queue"
                Issue = "Stuck Print Jobs"
                Description = "$($stuckJobs.Count) job(s) stuck for >60 minutes"
                Recommendation = "Clear stuck jobs or restart spooler"
            }
        }
        
        # Check for jobs in queue warning
        $jobsInQueue = @($PrinterData.PrintQueue | Where-Object { $_.TimeInQueueMinutes -gt 30 -and -not $_.IsStuck })
        if ($jobsInQueue.Count -gt 0) {
            $issues += [PSCustomObject]@{
                Severity = "Warning"
                Category = "Queue"
                Issue = "Slow Print Queue"
                Description = "$($jobsInQueue.Count) job(s) waiting >30 minutes"
                Recommendation = "Check printer status and connectivity"
            }
        }
        
        # Check for old drivers
        $oldDrivers = @($PrinterData.PrinterDrivers | Where-Object { $_.AgeStatus -eq "Very Old" })
        if ($oldDrivers.Count -gt 0) {
            $issues += [PSCustomObject]@{
                Severity = "Warning"
                Category = "Drivers"
                Issue = "Outdated Printer Drivers"
                Description = "$($oldDrivers.Count) driver(s) >2 years old"
                Recommendation = "Update printer drivers"
            }
        }
        
        # Check for error status printers
        $errorPrinters = @($PrinterData.Printers | Where-Object { $_.Status -in @("Error", "Paper Jam", "No Toner", "Door Open") })
        if ($errorPrinters.Count -gt 0) {
            foreach ($errorPrinter in $errorPrinters) {
                $issues += [PSCustomObject]@{
                    Severity = "Critical"
                    Category = "Printers"
                    Issue = "Printer Error"
                    Description = "$($errorPrinter.Name): $($errorPrinter.Status)"
                    Recommendation = "Check printer and resolve error condition"
                }
            }
        }
        
        return $issues
    }
    catch {
        Write-Warning "Failed to identify printer issues: $_"
        return @()
    }
}

function Get-PrinterSummary {
    param($PrinterData)
    
    try {
        $totalPrinters = $PrinterData.Printers.Count
        $onlinePrinters = @($PrinterData.Printers | Where-Object { $_.Status -eq "Ready" }).Count
        $offlinePrinters = @($PrinterData.Printers | Where-Object { $_.Status -eq "Offline" }).Count
        $errorPrinters = @($PrinterData.Printers | Where-Object { $_.Status -in @("Error", "Paper Jam", "No Toner") }).Count
        
        return [PSCustomObject]@{
            TotalPrinters = $totalPrinters
            OnlinePrinters = $onlinePrinters
            OfflinePrinters = $offlinePrinters
            ErrorPrinters = $errorPrinters
            DefaultPrinter = ($PrinterData.Printers | Where-Object IsDefault).Name
            TotalPrintJobs = $PrinterData.PrintQueue.Count
            StuckJobs = @($PrinterData.PrintQueue | Where-Object IsStuck).Count
            SpoolerStatus = if ($PrinterData.SpoolerHealth) { $PrinterData.SpoolerHealth.ServiceStatus } else { "Unknown" }
            TotalDrivers = $PrinterData.PrinterDrivers.Count
            OutdatedDrivers = @($PrinterData.PrinterDrivers | Where-Object { $_.AgeStatus -in @("Old", "Very Old") }).Count
            NetworkPrinters = @($PrinterData.Printers | Where-Object IsNetwork).Count
            LocalPrinters = @($PrinterData.Printers | Where-Object { -not $_.IsNetwork }).Count
            CriticalIssues = @($PrinterData.Issues | Where-Object { $_.Severity -eq "Critical" }).Count
            WarningIssues = @($PrinterData.Issues | Where-Object { $_.Severity -eq "Warning" }).Count
        }
    }
    catch {
        Write-Warning "Failed to create printer summary: $_"
        return $null
    }
}

function Get-PrinterHealthStatus {
    param($PrinterData)
    
    try {
        # Start with healthy
        $status = "Healthy"
        
        # Check for critical issues
        if ($PrinterData.Summary.CriticalIssues -gt 0) {
            return "Critical"
        }
        
        # Check spooler status
        if ($PrinterData.SpoolerHealth -and $PrinterData.SpoolerHealth.ServiceStatus -ne 'Running') {
            return "Critical"
        }
        
        # Check if all printers offline
        if ($PrinterData.Summary.TotalPrinters -gt 0 -and 
            $PrinterData.Summary.OnlinePrinters -eq 0) {
            return "Critical"
        }
        
        # Check for stuck jobs
        if ($PrinterData.Summary.StuckJobs -gt 0) {
            return "Critical"
        }
        
        # Check for warnings
        if ($PrinterData.Summary.WarningIssues -gt 0) {
            $status = "Warning"
        }
        
        if ($PrinterData.Summary.OfflinePrinters -gt 0) {
            $status = "Warning"
        }
        
        if ($PrinterData.Summary.OutdatedDrivers -gt 0) {
            $status = "Warning"
        }
        
        return $status
    }
    catch {
        Write-Warning "Failed to determine printer health status: $_"
        return "Unknown"
    }
}