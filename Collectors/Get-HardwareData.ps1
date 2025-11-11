# Get-HardwareData.ps1
# Collect comprehensive hardware health and status data
# Author: Joshua Walderbach

function Get-HardwareData {
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$DataCache = $Global:DataCache,

        [Parameter()]
        [bool]$SkipDiskTest = $false
    )
    
    Write-ProgressStatus -Activity "Collecting Hardware Data" -Status "Initializing" -Component "Hardware"
    Write-CollectorLog -Message "Starting hardware data collection" -Component "Hardware"
    
    # Initialize hardware data structure
    $hardwareData = [PSCustomObject]@{
        CollectedAt = Get-Date
        CPU = $null
        Memory = $null
        Storage = $null
        Graphics = $null
        SystemBoard = $null
        Power = $null
        USB = $null
        Audio = $null
        HealthScore = 0
    }
    
    try {
        # Process CPU data
        Write-ProgressStatus -Activity "Collecting Hardware Data" -Status "Processing CPU information" -PercentComplete 10 -Component "Hardware"
        Write-CollectorLog -Message "Processing CPU information" -Component "Hardware-CPU"
        $hardwareData.CPU = Get-CPUData -DataCache $DataCache
        Write-CollectorLog -Message "CPU data collected" -Component "Hardware-CPU" -Data $hardwareData.CPU
        
        # Process Memory data
        Write-ProgressStatus -Activity "Collecting Hardware Data" -Status "Processing memory information" -PercentComplete 20 -Component "Hardware"
        Write-CollectorLog -Message "Processing memory information" -Component "Hardware-Memory"
        $hardwareData.Memory = Get-MemoryData -DataCache $DataCache
        Write-CollectorLog -Message "Memory data collected" -Component "Hardware-Memory" -Data $hardwareData.Memory
        
        # Process Storage data with SMART
        Write-ProgressStatus -Activity "Collecting Hardware Data" -Status "Processing storage and SMART data" -PercentComplete 30 -Component "Hardware"
        Write-CollectorLog -Message "Processing storage and SMART data" -Component "Hardware-Storage"
        $hardwareData.Storage = Get-StorageData -DataCache $DataCache
        Write-CollectorLog -Message "Storage data collected: $($hardwareData.Storage.Disks.Count) disks found" -Component "Hardware-Storage"
        
        # Process Graphics data
        Write-ProgressStatus -Activity "Collecting Hardware Data" -Status "Processing graphics information" -PercentComplete 50
        $hardwareData.Graphics = Get-GraphicsData -DataCache $DataCache
        
        # Process System Board data
        Write-ProgressStatus -Activity "Collecting Hardware Data" -Status "Processing system board information" -PercentComplete 60
        $hardwareData.SystemBoard = Get-SystemBoardData -DataCache $DataCache
        
        # Process Power and Battery data
        Write-ProgressStatus -Activity "Collecting Hardware Data" -Status "Processing power and battery information" -PercentComplete 70
        $hardwareData.Power = Get-PowerData -DataCache $DataCache
        
        # Process USB data
        Write-ProgressStatus -Activity "Collecting Hardware Data" -Status "Processing USB information" -PercentComplete 80
        $hardwareData.USB = Get-USBData -DataCache $DataCache
        
        # Process Audio data
        Write-ProgressStatus -Activity "Collecting Hardware Data" -Status "Processing audio information" -PercentComplete 85
        $hardwareData.Audio = Get-AudioData -DataCache $DataCache
        
        # Calculate health score
        Write-ProgressStatus -Activity "Collecting Hardware Data" -Status "Calculating health score" -PercentComplete 95
        $hardwareData.HealthScore = Get-HardwareHealthScore -HardwareData $hardwareData
        
        Write-CollectorLog -Message "Hardware data collection completed successfully" -Component "Hardware" -Level "SUCCESS"
        Write-ProgressStatus -Activity "Collecting Hardware Data" -Completed -Component "Hardware"
    }
    catch {
        Write-Error "Failed to collect hardware data: $_"
        Write-CollectorLog -Message "Failed to collect hardware data: $_" -Level "ERROR" -Component "Hardware"
    }
    
    return $hardwareData
}

function Get-CPUData {
    param($DataCache)
    
    Write-CollectorLog -Message "Getting CPU data" -Component "Hardware-CPU"
    try {
        # Use direct query to avoid cache issues in parallel jobs
        Write-CollectorLog -Message "Querying Win32_Processor" -Component "Hardware-CPU"
        $processors = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
        if (-not $processors) { return $null }
        
        $cpu = $processors | Select-Object -First 1
        
        # Get current performance data
        $cpuCounter = $null
        try {
            Write-CollectorLog -Message "Getting CPU performance counter" -Component "Hardware-CPU"
            $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
            $cpuUsage = [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)
            Write-CollectorLog -Message "Current CPU usage: $cpuUsage%" -Component "Hardware-CPU"
        }
        catch {
            $cpuUsage = "N/A"
            Write-CollectorLog -Message "Could not get CPU performance counter" -Component "Hardware-CPU"
        }

        # Check for throttling
        $currentSpeed = $cpu.CurrentClockSpeed
        $maxSpeed = $cpu.MaxClockSpeed
        $isThrottling = if ($maxSpeed -gt 0) { ($currentSpeed / $maxSpeed) -lt 0.95 } else { $false }
        
        return [PSCustomObject]@{
            Model = $cpu.Name
            Manufacturer = $cpu.Manufacturer
            PhysicalCores = $cpu.NumberOfCores
            LogicalProcessors = $cpu.NumberOfLogicalProcessors
            CurrentSpeed = [math]::Round($currentSpeed / 1000, 2)  # Convert to GHz
            BaseSpeed = [math]::Round($cpu.MaxClockSpeed / 1000, 2)
            MaxSpeed = [math]::Round($cpu.MaxClockSpeed / 1000, 2)
            CurrentUtilization = $cpuUsage
            Throttling = $isThrottling
            L2CacheSize = Convert-BytesToSize -Bytes ($cpu.L2CacheSize * 1KB)
            L3CacheSize = Convert-BytesToSize -Bytes ($cpu.L3CacheSize * 1KB)
            Status = if ($cpuUsage -ne "N/A") {
                Get-StatusFromThreshold -Value $cpuUsage -WarningThreshold 80 -CriticalThreshold 95
            } else { "Unknown" }
        }
    }
    catch {
        Write-Warning "Failed to get CPU data: $_"
        return $null
    }
}

