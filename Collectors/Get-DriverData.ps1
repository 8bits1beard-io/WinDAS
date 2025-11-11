# Get-DriverData.ps1
# Collect comprehensive driver inventory and health data
# Author: Joshua Walderbach

function Get-DriverData {
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$DataCache = $Global:DataCache
    )
    
    Write-ProgressStatus -Activity "Collecting Driver Data" -Status "Initializing"
    
    # Initialize driver data structure
    $driverData = [PSCustomObject]@{
        CollectedAt = Get-Date
        Summary = $null
        ProblemDevices = @()
        DriverCategories = $null
        UpdateAnalysis = @()
        UnsignedDrivers = @()
        PerformanceImpact = $null
        RecentChanges = @()
        AllDrivers = @()
        HealthStatus = "Unknown"
    }
    
    try {
        # Get PnP device information
        Write-ProgressStatus -Activity "Collecting Driver Data" -Status "Getting PnP device status" -PercentComplete 10
        $pnpDevices = Get-PnPDeviceData -DataCache $DataCache
        
        # Get driver properties
        Write-ProgressStatus -Activity "Collecting Driver Data" -Status "Collecting driver properties" -PercentComplete 30
        $driverProperties = Get-DriverProperties -PnpDevices $pnpDevices
        
        # Skip driver store inventory (performance optimization - data not used)
        Write-ProgressStatus -Activity "Collecting Driver Data" -Status "Skipping driver store inventory" -PercentComplete 50
        $driverStore = @()  # Empty array - Get-DriverStoreInventory takes 23+ seconds but data is unused
        
        # Get signature information
        Write-ProgressStatus -Activity "Collecting Driver Data" -Status "Verifying driver signatures" -PercentComplete 60
        $signatureInfo = Get-DriverSignatures -DataCache $DataCache
        
        # Process and categorize drivers
        Write-ProgressStatus -Activity "Collecting Driver Data" -Status "Processing driver data" -PercentComplete 70
        $processedData = Process-DriverData -PnpDevices $pnpDevices -DriverProperties $driverProperties `
                                           -DriverStore $driverStore -SignatureInfo $signatureInfo
        
        # Populate driver data structure
        $driverData.AllDrivers = $processedData.AllDrivers
        $driverData.ProblemDevices = $processedData.ProblemDevices
        $driverData.DriverCategories = $processedData.Categories
        $driverData.UpdateAnalysis = $processedData.UpdateAnalysis
        $driverData.UnsignedDrivers = $processedData.UnsignedDrivers
        
        # Get performance impact
        Write-ProgressStatus -Activity "Collecting Driver Data" -Status "Analyzing performance impact" -PercentComplete 85
        $driverData.PerformanceImpact = Get-DriverPerformanceImpact
        
        # Get recent driver changes
        Write-ProgressStatus -Activity "Collecting Driver Data" -Status "Getting recent changes" -PercentComplete 90
        $driverData.RecentChanges = Get-RecentDriverChanges
        
        # Create summary
        Write-ProgressStatus -Activity "Collecting Driver Data" -Status "Creating summary" -PercentComplete 95
        $driverData.Summary = Get-DriverSummary -DriverData $driverData
        
        # Determine health status
        $driverData.HealthStatus = Get-DriverHealthStatus -DriverData $driverData
        
        Write-ProgressStatus -Activity "Collecting Driver Data" -Completed
    }
    catch {
        Write-Error "Failed to collect driver data: $_"
    }
    
    return $driverData
}

function Get-PnPDeviceData {
    param($DataCache)
    
    try {
        $devices = @()
        
        # Define relevant device classes for analysis
        $relevantClasses = @(
            'Display',           # Graphics adapters
            'Net',              # Network adapters
            'DiskDrive',        # Storage devices
            'AudioEndpoint',    # Audio devices
            'Media',            # Media devices
            'Monitor',          # Display monitors
            'USB',              # USB devices (not hubs)
            'Bluetooth',        # Bluetooth devices
            'Camera',           # Cameras
            'Keyboard',         # Keyboards
            'Mouse',            # Mice/pointing devices
            'HDC',              # Storage controllers
            'SCSIAdapter',      # SCSI/RAID controllers
            'System'            # System devices (filtered later)
        )
        
        # Query PnP entity data directly (not cached to save memory)
        Write-Verbose "Querying PnP entities..."
        try {
            $cachedPnPEntities = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop
        } catch {
            Write-Verbose "Failed to query PnP entities, using fallback"
            $cachedPnPEntities = $null
        }
        $entityLookup = @{}
        if ($cachedPnPEntities) {
            foreach ($entity in $cachedPnPEntities) {
                if ($entity.DeviceID) {
                    $entityLookup[$entity.DeviceID] = $entity
                }
            }
        }
        
        # Get current PnP device status - filtered to relevant devices
        try {
            Write-Verbose "Getting PnP devices..."
            $currentDevices = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
                # Include devices that are:
                # 1. In our relevant classes list
                # 2. Have problems (any status other than OK)
                # 3. Have error codes
                $_.Class -in $relevantClasses -or 
                $_.Status -ne 'OK' -or 
                $_.Problem -ne 'CM_PROB_NONE' -or
                $_.ProblemCode -gt 0
            }
            
            # Further filter out unimportant system devices
            $currentDevices = $currentDevices | Where-Object {
                $_.FriendlyName -notmatch 'System (timer|speaker|CMOS|board)' -and
                $_.FriendlyName -notmatch 'Numeric data processor' -and
                $_.FriendlyName -notmatch 'Programmable interrupt' -and
                $_.FriendlyName -notmatch 'Direct memory access' -and
                $_.FriendlyName -notmatch 'High precision event timer' -and
                $_.InstanceId -notmatch 'ROOT\\LEGACY'  # Legacy/virtual devices
            }
            
            Write-Verbose "Processing $(@($currentDevices).Count) relevant devices (filtered from total)"
            
            foreach ($device in $currentDevices) {
                # Use hashtable lookup instead of Where-Object (O(1) vs O(n))
                $cachedEntity = $entityLookup[$device.InstanceId]
                
                $devices += [PSCustomObject]@{
                    DeviceName = $device.FriendlyName
                    DeviceID = $device.InstanceId
                    Class = $device.Class
                    Status = $device.Status
                    ConfigManagerErrorCode = if ($cachedEntity) { $cachedEntity.ConfigManagerErrorCode } else { 0 }
                    Manufacturer = if ($cachedEntity) { $cachedEntity.Manufacturer } else { $device.Manufacturer }
                    Service = if ($cachedEntity) { $cachedEntity.Service } else { $null }
                    Present = $device.Present
                    Problem = $device.Problem
                    ProblemCode = $device.ProblemCode
                    ProblemDescription = Get-DeviceProblemDescription -Code $device.ProblemCode
                }
            }
        }
        catch {
            Write-Warning "Could not get PnP device data, falling back to cached data"
            
            # Fallback to cached data only
            foreach ($entity in $cachedPnPEntities) {
                $devices += [PSCustomObject]@{
                    DeviceName = $entity.Name
                    DeviceID = $entity.DeviceID
                    Class = $entity.PNPClass
                    Status = if ($entity.ConfigManagerErrorCode -eq 0) { "Healthy" } else { "Critical" }
                    ConfigManagerErrorCode = $entity.ConfigManagerErrorCode
                    Manufacturer = $entity.Manufacturer
                    Service = $entity.Service
                    Present = $true
                    Problem = $entity.ConfigManagerErrorCode -ne 0
                    ProblemCode = $entity.ConfigManagerErrorCode
                    ProblemDescription = Get-DeviceProblemDescription -Code $entity.ConfigManagerErrorCode
                }
            }
        }
        
        return $devices
    }
    catch {
        Write-Warning "Failed to get PnP device data: $_"
        return @()
    }
}

function Get-DeviceProblemDescription {
    param([int]$Code)
    
    switch ($Code) {
        0 { return "Device is working properly" }
        1 { return "Device is not configured correctly. May need to update driver or adjust settings in Device Manager." }
        3 { return "The driver for this device might be corrupted. Reinstall or update the driver." }
        10 { return "This device cannot start. Try updating the driver or checking for hardware conflicts." }
        12 { return "This device cannot find enough free resources. Check for IRQ/memory conflicts in Device Manager." }
        14 { return "This device cannot work properly until you restart your computer." }
        16 { return "Windows cannot identify all the resources this device uses. May need manual configuration." }
        18 { return "Reinstall the drivers for this device. Use Device Manager to uninstall and scan for hardware changes." }
        19 { return "Windows cannot start this hardware device. Registry may be corrupted. Try System Restore or driver reinstall." }
        21 { return "Windows is removing this device. Wait for removal to complete." }
        22 { return "This device is disabled. Enable it in Device Manager to use it." }
        24 { return "This device is not present or not working properly. Check physical connections." }
        28 { return "The drivers for this device are not installed. Install drivers from manufacturer or Windows Update." }
        29 { return "This device is disabled because firmware did not provide resources. Check BIOS/UEFI settings." }
        31 { return "This device is not working properly. Windows cannot load the required drivers." }
        32 { return "A driver service for this device has been disabled. Check Services or Device Manager." }
        33 { return "Windows cannot determine which resources are required. May need manual configuration." }
        34 { return "Windows cannot determine the settings for this device. Check manufacturer documentation." }
        35 { return "Your computer's firmware does not include enough information. BIOS/UEFI update may be needed." }
        36 { return "This device is requesting a PCI interrupt but is configured for ISA. Check BIOS settings." }
        37 { return "Windows cannot initialize the device driver. Try reinstalling or updating the driver." }
        38 { return "Windows cannot load the device driver. Another instance may already be loaded." }
        39 { return "Windows cannot load the device driver. Registry may be corrupted. Try driver reinstall." }
        40 { return "Windows cannot access this hardware. Service key information is missing from registry." }
        41 { return "Windows successfully loaded the driver but cannot find the hardware device." }
        42 { return "Windows cannot load the driver because a duplicate device already exists." }
        43 { return "Windows has stopped this device because it has reported problems. Check Event Viewer for details." }
        44 { return "An application or service has shut down this device. Check related software settings." }
        45 { return "Currently, this device is not connected to the computer. Check cable connections." }
        46 { return "Windows cannot gain access to this hardware device. May be in use by another process." }
        47 { return "Windows cannot use this device because computer is in Safe Mode. Restart normally to use device." }
        48 { return "The driver has been blocked from starting. May be incompatible or unsigned." }
        default { return "Unknown error code: $Code. Check Device Manager for more information." }
    }
}

function Get-DriverProperties {
    param($PnpDevices)
    
    try {
        $driverProps = @{}
        
        # Get all device IDs at once
        $deviceIds = @($PnpDevices | Where-Object { $_.DeviceID } | Select-Object -ExpandProperty DeviceID)
        
        if ($deviceIds.Count -eq 0) {
            return $driverProps
        }
        
        # Batch query all properties for all devices at once
        # This reduces from 4 * N queries to just 4 queries total
        $allDriverDates = @{}
        $allDriverVersions = @{}
        $allDriverProviders = @{}
        $allDriverInfPaths = @{}
        
        try {
            # Get all driver dates in one batch
            $dates = Get-PnpDeviceProperty -InstanceId $deviceIds -KeyName 'DEVPKEY_Device_DriverDate' -ErrorAction SilentlyContinue
            if ($dates) {
                foreach ($item in $dates) {
                    $allDriverDates[$item.InstanceId] = $item.Data
                }
            }
        } catch { Write-Verbose "Could not batch get driver dates" }
        
        try {
            # Get all driver versions in one batch
            $versions = Get-PnpDeviceProperty -InstanceId $deviceIds -KeyName 'DEVPKEY_Device_DriverVersion' -ErrorAction SilentlyContinue
            if ($versions) {
                foreach ($item in $versions) {
                    $allDriverVersions[$item.InstanceId] = $item.Data
                }
            }
        } catch { Write-Verbose "Could not batch get driver versions" }
        
        try {
            # Get all driver providers in one batch
            $providers = Get-PnpDeviceProperty -InstanceId $deviceIds -KeyName 'DEVPKEY_Device_DriverProvider' -ErrorAction SilentlyContinue
            if ($providers) {
                foreach ($item in $providers) {
                    $allDriverProviders[$item.InstanceId] = $item.Data
                }
            }
        } catch { Write-Verbose "Could not batch get driver providers" }
        
        try {
            # Get all driver inf paths in one batch
            $infPaths = Get-PnpDeviceProperty -InstanceId $deviceIds -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction SilentlyContinue
            if ($infPaths) {
                foreach ($item in $infPaths) {
                    $allDriverInfPaths[$item.InstanceId] = $item.Data
                }
            }
        } catch { Write-Verbose "Could not batch get driver inf paths" }
        
        # Now build the results from the batched data
        foreach ($device in $PnpDevices) {
            if (-not $device.DeviceID) { continue }
            
            $driverDate = $allDriverDates[$device.DeviceID]
            
            $driverProps[$device.DeviceID] = [PSCustomObject]@{
                DriverDate = $driverDate
                DriverVersion = if ($allDriverVersions.ContainsKey($device.DeviceID)) { $allDriverVersions[$device.DeviceID] } else { "Unknown" }
                DriverProvider = if ($allDriverProviders.ContainsKey($device.DeviceID)) { $allDriverProviders[$device.DeviceID] } else { "Unknown" }
                DriverInfPath = $allDriverInfPaths[$device.DeviceID]
                DriverAge = if ($driverDate) {
                    Get-AgeInDays -StartDate $driverDate
                } else { $null }
            }
        }
        
        return $driverProps
    }
    catch {
        Write-Warning "Failed to get driver properties: $_"
        return @{}
    }
}


function Get-DriverSignatures {
    param($DataCache)
    
    try {
        Write-Verbose "Getting driver signature information"
        
        # Get signed driver information from WMI (single query)
        $signedDrivers = @{}
        
        try {
            # Use Win32_PnPSignedDriver for signature information
            $pnpSignedDrivers = Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction SilentlyContinue
            
            foreach ($driver in $pnpSignedDrivers) {
                $signedDrivers[$driver.DeviceID] = [PSCustomObject]@{
                    DeviceName = $driver.DeviceName
                    DriverName = $driver.DriverName
                    DriverVersion = $driver.DriverVersion
                    DriverDate = if ($driver.DriverDate) { 
                        try {
                            [Management.ManagementDateTimeConverter]::ToDateTime($driver.DriverDate)
                        } catch {
                            Write-Verbose "Could not convert driver date for $($driver.DeviceID): $_"
                            $null
                        }
                    } else { $null }
                    IsSigned = $driver.IsSigned
                    Signer = $driver.Signer
                    InfName = $driver.InfName
                }
            }
        }
        catch {
            Write-Warning "Could not get signed driver information: $_"
        }
        
        return $signedDrivers
    }
    catch {
        Write-Warning "Failed to get driver signatures: $_"
        return @{}
    }
}

function Process-DriverData {
    param($PnpDevices, $DriverProperties, $DriverStore, $SignatureInfo)
    
    try {
        $allDrivers = @()
        $problemDevices = @()
        $unsignedDrivers = @()
        $updateAnalysis = @()
        
        # Define categories
        $categories = @{
            Display = @()
            Network = @()
            Audio = @()
            Storage = @()
            System = @()
            Other = @()
        }
        
        foreach ($device in $PnpDevices) {
            # Get driver properties for this device
            $props = $DriverProperties[$device.DeviceID]
            $signature = $SignatureInfo[$device.DeviceID]
            
            # Create driver object
            $driver = [PSCustomObject]@{
                DeviceName = $device.DeviceName
                DeviceID = $device.DeviceID
                Class = $device.Class
                Category = Get-DriverCategory -Class $device.Class
                Status = $device.Status
                ProblemCode = $device.ProblemCode
                ProblemDescription = $device.ProblemDescription
                Manufacturer = $device.Manufacturer
                DriverVersion = if ($props) { $props.DriverVersion } else { "Unknown" }
                DriverDate = if ($props) { $props.DriverDate } else { $null }
                DriverAge = if ($props) { $props.DriverAge } else { $null }
                DriverProvider = if ($props) { $props.DriverProvider } else { "Unknown" }
                DriverInfPath = if ($props) { $props.DriverInfPath } else { $null }
                IsSigned = if ($signature) { $signature.IsSigned } else { $null }
                Signer = if ($signature) { $signature.Signer } else { "Unknown" }
                InfName = if ($signature) { $signature.InfName } else { $null }
                UpdateStatus = "Unknown"
                Priority = Get-DriverPriority -Class $device.Class
            }
            
            # Determine update status based on age
            if ($driver.DriverAge) {
                $driver.UpdateStatus = Get-DriverUpdateStatus -AgeInDays $driver.DriverAge -Priority $driver.Priority
            }
            
            # Add to all drivers list
            $allDrivers += $driver
            
            # Check for problems - only include actual problem codes (not 0 or null)
            if ($device.ProblemCode -and $device.ProblemCode -ne 0) {
                $problemDevices += $driver
            }
            
            # Check for unsigned drivers
            if ($signature -and -not $signature.IsSigned) {
                $unsignedDrivers += $driver
            }
            
            # Add to update analysis if old
            if ($driver.DriverAge -and $driver.DriverAge -gt 365) {
                $updateAnalysis += $driver
            }
            
            # Categorize driver
            switch ($driver.Category) {
                "Display" { $categories.Display += $driver }
                "Network" { $categories.Network += $driver }
                "Audio" { $categories.Audio += $driver }
                "Storage" { $categories.Storage += $driver }
                "System" { $categories.System += $driver }
                default { $categories.Other += $driver }
            }
        }
        
        # Sort update analysis by age
        $updateAnalysis = $updateAnalysis | Sort-Object DriverAge -Descending
        
        return [PSCustomObject]@{
            AllDrivers = $allDrivers
            ProblemDevices = $problemDevices
            Categories = $categories
            UpdateAnalysis = $updateAnalysis
            UnsignedDrivers = $unsignedDrivers
        }
    }
    catch {
        Write-Warning "Failed to process driver data: $_"
        return [PSCustomObject]@{
            AllDrivers = @()
            ProblemDevices = @()
            Categories = @{}
            UpdateAnalysis = @()
            UnsignedDrivers = @()
        }
    }
}

function Get-DriverCategory {
    param([string]$Class)
    
    switch ($Class) {
        { $_ -in 'Display', 'Monitor' } { return "Display" }
        { $_ -in 'Net', 'Network' } { return "Network" }
        { $_ -in 'AudioEndpoint', 'Media', 'Sound' } { return "Audio" }
        { $_ -in 'DiskDrive', 'SCSIAdapter', 'HDC', 'Storage' } { return "Storage" }
        { $_ -in 'System', 'Processor', 'Computer' } { return "System" }
        default { return "Other" }
    }
}

function Get-DriverPriority {
    param([string]$Class)
    
    switch ($Class) {
        { $_ -in 'System', 'Processor', 'Computer', 'DiskDrive', 'SCSIAdapter', 'HDC', 'Storage', 'Net', 'Network' } { 
            return "Critical" 
        }
        { $_ -in 'Display', 'Monitor', 'AudioEndpoint', 'Media', 'Sound' } { 
            return "Important" 
        }
        default { 
            return "Standard" 
        }
    }
}

function Get-DriverUpdateStatus {
    param(
        [double]$AgeInDays,
        [string]$Priority
    )
    
    if ($Priority -eq "Critical") {
        if ($AgeInDays -gt 730) { return "Very Old" }  # >2 years
        elseif ($AgeInDays -gt 365) { return "Old" }   # >1 year
        elseif ($AgeInDays -gt 180) { return "Aging" }  # >6 months
        else { return "Current" }
    }
    elseif ($Priority -eq "Important") {
        if ($AgeInDays -gt 730) { return "Very Old" }
        elseif ($AgeInDays -gt 365) { return "Old" }
        elseif ($AgeInDays -gt 270) { return "Aging" }  # >9 months
        else { return "Current" }
    }
    else {
        if ($AgeInDays -gt 1095) { return "Very Old" }  # >3 years
        elseif ($AgeInDays -gt 730) { return "Old" }    # >2 years
        elseif ($AgeInDays -gt 365) { return "Aging" }  # >1 year
        else { return "Current" }
    }
}

function Get-DriverPerformanceImpact {
    try {
        $perfImpact = [PSCustomObject]@{
            DriverErrors = @()
            BootImpact = $null
            ResourceUsage = @()
        }
        
        # Get driver errors from event log (last 24 hours)
        $24HoursAgo = (Get-Date).AddHours(-24)
        try {
            $driverErrors = @(Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                ProviderName = 'Microsoft-Windows-Kernel-PnP'
                StartTime = $24HoursAgo
            } -ErrorAction SilentlyContinue | Where-Object { $_.Level -le 3 })  # Warning or Error
            
            if ($driverErrors.Count -gt 0) {
                $errorGroups = $driverErrors | Group-Object { $_.Message -replace '\n.*', '' } | 
                               Sort-Object Count -Descending | Select-Object -First 5
                
                $perfImpact.DriverErrors = @($errorGroups | ForEach-Object {
                    [PSCustomObject]@{
                        Description = $_.Name
                        Count = $_.Count
                        LastOccurrence = ($_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated
                    }
                })
            }
        }
        catch {
            Write-Verbose "Could not get driver errors from event log"
        }
        
        return $perfImpact
    }
    catch {
        Write-Warning "Failed to get driver performance impact: $_"
        return $null
    }
}

function Get-RecentDriverChanges {
    try {
        $changes = @()
        
        # Get driver installation events from last 24 hours
        $24HoursAgoDrivers = (Get-Date).AddHours(-24)

        try {
            $driverEvents = @(Get-WinEvent -FilterHashtable @{
                LogName = 'Microsoft-Windows-UserPnp/DeviceInstall/Operational'
                StartTime = $24HoursAgoDrivers
            } -ErrorAction SilentlyContinue | Where-Object { $_.Id -in 100, 101, 102, 400, 410 })
            
            $changes = @($driverEvents | Select-Object -First 10 | ForEach-Object {
                [PSCustomObject]@{
                    Date = $_.TimeCreated
                    Action = switch ($_.Id) {
                        100 { "Driver Installed" }
                        101 { "Driver Updated" }
                        102 { "Driver Configured" }
                        400 { "Installation Started" }
                        410 { "Installation Failed" }
                        default { "Driver Change" }
                    }
                    Device = if ($_.Message -match 'Device Instance ID:\s+(.+)') { $matches[1] } else { "Unknown" }
                    Success = $_.Id -ne 410
                }
            })
        }
        catch {
            Write-Verbose "Could not get recent driver changes from event log"
        }
        
        return $changes
    }
    catch {
        Write-Warning "Failed to get recent driver changes: $_"
        return @()
    }
}

function Get-DriverSummary {
    param($DriverData)
    
    try {
        $totalDrivers = $DriverData.AllDrivers.Count
        $outdatedDrivers = @($DriverData.UpdateAnalysis | Where-Object { $_.UpdateStatus -in "Old", "Very Old" }).Count
        $problemCount = $DriverData.ProblemDevices.Count
        $unsignedCount = $DriverData.UnsignedDrivers.Count
        
        # Count missing drivers (error code 28)
        $missingDrivers = @($DriverData.ProblemDevices | Where-Object { $_.ProblemCode -eq 28 }).Count
        
        return [PSCustomObject]@{
            TotalDrivers = $totalDrivers
            OutdatedDrivers = $outdatedDrivers
            ProblemDrivers = $problemCount
            MissingDrivers = $missingDrivers
            UnsignedDrivers = $unsignedCount
            CriticalIssues = @($DriverData.ProblemDevices | Where-Object { 
                $_.ProblemCode -in 10, 19, 28, 31, 39, 43 
            }).Count
            Categories = [PSCustomObject]@{
                Display = $DriverData.DriverCategories.Display.Count
                Network = $DriverData.DriverCategories.Network.Count
                Audio = $DriverData.DriverCategories.Audio.Count
                Storage = $DriverData.DriverCategories.Storage.Count
                System = $DriverData.DriverCategories.System.Count
                Other = $DriverData.DriverCategories.Other.Count
            }
        }
    }
    catch {
        Write-Warning "Failed to create driver summary: $_"
        return $null
    }
}

function Get-DriverHealthStatus {
    param($DriverData)
    
    try {
        # Start with healthy
        $status = "Healthy"
        
        # Check for critical issues
        if ($DriverData.Summary.MissingDrivers -gt 0) {
            return "Critical"
        }
        
        if ($DriverData.Summary.CriticalIssues -gt 0) {
            return "Critical"
        }
        
        # Check for very old critical drivers
        $veryOldCritical = @($DriverData.UpdateAnalysis | Where-Object { 
            $_.Priority -eq "Critical" -and $_.UpdateStatus -eq "Very Old" 
        }).Count
        
        if ($veryOldCritical -gt 0) {
            return "Critical"
        }
        
        # Check for warnings
        if ($DriverData.Summary.ProblemDevices -gt 0) {
            $status = "Warning"
        }
        
        if ($DriverData.Summary.OutdatedDrivers -gt 5) {
            $status = "Warning"
        }
        
        if ($DriverData.Summary.UnsignedDrivers -gt 0) {
            $status = "Warning"
        }
        
        return $status
    }
    catch {
        Write-Warning "Failed to determine driver health status: $_"
        return "Unknown"
    }
}