# CPU Temperature function removed - inconsistent support across Dell/HP/Lenovo systems

function Get-MemoryData {
    param($DataCache)
    
    try {
        # Use direct queries to avoid cache issues in parallel jobs
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        $physicalMemory = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue
        
        if (-not $os -or -not $cs) { return $null }
        
        $totalMemoryGB = if ($cs.TotalPhysicalMemory -and $cs.TotalPhysicalMemory -gt 0) {
            [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        } else { 0 }
        
        $availableMemoryGB = if ($os.FreePhysicalMemory -and $os.FreePhysicalMemory -gt 0) {
            [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        } else { 0 }
        
        $usedMemoryGB = if ($totalMemoryGB -gt 0) { $totalMemoryGB - $availableMemoryGB } else { 0 }
        
        $percentFree = if ($totalMemoryGB -gt 0) {
            [math]::Round(($availableMemoryGB / $totalMemoryGB) * 100, 2)
        } else { 0 }
        
        # Get memory pressure (pages/sec)
        $memoryPressure = "N/A"
        try {
            $pagesCounter = Get-Counter '\Memory\Pages/sec' -ErrorAction SilentlyContinue
            $memoryPressure = [math]::Round($pagesCounter.CounterSamples[0].CookedValue, 2)
        }
        catch {
            Write-Verbose "Could not get memory pressure data"
        }
        
        # Get top memory consumers - query directly for current state
        $processes = Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue
        $topMemory = @($processes | Sort-Object WorkingSetSize -Descending | Select-Object -First 5 | ForEach-Object {
            [PSCustomObject]@{
                Process = $_.Name
                MemoryGB = [math]::Round($_.WorkingSetSize / 1GB, 2)
            }
        })

        # Get top CPU consumers
        $topCPU = @()
        try {
            # Get process CPU usage - this requires a bit more work
            $processCounters = Get-Counter '\Process(*)\% Processor Time' -ErrorAction SilentlyContinue
            if ($processCounters) {
                $cpuData = $processCounters.CounterSamples |
                    Where-Object { $_.InstanceName -ne '_total' -and $_.InstanceName -ne 'idle' } |
                    Sort-Object CookedValue -Descending |
                    Select-Object -First 5

                $topCPU = @($cpuData | ForEach-Object {
                    [PSCustomObject]@{
                        Process = $_.InstanceName
                        CPUPercent = [math]::Round($_.CookedValue, 2)
                    }
                })
            }
        }
        catch {
            Write-Verbose "Could not get CPU performance counters"
            # Fallback to getting processes by CPU time
            $topCPU = @($processes | Sort-Object {$_.KernelModeTime + $_.UserModeTime} -Descending | Select-Object -First 5 | ForEach-Object {
                [PSCustomObject]@{
                    Process = $_.Name
                    Runtime = "$([math]::Round(($_.KernelModeTime + $_.UserModeTime) / 10000000 / 60, 0)) min"
                }
            })
        }

        # Process memory modules
        $memoryModules = @($physicalMemory | ForEach-Object {
            [PSCustomObject]@{
                Manufacturer = $_.Manufacturer
                CapacityGB = [math]::Round($_.Capacity / 1GB, 2)
                Speed = $_.Speed
                Type = switch ($_.SMBIOSMemoryType) {
                    20 { "DDR" }
                    21 { "DDR2" }
                    24 { "DDR3" }
                    26 { "DDR4" }
                    34 { "DDR5" }
                    default { "Unknown" }
                }
                FormFactor = switch ($_.FormFactor) {
                    8 { "DIMM" }
                    12 { "SODIMM" }
                    default { "Unknown" }
                }
            }
        })
        
        return [PSCustomObject]@{
            TotalGB = $totalMemoryGB
            AvailableGB = $availableMemoryGB
            UsedGB = $usedMemoryGB
            PercentFree = $percentFree
            SlotsUsed = @($physicalMemory).Count
            TotalSlots = if ($cs.NumberOfMemorySlots) { 
                $cs.NumberOfMemorySlots 
            } else {
                # Fallback to PhysicalMemoryArray if ComputerSystem doesn't have it
                $memArray = Get-CimInstance -ClassName Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue
                if ($memArray -and $memArray.MemoryDevices) { $memArray.MemoryDevices } else { $null }
            }
            Type = if ($memoryModules.Count -gt 0) { $memoryModules[0].Type } else { "Unknown" }
            Speed = if ($memoryModules.Count -gt 0) { "$($memoryModules[0].Speed) MHz" } else { "Unknown" }
            ECCSupport = $cs.TotalPhysicalMemorySupportsECC
            MemoryPressure = $memoryPressure
            Modules = $memoryModules
            TopConsumers = $topMemory
            TopCPUConsumers = $topCPU
            Status = Get-StatusFromThreshold -Value $percentFree -WarningThreshold 20 -CriticalThreshold 10 -Reverse
        }
    }
    catch {
        Write-Warning "Failed to get memory data: $_"
        return $null
    }
}

function Get-StorageData {
    param($DataCache)
    
    try {
        # Use direct query to avoid cache issues in parallel jobs
        $logicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction SilentlyContinue
        $storageDevices = @()
        
        # Get physical disks with SMART data
        try {
            $physicalDisks = Get-PhysicalDisk -ErrorAction SilentlyContinue
            
            foreach ($disk in $physicalDisks) {
                $smartData = Get-StorageReliabilityCounter -PhysicalDisk $disk -ErrorAction SilentlyContinue
                
                # For NVMe/physical disks, we'll use the disk size directly
                # Finding the exact logical disk mapping is complex and unreliable
                $totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)
                
                # Try to find total used space across all fixed logical disks
                $totalLogicalUsed = 0
                $totalLogicalSize = 0
                $logicalFixedDisks = $logicalDisks | Where-Object { $_.DriveType -eq 3 }
                foreach ($ld in $logicalFixedDisks) {
                    $totalLogicalSize += $ld.Size
                    $totalLogicalUsed += ($ld.Size - $ld.FreeSpace)
                }
                
                # If we have logical disk info, calculate proportional usage
                if ($totalLogicalSize -gt 0) {
                    $usageRatio = $totalLogicalUsed / $totalLogicalSize
                    $usedSpaceGB = [math]::Round($totalSpaceGB * $usageRatio, 2)
                    $freeSpaceGB = [math]::Round($totalSpaceGB - $usedSpaceGB, 2)
                } else {
                    # Fallback if no logical disk info
                    $freeSpaceGB = 0
                    $usedSpaceGB = $totalSpaceGB
                }
                $percentFree = if ($totalSpaceGB -gt 0) { [math]::Round(($freeSpaceGB / $totalSpaceGB) * 100, 2) } else { 0 }
                
                # Determine more specific drive type
                $driveType = switch ($disk.BusType) {
                    'NVMe' { 'NVMe SSD' }
                    'SATA' { if ($disk.MediaType -eq 'SSD') { 'SATA SSD' } else { $disk.MediaType } }
                    'USB' { "USB $($disk.MediaType)" }
                    default { $disk.MediaType }
                }
                
                # Try to run a simple performance test
                $readSpeed = "Not tested"
                $writeSpeed = "Not tested"

                # Try to find the system drive for testing (skip if SkipDiskTest is enabled)
                $systemDrive = $env:SystemDrive
                if ($systemDrive -and -not $SkipDiskTest) {
                    try {
                        Write-CollectorLog -Message "Running disk speed test (100MB)" -Component "Hardware"
                        # Use a smaller test file for speed
                        $testFile = "$systemDrive\windas_speedtest_$(Get-Random).tmp"
                        $testSizeMB = 100  # 100MB test file

                        # Create test data
                        $data = New-Object byte[] (1MB)
                        $random = New-Object System.Random
                        $random.NextBytes($data)

                        # Test write speed
                        $writeStart = Get-Date
                        $stream = [System.IO.File]::OpenWrite($testFile)
                        for ($i = 0; $i -lt $testSizeMB; $i++) {
                            $stream.Write($data, 0, $data.Length)
                        }
                        $stream.Flush()
                        $stream.Close()
                        $writeTime = (Get-Date) - $writeStart

                        if ($writeTime.TotalSeconds -gt 0) {
                            $writeMBps = [math]::Round($testSizeMB / $writeTime.TotalSeconds, 0)
                            $writeSpeed = "$writeMBps MB/s"
                        }

                        # Test read speed
                        # Clear file cache
                        [System.GC]::Collect()
                        [System.GC]::WaitForPendingFinalizers()

                        $readStart = Get-Date
                        $stream = [System.IO.File]::OpenRead($testFile)
                        $buffer = New-Object byte[] (1MB)
                        while ($stream.Read($buffer, 0, $buffer.Length) -gt 0) {
                            # Just read through the file
                        }
                        $stream.Close()
                        $readTime = (Get-Date) - $readStart

                        if ($readTime.TotalSeconds -gt 0) {
                            $readMBps = [math]::Round($testSizeMB / $readTime.TotalSeconds, 0)
                            $readSpeed = "$readMBps MB/s"
                        }

                        # Clean up test file
                        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                        Write-CollectorLog -Message "Disk speed test completed: Read=$readSpeed, Write=$writeSpeed" -Component "Hardware"

                    } catch {
                        Write-Verbose "Speed test failed: $_"
                        Write-CollectorLog -Message "Disk speed test failed: $_" -Level "WARNING" -Component "Hardware"
                        # Fall back to disk type estimates if test fails
                        switch ($disk.BusType) {
                            'NVMe' { $readSpeed = "~3500 MB/s"; $writeSpeed = "~3000 MB/s" }
                            'SATA' {
                                if ($disk.MediaType -eq 'SSD') {
                                    $readSpeed = "~550 MB/s"; $writeSpeed = "~520 MB/s"
                                } else {
                                    $readSpeed = "~150 MB/s"; $writeSpeed = "~150 MB/s"
                                }
                            }
                            default { 
                                $readSpeed = "Not tested"
                                $writeSpeed = "Not tested"
                            }
                        }
                    }
                } elseif ($SkipDiskTest) {
                    # Disk speed test was skipped via parameter
                    Write-CollectorLog -Message "Disk speed test skipped (SkipDiskTest parameter)" -Component "Hardware"
                    $readSpeed = "Skipped"
                    $writeSpeed = "Skipped"
                } else {
                    # Can't test without system drive access
                    $readSpeed = "Not tested"
                    $writeSpeed = "Not tested"
                }
                
                # Check TRIM status for SSDs
                $trimStatus = "N/A"
                $trimSupported = $false
                $trimEnabled = $false
                
                # Check if this is an SSD (includes NVMe SSD, SATA SSD, etc.)
                if ($disk.MediaType -eq 'SSD' -or $disk.BusType -eq 'NVMe') {
                    try {
                        # Check filesystem support for TRIM
                        $fsutilOutput = & fsutil behavior query DisableDeleteNotify 2>$null
                        if ($fsutilOutput) {
                            # DisableDeleteNotify = 0 means TRIM is enabled
                            # DisableDeleteNotify = 1 means TRIM is disabled  
                            # Note: On newer Windows, there might be separate values for NTFS and ReFS
                            if ($fsutilOutput -match "NTFS DisableDeleteNotify\s*=\s*0|DisableDeleteNotify\s*=\s*0") {
                                $trimEnabled = $true
                                $trimStatus = "Enabled"
                                $trimSupported = $true
                            } elseif ($fsutilOutput -match "NTFS DisableDeleteNotify\s*=\s*1|DisableDeleteNotify\s*=\s*1") {
                                $trimEnabled = $false
                                $trimStatus = "Disabled"
                                $trimSupported = $true
                            }
                        }
                    } catch {
                        Write-Verbose "Could not check TRIM status: $_"
                    }
                }

                # Build SMARTDetails object if we have SMART data
                $smartDetails = $null
                if ($smartData) {
                    $smartDetails = @{}

                    # Add available SMART attributes
                    # Temperature (include even if 0, as 0 might be valid for some devices)
                    if ($null -ne $smartData.Temperature) {
                        $smartDetails["Temperature"] = "$($smartData.Temperature)°C"
                    }
                    if ($null -ne $smartData.TemperatureMax) {
                        $smartDetails["Max Temperature"] = "$($smartData.TemperatureMax)°C"
                    }

                    # Power-on time
                    if ($smartData.PowerOnHours) {
                        $smartDetails["Power-On Hours"] = "{0:N0}" -f $smartData.PowerOnHours
                        $smartDetails["Power-On Days"] = "{0:N0}" -f [math]::Round($smartData.PowerOnHours / 24, 0)
                    }

                    # SSD Wear (include 0 as it means no wear)
                    if ($null -ne $smartData.Wear -and ($disk.MediaType -eq 'SSD' -or $disk.BusType -eq 'NVMe')) {
                        $smartDetails["SSD Wear Level"] = "$($smartData.Wear)%"
                    }

                    # Error counts
                    if ($smartData.ReadErrorsTotal) {
                        $smartDetails["Total Read Errors"] = $smartData.ReadErrorsTotal
                    }
                    if ($smartData.WriteErrorsTotal) {
                        $smartDetails["Total Write Errors"] = $smartData.WriteErrorsTotal
                    }
                    if ($smartData.ReadErrorsUncorrected) {
                        $smartDetails["Uncorrected Read Errors"] = $smartData.ReadErrorsUncorrected
                    }
                    if ($smartData.WriteErrorsUncorrected) {
                        $smartDetails["Uncorrected Write Errors"] = $smartData.WriteErrorsUncorrected
                    }

                    # Cycle counts
                    if ($smartData.StartStopCycleCount) {
                        $smartDetails["Start/Stop Cycles"] = $smartData.StartStopCycleCount
                    }
                    if ($smartData.LoadUnloadCycleCount) {
                        $smartDetails["Load/Unload Cycles"] = $smartData.LoadUnloadCycleCount
                    }

                    # Latency metrics (important for performance monitoring)
                    if ($null -ne $smartData.FlushLatencyMax) {
                        $smartDetails["Max Flush Latency"] = "$($smartData.FlushLatencyMax) ms"
                    }
                    if ($null -ne $smartData.ReadLatencyMax) {
                        $smartDetails["Max Read Latency"] = "$($smartData.ReadLatencyMax) ms"
                    }
                    if ($null -ne $smartData.WriteLatencyMax) {
                        $smartDetails["Max Write Latency"] = "$($smartData.WriteLatencyMax) ms"
                    }

                    # Only include SMARTDetails if we have any data
                    if ($smartDetails.Count -eq 0) {
                        $smartDetails = $null
                    }
                }

                $deviceData = [PSCustomObject]@{
                    Model = $disk.FriendlyName
                    DeviceID = "Disk $($disk.DeviceId)"  # Add disk identifier
                    SerialNumber = $disk.SerialNumber
                    MediaType = $driveType
                    BusType = $disk.BusType
                    HealthStatus = $disk.HealthStatus
                    OperationalStatus = $disk.OperationalStatus
                    SizeGB = [math]::Round($disk.Size / 1GB, 2)
                    FreeSpaceGB = $freeSpaceGB
                    UsedSpaceGB = $usedSpaceGB
                    PercentFree = $percentFree
                    Temperature = if ($smartData.Temperature) { $smartData.Temperature } else { "N/A" }
                    PowerOnHours = if ($smartData.PowerOnHours) { [math]::Round($smartData.PowerOnHours / 24, 0) } else { "N/A" }
                    WearLevel = if ($smartData.Wear -and ($disk.MediaType -eq 'SSD' -or $disk.BusType -eq 'NVMe')) { $smartData.Wear } else { "N/A" }
                    ReadSpeed = $readSpeed
                    WriteSpeed = $writeSpeed
                    ReadErrors = if ($smartData.ReadErrorsTotal) { $smartData.ReadErrorsTotal } else { 0 }
                    WriteErrors = if ($smartData.WriteErrorsTotal) { $smartData.WriteErrorsTotal } else { 0 }
                    ReallocatedSectors = if ($smartData.ReallocatedSectors) { $smartData.ReallocatedSectors } else { 0 }
                    TrimStatus = $trimStatus
                    TrimSupported = $trimSupported
                    TrimEnabled = $trimEnabled
                    SMARTDetails = $smartDetails
                    Status = "Healthy"  # Will be updated below
                }
                
                # Determine status based on thresholds
                $status = "Healthy"
                if ($disk.HealthStatus -and $disk.HealthStatus -notin @("Healthy", "OK", "Normal")) {
                    $status = "Critical"
                } elseif ($deviceData.ReallocatedSectors -gt 0) {
                    $status = "Critical"
                } elseif ($deviceData.WearLevel -ne "N/A" -and $deviceData.WearLevel -gt 80) {
                    $status = "Critical"
                } elseif ($percentFree -lt 10) {
                    $status = "Critical"
                } elseif ($deviceData.WearLevel -ne "N/A" -and $deviceData.WearLevel -gt 70) {
                    $status = "Warning"
                } elseif ($percentFree -lt 20) {
                    $status = "Warning"
                } elseif ($deviceData.Temperature -ne "N/A" -and $deviceData.Temperature -gt 50) {
                    $status = "Warning"
                }
                
                $deviceData.Status = $status
                $storageDevices += $deviceData
            }
        }
        catch {
            Write-Warning "Failed to get physical disk SMART data: $_"
            
            # Fallback to logical disks only
            foreach ($logical in ($logicalDisks | Where-Object { $_.DriveType -eq 3 })) {
                $freeSpaceGB = [math]::Round($logical.FreeSpace / 1GB, 2)
                $totalSpaceGB = [math]::Round($logical.Size / 1GB, 2)
                $usedSpaceGB = $totalSpaceGB - $freeSpaceGB
                $percentFree = [math]::Round(($freeSpaceGB / $totalSpaceGB) * 100, 2)
                
                $storageDevices += [PSCustomObject]@{
                    Model = "$($logical.DeviceID) Drive"
                    MediaType = "Unknown"
                    SizeGB = $totalSpaceGB
                    FreeSpaceGB = $freeSpaceGB
                    UsedSpaceGB = $usedSpaceGB
                    PercentFree = $percentFree
                    Status = Get-StatusFromThreshold -Value $percentFree -WarningThreshold 20 -CriticalThreshold 10 -Reverse
                }
            }
        }
        
        return [PSCustomObject]@{
            Devices = $storageDevices
            TotalDevices = $storageDevices.Count
            CriticalDevices = @($storageDevices | Where-Object { $_.Status -eq "Critical" }).Count
            WarningDevices = @($storageDevices | Where-Object { $_.Status -eq "Warning" }).Count
        }
    }
    catch {
        Write-Warning "Failed to get storage data: $_"
        return $null
    }
}

function Get-GraphicsData {
    param($DataCache)
    
    try {
        # Use direct query to avoid cache issues in parallel jobs
        $videoControllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
        if (-not $videoControllers) { return $null }
        
        $gpuDevices = @($videoControllers | ForEach-Object {
            # AdapterRAM can be wrong for cards > 4GB due to 32-bit integer overflow
            # Win32_VideoController has a known limitation with AdapterRAM being a 32-bit value
            $vramGB = if ($_.AdapterRAM -and $_.AdapterRAM -gt 0) { 
                $ramBytes = [int64]$_.AdapterRAM
                Write-Verbose "GPU: $($_.Name), AdapterRAM bytes: $ramBytes"
                
                # Check if it's at or near 4GB (likely overflow)
                # 4294967296 = exactly 4GB, but sometimes it's slightly less
                if ($ramBytes -ge 4293918720 -and $ramBytes -le 4294967296) {
                    Write-Verbose "Detected 4GB limit, checking GPU model for actual VRAM"
                    # For NVIDIA cards, try to parse from the Name
                    if ($_.Name -match 'RTX\s*(\d{4})') {
                        # Known VRAM sizes for RTX cards
                        $model = $matches[1]
                        Write-Verbose "Detected RTX model: $model"
                        switch -Regex ($model) {
                            "^4090" { "24" }
                            "^4080" { "16" }
                            "^4070" { "12" }  # 4070, 4070 Ti, and 4070 SUPER all have 12GB+
                            "^4060" { "8" }
                            "^3090" { "24" }
                            "^3080" { "10" }
                            "^3070" { "8" }
                            "^3060" { "12" }
                            "^3050" { "8" }
                            default { "4+" }
                        }
                    } elseif ($_.Name -match 'GTX\s*(\d{4})') {
                        $model = $matches[1]
                        switch -Regex ($model) {
                            "^1080" { "8" }
                            "^1070" { "8" }
                            "^1060" { "6" }
                            default { "4+" }
                        }
                    } else {
                        "4+"
                    }
                } else {
                    [math]::Round($ramBytes / 1GB, 2)
                }
            } else { "N/A" }
            
            # Try to get driver date properly
            $driverDateValue = "Unknown"
            if ($_.DriverDate) {
                try {
                    # DriverDate might be a CIM DateTime string or already a DateTime object
                    if ($_.DriverDate -is [DateTime]) {
                        $driverDateValue = $_.DriverDate.ToString("yyyy-MM-dd")
                    } elseif ($_.DriverDate -is [String] -and $_.DriverDate.Length -eq 25) {
                        # CIM DateTime format (e.g., "20250806190000.000000-000")
                        $dt = [Management.ManagementDateTimeConverter]::ToDateTime($_.DriverDate)
                        $driverDateValue = $dt.ToString("yyyy-MM-dd")
                    } else {
                        # Try direct conversion as last resort
                        $dt = [DateTime]$_.DriverDate
                        $driverDateValue = $dt.ToString("yyyy-MM-dd")
                    }
                } catch {
                    Write-Verbose "Failed to convert driver date: $($_.Exception.Message)"
                    $driverDateValue = "Unknown"
                }
            }
            
            # For modern GPUs, VideoArchitecture doesn't represent connection type
            # Try to determine actual output type based on the GPU
            $adapterType = if ($_.Name -match "NVIDIA|AMD|Intel") {
                # Modern GPUs support multiple outputs
                "PCIe (DisplayPort/HDMI)"
            } else {
                switch ($_.VideoArchitecture) {
                    1 { "Other" }
                    2 { "Unknown" }
                    3 { "CGA" }
                    4 { "EGA" }
                    5 { "VGA" }
                    6 { "SVGA" }
                    7 { "MDA" }
                    8 { "HGC" }
                    9 { "MCGA" }
                    10 { "8514A" }
                    11 { "XGA" }
                    12 { "Linear Frame Buffer" }
                    160 { "PC-98" }
                    default { "PCIe" }
                }
            }
            
            [PSCustomObject]@{
                Name = $_.Name
                AdapterCompatibility = $_.AdapterCompatibility
                DriverVersion = $_.DriverVersion
                DriverDate = $driverDateValue
                VRAMSizeGB = $vramGB
                CurrentResolution = "$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution)"
                RefreshRate = "$($_.CurrentRefreshRate)"
                Status = $_.Status
                VideoProcessor = $_.VideoProcessor
                VideoArchitecture = $adapterType
            }
        })
        
        return [PSCustomObject]@{
            Devices = $gpuDevices
            PrimaryDevice = $gpuDevices | Select-Object -First 1
        }
    }
    catch {
        Write-Warning "Failed to get graphics data: $_"
        return $null
    }
}

function Get-SystemBoardData {
    param($DataCache)
    
    try {
        # Use direct queries to avoid cache issues in parallel jobs
        $baseBoard = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue | Select-Object -First 1
        
        # Check boot mode and security features
        $bootMode = if (Test-Path 'HKLM:\System\CurrentControlSet\Control\SecureBoot\State') { "UEFI" } else { "Legacy" }
        
        $secureBootEnabled = $false
        try {
            $secureBootState = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\SecureBoot\State' -Name UEFISecureBootEnabled -ErrorAction SilentlyContinue
            $secureBootEnabled = $secureBootState.UEFISecureBootEnabled -eq 1
        }
        catch {
            Write-Verbose "Secure Boot state not available"
        }
        
        # Check TPM
        $tpmStatus = "Not Available"
        $tpmVersion = $null
        try {
            $tpm = Get-CimInstance -Namespace "root\cimv2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ErrorAction SilentlyContinue
            if ($tpm) {
                # Extract just the major version from SpecVersion string (e.g., "2.0, 0, 1.38" -> "2.0")
                if ($tpm.SpecVersion) {
                    $versionParts = $tpm.SpecVersion -split ','
                    $tpmVersion = $versionParts[0].Trim()
                }
                $tpmStatus = if ($tpm.IsEnabled_InitialValue) {
                    if ($tpmVersion) { "Enabled (v$tpmVersion)" } else { "Enabled" }
                } else {
                    "Disabled"
                }
            }
        }
        catch {
            Write-Verbose "TPM information not available"
        }
        
        $biosDate = if ($bios.ReleaseDate) {
            try {
                $dt = [Management.ManagementDateTimeConverter]::ToDateTime($bios.ReleaseDate)
                $dt.ToString("yyyy-MM-dd")
            } catch {
                # Try alternative date parsing
                try {
                    $dt = [DateTime]$bios.ReleaseDate
                    $dt.ToString("yyyy-MM-dd")
                } catch {
                    "Unknown"
                }
            }
        } else { "Unknown" }
        
        $biosAge = if ($biosDate -ne "Unknown" -and $biosDate -ne "N/A") {
            try {
                Get-AgeInDays -StartDate ([DateTime]$biosDate)
            } catch {
                "N/A"
            }
        } else { "N/A" }
        
        return [PSCustomObject]@{
            Computer = [PSCustomObject]@{
                Manufacturer = $computerSystem.Manufacturer
                Model = $computerSystem.Model
            }
            Motherboard = [PSCustomObject]@{
                Manufacturer = $baseBoard.Manufacturer
                Product = $baseBoard.Product
                Version = $baseBoard.Version
                SerialNumber = $baseBoard.SerialNumber
            }
            BIOS = [PSCustomObject]@{
                Manufacturer = $bios.Manufacturer
                Version = $bios.SMBIOSBIOSVersion
                ReleaseDate = $biosDate
                AgeInDays = $biosAge
            }
            Security = [PSCustomObject]@{
                BootMode = $bootMode
                SecureBootEnabled = $secureBootEnabled
                TPMStatus = $tpmStatus
                TPMVersion = $tpmVersion
            }
        }
    }
    catch {
        Write-Warning "Failed to get system board data: $_"
        return $null
    }
}

function Get-PowerData {
    param($DataCache)
    
    try {
        # Get power plan
        $powerPlan = powercfg /getactivescheme 2>$null
        $activePlan = if ($powerPlan) {
            if ($powerPlan -match 'Balanced') { "Balanced" }
            elseif ($powerPlan -match 'High performance') { "High Performance" }
            elseif ($powerPlan -match 'Power saver') { "Power Saver" }
            else { "Custom" }
        } else { "Unknown" }
        
        $powerData = [PSCustomObject]@{
            PowerPlan = $activePlan
            Battery = $null
        }
        
        # Enhanced battery detection using multiple WMI sources
        $powerData.Battery = Get-EnhancedBatteryData
        
        return $powerData
    }
    catch {
        Write-Warning "Failed to get power data: $_"
        return $null
    }
}

function Get-EnhancedBatteryData {
    try {
        # Try Win32_Battery for basic information
        $batteries = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
        if (-not $batteries) {
            Write-Verbose "No battery detected via Win32_Battery"
            return $null
        }
        
        $battery = $batteries | Select-Object -First 1
        Write-Verbose "Battery detected: $($battery.Name)"
        
        # Get enhanced battery information from WMI classes
        $batteryStatus = Get-CimInstance -ClassName BatteryStatus -Namespace root/WMI -ErrorAction SilentlyContinue | Select-Object -First 1
        $batteryFullCharge = Get-CimInstance -ClassName BatteryFullChargedCapacity -Namespace root/WMI -ErrorAction SilentlyContinue | Select-Object -First 1
        $batteryCycleCount = Get-CimInstance -ClassName BatteryCycleCount -Namespace root/WMI -ErrorAction SilentlyContinue | Select-Object -First 1
        
        # Extract design capacity from powercfg battery report (most reliable source)
        $designCapacity = $null
        $manufacturer = "Unknown"
        $chemistry = "Unknown"
        try {
            $tempReport = "$env:TEMP\battery_report_temp.html"
            $null = powercfg /batteryreport /output $tempReport 2>$null
            if (Test-Path $tempReport) {
                $reportContent = Get-Content $tempReport -Raw
                
                # Extract design capacity (mWh)
                if ($reportContent -match 'DESIGN CAPACITY.*?(\d{1,3}(?:,\d{3})*)\s*mWh') {
                    $designCapacityString = $matches[1] -replace ',', ''
                    $designCapacity = [int]$designCapacityString
                }
                
                # Extract manufacturer
                if ($reportContent -match 'MANUFACTURER.*?<td>([^<]+)</td>') {
                    $manufacturer = $matches[1].Trim()
                }
                
                # Extract chemistry
                if ($reportContent -match 'CHEMISTRY.*?<td>([^<]+)</td>') {
                    $chemistryCode = $matches[1].Trim()
                    $chemistry = switch ($chemistryCode) {
                        "LiP" { "Lithium Polymer" }
                        "LION" { "Lithium-ion" }
                        "LI-ION" { "Lithium-ion" }
                        "NiMH" { "Nickel Metal Hydride" }
                        "NiCd" { "Nickel Cadmium" }
                        "PbAc" { "Lead Acid" }
                        default { $chemistryCode }
                    }
                }
                
                Remove-Item $tempReport -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-Verbose "Could not extract design capacity from battery report: $_"
        }
        
        # Get full charge capacity (from WMI if available, fallback to Win32_Battery)
        $fullChargeCapacity = if ($batteryFullCharge -and $batteryFullCharge.FullChargedCapacity) {
            $batteryFullCharge.FullChargedCapacity
        } elseif ($battery.FullChargeCapacity) {
            $battery.FullChargeCapacity
        } else { $null }
        
        # Calculate health percentage
        $health = if ($designCapacity -and $designCapacity -gt 0 -and $fullChargeCapacity -and $fullChargeCapacity -gt 0) {
            [math]::Round(($fullChargeCapacity / $designCapacity) * 100, 2)
        } else { $null }
        
        # Get current charge percentage
        $chargePercent = $battery.EstimatedChargeRemaining
        
        # Calculate time remaining more accurately
        $timeRemaining = $null
        if ($batteryStatus -and $batteryStatus.RemainingCapacity -and $batteryStatus.DischargeRate -and $batteryStatus.DischargeRate -gt 0) {
            # Calculate based on discharge rate (in minutes)
            $timeRemaining = [math]::Round($batteryStatus.RemainingCapacity / $batteryStatus.DischargeRate * 60, 0)
        } elseif ($battery.EstimatedRunTime -and $battery.EstimatedRunTime -ne 71582788 -and $battery.EstimatedRunTime -lt 65535 -and $battery.EstimatedRunTime -gt 0) {
            $timeRemaining = $battery.EstimatedRunTime
        }
        
        # Get cycle count
        $cycleCount = if ($batteryCycleCount -and $batteryCycleCount.CycleCount) {
            $batteryCycleCount.CycleCount
        } else { $null }
        
        # Determine battery status with enhanced logic
        $status = switch ($battery.BatteryStatus) {
            1 { "Discharging" }
            2 { "AC Power" }
            3 { "Fully Charged" }
            4 { "Low" }
            5 { "Critical" }
            6 { "Charging" }
            7 { "Charging High" }
            8 { "Charging Low" }
            9 { "Charging Critical" }
            10 { "Undefined" }
            11 { "Partially Charged" }
            default { "Unknown" }
        }
        
        # Override status with WMI data if available
        if ($batteryStatus) {
            if ($batteryStatus.Charging) { $status = "Charging" }
            elseif ($batteryStatus.Critical) { $status = "Critical" }
            elseif ($batteryStatus.PowerOnline -and -not $batteryStatus.Discharging) { $status = "AC Power" }
            elseif ($batteryStatus.Discharging) { $status = "Discharging" }
        }
        
        return [PSCustomObject]@{
            Name = if ($battery.Name) { $battery.Name } else { "Battery" }
            Manufacturer = $manufacturer
            HealthPercent = $health
            Status = $status
            EstimatedChargeRemaining = $chargePercent
            EstimatedRunTime = $timeRemaining
            DesignCapacity = $designCapacity
            FullChargeCapacity = $fullChargeCapacity
            CycleCount = $cycleCount
            Chemistry = $chemistry
            HealthStatus = if ($health) {
                Get-StatusFromThreshold -Value $health -WarningThreshold 75 -CriticalThreshold 60 -Reverse
            } else { "Unknown" }
        }
    }
    catch {
        Write-Warning "Failed to get enhanced battery data: $_"
        return $null
    }
}

function Get-USBData {
    param($DataCache)
    
    try {
        # Get USB controllers
        $usbControllers = Get-CimInstance -ClassName Win32_USBController -ErrorAction SilentlyContinue
        
        # Get USB devices - Direct query to avoid cache issues
        $usbDevices = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { 
            $_.DeviceID -like "USB*" -or 
            $_.Service -eq "USBSTOR" -or
            $_.PNPClass -eq "USB"
        }
        
        # Check for USB 3.0+ support
        $usb3Support = $false
        if ($usbControllers) {
            $usb3Support = @($usbControllers | Where-Object { 
                $_.Name -match "USB 3|xHCI|Enhanced"
            }).Count -gt 0
        }
        
        # Count error devices
        $errorDevices = @($usbDevices | Where-Object { $_.ConfigManagerErrorCode -ne 0 }).Count
        
        return [PSCustomObject]@{
            ControllerCount = @($usbControllers).Count
            ConnectedDevices = @($usbDevices).Count
            ErrorCount = $errorDevices
            USB3Support = $usb3Support
            Controllers = @($usbControllers | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    Status = $_.Status
                    Manufacturer = $_.Manufacturer
                }
            })
            Devices = @($usbDevices | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    DeviceID = $_.DeviceID
                    Status = $_.Status
                    Manufacturer = $_.Manufacturer
                }
            })
        }
    }
    catch {
        Write-Warning "Failed to get USB data: $_"
        return $null
    }
}

function Get-AudioData {
    param($DataCache)
    
    try {
        # Get only audio endpoints that represent actual playback/recording devices
        # These are what show up in Windows Sound settings
        $audioEndpoints = @()
        
        # Get audio endpoint devices (these are the actual speakers, headphones, mics that show in volume control)
        $endpoints = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { 
            $_.PNPClass -eq 'AudioEndpoint' -and
            $_.ConfigManagerErrorCode -eq 0 -and
            $_.Status -eq 'OK'
        }
        
        # Filter to only get actual audio devices users care about
        if ($endpoints) {
            $audioEndpoints = $endpoints | Where-Object {
                $_.Name -match 'Speakers|Headphone|Microphone|Digital Audio|Line In|Line Out|SPDIF' -and
                $_.Name -notmatch 'Root Level|Virtual'
            }
        }
        
        # If no endpoints found, fall back to sound devices
        if ($audioEndpoints.Count -eq 0) {
            $soundCards = Get-CimInstance -ClassName Win32_SoundDevice -ErrorAction SilentlyContinue | Where-Object {
                $_.Status -eq 'OK'
            }
            if ($soundCards) {
                $audioEndpoints = $soundCards
            }
        }
        
        $soundDevices = $audioEndpoints
        
        # Identify default playback and recording devices
        $defaultPlayback = "Not detected"
        $defaultRecording = "Not detected"
        
        # Find speaker/headphone devices for playback
        $playbackDevice = $soundDevices | Where-Object { 
            $_.Name -match 'Speaker|Headphone|Digital.*Out' 
        } | Select-Object -First 1
        
        if ($playbackDevice) {
            $defaultPlayback = $playbackDevice.Name
        }
        
        # Find microphone devices for recording
        $recordingDevice = $soundDevices | Where-Object { 
            $_.Name -match 'Microphone|Line In' 
        } | Select-Object -First 1
        
        if ($recordingDevice) {
            $defaultRecording = $recordingDevice.Name
        }
        
        # Count devices with errors
        $errorCount = @($soundDevices | Where-Object { $_.ConfigManagerErrorCode -ne 0 -or $_.Status -ne "OK" }).Count
        
        return [PSCustomObject]@{
            PlaybackDevice = $defaultPlayback
            RecordingDevice = $defaultRecording
            TotalDevices = @($soundDevices).Count
            ErrorCount = $errorCount
            Devices = @($soundDevices | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    Status = if ($_.Status) { ConvertTo-StandardStatus -Status $_.Status } else { "Healthy" }
                    Type = if ($_.Name -match 'Speaker|Headphone') { 
                        "Playback" 
                    } elseif ($_.Name -match 'Microphone|Line In') { 
                        "Recording" 
                    } else { 
                        "Audio Device" 
                    }
                }
            })
        }
    }
    catch {
        Write-Warning "Failed to get audio data: $_"
        return $null
    }
}

function Get-HardwareHealthScore {
    param($HardwareData)
    
    try {
        $score = 100
        $weights = @{
            Storage = 30
            Memory = 25
            CPU = 20
            Power = 15
            Other = 10
        }
        
        # Storage scoring (30%)
        if ($HardwareData.Storage) {
            $storageScore = 100
            if ($HardwareData.Storage.CriticalDevices -gt 0) {
                $storageScore = 40
            } elseif ($HardwareData.Storage.WarningDevices -gt 0) {
                $storageScore = 70
            }
            $score -= ($weights.Storage * (100 - $storageScore) / 100)
        }
        
        # Memory scoring (25%)
        if ($HardwareData.Memory) {
            $memoryScore = 100
            if ($HardwareData.Memory.Status -eq "Critical") {
                $memoryScore = 40
            } elseif ($HardwareData.Memory.Status -eq "Warning") {
                $memoryScore = 70
            }
            $score -= ($weights.Memory * (100 - $memoryScore) / 100)
        }
        
        # CPU scoring (20%)
        if ($HardwareData.CPU) {
            $cpuScore = 100
            if ($HardwareData.CPU.Status -eq "Critical") {
                $cpuScore = 40
            } elseif ($HardwareData.CPU.Status -eq "Warning") {
                $cpuScore = 70
            }
            if ($HardwareData.CPU.Throttling) {
                $cpuScore -= 20
            }
            $score -= ($weights.CPU * (100 - $cpuScore) / 100)
        }
        
        # Power/Battery scoring (15% for laptops)
        if ($HardwareData.Power -and $HardwareData.Power.Battery) {
            $powerScore = 100
            if ($HardwareData.Power.Battery.HealthStatus -eq "Critical") {
                $powerScore = 40
            } elseif ($HardwareData.Power.Battery.HealthStatus -eq "Warning") {
                $powerScore = 70
            }
            $score -= ($weights.Power * (100 - $powerScore) / 100)
        }
        
        return [math]::Round($score, 0)
    }
    catch {
        Write-Warning "Failed to calculate health score: $_"
        return 0
    }
}