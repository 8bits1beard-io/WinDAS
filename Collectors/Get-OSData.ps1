# Get-OSData.ps1
# Collect Operating System health and status data
# Author: Joshua Walderbach

function Get-OSData {
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$DataCache = $Global:DataCache
    )
    
    Write-ProgressStatus -Activity "Collecting OS Data" -Status "Initializing" -Component "OS"
    Write-CollectorLog -Message "Starting OS data collection" -Component "OS"
    
    # Initialize OS data structure
    $osData = [PSCustomObject]@{
        CollectedAt = Get-Date
        SystemInfo = $null
        Stability = $null
        WindowsUpdate = $null
        Security = $null
        Services = $null
        IntuneServices = $null  # Optional Intune/MDM services
        SystemIntegrity = $null
        Performance = $null
        BootPerformance = $null
        AllUserProfiles = $null  # Changed to include all profiles
        GroupPolicy = $null
        DomainGPValidation = $null  # Domain/Group Policy consistency validation
        DomainAuthentication = $null
        TimeSynchronization = $null
        EventLogAnalysis = $null
        WindowsFeatures = $null
    }
    
    try {
        # Get data directly instead of from cache to avoid serialization issues
        # This ensures we always get fresh, complete data in job context
        Write-CollectorLog -Message "Querying Win32_OperatingSystem" -Component "OS"
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        Write-CollectorLog -Message "Retrieved OS info: $($osInfo.Caption) Build $($osInfo.BuildNumber)" -Component "OS" -Data @{Caption=$osInfo.Caption; Build=$osInfo.BuildNumber; Version=$osInfo.Version}
        
        Write-CollectorLog -Message "Querying Win32_ComputerSystem" -Component "OS"
        $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        Write-CollectorLog -Message "Retrieved Computer info: $($computerInfo.Name) - $($computerInfo.Model)" -Component "OS" -Data @{Name=$computerInfo.Name; Model=$computerInfo.Model; Manufacturer=$computerInfo.Manufacturer}
        
        if (-not $osInfo -or -not $computerInfo) {
            Write-Warning "Could not retrieve OS or Computer information"
            Write-CollectorLog -Message "Failed to retrieve OS or Computer information" -Level "ERROR" -Component "OS"
            return $osData
        }

        # Cache expensive queries that are reused multiple times throughout collection
        Write-CollectorLog -Message "Caching common queries for performance optimization" -Component "OS"

        # Cache Win32_Service (used in Get-OSCriticalServices and Get-OSIntegrityStatus)
        $cachedServices = Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue
        Write-CollectorLog -Message "Cached $($cachedServices.Count) services" -Component "OS"

        # Cache event log queries
        $24HoursAgo = (Get-Date).AddHours(-24)
        $cachedSystemCriticalEvents = @(Get-WinEvent -FilterHashtable @{LogName='System'; Level=1; StartTime=$24HoursAgo} -ErrorAction SilentlyContinue)
        Write-CollectorLog -Message "Cached $($cachedSystemCriticalEvents.Count) critical system events" -Component "OS"

        # Cache Security log failed logins (only if running as admin)
        if (Test-Administrator) {
            $cachedSecurityFailedLogins = @(Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=$24HoursAgo} -ErrorAction SilentlyContinue)
            Write-CollectorLog -Message "Cached $($cachedSecurityFailedLogins.Count) failed login events" -Component "OS"
        } else {
            $cachedSecurityFailedLogins = @()
        }

        # 1. System Information
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Processing system information" -PercentComplete 10 -Component "OS"
        Write-CollectorLog -Message "Processing system information" -Component "OS"
        $osData.SystemInfo = Get-OSSystemInfo -OSInfo $osInfo -ComputerInfo $computerInfo
        Write-CollectorLog -Message "System info collected" -Component "OS" -Data $osData.SystemInfo
        
        # 2. System Stability & Reliability
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Analyzing system stability" -PercentComplete 20 -Component "OS"
        Write-CollectorLog -Message "Analyzing system stability and reliability" -Component "OS"
        $osData.Stability = Get-OSStability
        Write-CollectorLog -Message "Stability data collected" -Component "OS" -Data $osData.Stability
        
        # 3. Windows Update Status (Monthly Cumulative Updates)
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Checking Windows Update status" -PercentComplete 30 -Component "OS"
        Write-CollectorLog -Message "Checking Windows Update status" -Component "OS"
        $osData.WindowsUpdate = Get-OSUpdateStatus
        Write-CollectorLog -Message "Windows Update status collected" -Component "OS" -Data $osData.WindowsUpdate
        
        # 4. Security Status
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Evaluating security status" -PercentComplete 40 -Component "OS"
        Write-CollectorLog -Message "Evaluating security status" -Component "OS"
        $osData.Security = Get-OSSecurityStatus
        Write-CollectorLog -Message "Security status collected" -Component "OS" -Data $osData.Security
        
        # 5. Critical Services
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Checking critical services" -PercentComplete 50 -Component "OS"
        Write-CollectorLog -Message "Checking critical services status" -Component "OS"
        $osData.Services = Get-OSCriticalServices -CachedServices $cachedServices
        Write-CollectorLog -Message "Critical services status collected" -Component "OS" -Data $osData.Services
        
        # 5a. Optional Intune Services (for MDM-managed devices)
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Checking optional Intune services" -PercentComplete 52 -Component "OS"
        Write-CollectorLog -Message "Checking optional Intune/MDM services" -Component "OS"
        $osData.IntuneServices = Get-OSIntuneServices
        Write-CollectorLog -Message "Intune services status collected" -Component "OS" -Data $osData.IntuneServices
        
        # 6. System Integrity
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Checking system integrity" -PercentComplete 60 -Component "OS"
        Write-CollectorLog -Message "Checking system integrity" -Component "OS"
        $osData.SystemIntegrity = Get-OSSystemIntegrity -CachedServices $cachedServices -CachedComputerInfo $computerInfo
        Write-CollectorLog -Message "System integrity data collected" -Component "OS" -Data $osData.SystemIntegrity
        
        # 7. Performance Metrics
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Gathering performance metrics" -PercentComplete 70 -Component "OS"
        Write-CollectorLog -Message "Gathering performance metrics" -Component "OS"
        $osData.Performance = Get-OSPerformanceMetrics -OSInfo $osInfo
        Write-CollectorLog -Message "Performance metrics collected" -Component "OS" -Data $osData.Performance
        
        # 8. Boot Performance
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Analyzing boot performance" -PercentComplete 75 -Component "OS"
        Write-CollectorLog -Message "Analyzing boot performance" -Component "OS"
        $osData.BootPerformance = Get-OSBootPerformance
        Write-CollectorLog -Message "Boot performance data collected" -Component "OS" -Data $osData.BootPerformance
        
        # 9. ALL User Profiles (Enhanced)
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Enumerating all user profiles" -PercentComplete 80 -Component "OS"
        Write-CollectorLog -Message "Enumerating all user profiles" -Component "OS"
        $osData.AllUserProfiles = Get-AllUserProfiles
        Write-CollectorLog -Message "User profiles collected: $($osData.AllUserProfiles.Count) profiles found" -Component "OS" -Data @{ProfileCount=$osData.AllUserProfiles.Count}
        
        # 10. Group Policy Status
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Checking Group Policy status" -PercentComplete 85 -Component "OS"
        Write-CollectorLog -Message "Checking Group Policy status" -Component "OS"
        $osData.GroupPolicy = Get-OSGroupPolicyStatus
        Write-CollectorLog -Message "Group Policy status collected" -Component "OS" -Data $osData.GroupPolicy

        # 10a. Domain/Group Policy Consistency Validation
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Validating domain/GP consistency" -PercentComplete 87 -Component "OS"
        Write-CollectorLog -Message "Validating domain/Group Policy consistency" -Component "OS"
        if ($osData.SystemInfo.Domain -and $osData.GroupPolicy) {
            $osData.DomainGPValidation = Test-DomainGroupPolicyConsistency -DomainInfo $osData.SystemInfo.Domain -GroupPolicyInfo $osData.GroupPolicy
            Write-CollectorLog -Message "Domain/GP validation completed" -Component "OS" -Data $osData.DomainGPValidation
        } else {
            Write-CollectorLog -Message "Skipping domain/GP validation - insufficient data" -Level "WARNING" -Component "OS"
        }
        
        # 11. Domain/Authentication Status
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Checking domain authentication status" -PercentComplete 88 -Component "OS"
        Write-CollectorLog -Message "Checking domain authentication status" -Component "OS"
        $osData.DomainAuthentication = Get-DomainAuthenticationStatus -CachedFailedLogins $cachedSecurityFailedLogins
        Write-CollectorLog -Message "Domain authentication status collected" -Component "OS" -Data $osData.DomainAuthentication

        # 12. Time Synchronization Status
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Checking time synchronization" -PercentComplete 89 -Component "OS"
        Write-CollectorLog -Message "Checking time synchronization status" -Component "OS"
        $osData.TimeSynchronization = Get-TimeSynchronizationStatus
        Write-CollectorLog -Message "Time synchronization status collected" -Component "OS" -Data $osData.TimeSynchronization

        # 13. Event Log Analysis
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Analyzing event logs" -PercentComplete 90 -Component "OS"
        Write-CollectorLog -Message "Analyzing event logs" -Component "OS"
        $osData.EventLogAnalysis = Get-OSEventLogAnalysis -CachedCriticalEvents $cachedSystemCriticalEvents -CachedFailedLogins $cachedSecurityFailedLogins
        Write-CollectorLog -Message "Event log analysis completed" -Component "OS" -Data $osData.EventLogAnalysis

        # 14. Windows Features
        Write-ProgressStatus -Activity "Collecting OS Data" -Status "Enumerating Windows features" -PercentComplete 92 -Component "OS"
        Write-CollectorLog -Message "Enumerating Windows optional features" -Component "OS"
        $osData.WindowsFeatures = Get-WindowsFeatures
        Write-CollectorLog -Message "Windows features collected" -Component "OS" -Data $osData.WindowsFeatures

        Write-CollectorLog -Message "OS data collection completed successfully" -Component "OS" -Level "SUCCESS"
        Write-ProgressStatus -Activity "Collecting OS Data" -Completed -Component "OS"
    }
    catch {
        Write-Error "Failed to collect OS data: $_"
        Write-CollectorLog -Message "Failed to collect OS data: $_" -Level "ERROR" -Component "OS"
    }
    
    return $osData
}

function Get-EnhancedDomainInfo {
    param($ComputerInfo)

    try {
        # Enhanced domain detection
        $domainInfo = [PSCustomObject]@{
            Name = $ComputerInfo.Domain
            DNSDomain = $null
            IsDomainJoined = $ComputerInfo.DomainRole -in @(1,3,4,5)
            WorkgroupName = if ($ComputerInfo.DomainRole -eq 0) { $ComputerInfo.Domain } else { $null }
            DomainRole = $ComputerInfo.DomainRole
            ValidationMethod = @()
        }

        # Cross-validate with TCP/IP parameters registry
        try {
            $tcpipParams = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -ErrorAction SilentlyContinue
            if ($tcpipParams.Domain -and $tcpipParams.Domain -ne $ComputerInfo.Domain) {
                $domainInfo.DNSDomain = $tcpipParams.Domain
                $domainInfo.ValidationMethod += "TCP/IP-Registry"
            }
        } catch { }

        # Check computer account registry for additional validation
        try {
            $netlogonParams = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -ErrorAction SilentlyContinue
            if ($netlogonParams -and $netlogonParams.RequireSignOrSeal) {
                $domainInfo.ValidationMethod += "Netlogon-Config"
            }
        } catch { }

        # Additional validation via LSA policy
        try {
            $lsaPolicy = Get-ItemProperty "HKLM:\SECURITY\Policy\PolPrDmN" -ErrorAction SilentlyContinue
            if ($lsaPolicy) {
                $domainInfo.ValidationMethod += "LSA-Policy"
            }
        } catch { }

        # Final validation - if domain role indicates domain membership but no domain name, investigate
        if ($domainInfo.IsDomainJoined -and ($domainInfo.Name -eq "WORKGROUP" -or $domainInfo.Name -like "*workstation*")) {
            $domainInfo | Add-Member -NotePropertyName Warning -NotePropertyValue "Domain role indicates domain membership but domain name suggests workgroup" -Force
        }

        return $domainInfo
    }
    catch {
        Write-Warning "Failed to get enhanced domain info: $_"
        return [PSCustomObject]@{
            Name = $ComputerInfo.Domain
            DNSDomain = $null
            IsDomainJoined = $ComputerInfo.DomainRole -in @(1,3,4,5)
            WorkgroupName = if ($ComputerInfo.DomainRole -eq 0) { $ComputerInfo.Domain } else { $null }
            DomainRole = $ComputerInfo.DomainRole
            ValidationMethod = @("Basic-WMI")
            Warning = "Enhanced validation failed"
        }
    }
}

function Get-OSSystemInfo {
    param($OSInfo, $ComputerInfo)
    
    try {
        # CIM returns DateTime directly, no conversion needed
        $lastBootTime = $null
        $uptime = $null
        if ($OSInfo.LastBootUpTime) {
            try {
                # CIM already returns DateTime, WMI would need conversion
                if ($OSInfo.LastBootUpTime -is [DateTime]) {
                    $lastBootTime = $OSInfo.LastBootUpTime
                } else {
                    # Fallback for WMI format
                    $lastBootTime = [Management.ManagementDateTimeConverter]::ToDateTime($OSInfo.LastBootUpTime)
                }
                $uptime = (Get-Date) - $lastBootTime
            } catch {
                Write-Verbose "Could not process LastBootUpTime: $_"
            }
        }
        
        # Safely convert install date
        $installDate = $null
        $ageInDays = 0
        if ($OSInfo.InstallDate) {
            try {
                # CIM already returns DateTime, WMI would need conversion
                if ($OSInfo.InstallDate -is [DateTime]) {
                    $installDate = $OSInfo.InstallDate
                } else {
                    # Fallback for WMI format
                    $installDate = [Management.ManagementDateTimeConverter]::ToDateTime($OSInfo.InstallDate)
                }
                $ageInDays = Get-AgeInDays -StartDate $installDate
            } catch {
                Write-Verbose "Could not process InstallDate: $_"
            }
        }
        
        # Get Windows DisplayVersion (23H2, 24H2, etc.) from registry
        $displayVersion = $null
        try {
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $displayVersion = (Get-ItemProperty -Path $regPath -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
            if (-not $displayVersion) {
                # Fallback to ReleaseId for older Windows versions
                $displayVersion = (Get-ItemProperty -Path $regPath -Name ReleaseId -ErrorAction SilentlyContinue).ReleaseId
            }
        } catch {
            Write-Verbose "Could not retrieve DisplayVersion: $_"
        }

        # Get activation status
        $activation = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue |
                     Select-Object -First 1

        return [PSCustomObject]@{
            WindowsVersion = "$($OSInfo.Caption) $($OSInfo.Version)"
            DisplayVersion = $displayVersion
            Build = $OSInfo.BuildNumber
            InstallDate = $installDate
            InstallAgeInDays = $ageInDays
            SystemUptime = if ($uptime) {
                [PSCustomObject]@{
                    Days = $uptime.Days
                    Hours = $uptime.Hours
                    Minutes = $uptime.Minutes
                    TotalHours = [math]::Round($uptime.TotalHours, 2)
                }
            } else {
                [PSCustomObject]@{ Days = 0; Hours = 0; Minutes = 0; TotalHours = 0 }
            }
            LastBootTime = $lastBootTime
            ComputerName = $ComputerInfo.Name
            Domain = Get-EnhancedDomainInfo -ComputerInfo $ComputerInfo
            DomainName = if ($ComputerInfo.DomainRole -in @(1,3,4,5)) { $ComputerInfo.Domain } else { "WORKGROUP" }
            DomainRole = switch ($ComputerInfo.DomainRole) {
                0 { "Standalone Workstation" }
                1 { "Member Workstation" }
                2 { "Standalone Server" }
                3 { "Member Server" }
                4 { "Backup Domain Controller" }
                5 { "Primary Domain Controller" }
                default { "Unknown" }
            }
            ActivationStatus = if ($activation) {
                [PSCustomObject]@{
                    Status = switch ($activation.LicenseStatus) {
                        0 { "Unlicensed" }
                        1 { "Licensed" }
                        2 { "OOBGrace" }
                        3 { "OOTGrace" }
                        4 { "NonGenuineGrace" }
                        5 { "Notification" }
                        6 { "ExtendedGrace" }
                        default { "Unknown" }
                    }
                    Description = $activation.Description
                }
            } else { "Unknown" }
        }
    }
    catch {
        Write-Warning "Failed to get system info: $_"
        return $null
    }
}

function Get-WindowsFeatures {
    [CmdletBinding()]
    param()

    Write-CollectorLog -Message "Enumerating Windows Optional Features" -Component "OS-Features"

    try {
        # Get all Windows Optional Features
        $features = Get-WindowsOptionalFeature -Online -ErrorAction Stop

        Write-CollectorLog -Message "Retrieved $($features.Count) Windows features" -Component "OS-Features"

        # Categorize features
        $enabled = @($features | Where-Object State -eq 'Enabled')
        $disabled = @($features | Where-Object State -eq 'Disabled')

        Write-CollectorLog -Message "Enabled: $($enabled.Count), Disabled: $($disabled.Count)" -Component "OS-Features"

        # Key features to highlight (commonly relevant for diagnostics)
        $keyFeatures = @{
            'NetFx3' = 'Disabled'
            'NetFx4Extended-ASPNET45' = 'Disabled'
            'IIS-WebServer' = 'Disabled'
            'IIS-WebServerRole' = 'Disabled'
            'Microsoft-Hyper-V-All' = 'Disabled'
            'VirtualMachinePlatform' = 'Disabled'
            'Microsoft-Windows-Subsystem-Linux' = 'Disabled'
            'HypervisorPlatform' = 'Disabled'
            'Containers-DisposableClientVM' = 'Disabled'  # Windows Sandbox
            'SMB1Protocol' = 'Disabled'  # Security concern if enabled
            'SMB1Protocol-Client' = 'Disabled'
            'TelnetClient' = 'Disabled'
            'TFTP' = 'Disabled'
            'WorkFolders-Client' = 'Unknown'
        }

        # Check each key feature
        foreach ($feature in $enabled) {
            $name = $feature.FeatureName
            if ($keyFeatures.ContainsKey($name)) {
                $keyFeatures[$name] = 'Enabled'
                Write-CollectorLog -Message "Key feature enabled: $name" -Component "OS-Features"
            }
        }

        # Identify security concerns
        $securityConcerns = @()
        if ($keyFeatures['SMB1Protocol'] -eq 'Enabled') {
            $securityConcerns += 'SMBv1 Protocol is enabled (security risk - vulnerable to ransomware)'
            Write-CollectorLog -Message "SECURITY: SMBv1 Protocol is enabled" -Component "OS-Features" -Level "WARNING"
        }
        if ($keyFeatures['SMB1Protocol-Client'] -eq 'Enabled') {
            $securityConcerns += 'SMBv1 Client is enabled (security risk)'
            Write-CollectorLog -Message "SECURITY: SMBv1 Client is enabled" -Component "OS-Features" -Level "WARNING"
        }
        if ($keyFeatures['TelnetClient'] -eq 'Enabled') {
            $securityConcerns += 'Telnet client is enabled (unencrypted communication)'
            Write-CollectorLog -Message "SECURITY: Telnet client is enabled" -Component "OS-Features" -Level "WARNING"
        }

        return [PSCustomObject]@{
            TotalFeatures = $features.Count
            EnabledCount = $enabled.Count
            DisabledCount = $disabled.Count
            EnabledFeatures = @($enabled | Select-Object FeatureName, State)
            KeyFeatures = $keyFeatures
            SecurityConcerns = $securityConcerns
        }
    }
    catch {
        Write-CollectorLog -Message "Failed to get Windows Features: $_" -Component "OS-Features" -Level "WARNING"
        return $null
    }
}

function Get-OSStability {
    Write-CollectorLog -Message "Getting system stability metrics" -Component "OS-Stability"
    try {
        # Get reliability index from WMI
        Write-CollectorLog -Message "Querying Win32_ReliabilityStabilityMetrics" -Component "OS-Stability"
        $reliability = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ReliabilityStabilityMetrics -ErrorAction SilentlyContinue | 
                      Select-Object -Last 1
        Write-CollectorLog -Message "Reliability index: $(if($reliability) { $reliability.SystemStabilityIndex } else { 'N/A' })" -Component "OS-Stability"
        
        # Get recent critical events
        $24HoursAgo = (Get-Date).AddHours(-24)
        Write-CollectorLog -Message "Checking for critical events in last 24 hours" -Component "OS-Stability"
        $criticalEvents = @(Get-WinEvent -FilterHashtable @{LogName='System'; Level=1; StartTime=$24HoursAgo} -ErrorAction SilentlyContinue)
        Write-CollectorLog -Message "Found $($criticalEvents.Count) critical events" -Component "OS-Stability"
        
        # Get unexpected shutdowns (Event ID 6008) - last 7 days
        $7DaysAgoShutdowns = (Get-Date).AddDays(-7)
        Write-CollectorLog -Message "Checking for unexpected shutdowns (Event ID 6008) in last 7 days" -Component "OS-Stability"
        $unexpectedShutdowns = @(Get-WinEvent -FilterHashtable @{LogName='System'; ID=6008; StartTime=$7DaysAgoShutdowns} -ErrorAction SilentlyContinue |
                                Select-Object -First 5)
        Write-CollectorLog -Message "Found $($unexpectedShutdowns.Count) unexpected shutdowns" -Component "OS-Stability"

        # Get blue screen events (Event ID 1001 - BugCheck) - last 7 days only
        $7DaysAgo = (Get-Date).AddDays(-7)
        Write-CollectorLog -Message "Checking for blue screen events (BugCheck) in last 7 days" -Component "OS-Stability"
        $blueScreens = @(Get-WinEvent -FilterHashtable @{LogName='System'; ID=1001; StartTime=$7DaysAgo} -ErrorAction SilentlyContinue |
                        Where-Object { $_.Message -like "*BugCheck*" })
        Write-CollectorLog -Message "Found $($blueScreens.Count) blue screen events" -Component "OS-Stability"
        
        return [PSCustomObject]@{
            ReliabilityIndex = if ($reliability) { [math]::Round($reliability.SystemStabilityIndex, 2) } else { "N/A" }
            RecentCriticalEvents = $criticalEvents.Count
            UnexpectedShutdowns = @($unexpectedShutdowns | ForEach-Object {
                [PSCustomObject]@{
                    TimeCreated = $_.TimeCreated
                    Message = ($_.Message -split "`n")[0]
                }
            })
            BlueScreenEvents7Days = $blueScreens.Count
            LastCrashTime = if ($blueScreens.Count -gt 0) { $blueScreens[0].TimeCreated } else { $null }
        }
    }
    catch {
        Write-Warning "Failed to get stability data: $_"
        Write-CollectorLog -Message "Failed to get stability data: $_" -Level "ERROR" -Component "OS-Stability"
        return $null
    }
}

function Get-OSUpdateStatus {
    Write-CollectorLog -Message "Checking Windows Update status" -Component "OS-Updates"
    try {
        # Get installed updates first
        Write-CollectorLog -Message "Getting installed hotfixes" -Component "OS-Updates"
        $allHotfixes = @(Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending)
        Write-CollectorLog -Message "Found $($allHotfixes.Count) total installed hotfixes" -Component "OS-Updates"
        
        # Filter for Monthly Cumulative Updates (KB50xxxxx patterns)
        Write-CollectorLog -Message "Filtering for cumulative updates (KB50xxxxx)" -Component "OS-Updates"
        $cumulativeUpdates = @($allHotfixes | Where-Object { 
            $_.HotFixID -match 'KB50\d{5}'
        })
        Write-CollectorLog -Message "Found $($cumulativeUpdates.Count) cumulative updates" -Component "OS-Updates"
        
        # Get most recent cumulative update
        $lastCumulative = $cumulativeUpdates | Select-Object -First 1
        if ($lastCumulative) {
            $updateMonth = if ($lastCumulative.InstalledOn) { 
                $lastCumulative.InstalledOn.ToString("MMMM yyyy")
            } else { "" }
            
            $lastCumulative | Add-Member -NotePropertyName Title -NotePropertyValue "Windows 11 Cumulative Update - $updateMonth" -Force
        }
        
        $daysSinceUpdate = if ($lastCumulative.InstalledOn) {
            (Get-Date) - $lastCumulative.InstalledOn | Select-Object -ExpandProperty Days
        } else { 999 }
        
        # Check for pending updates using fast registry-based approach (performance optimization)
        $pendingUpdates = @()
        $pendingCumulativeCount = 0
        $pendingSecurityCount = 0
        $pendingOtherCount = 0
        
        Write-CollectorLog -Message "Checking for pending updates using registry-based approach (fast)" -Component "OS-Updates"
        try {
            # Method 1: Check Windows Update registry keys for pending updates
            $updatesPending = $false
            $updateRegistryPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending"
            )
            
            foreach ($path in $updateRegistryPaths) {
                if (Test-Path $path -ErrorAction SilentlyContinue) {
                    $updatesPending = $true
                    break
                }
            }
            
            # Method 2: Check AU registry for download status (much faster than COM)
            $auKeys = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -ErrorAction SilentlyContinue
            if ($auKeys) {
                if ($auKeys.PSObject.Properties.Name -contains "RebootRequired") {
                    $updatesPending = $true
                }
            }
            
            # Method 3: Enhanced registry detection - check for actual pending download/install state
            if ($updatesPending) {
                # Check if there are actual pending updates vs just reboot flags
                $actualPendingFound = $false
                
                # Check for Windows Update session state
                try {
                    $updateSessionKeys = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending" -ErrorAction SilentlyContinue
                    if ($updateSessionKeys -and $updateSessionKeys.Count -gt 0) {
                        $actualPendingFound = $true
                    }
                } catch { }
                
                # Check Component Based Servicing for pending packages
                try {
                    $cbsPendingPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending"
                    if (Test-Path $cbsPendingPath -ErrorAction SilentlyContinue) {
                        $pendingPackages = Get-ChildItem -Path $cbsPendingPath -ErrorAction SilentlyContinue
                        if ($pendingPackages -and $pendingPackages.Count -gt 0) {
                            $actualPendingFound = $true
                        }
                    }
                } catch { }
                
                # Only report pending updates if we find evidence of actual pending downloads/installs
                if ($actualPendingFound) {
                    $pendingCumulativeCount = 1
                    $pendingOtherCount = 0
                    $pendingSecurityCount = 0
                    
                    $pendingUpdates += [PSCustomObject]@{
                        Title = "Cumulative Update (Registry Detection)"
                        KBNumber = "Unknown"
                        IsCumulative = $true
                        IsSecurity = $false
                    }
                }
                # If only reboot keys exist but no actual pending updates, don't report false positive
            }
            
            Write-CollectorLog -Message "Registry-based update check completed - Pending: $updatesPending" -Component "OS-Updates"
        } catch {
            Write-Verbose "Could not check for pending updates via registry: $_"
        }
        
        # Check for pending reboot from multiple sources
        $rebootRequired = $false
        $rebootReasons = @()
        
        # Check various registry keys for pending reboot
        $rebootChecks = @{
            "Windows Update" = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
            )
            "Pending File Operations" = @("HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations")
        }
        
        foreach ($reason in $rebootChecks.Keys) {
            foreach ($path in $rebootChecks[$reason]) {
                if (Test-Path $path -ErrorAction SilentlyContinue) {
                    $rebootRequired = $true
                    if ($rebootReasons -notcontains $reason) {
                        $rebootReasons += $reason
                    }
                    break
                }
            }
        }
        
        # Check if updates are currently installing (removed - too unreliable)
        # TiWorker and TrustedInstaller run for many maintenance tasks, not just updates
        $updatesInstalling = $false
        
        # Simple status: just cumulative updates and reboot status
        $status = if ($pendingCumulativeCount -gt 0 -and $rebootRequired) {
            "$pendingCumulativeCount Update(s) Available - Reboot Pending"
        } elseif ($pendingCumulativeCount -gt 0) {
            "$pendingCumulativeCount Cumulative Update(s) Available"
        } elseif ($rebootRequired) {
            "Reboot Pending"
        } else {
            "No Updates Available"
        }
        
        return [PSCustomObject]@{
            LastCumulativeUpdate = if ($lastCumulative) {
                [PSCustomObject]@{
                    KBNumber = $lastCumulative.HotFixID
                    InstalledOn = $lastCumulative.InstalledOn
                    Description = $lastCumulative.Description
                    Title = $lastCumulative.Title
                }
            } else { "None found" }
            DaysSinceLastCumulative = $daysSinceUpdate
            PendingUpdates = [PSCustomObject]@{
                CumulativeCount = $pendingCumulativeCount
                SecurityCount = $pendingSecurityCount
                OtherCount = $pendingOtherCount
                TotalCount = $pendingCumulativeCount + $pendingSecurityCount + $pendingOtherCount
                Updates = $pendingUpdates
            }
            RebootStatus = [PSCustomObject]@{
                Required = $rebootRequired
                Reasons = $rebootReasons
            }
            UpdatesInstalling = $updatesInstalling
            WindowsUpdateService = if ($wuService) { $wuService.Status } else { "Not Found" }
            Status = $status
        }
    }
    catch {
        Write-Warning "Failed to get update status: $_"
        return $null
    }
}

function Get-OSSecurityStatus {
    try {
        $security = [PSCustomObject]@{
            WindowsDefender = $null
            Firewall = $null
            BitLocker = $null
            UAC = $null
        }
        
        # Windows Defender status - try multiple methods
        try {
            # First try Get-MpComputerStatus (might not work in jobs)
            $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
            if ($defender) {
                $security.WindowsDefender = [PSCustomObject]@{
                    Enabled = $defender.AntivirusEnabled
                    RealTimeProtection = $defender.RealTimeProtectionEnabled
                    DefinitionAge = if ($defender.AntivirusSignatureLastUpdated) {
                        ((Get-Date) - $defender.AntivirusSignatureLastUpdated).Days
                    } else { 999 }
                    LastQuickScan = if ($defender.QuickScanEndTime) {
                        ((Get-Date) - $defender.QuickScanEndTime).Days
                    } else { 999 }
                    LastFullScan = if ($defender.FullScanEndTime) {
                        ((Get-Date) - $defender.FullScanEndTime).Days
                    } else { 999 }
                    TamperProtection = $defender.IsTamperProtected
                }
            }
        }
        catch {
            Write-Verbose "Windows Defender status via Get-MpComputerStatus not available: $_"
        }
        
        # Fallback: Check Windows Defender service status if cmdlet failed
        if (-not $security.WindowsDefender) {
            try {
                $defenderService = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
                if ($defenderService) {
                    $security.WindowsDefender = [PSCustomObject]@{
                        Enabled = ($defenderService.Status -eq 'Running')
                        RealTimeProtection = ($defenderService.Status -eq 'Running')
                        DefinitionAge = 999  # Cannot determine via service
                        LastQuickScan = 999  # Cannot determine via service
                        LastFullScan = 999   # Cannot determine via service
                        TamperProtection = $null
                    }
                }
            }
            catch {
                Write-Verbose "Windows Defender service check failed: $_"
            }
        }
        
        # Firewall profiles - try multiple methods
        try {
            $firewallProfiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
            if ($firewallProfiles) {
                $security.Firewall = [PSCustomObject]@{
                    DomainProfile = ($firewallProfiles | Where-Object Name -eq 'Domain').Enabled
                    PrivateProfile = ($firewallProfiles | Where-Object Name -eq 'Private').Enabled
                    PublicProfile = ($firewallProfiles | Where-Object Name -eq 'Public').Enabled
                }
            }
        }
        catch {
            Write-Verbose "Firewall profile status via Get-NetFirewallProfile not available: $_"
        }
        
        # Fallback: Check Windows Firewall service status
        if (-not $security.Firewall) {
            try {
                $firewallService = Get-Service -Name MpsSvc -ErrorAction SilentlyContinue
                if ($firewallService) {
                    # If Windows Firewall service is running, assume profiles are enabled
                    $isRunning = ($firewallService.Status -eq 'Running')
                    $security.Firewall = [PSCustomObject]@{
                        DomainProfile = $isRunning
                        PrivateProfile = $isRunning
                        PublicProfile = $isRunning
                    }
                }
            }
            catch {
                Write-Verbose "Windows Firewall service check failed: $_"
            }
        }
        
        # BitLocker status for C: drive
        try {
            $bitlocker = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
            if ($bitlocker) {
                $security.BitLocker = [PSCustomObject]@{
                    VolumeStatus = $bitlocker.VolumeStatus.ToString()
                    ProtectionStatus = $bitlocker.ProtectionStatus.ToString()
                    EncryptionPercentage = $bitlocker.EncryptionPercentage
                    KeyProtector = if ($bitlocker.KeyProtector) {
                        ($bitlocker.KeyProtector | Select-Object -First 1).KeyProtectorType.ToString()
                    } else { "None" }
                }
            }
        }
        catch {
            Write-Verbose "BitLocker status not available: $_"
        }
        
        # Fallback for BitLocker if cmdlet failed
        if (-not $security.BitLocker) {
            try {
                # Check if BitLocker service exists and is running
                $bdeService = Get-Service -Name BDESVC -ErrorAction SilentlyContinue
                if ($bdeService) {
                    $security.BitLocker = [PSCustomObject]@{
                        VolumeStatus = "Service Available"
                        ProtectionStatus = if ($bdeService.Status -eq 'Running') { "Healthy" } else { "Warning" }
                        EncryptionPercentage = 0
                        KeyProtector = "Unknown"
                    }
                } else {
                    $security.BitLocker = [PSCustomObject]@{
                        VolumeStatus = "Not Available"
                        ProtectionStatus = "Off"
                        EncryptionPercentage = 0
                        KeyProtector = "None"
                    }
                }
            }
            catch {
                $security.BitLocker = [PSCustomObject]@{
                    VolumeStatus = "Not Available"
                    ProtectionStatus = "Off"
                    EncryptionPercentage = 0
                    KeyProtector = "None"
                }
            }
        }
        
        # UAC (User Account Control) status
        try {
            # Check UAC registry settings
            $uacEnabled = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA -ErrorAction SilentlyContinue
            $uacConsentPrompt = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name ConsentPromptBehaviorAdmin -ErrorAction SilentlyContinue
            $uacSecureDesktop = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name PromptOnSecureDesktop -ErrorAction SilentlyContinue
            
            if ($uacEnabled -and $uacConsentPrompt -and $uacSecureDesktop) {
                $isEnabled = $uacEnabled.EnableLUA -eq 1
                $promptBehavior = $uacConsentPrompt.ConsentPromptBehaviorAdmin
                $secureDesktop = $uacSecureDesktop.PromptOnSecureDesktop -eq 1
                
                # Determine UAC level based on settings
                $uacLevel = "Unknown"
                if (-not $isEnabled) {
                    $uacLevel = "Never notify"
                } elseif ($promptBehavior -eq 0) {
                    $uacLevel = "Never notify"
                } elseif ($promptBehavior -eq 1) {
                    $uacLevel = "Notify me only when apps try to make changes (no dim)"
                } elseif ($promptBehavior -eq 2) {
                    $uacLevel = if ($secureDesktop) { "Always notify" } else { "Notify me only when apps try to make changes (no dim)" }
                } elseif ($promptBehavior -eq 5) {
                    $uacLevel = if ($secureDesktop) { "Notify me only when apps try to make changes (default)" } else { "Notify me only when apps try to make changes (no dim)" }
                }
                
                $security.UAC = [PSCustomObject]@{
                    Enabled = $isEnabled
                    Level = $uacLevel
                    ConsentPromptBehavior = $promptBehavior
                    SecureDesktop = $secureDesktop
                }
            } else {
                $security.UAC = [PSCustomObject]@{
                    Enabled = $false
                    Level = "Unknown"
                    ConsentPromptBehavior = $null
                    SecureDesktop = $null
                }
            }
        }
        catch {
            Write-Verbose "UAC status check failed: $_"
            $security.UAC = [PSCustomObject]@{
                Enabled = $false
                Level = "Unknown"
                ConsentPromptBehavior = $null
                SecureDesktop = $null
            }
        }
        
        # Ensure we always return valid data
        if (-not $security.WindowsDefender) {
            $security.WindowsDefender = [PSCustomObject]@{
                Enabled = $false
                RealTimeProtection = $false
                DefinitionAge = 999
                LastQuickScan = 999
                LastFullScan = 999
                TamperProtection = $null
            }
        }
        
        if (-not $security.Firewall) {
            $security.Firewall = [PSCustomObject]@{
                DomainProfile = $false
                PrivateProfile = $false
                PublicProfile = $false
            }
        }
        
        return $security
    }
    catch {
        Write-Warning "Failed to get security status: $_"
        # Return a default structure rather than null
        return [PSCustomObject]@{
            WindowsDefender = [PSCustomObject]@{
                Enabled = $false
                RealTimeProtection = $false
                DefinitionAge = 999
                LastQuickScan = 999
                LastFullScan = 999
                TamperProtection = $null
            }
            Firewall = [PSCustomObject]@{
                DomainProfile = $false
                PrivateProfile = $false
                PublicProfile = $false
            }
            BitLocker = [PSCustomObject]@{
                VolumeStatus = "Not Available"
                ProtectionStatus = "Off"
                EncryptionPercentage = 0
                KeyProtector = "None"
            }
            UAC = [PSCustomObject]@{
                Enabled = $false
                Level = "Unknown"
                ConsentPromptBehavior = $null
                SecureDesktop = $null
            }
        }
    }
}

function Get-OSCriticalServices {
    param(
        [Parameter(Mandatory=$false)]
        $CachedServices
    )
    try {
        # Comprehensive critical services list with categorization
        $criticalServices = @(
            # Core System Services (Critical - System Won't Function)
            @{Name='RpcSs'; DisplayName='Remote Procedure Call (RPC)'; Category='Core System'; IsCritical=$true}
            @{Name='DcomLaunch'; DisplayName='DCOM Server Process Launcher'; Category='Core System'; IsCritical=$true}
            @{Name='LSM'; DisplayName='Local Session Manager'; Category='Core System'; IsCritical=$true}
            @{Name='PlugPlay'; DisplayName='Plug and Play'; Category='Core System'; IsCritical=$true}
            
            # Security Services (Critical for Protection)
            @{Name='WinDefend'; DisplayName='Windows Defender Antivirus Service'; Category='Security'; IsCritical=$false}
            @{Name='EventLog'; DisplayName='Windows Event Log'; Category='Security'; IsCritical=$true}
            @{Name='SamSs'; DisplayName='Security Accounts Manager'; Category='Security'; IsCritical=$true}
            @{Name='mpssvc'; DisplayName='Windows Defender Firewall'; Category='Security'; IsCritical=$false}
            
            # Core Functionality Services
            @{Name='Winmgmt'; DisplayName='Windows Management Instrumentation'; Category='Core Functionality'; IsCritical=$true}
            @{Name='Schedule'; DisplayName='Task Scheduler'; Category='Core Functionality'; IsCritical=$false}
            @{Name='SENS'; DisplayName='System Event Notification Service'; Category='Core Functionality'; IsCritical=$false}
            @{Name='Dhcp'; DisplayName='DHCP Client'; Category='Core Functionality'; IsCritical=$true}
            @{Name='Dnscache'; DisplayName='DNS Client'; Category='Core Functionality'; IsCritical=$true}
            @{Name='LanmanWorkstation'; DisplayName='Workstation'; Category='Core Functionality'; IsCritical=$false}
            
            # Update & Maintenance Services
            @{Name='wuauserv'; DisplayName='Windows Update'; Category='Update & Maintenance'; IsCritical=$false}
            @{Name='BITS'; DisplayName='Background Intelligent Transfer Service'; Category='Update & Maintenance'; IsCritical=$false}
            @{Name='CryptSvc'; DisplayName='Cryptographic Services'; Category='Update & Maintenance'; IsCritical=$true}


            # User Experience Services
            @{Name='Themes'; DisplayName='Themes'; Category='User Experience'; IsCritical=$false}
            @{Name='AudioSrv'; DisplayName='Windows Audio'; Category='User Experience'; IsCritical=$false}
            @{Name='Spooler'; DisplayName='Print Spooler'; Category='User Experience'; IsCritical=$false}
            
            # Legacy services for compatibility
            @{Name='W32Time'; DisplayName='Windows Time'; Category='Core Functionality'; IsCritical=$false}
        )

        # Use cached services if available, otherwise query directly
        $services = if ($CachedServices) {
            Write-CollectorLog -Message "Using cached services (performance optimization)" -Component "OS-Services"
            $CachedServices
        } else {
            Write-CollectorLog -Message "Querying Win32_Service directly (no cache available)" -Component "OS-Services"
            Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue
        }

        # Sort critical services alphabetically by display name for consistent presentation
        $sortedCriticalServices = $criticalServices | Sort-Object DisplayName
        
        $serviceStatus = @($sortedCriticalServices | ForEach-Object {
            $svcName = $_.Name
            $svc = $services | Where-Object { $_.Name -eq $svcName }
            
            # Determine health status based on criticality and configuration
            $isHealthy = $false
            $healthReason = "Unknown"
            
            if ($svc) {
                if ($_.IsCritical) {
                    # Critical services should be running regardless of startup type
                    $isHealthy = ($svc.State -eq 'Running')
                    $healthReason = if ($svc.State -eq 'Running') { "Running (Critical)" } 
                                   elseif ($svc.StartMode -eq 'Disabled') { "DISABLED - Critical service!" }
                                   else { "STOPPED - Critical service!" }
                } else {
                    # Non-critical services: OK if running with Auto, or stopped with Manual/Disabled
                    $isHealthy = ($svc.State -eq 'Running') -or 
                               (($svc.StartMode -eq 'Manual' -or $svc.StartMode -eq 'Disabled') -and $svc.State -eq 'Stopped')
                    $healthReason = if ($svc.State -eq 'Running') { "Running" }
                                   elseif ($svc.StartMode -eq 'Auto' -and $svc.State -eq 'Stopped') { "STOPPED - Should be running" }
                                   else { "OK ($($svc.StartMode)/$($svc.State))" }
                }
            } else {
                $healthReason = "Service not found"
            }
            
            [PSCustomObject]@{
                Name = $svcName
                DisplayName = $_.DisplayName
                Category = $_.Category
                IsCritical = $_.IsCritical
                Status = if ($svc) { $svc.State } else { "Not Found" }
                StartType = if ($svc) { $svc.StartMode } else { "N/A" }
                IsHealthy = $isHealthy
                HealthReason = $healthReason
            }
        })
        
        # Group services by category for better display
        $servicesByCategory = $serviceStatus | Group-Object -Property Category | ForEach-Object {
            [PSCustomObject]@{
                Category = $_.Name
                Services = $_.Group
                HealthyCount = @($_.Group | Where-Object IsHealthy).Count
                TotalCount = $_.Group.Count
                CriticalIssues = @($_.Group | Where-Object { $_.IsCritical -and -not $_.IsHealthy }).Count
            }
        }
        
        return [PSCustomObject]@{
            Services = $serviceStatus
            ServicesByCategory = $servicesByCategory
            HealthyCount = @($serviceStatus | Where-Object IsHealthy).Count
            TotalCount = $serviceStatus.Count
            CriticalCount = @($serviceStatus | Where-Object IsCritical).Count
            StoppedCritical = @($serviceStatus | Where-Object { $_.IsCritical -and $_.Status -ne 'Running' })
            DisabledCritical = @($serviceStatus | Where-Object { $_.IsCritical -and $_.StartType -eq 'Disabled' })
            Issues = @($serviceStatus | Where-Object { -not $_.IsHealthy })
        }
    }
    catch {
        Write-Warning "Failed to get service status: $_"
        return $null
    }
}

function Get-OSIntuneServices {
    <#
    .SYNOPSIS
        Checks optional Intune/MDM-related services for enrolled Windows devices
    
    .DESCRIPTION
        This function checks services that are typically required or beneficial for 
        Microsoft Intune-enrolled (MDM-managed) Windows devices. These services are
        optional because not all systems will be Intune-managed.
    #>
    
    try {
        # First, check actual MDM enrollment status
        $mdmEnrollmentInfo = @{
            IsEnrolled = $false
            EnrollmentType = $null
            TenantId = $null
            DeviceId = $null
            Authority = $null
        }
        
        # Method 1: Check MDM enrollment via registry
        try {
            $mdmEnrollmentPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
            if (Test-Path $mdmEnrollmentPath) {
                $enrollments = Get-ChildItem -Path $mdmEnrollmentPath -ErrorAction SilentlyContinue
                foreach ($enrollment in $enrollments) {
                    $enrollmentKey = Get-ItemProperty -Path $enrollment.PSPath -ErrorAction SilentlyContinue
                    if ($enrollmentKey.EnrollmentState -eq 1 -and $enrollmentKey.ProviderID) {
                        $mdmEnrollmentInfo.IsEnrolled = $true
                        $mdmEnrollmentInfo.Authority = $enrollmentKey.ProviderID
                        $mdmEnrollmentInfo.DeviceId = $enrollment.PSChildName
                        
                        # Check for Intune specifically
                        if ($enrollmentKey.ProviderID -match "MS DM Server" -or $enrollmentKey.ProviderID -match "Microsoft Intune") {
                            $mdmEnrollmentInfo.EnrollmentType = "Microsoft Intune"
                        } else {
                            $mdmEnrollmentInfo.EnrollmentType = "Third-party MDM"
                        }
                        break
                    }
                }
            }
        } catch {
            Write-Verbose "Could not check MDM enrollment via registry: $_"
        }
        
        # Method 2: Check via WMI/CIM for MDM enrollment
        if (-not $mdmEnrollmentInfo.IsEnrolled) {
            try {
                $mdmWmi = Get-CimInstance -Namespace "root/cimv2/mdm/dmmap" -ClassName "MDM_DevDetail_Ext01" -ErrorAction SilentlyContinue
                if ($mdmWmi -and $mdmWmi.DeviceId) {
                    $mdmEnrollmentInfo.IsEnrolled = $true
                    $mdmEnrollmentInfo.DeviceId = $mdmWmi.DeviceId
                    $mdmEnrollmentInfo.EnrollmentType = "MDM Enrolled"
                }
            } catch {
                Write-Verbose "Could not check MDM via WMI: $_"
            }
        }
        
        # Method 3: Check Azure AD join status (often correlates with Intune)
        $azureAdInfo = @{
            IsJoined = $false
            TenantId = $null
            UserEmail = $null
        }
        
        try {
            $dsregStatus = & dsregcmd /status 2>$null
            if ($dsregStatus) {
                $azureAdJoined = $dsregStatus | Select-String "AzureAdJoined\s*:\s*YES" -Quiet
                if ($azureAdJoined) {
                    $azureAdInfo.IsJoined = $true
                    $tenantMatch = $dsregStatus | Select-String "TenantId\s*:\s*([a-fA-F0-9-]+)"
                    if ($tenantMatch) {
                        $azureAdInfo.TenantId = $tenantMatch.Matches[0].Groups[1].Value
                        $mdmEnrollmentInfo.TenantId = $azureAdInfo.TenantId
                    }
                }
            }
        } catch {
            Write-Verbose "Could not check Azure AD status: $_"
        }

        # Check Intune sync status and timing
        $syncInfo = @{
            LastSyncTime = $null
            LastSyncStatus = "Unknown"
            NextScheduledSync = $null
            SyncFrequency = $null
            SyncErrors = @()
        }

        if ($mdmEnrollmentInfo.IsEnrolled) {
            try {
                # Method 1: Check multiple Intune registry locations for sync information
                $registryPaths = @(
                    "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device",
                    "HKLM:\SOFTWARE\Microsoft\Enrollments",
                    "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Policies",
                    "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\SideCarPolicies\Scripts\Reports"
                )

                foreach ($regPath in $registryPaths) {
                    if (Test-Path $regPath) {
                        try {
                            # Look for timestamp properties
                            $regData = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue

                            # Check various timestamp property names
                            $timestampProps = @('LastSyncTime', 'LastUpdateTime', 'LastSuccessTime', 'LastContactTime', 'Timestamp')
                            foreach ($prop in $timestampProps) {
                                if ($regData.$prop) {
                                    try {
                                        # Try different timestamp formats
                                        if ($regData.$prop -is [int64] -or $regData.$prop -is [int32]) {
                                            # File time format
                                            $tempTime = [DateTime]::FromFileTime($regData.$prop)
                                        } elseif ($regData.$prop -is [string]) {
                                            # String date format
                                            $tempTime = [DateTime]::Parse($regData.$prop)
                                        } else {
                                            continue
                                        }

                                        # Keep the most recent timestamp
                                        if ($tempTime -gt (Get-Date "1/1/2020") -and ($syncInfo.LastSyncTime -eq $null -or $tempTime -gt $syncInfo.LastSyncTime)) {
                                            $syncInfo.LastSyncTime = $tempTime
                                            $syncInfo.LastSyncStatus = "Success"
                                        }
                                    } catch {
                                        continue
                                    }
                                }
                            }

                            # Check subkeys for enrollment information
                            if ($regPath -like "*Enrollments*") {
                                $enrollmentKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
                                foreach ($enrollmentKey in $enrollmentKeys) {
                                    $enrollmentData = Get-ItemProperty -Path $enrollmentKey.PSPath -ErrorAction SilentlyContinue
                                    if ($enrollmentData.LastSyncTime) {
                                        try {
                                            $tempTime = [DateTime]::FromFileTime($enrollmentData.LastSyncTime)
                                            if ($tempTime -gt (Get-Date "1/1/2020") -and ($syncInfo.LastSyncTime -eq $null -or $tempTime -gt $syncInfo.LastSyncTime)) {
                                                $syncInfo.LastSyncTime = $tempTime
                                                $syncInfo.LastSyncStatus = "Success"
                                            }
                                        } catch { }
                                    }
                                }
                            }
                        } catch {
                            Write-Verbose "Could not read registry path $regPath : $_"
                        }
                    }
                }

                # Method 2: Check Event Logs for Intune sync events
                try {
                    $eventLogs = @(
                        @{LogName='Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin'; IDs=@(72,73,75,76,77)},
                        @{LogName='Application'; IDs=@()},
                        @{LogName='Microsoft-Windows-AAD/Operational'; IDs=@()}
                    )

                    foreach ($eventLog in $eventLogs) {
                        try {
                            if ($eventLog.IDs.Count -gt 0) {
                                $events = Get-WinEvent -FilterHashtable @{LogName=$eventLog.LogName; ID=$eventLog.IDs} -MaxEvents 10 -ErrorAction SilentlyContinue
                            } else {
                                $events = Get-WinEvent -FilterHashtable @{LogName=$eventLog.LogName} -MaxEvents 50 -ErrorAction SilentlyContinue | Where-Object { $_.Message -like "*Intune*" -or $_.Message -like "*MDM*" -or $_.Message -like "*device management*" }
                            }

                            if ($events) {
                                $latestEvent = $events | Sort-Object TimeCreated -Descending | Select-Object -First 1
                                if ($syncInfo.LastSyncTime -eq $null -or $latestEvent.TimeCreated -gt $syncInfo.LastSyncTime) {
                                    $syncInfo.LastSyncTime = $latestEvent.TimeCreated
                                    $syncInfo.LastSyncStatus = switch ($latestEvent.Id) {
                                        72 { "Success" }
                                        73 { "Failed" }
                                        75 { "In Progress" }
                                        76 { "Success" }
                                        77 { "Warning" }
                                        default {
                                            if ($latestEvent.LevelDisplayName -eq "Error") { "Failed" }
                                            elseif ($latestEvent.LevelDisplayName -eq "Warning") { "Warning" }
                                            else { "Success" }
                                        }
                                    }
                                }
                            }
                        } catch {
                            Write-Verbose "Could not check event log $($eventLog.LogName): $_"
                        }
                    }
                } catch {
                    Write-Verbose "Could not check Intune event logs: $_"
                }

                # Method 3: Check IME (Intune Management Extension) logs directory for recent activity
                try {
                    $imeLogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
                    if (Test-Path $imeLogPath) {
                        $recentLogFiles = Get-ChildItem -Path $imeLogPath -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5
                        if ($recentLogFiles) {
                            $mostRecentLog = $recentLogFiles[0]
                            if ($syncInfo.LastSyncTime -eq $null -or $mostRecentLog.LastWriteTime -gt $syncInfo.LastSyncTime) {
                                $syncInfo.LastSyncTime = $mostRecentLog.LastWriteTime
                                $syncInfo.LastSyncStatus = "Recent Activity"
                            }
                        }
                    }
                } catch {
                    Write-Verbose "Could not check IME logs: $_"
                }

                # Method 4: Calculate next sync and frequency
                if ($syncInfo.LastSyncTime) {
                    $syncInfo.SyncFrequency = "Every 8 hours (typical Intune schedule)"
                    $syncInfo.NextScheduledSync = $syncInfo.LastSyncTime.AddHours(8)

                    # If last sync was more than 24 hours ago, indicate potential issue
                    $hoursSinceSync = ((Get-Date) - $syncInfo.LastSyncTime).TotalHours
                    if ($hoursSinceSync -gt 24 -and $syncInfo.LastSyncStatus -eq "Success") {
                        $syncInfo.LastSyncStatus = "Overdue"
                    }
                } else {
                    $syncInfo.SyncFrequency = "Every 8 hours (when enrolled)"
                    $syncInfo.LastSyncStatus = "No sync data found"
                }

            } catch {
                Write-Verbose "Could not retrieve sync information: $_"
            }
        } else {
            $syncInfo.LastSyncStatus = "Not enrolled in MDM"
            $syncInfo.SyncFrequency = "N/A - Device not enrolled"
        }

        # Comprehensive Intune/MDM services list based on research and real-world behavior
        $intuneServices = @(
            # Core MDM Services - Note: Many of these are designed to be stopped when not actively needed
            @{Name='dmwappushservice'; DisplayName='Device Management Wireless Application Protocol Push service'; Category='Core MDM'; IsOptional=$true; Description='Normally stopped - starts when needed for Intune sync operations'}
            @{Name='DmEnrollmentSvc'; DisplayName='Device Management Enrollment Service'; Category='Core MDM'; IsOptional=$true; Description='On-demand service for device enrollment'}
            @{Name='DeviceManagementService'; DisplayName='Microsoft Device Management Service'; Category='Core MDM'; IsOptional=$true; Description='May not be present on all Intune-enrolled devices'}
            
            # Windows Push Notifications (WNS)
            @{Name='WpnService'; DisplayName='Windows Push Notifications System Service'; Category='Push Notifications'; IsOptional=$false; Description='Enables Windows Push Notification Services (WNS) for Intune'}
            @{Name='WpnUserService'; DisplayName='Windows Push Notifications User Service'; Category='Push Notifications'; IsOptional=$true; Description='Per-user WNS service for notifications'}
            
            # Microsoft Entra ID (Azure AD) Integration
            @{Name='TokenBroker'; DisplayName='Web Account Manager'; Category='Identity'; IsOptional=$false; Description='Manages Azure AD/Microsoft Entra authentication tokens'}
            @{Name='KeyIso'; DisplayName='CNG Key Isolation'; Category='Identity'; IsOptional=$false; Description='Provides key process isolation for cryptographic keys and SSL certificates'}
            @{Name='AppIDSvc'; DisplayName='Application Identity'; Category='Identity'; IsOptional=$true; Description='Determines and verifies the identity of applications'}
            
            # Certificate and Trust Services
            @{Name='CertPropSvc'; DisplayName='Certificate Propagation'; Category='Certificates'; IsOptional=$false; Description='Copies certificates from user store to computer store for smart cards'}
            @{Name='TrustedInstaller'; DisplayName='Windows Modules Installer'; Category='Updates'; IsOptional=$false; Description='Enables installation of Windows updates and optional components'}
            
            # Windows Update Medic and Management - Note: WaaSMedicSvc is on-demand, normally stopped
            @{Name='WaaSMedicSvc'; DisplayName='Windows Update Medic Service'; Category='Updates'; IsOptional=$true; Description='On-demand service for Windows Update repair - normally stopped'}
            @{Name='UsoSvc'; DisplayName='Update Orchestrator Service'; Category='Updates'; IsOptional=$false; Description='Manages Windows Updates and Intune-delivered updates'}
            @{Name='DoSvc'; DisplayName='Delivery Optimization'; Category='Updates'; IsOptional=$true; Description='Optimizes download bandwidth for Windows Updates and Intune apps'}
            
            # Device Registration and Enrollment
            @{Name='DeviceAssociationService'; DisplayName='Device Association Service'; Category='Enrollment'; IsOptional=$true; Description='Enables pairing between the system and wired or wireless devices'}
            @{Name='CDPUserSvc'; DisplayName='Connected Devices Platform User Service'; Category='Enrollment'; IsOptional=$true; Description='Per-user service for Connected Devices Platform scenarios'}
            
            # Windows Licensing and Activation
            @{Name='LicenseManager'; DisplayName='Windows License Manager Service'; Category='Licensing'; IsOptional=$true; Description='Provides infrastructure support for the Windows Store'}
            @{Name='ClipSVC'; DisplayName='Client License Service (ClipSVC)'; Category='Licensing'; IsOptional=$true; Description='Provides infrastructure support for the Microsoft Store'}
            @{Name='sppsvc'; DisplayName='Software Protection'; Category='Licensing'; IsOptional=$false; Description='Enables the download, installation and enforcement of digital licenses for Windows'}
            
            # Additional Management Services  
            @{Name='PimIndexMaintenanceSvc'; DisplayName='Contact Data'; Category='Data Sync'; IsOptional=$true; Description='Indexes contact data for fast contact searching'}
            @{Name='DiagTrack'; DisplayName='Connected User Experiences and Telemetry'; Category='Telemetry'; IsOptional=$true; Description='Enables experiences that connect users and telemetry data'}
            @{Name='InstallService'; DisplayName='Windows Installer'; Category='App Management'; IsOptional=$false; Description='Adds, modifies, and removes applications provided as Windows Installer packages'}
        )
        
        # Get services directly to avoid cache serialization issues
        $services = Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue
        
        # Sort Intune services alphabetically by display name for consistent presentation
        $sortedIntuneServices = $intuneServices | Sort-Object DisplayName
        
        $serviceStatus = @($sortedIntuneServices | ForEach-Object {
            $svcName = $_.Name
            $svc = $services | Where-Object { $_.Name -eq $svcName }
            
            # Determine health status for optional services
            $isHealthy = $false
            $healthReason = "Unknown"
            $isPresent = $svc -ne $null
            
            if ($svc) {
                if (-not $_.IsOptional) {
                    # Non-optional Intune services should be running
                    $isHealthy = ($svc.State -eq 'Running')
                    $healthReason = if ($svc.State -eq 'Running') { "Running (Required for MDM)" } 
                                   elseif ($svc.StartMode -eq 'Disabled') { "DISABLED - May impact Intune functionality" }
                                   else { "STOPPED - May impact Intune functionality" }
                } else {
                    # Optional services: Many are designed to be stopped when not actively needed
                    # Special case for on-demand services
                    if (($svc.Name -eq 'dmwappushservice' -or $svc.Name -eq 'WaaSMedicSvc') -and $svc.State -eq 'Stopped') {
                        # These services are supposed to be stopped most of the time
                        $isHealthy = $true
                        $healthReason = "OK (On-demand service - starts when needed)"
                    } else {
                        # Other optional services: OK if running or properly configured
                        $isHealthy = ($svc.State -eq 'Running') -or
                                   (($svc.StartMode -eq 'Manual' -or $svc.StartMode -eq 'Disabled') -and $svc.State -eq 'Stopped')
                        $healthReason = if ($svc.State -eq 'Running') { "Running (Optional)" }
                                       elseif ($svc.StartMode -eq 'Auto' -and $svc.State -eq 'Stopped') { "STOPPED - Should be running for optimal experience" }
                                       else { "OK ($($svc.StartMode)/$($svc.State))" }
                    }
                }
            } else {
                $healthReason = "Service not found"
                # For optional services, not being present is OK
                $isHealthy = $_.IsOptional
            }
            
            [PSCustomObject]@{
                Name = $svcName
                DisplayName = $_.DisplayName
                Category = $_.Category
                Description = $_.Description
                IsOptional = $_.IsOptional
                IsPresent = $isPresent
                Status = if ($svc) { $svc.State } else { "Not Found" }
                StartType = if ($svc) { $svc.StartMode } else { "N/A" }
                IsHealthy = $isHealthy
                HealthReason = $healthReason
            }
        })
        
        # Group services by category for better display
        $servicesByCategory = $serviceStatus | Group-Object -Property Category | ForEach-Object {
            [PSCustomObject]@{
                Category = $_.Name
                Services = $_.Group
                HealthyCount = @($_.Group | Where-Object IsHealthy).Count
                TotalCount = $_.Group.Count
                RequiredIssues = @($_.Group | Where-Object { -not $_.IsOptional -and -not $_.IsHealthy }).Count
                OptionalIssues = @($_.Group | Where-Object { $_.IsOptional -and -not $_.IsHealthy }).Count
            }
        }
        
        # Determine overall Intune services health
        $requiredServices = $serviceStatus | Where-Object { -not $_.IsOptional }
        $requiredHealthy = @($requiredServices | Where-Object IsHealthy).Count
        $requiredTotal = $requiredServices.Count
        
        $overallHealth = if ($requiredHealthy -eq $requiredTotal) { "Healthy" }
                        elseif ($requiredHealthy -gt ($requiredTotal * 0.8)) { "Warning" }
                        else { "Issues" }
        
        return [PSCustomObject]@{
            # MDM Enrollment Status
            IsEnrolled = $mdmEnrollmentInfo.IsEnrolled
            EnrollmentType = $mdmEnrollmentInfo.EnrollmentType
            DeviceId = $mdmEnrollmentInfo.DeviceId
            Authority = $mdmEnrollmentInfo.Authority
            TenantId = $mdmEnrollmentInfo.TenantId
            # Azure AD Status
            AzureAdJoined = $azureAdInfo.IsJoined
            AzureAdTenantId = $azureAdInfo.TenantId
            # Sync Information
            LastSyncTime = $syncInfo.LastSyncTime
            LastSyncStatus = $syncInfo.LastSyncStatus
            NextScheduledSync = $syncInfo.NextScheduledSync
            SyncFrequency = $syncInfo.SyncFrequency
            # Service Status
            Services = $serviceStatus
            ServicesByCategory = $servicesByCategory  
            HealthyCount = @($serviceStatus | Where-Object IsHealthy).Count
            TotalCount = $serviceStatus.Count
            RequiredCount = @($serviceStatus | Where-Object { -not $_.IsOptional }).Count
            OptionalCount = @($serviceStatus | Where-Object IsOptional).Count
            RequiredIssues = @($serviceStatus | Where-Object { -not $_.IsOptional -and -not $_.IsHealthy })
            OptionalIssues = @($serviceStatus | Where-Object { $_.IsOptional -and -not $_.IsHealthy })
            OverallHealth = $overallHealth
            IsIntuneCapable = ($requiredHealthy -ge ($requiredTotal * 0.8))  # 80% of required services healthy
        }
    }
    catch {
        Write-Warning "Failed to get Intune service status: $_"
        return [PSCustomObject]@{
            # MDM Enrollment Status
            IsEnrolled = $false
            EnrollmentType = $null
            DeviceId = $null
            Authority = $null
            TenantId = $null
            # Azure AD Status
            AzureAdJoined = $false
            AzureAdTenantId = $null
            # Service Status
            Services = @()
            ServicesByCategory = @()
            HealthyCount = 0
            TotalCount = 0
            RequiredCount = 0
            OptionalCount = 0
            RequiredIssues = @()
            OptionalIssues = @()
            OverallHealth = "Unknown"
            IsIntuneCapable = $false
        }
    }
}

function Get-SFCResultsFromCBS {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CBSLogPath,

        [Parameter(Mandatory)]
        [DateTime]$LastWrite,

        [Parameter(Mandatory)]
        [int]$DaysSinceScan
    )

    try {
        # Read the last 1000 lines of CBS.log to look for SFC results
        $logContent = Get-Content $CBSLogPath -Tail 1000 -ErrorAction SilentlyContinue

        if (-not $logContent) {
            return [PSCustomObject]@{
                LastScan = $null
                DaysSinceScan = $null
                Status = "CBS.log found but could not read content"
                Issues = @()
                Summary = "Unable to parse log"
                CBSLogLastModified = $LastWrite
            }
        }

        # Look for SFC scan completion markers
        # Modern Windows (10/11) uses [SR] markers in CBS.log
        $srPattern = "\[SR\]"
        $srVerifyComplete = "\[SR\].*Verify complete"
        $srRepairComplete = "\[SR\].*Repair complete"
        $srRepairing = "\[SR\].*Repairing (\d+) components"

        # Legacy patterns (Windows 7/8)
        $protectionViolation = "Windows Resource Protection found corrupt files"
        $noViolation = "Windows Resource Protection did not find any integrity violations"
        $couldNotRepair = "Windows Resource Protection found corrupt files but was unable to fix some of them"

        # Find the most recent SFC scan (modern [SR] markers or legacy text)
        $recentSfcLines = $logContent | Where-Object {
            $_ -match $srPattern -or
            $_ -match $protectionViolation -or
            $_ -match $noViolation -or
            $_ -match $couldNotRepair
        }

        if (-not $recentSfcLines) {
            return [PSCustomObject]@{
                LastScan = $null
                DaysSinceScan = $null
                Status = "No recent SFC scan found in CBS.log"
                Issues = @()
                Summary = "No SFC activity detected"
                CBSLogLastModified = $LastWrite
            }
        }

        # Find corruption issues
        $corruptFiles = @()
        try {
            $corruptFiles = $logContent | Where-Object { $_ -match $corruptionPattern } | ForEach-Object {
                try {
                    if ($_ -match "manifest file (.+) do not match") {
                        "Corrupt manifest: $($Matches[1])"
                    }
                    elseif ($_ -match "Cannot repair member file (.+)") {
                        "Cannot repair: $($Matches[1])"
                    }
                    elseif ($_ -match "(.+) could not be repaired") {
                        "Repair failed: $($Matches[1])"
                    }
                    else {
                        $_.Trim()
                    }
                } catch {
                    $_.Trim()  # Fallback to just the trimmed line
                }
            }
            if (-not $corruptFiles) { $corruptFiles = @() }
        } catch {
            Write-CollectorLog -Message "Error parsing corrupt files from CBS.log: $_" -Component "OS-Integrity" -Level "WARNING"
            $corruptFiles = @()
        }

        # Determine overall status and extract scan timestamp
        $status = "Unknown"
        $summary = "Unable to determine SFC result"
        $scanTimestamp = $LastWrite

        # Check modern [SR] format first
        $repairLine = $recentSfcLines | Where-Object { $_ -match $srRepairing } | Select-Object -Last 1
        if ($repairLine -and $repairLine -match "Repairing (\d+) components") {
            $componentCount = [int]$Matches[1]

            # Extract timestamp from log line (format: "2025-10-07 23:03:09, Info...")
            if ($repairLine -match "^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})") {
                try {
                    $scanTimestamp = [DateTime]::Parse($Matches[1])
                } catch {
                    # Keep using CBS.log LastWrite time if parsing fails
                }
            }

            if ($componentCount -eq 0) {
                $status = "No integrity violations found"
                $summary = "System files are healthy"
            } else {
                $status = "Repaired $componentCount component(s)"
                $summary = "System files had issues but were successfully repaired"
            }
        }
        # Check legacy format
        elseif ($recentSfcLines | Where-Object { $_ -match $noViolation }) {
            $status = "No integrity violations found"
            $summary = "System files are healthy"
        }
        elseif ($recentSfcLines | Where-Object { $_ -match $couldNotRepair }) {
            $status = "Integrity violations found but could not fix some"
            $summary = "System files have corruption that SFC could not repair"
        }
        elseif ($recentSfcLines | Where-Object { $_ -match $protectionViolation }) {
            $status = "Integrity violations found and repaired"
            $summary = "System files were corrupted but have been repaired"
        }
        elseif ($corruptFiles.Count -gt 0) {
            $status = "File corruption detected"
            $summary = "Corrupt files found in CBS.log"
        }

        # Calculate days since actual scan (not just CBS.log modification)
        $actualDaysSinceScan = ((Get-Date) - $scanTimestamp).Days

        return [PSCustomObject]@{
            LastScan = $scanTimestamp
            DaysSinceScan = $actualDaysSinceScan
            Status = $status
            Issues = [array]($corruptFiles | Select-Object -First 10)  # Ensure it's an array
            Summary = $summary
            TotalIssues = $corruptFiles.Count
            CBSLogLastModified = $LastWrite
        }
    }
    catch {
        Write-CollectorLog -Message "Failed to parse CBS.log: $_" -Component "OS-Integrity" -Level "ERROR"
        return [PSCustomObject]@{
            LastScan = $null
            DaysSinceScan = $null
            Status = "Critical"
            Issues = [array]@()
            Summary = "CBS.log parsing failed"
            CBSLogLastModified = $LastWrite
        }
    }
}

function Get-DISMResultsFromLogs {
    [CmdletBinding()]
    param()

    try {
        # IMPORTANT: DISM health check results are NOT logged to files
        # They only appear in console output, so we must run DISM /CheckHealth
        # This is a fast operation (1-3 seconds) and doesn't modify anything

        Write-CollectorLog -Message "Running DISM /CheckHealth to get current image health status" -Component "OS-Integrity"

        $dismResults = @{
            Status = "Unknown"
            Issues = @()
            Summary = "Unable to check DISM status"
            LastScan = (Get-Date)
            CorruptionLevel = "Unknown"
        }

        try {
            # Run DISM CheckHealth (fast, read-only check)
            $dismOutput = & dism.exe /Online /Cleanup-Image /CheckHealth /NoRestart 2>&1
            $dismExitCode = $LASTEXITCODE

            Write-CollectorLog -Message "DISM CheckHealth completed with exit code: $dismExitCode" -Component "OS-Integrity"

            # Parse DISM output
            $outputText = $dismOutput -join "`n"

            if ($outputText -match "No component store corruption detected") {
                $dismResults.Status = "Healthy"
                $dismResults.Summary = "No component store corruption detected"
                $dismResults.CorruptionLevel = "None"
            }
            elseif ($outputText -match "The component store is repairable") {
                $dismResults.Status = "Repairable"
                $dismResults.Summary = "Component store corruption detected but is repairable"
                $dismResults.CorruptionLevel = "Repairable"
            }
            elseif ($outputText -match "component store corruption was detected") {
                $dismResults.Status = "Corruption detected"
                $dismResults.Summary = "Component store corruption detected - run /RestoreHealth"
                $dismResults.CorruptionLevel = "Corruption"
            }
            else {
                $dismResults.Status = "Check completed"
                $dismResults.Summary = "DISM check completed (see full output for details)"
            }

            $dismResults.LastScan = Get-Date

            return [PSCustomObject]$dismResults

        } catch {
            Write-CollectorLog -Message "Failed to run DISM CheckHealth: $_" -Component "OS-Integrity" -Level "WARNING"
            $dismResults.Status = "Unable to run DISM"
            $dismResults.Summary = "Error executing DISM: $_"
            return [PSCustomObject]$dismResults
        }

        # If we got here, DISM execution failed above - return error result
        return [PSCustomObject]$dismResults
    }
    catch {
        Write-CollectorLog -Message "Failed to parse DISM logs: $_" -Component "OS-Integrity" -Level "ERROR"
        return [PSCustomObject]@{
            Status = "Critical"
            Issues = [array]@()
            Summary = "DISM log parsing failed"
            LastScan = $null
            CorruptionLevel = "Unknown"
        }
    }
}

function Get-OSSystemIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        $CachedServices,
        [Parameter(Mandatory=$false)]
        $CachedComputerInfo
    )

    try {
        $integrity = [PSCustomObject]@{
            SFC = $null
            DISM = $null
            WMI = $null
            ComponentStore = $null
            ChecksRun = $false  # Never run time-consuming checks
            Duration = $null
        }

        # Check for recent SFC scan results in CBS.log
        $cbsLog = "$env:windir\Logs\CBS\CBS.log"
        if (Test-Path $cbsLog) {
            $lastWrite = (Get-Item $cbsLog).LastWriteTime
            $daysSinceScan = ((Get-Date) - $lastWrite).Days

            # Look for SFC completion in recent log entries
            if ($daysSinceScan -lt 30) {
                $integrity.SFC = Get-SFCResultsFromCBS -CBSLogPath $cbsLog -LastWrite $lastWrite -DaysSinceScan $daysSinceScan
            }
        }

        # Check WMI repository - use cached computerInfo if available
        try {
            if ($CachedComputerInfo) {
                Write-CollectorLog -Message "Using cached ComputerInfo for WMI test (performance optimization)" -Component "OS-Integrity"
                $wmiTest = $CachedComputerInfo
            } else {
                $wmiTest = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
            }
            if ($wmiTest) {
                $integrity.WMI = "Consistent"
            }
        }
        catch {
            $integrity.WMI = "Potentially Inconsistent"
        }

        # Passive checks only - parse existing logs, no time-consuming scans
        $dismResults = Get-DISMResultsFromLogs
        if ($dismResults.LastScan) {
            $integrity.DISM = $dismResults
        } else {
            $integrity.DISM = [PSCustomObject]@{
                Status = "No recent scan results found"
                ManualCommand = "DISM /Online /Cleanup-Image /ScanHealth"
                Description = "Run this command as Administrator to check image health"
                EstimatedTime = "10-20 minutes"
            }
        }

        # Check if SFC results weren't found in passive check
        if (-not $integrity.SFC) {
            $integrity.SFC = [PSCustomObject]@{
                Status = "No recent scan results found"
                ManualCommand = "sfc /scannow"
                Description = "Run this command as Administrator to scan system files"
                EstimatedTime = "15-30 minutes"
            }
        }

        return $integrity
    }
    catch {
        Write-Warning "Failed to get system integrity: $_"
        return $null
    }
}

function Get-OSPerformanceMetrics {
    param($OSInfo)
    
    try {
        # Get current process snapshot directly
        $processes = Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue
        $perfData = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -ErrorAction SilentlyContinue
        
        # Get memory info
        $totalMemory = if ($OSInfo.TotalVisibleMemorySize -and $OSInfo.TotalVisibleMemorySize -gt 0) {
            $OSInfo.TotalVisibleMemorySize / 1MB
        } else { 0 }
        
        $freeMemory = if ($OSInfo.FreePhysicalMemory -and $OSInfo.FreePhysicalMemory -gt 0) {
            $OSInfo.FreePhysicalMemory / 1MB
        } else { 0 }
        
        $usedMemory = if ($totalMemory -gt 0) { $totalMemory - $freeMemory } else { 0 }
        
        # Get page file info
        $pageFile = Get-CimInstance -ClassName Win32_PageFileUsage -ErrorAction SilentlyContinue | Select-Object -First 1
        
        # Get disk info for C:
        # Get disk info directly
        $cDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
        
        # Get top processes by memory (approximate)
        $topMemory = @($processes | Sort-Object WorkingSetSize -Descending | Select-Object -First 5 | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                ProcessId = $_.ProcessId
                MemoryMB = [math]::Round($_.WorkingSetSize / 1MB, 2)
            }
        })
        
        return [PSCustomObject]@{
            CPUUsage = if ($perfData) { $perfData.PercentProcessorTime } else { "N/A" }
            Memory = [PSCustomObject]@{
                TotalGB = [math]::Round($totalMemory, 2)
                UsedGB = [math]::Round($usedMemory, 2)
                FreeGB = [math]::Round($freeMemory, 2)
                PercentUsed = if ($totalMemory -gt 0) {
                    [math]::Round(($usedMemory / $totalMemory) * 100, 2)
                } else { 0 }
            }
            PageFile = if ($pageFile -and $pageFile.AllocatedBaseSize -gt 0) {
                [PSCustomObject]@{
                    TotalSizeMB = $pageFile.AllocatedBaseSize
                    CurrentUsageMB = $pageFile.CurrentUsage
                    PeakUsageMB = $pageFile.PeakUsage
                    PercentUsed = [math]::Round(($pageFile.CurrentUsage / $pageFile.AllocatedBaseSize) * 100, 2)
                }
            } else { "N/A" }
            CDrive = if ($cDrive -and $cDrive.Size -gt 0) {
                [PSCustomObject]@{
                    TotalGB = [math]::Round($cDrive.Size / 1GB, 2)
                    FreeGB = [math]::Round($cDrive.FreeSpace / 1GB, 2)
                    UsedGB = [math]::Round(($cDrive.Size - $cDrive.FreeSpace) / 1GB, 2)
                    PercentFree = [math]::Round(($cDrive.FreeSpace / $cDrive.Size) * 100, 2)
                }
            } else { "N/A" }
            TopProcessesByMemory = $topMemory
            ProcessCount = @($processes).Count
        }
    }
    catch {
        Write-Warning "Failed to get performance metrics: $_"
        return $null
    }
}

function Get-OSBootPerformance {
    try {
        # Get boot performance from event log
        $bootEvents = @(Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational'; ID=100} -MaxEvents 1 -ErrorAction SilentlyContinue)
        
        $bootPerf = [PSCustomObject]@{
            LastBootDuration = "N/A"
            BootType = "N/A"
            MainPathBootTime = "N/A"
            BootPostBootTime = "N/A"
        }
        
        if ($bootEvents.Count -gt 0) {
            $xml = [xml]$bootEvents[0].ToXml()
            $eventData = $xml.Event.EventData.Data
            
            $bootPerf.LastBootDuration = ($eventData | Where-Object Name -eq 'BootTime').'#text'
            $bootPerf.BootType = ($eventData | Where-Object Name -eq 'BootType').'#text'
            $bootPerf.MainPathBootTime = ($eventData | Where-Object Name -eq 'MainPathBootTime').'#text'
            $bootPerf.BootPostBootTime = ($eventData | Where-Object Name -eq 'BootPostBootTime').'#text'
        }
        
        
        return $bootPerf
    }
    catch {
        Write-Warning "Failed to get boot performance: $_"
        return $null
    }
}

function Get-AllUserProfiles {
    try {
        Write-Verbose "Enumerating all user profiles from registry"
        $profiles = @()
        
        # Get all profiles from ProfileList registry
        $profileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
        $profileKeys = Get-ChildItem $profileListPath -ErrorAction SilentlyContinue
        
        foreach ($key in $profileKeys) {
            # Skip non-SID entries (.DEFAULT, etc.)
            if ($key.PSChildName -notmatch '^S-\d-\d+-(\d+-){1,14}\d+$' -and 
                $key.PSChildName -ne '.DEFAULT' -and 
                $key.PSChildName -ne 'Public') {
                continue
            }
            
            try {
                $profileReg = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue
                
                if (-not $profileReg.ProfileImagePath) { continue }
                
                # Get profile information
                $profilePath = $profileReg.ProfileImagePath
                $sid = $key.PSChildName
                
                # Determine profile type and status
                $profileType = "User"
                $isTemporary = $false
                $isDefault = $false
                $isPublic = $false
                
                if ($sid -eq '.DEFAULT') {
                    $profileType = "Default"
                    $isDefault = $true
                } elseif ($profilePath -match '\\Public$') {
                    $profileType = "Public"
                    $isPublic = $true
                } elseif ($profileReg.State -band 0x8000) {
                    # Temporary profile flag
                    $profileType = "Temporary"
                    $isTemporary = $true
                } elseif ($profilePath -match '\.bak$') {
                    $profileType = "Backup"
                }
                
                # Try to resolve SID to username
                $userName = "Unknown"
                if ($sid -match '^S-\d-\d+-') {
                    try {
                        $sidObj = New-Object System.Security.Principal.SecurityIdentifier($sid)
                        $userName = $sidObj.Translate([System.Security.Principal.NTAccount]).Value
                    }
                    catch {
                        # If SID can't be resolved, extract username from path
                        if ($profilePath -match '\\([^\\]+)$') {
                            $userName = $matches[1]
                        }
                    }
                } else {
                    $userName = $sid  # For .DEFAULT, Public, etc.
                }
                
                # Calculate profile size
                $profileSize = 0
                if (Test-Path $profilePath) {
                    try {
                        Write-Verbose "Calculating size for profile: $profilePath"
                        $profileSize = (Get-ChildItem $profilePath -Recurse -ErrorAction SilentlyContinue | 
                                       Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    }
                    catch {
                        Write-Verbose "Could not calculate size for profile: $profilePath"
                    }
                }
                
                # Get last use time
                $lastUseTime = $null
                if ($profileReg.LocalProfileLoadTimeHigh -and $profileReg.LocalProfileLoadTimeLow) {
                    $high = $profileReg.LocalProfileLoadTimeHigh
                    $low = $profileReg.LocalProfileLoadTimeLow
                    $fileTime = ([long]$high -shl 32) + $low
                    if ($fileTime -gt 0) {
                        $lastUseTime = [DateTime]::FromFileTime($fileTime)
                    }
                }
                
                # Get profile load/unload time for performance
                $profileLoadTime = $null
                if ($profileReg.LocalProfileLoadTimeHigh) {
                    # This gives us last load time
                    $profileLoadTime = $lastUseTime
                }
                
                # Determine if profile is currently loaded using multiple methods
                $isLoaded = $false
                $loadMethod = "RefCount"
                
                # Method 1: Check RefCount (traditional method)
                if ($profileReg.RefCount -gt 0) {
                    $isLoaded = $true
                    $loadMethod = "RefCount"
                }
                
                # Method 2: Check if this is the current user
                $currentUserSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
                if ($sid -eq $currentUserSid) {
                    $isLoaded = $true
                    $loadMethod = "CurrentUser"
                }
                
                # Method 3: Check if profile registry hive is loaded (for user profiles)
                if ($sid -match '^S-\d-\d+-' -and $sid -ne $currentUserSid) {
                    try {
                        $hiveKey = "HKU:\$sid"
                        if (Test-Path $hiveKey) {
                            $isLoaded = $true
                            $loadMethod = "HiveLoaded"
                        }
                    } catch {
                        # HKU might not be accessible, skip this check
                    }
                }
                
                # Method 4: Check running processes for the user (additional confirmation)
                if ($sid -match '^S-\d-\d+-' -and -not $isLoaded) {
                    try {
                        # Get processes for this user to confirm they're logged in
                        $userProcesses = Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue | 
                                       Where-Object { 
                                           try {
                                               $processOwner = $_.GetOwner()
                                               if ($processOwner -and $processOwner.Domain -and $processOwner.User) {
                                                   $processUserAccount = "$($processOwner.Domain)\$($processOwner.User)"
                                                   $processUserSid = (New-Object System.Security.Principal.NTAccount($processUserAccount)).Translate([System.Security.Principal.SecurityIdentifier]).Value
                                                   return $processUserSid -eq $sid
                                               }
                                           } catch { }
                                           return $false
                                       }
                        if ($userProcesses -and @($userProcesses).Count -gt 0) {
                            $isLoaded = $true
                            $loadMethod = "ProcessCheck"
                        }
                    } catch {
                        # Process check failed, rely on previous methods
                    }
                }
                
                $profiles += [PSCustomObject]@{
                    UserName = $userName
                    SID = $sid
                    ProfilePath = $profilePath
                    ProfileType = $profileType
                    IsTemporary = $isTemporary
                    IsDefault = $isDefault
                    IsPublic = $isPublic
                    State = $profileReg.State
                    ProfileSizeGB = [math]::Round($profileSize / 1GB, 2)
                    LastUseTime = $lastUseTime
                    ProfileLoadTime = $profileLoadTime
                    RefCount = $profileReg.RefCount
                    RunLogonScriptSync = $profileReg.RunLogonScriptSync
                    IsLoaded = $isLoaded
                    LoadMethod = $loadMethod  # How we determined the profile was loaded
                }
            }
            catch {
                Write-Warning "Failed to process profile $($key.PSChildName): $_"
            }
        }
        
        # Add system profiles if not already included
        $systemProfiles = @('Default', 'Public')
        foreach ($sysProfile in $systemProfiles) {
            if (-not ($profiles | Where-Object { $_.ProfileType -eq $sysProfile })) {
                $sysPath = if ($sysProfile -eq 'Default') {
                    "$env:SystemDrive\Users\Default"
                } else {
                    "$env:SystemDrive\Users\Public"
                }
                
                if (Test-Path $sysPath) {
                    $size = 0
                    try {
                        $size = (Get-ChildItem $sysPath -Recurse -ErrorAction SilentlyContinue | 
                                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    }
                    catch {
                        Write-Verbose "Could not calculate size for $sysProfile profile"
                    }
                    
                    $profiles += [PSCustomObject]@{
                        UserName = $sysProfile
                        SID = $sysProfile
                        ProfilePath = $sysPath
                        ProfileType = $sysProfile
                        IsTemporary = $false
                        IsDefault = $sysProfile -eq 'Default'
                        IsPublic = $sysProfile -eq 'Public'
                        State = 0
                        ProfileSizeGB = [math]::Round($size / 1GB, 2)
                        LastUseTime = $null
                        ProfileLoadTime = $null
                        RefCount = 0
                        RunLogonScriptSync = $false
                        IsLoaded = $false
                    }
                }
            }
        }
        
        # Create summary
        $summary = [PSCustomObject]@{
            TotalProfiles = $profiles.Count
            UserProfiles = @($profiles | Where-Object { $_.ProfileType -eq 'User' }).Count
            TemporaryProfiles = @($profiles | Where-Object { $_.IsTemporary }).Count
            LoadedProfiles = @($profiles | Where-Object { $_.IsLoaded }).Count
            TotalSizeGB = [math]::Round(($profiles | Measure-Object -Property ProfileSizeGB -Sum).Sum, 2)
            HasTemporaryProfiles = @($profiles | Where-Object { $_.IsTemporary }).Count -gt 0
        }
        
        return [PSCustomObject]@{
            Profiles = $profiles
            Summary = $summary
            CurrentUser = [PSCustomObject]@{
                UserName = $env:USERNAME
                ProfilePath = $env:USERPROFILE
                Domain = $env:USERDOMAIN
            }
        }
    }
    catch {
        Write-Warning "Failed to enumerate user profiles: $_"
        return $null
    }
}

function Get-OSGroupPolicyStatus {
    try {
        Write-CollectorLog -Message "Enhanced Group Policy status detection starting" -Component "OS-GroupPolicy"

        $gpStatus = @{
            LastComputerPolicyRefresh = $null
            LastUserPolicyRefresh = $null
            HoursSinceRefresh = 999
            Status = "Unknown"
            Applied = $false
            DetectionMethods = @()
            Warnings = @()
        }

        # Method 1: Check Event Log for recent GP events (priority for cloud-managed devices)
        Write-CollectorLog -Message "Checking Event Log for GP events" -Component "OS-GroupPolicy"
        try {
            $gpEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ID=1500,1501,1502,1503} -MaxEvents 1 -ErrorAction SilentlyContinue
            if ($gpEvents) {
                $latestEvent = $gpEvents[0]
                $gpStatus.LastComputerPolicyRefresh = $latestEvent.TimeCreated
                $gpStatus.HoursSinceRefresh = [math]::Round(((Get-Date) - $latestEvent.TimeCreated).TotalHours, 2)
                $gpStatus.Applied = $true
                $gpStatus.Status = "Applied"
                $gpStatus.DetectionMethods += "Event-Log"
                Write-CollectorLog -Message "GP last refresh from events: $($latestEvent.TimeCreated)" -Component "OS-GroupPolicy"
            }
        } catch {
            Write-CollectorLog -Message "Failed to check GP events: $_" -Level "WARNING" -Component "OS-GroupPolicy"
        }

        # Method 1b: Check machine GP state registry (fallback for traditional domain)
        if (-not $gpStatus.Applied) {
            Write-CollectorLog -Message "Checking machine GP state registry" -Component "OS-GroupPolicy"
            $machineGPPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine"
            $machineGP = Get-ItemProperty -Path $machineGPPath -ErrorAction SilentlyContinue

            if ($machineGP -and $machineGP.LastPolicyRefreshTime) {
                try {
                    $lastRefresh = [datetime]::FromFileTime($machineGP.LastPolicyRefreshTime)
                    $gpStatus.LastComputerPolicyRefresh = $lastRefresh
                    $gpStatus.HoursSinceRefresh = [math]::Round(((Get-Date) - $lastRefresh).TotalHours, 2)
                    $gpStatus.Applied = $true
                    $gpStatus.Status = "Applied"
                    $gpStatus.DetectionMethods += "Machine-State-Registry"
                    Write-CollectorLog -Message "GP last refresh from registry: $lastRefresh" -Component "OS-GroupPolicy"
                } catch {
                    Write-CollectorLog -Message "Failed to parse GP refresh time: $_" -Level "WARNING" -Component "OS-GroupPolicy"
                    $gpStatus.Warnings += "Failed to parse GP refresh time"
                }
            }
        }

        # Method 1c: Check gpresult command (fallback for cloud-managed devices)
        if (-not $gpStatus.Applied) {
            Write-CollectorLog -Message "Checking gpresult for GP refresh time" -Component "OS-GroupPolicy"
            try {
                $gpresultOutput = & gpresult /R /SCOPE COMPUTER 2>$null
                if ($gpresultOutput -and $gpresultOutput -match "Last time Group Policy was applied:\s*(.+)") {
                    $gpTimeString = $matches[1].Trim()
                    try {
                        $lastRefresh = [datetime]::Parse($gpTimeString)
                        $gpStatus.LastComputerPolicyRefresh = $lastRefresh
                        $gpStatus.HoursSinceRefresh = [math]::Round(((Get-Date) - $lastRefresh).TotalHours, 2)
                        $gpStatus.Applied = $true
                        $gpStatus.Status = "Applied"
                        $gpStatus.DetectionMethods += "GPResult-Command"
                        Write-CollectorLog -Message "GP last refresh from gpresult: $lastRefresh" -Component "OS-GroupPolicy"
                    } catch {
                        Write-CollectorLog -Message "Failed to parse gpresult time '$gpTimeString': $_" -Level "WARNING" -Component "OS-GroupPolicy"
                        $gpStatus.Warnings += "Failed to parse gpresult time"
                    }
                }
            } catch {
                Write-CollectorLog -Message "Failed to run gpresult: $_" -Level "WARNING" -Component "OS-GroupPolicy"
            }
        }

        # Method 2: Check for GP history registry
        Write-CollectorLog -Message "Checking GP history registry" -Component "OS-GroupPolicy"
        $gpHistoryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\History"
        if (Test-Path $gpHistoryPath -ErrorAction SilentlyContinue) {
            $gpStatus.Applied = $true
            $gpStatus.DetectionMethods += "History-Registry"
            if ($gpStatus.Status -eq "Unknown") {
                $gpStatus.Status = "Applied (History Found)"
            }
            Write-CollectorLog -Message "GP history registry found" -Component "OS-GroupPolicy"
        }

        # Method 3: Check for GP extensions (indicates GP processing capability)
        Write-CollectorLog -Message "Checking GP extensions registry" -Component "OS-GroupPolicy"
        $gpExtPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions"
        if (Test-Path $gpExtPath -ErrorAction SilentlyContinue) {
            $extensions = Get-ChildItem $gpExtPath -ErrorAction SilentlyContinue
            if ($extensions -and $extensions.Count -gt 0) {
                $gpStatus.Applied = $true
                $gpStatus.DetectionMethods += "Extensions-Registry"
                if ($gpStatus.Status -eq "Unknown") {
                    $gpStatus.Status = "Applied (Extensions Found)"
                }
                Write-CollectorLog -Message "GP extensions found: $($extensions.Count) extensions" -Component "OS-GroupPolicy"
            }
        }

        # Method 4: Check GP cache directory
        Write-CollectorLog -Message "Checking GP cache directory" -Component "OS-GroupPolicy"
        $gpCachePath = "$env:WINDIR\System32\GroupPolicy"
        if (Test-Path $gpCachePath -ErrorAction SilentlyContinue) {
            $cacheFiles = Get-ChildItem $gpCachePath -Recurse -ErrorAction SilentlyContinue
            if ($cacheFiles -and $cacheFiles.Count -gt 0) {
                $gpStatus.Applied = $true
                $gpStatus.DetectionMethods += "Cache-Directory"
                if ($gpStatus.Status -eq "Unknown") {
                    $gpStatus.Status = "Applied (Cache Found)"
                }
                Write-CollectorLog -Message "GP cache directory found with $($cacheFiles.Count) files" -Component "OS-GroupPolicy"
            }
        }

        # Method 5: Check if domain-joined (GP likely applies) - use passed-in computerInfo
        Write-CollectorLog -Message "Checking domain membership context" -Component "OS-GroupPolicy"
        # $computerInfo is already available from parent function, no need to query again
        if ($computerInfo -and $computerInfo.DomainRole -in @(1,3,4,5)) {
            $gpStatus.DetectionMethods += "Domain-Context"
            if ($gpStatus.Status -eq "Unknown") {
                $gpStatus.Status = "Expected (Domain Joined)"
                $gpStatus.Applied = $true
            }
            Write-CollectorLog -Message "Domain membership detected, GP expected" -Component "OS-GroupPolicy"
        } else {
            if ($gpStatus.Applied) {
                $gpStatus.Warnings += "GP appears applied but device is not domain-joined"
                Write-CollectorLog -Message "Warning: GP applied on non-domain device" -Level "WARNING" -Component "OS-GroupPolicy"
            }
        }

        # Method 6: Check GP service status
        Write-CollectorLog -Message "Checking Group Policy service status" -Component "OS-GroupPolicy"
        $gpSvc = Get-Service -Name gpsvc -ErrorAction SilentlyContinue
        if ($gpSvc) {
            $gpStatus.DetectionMethods += "Service-Status"
            if ($gpSvc.Status -eq 'Running') {
                Write-CollectorLog -Message "Group Policy service is running" -Component "OS-GroupPolicy"
            } else {
                $gpStatus.Warnings += "Group Policy service is not running"
                Write-CollectorLog -Message "Warning: Group Policy service not running" -Level "WARNING" -Component "OS-GroupPolicy"
            }
        }

        # Final status determination
        if ($gpStatus.Status -eq "Unknown" -and $gpStatus.DetectionMethods.Count -eq 0) {
            $gpStatus.Status = "Not Applied"
            Write-CollectorLog -Message "No GP evidence found" -Component "OS-GroupPolicy"
        }

        Write-CollectorLog -Message "GP detection completed. Status: $($gpStatus.Status), Methods: $($gpStatus.DetectionMethods -join ',')" -Component "OS-GroupPolicy"

        return [PSCustomObject]$gpStatus
    }
    catch {
        Write-Warning "Failed to get GP status: $_"
        Write-CollectorLog -Message "Failed to get GP status: $_" -Level "ERROR" -Component "OS-GroupPolicy"
        return [PSCustomObject]@{
            LastComputerPolicyRefresh = $null
            LastUserPolicyRefresh = $null
            HoursSinceRefresh = 999
            Status = "Critical"
            Applied = $false
            DetectionMethods = @()
            Warnings = @("Failed to retrieve GP status: $_")
        }
    }
}

function Test-DomainGroupPolicyConsistency {
    param(
        [Parameter(Mandatory)]
        $DomainInfo,
        [Parameter(Mandatory)]
        $GroupPolicyInfo
    )

    try {
        Write-CollectorLog -Message "Testing domain/GP consistency" -Component "OS-Validation"

        $validation = @{
            IsConsistent = $true
            Warnings = @()
            Recommendations = @()
            Severity = "None"
        }

        # Check for domain/GP inconsistencies
        if ($DomainInfo.IsDomainJoined -and -not $GroupPolicyInfo.Applied) {
            $validation.IsConsistent = $false
            $validation.Warnings += "Device appears domain-joined but no group policy evidence found"
            $validation.Recommendations += "Check group policy service status and network connectivity to domain controllers"
            $validation.Severity = "High"
            Write-CollectorLog -Message "Inconsistency: Domain joined but no GP" -Level "WARNING" -Component "OS-Validation"
        }

        if (-not $DomainInfo.IsDomainJoined -and $GroupPolicyInfo.Applied) {
            $validation.IsConsistent = $false
            $validation.Warnings += "Group policy appears applied but device shows as workgroup member"
            $validation.Recommendations += "Verify domain membership status and check for local group policy"
            $validation.Severity = "Medium"
            Write-CollectorLog -Message "Inconsistency: GP applied but not domain joined" -Level "WARNING" -Component "OS-Validation"
        }

        # Check for workgroup/domain name conflicts
        if ($DomainInfo.PSObject.Properties.Name -contains "Warning") {
            $validation.IsConsistent = $false
            $validation.Warnings += $DomainInfo.Warning
            $validation.Recommendations += "Investigate domain trust relationship and network configuration"
            if ($validation.Severity -eq "None") { $validation.Severity = "Medium" }
            Write-CollectorLog -Message "Domain info warning detected" -Level "WARNING" -Component "OS-Validation"
        }

        # Check GP refresh time anomalies
        if ($GroupPolicyInfo.Applied -and $GroupPolicyInfo.HoursSinceRefresh -gt (24 * 7)) {
            $validation.Warnings += "Group policy last refresh was over a week ago"
            $validation.Recommendations += "Consider running 'gpupdate /force' to refresh group policy"
            if ($validation.Severity -eq "None") { $validation.Severity = "Low" }
            Write-CollectorLog -Message "GP refresh time is stale" -Level "WARNING" -Component "OS-Validation"
        }

        # Check for GP service issues
        if ($GroupPolicyInfo.Warnings -and $GroupPolicyInfo.Warnings.Count -gt 0) {
            $validation.IsConsistent = $false
            $validation.Warnings += $GroupPolicyInfo.Warnings
            $validation.Recommendations += "Address group policy service issues for proper policy application"
            if ($validation.Severity -eq "None") { $validation.Severity = "Medium" }
            Write-CollectorLog -Message "GP service warnings detected" -Level "WARNING" -Component "OS-Validation"
        }

        # Positive validation
        if ($validation.IsConsistent) {
            Write-CollectorLog -Message "Domain/GP configuration appears consistent" -Component "OS-Validation"
        }

        return [PSCustomObject]$validation
    }
    catch {
        Write-Warning "Failed to validate domain/GP consistency: $_"
        Write-CollectorLog -Message "Failed to validate domain/GP consistency: $_" -Level "ERROR" -Component "OS-Validation"
        return [PSCustomObject]@{
            IsConsistent = $false
            Warnings = @("Failed to perform consistency validation: $_")
            Recommendations = @("Manually verify domain membership and group policy status")
            Severity = "Unknown"
        }
    }
}

function Get-OSEventLogAnalysis {
    param(
        [Parameter(Mandatory=$false)]
        $CachedCriticalEvents,
        [Parameter(Mandatory=$false)]
        $CachedFailedLogins
    )
    try {
        $7DaysAgo = (Get-Date).AddDays(-7)

        # Use cached critical errors if available
        $criticalErrors = if ($CachedCriticalEvents) {
            Write-CollectorLog -Message "Using cached critical events (performance optimization)" -Component "OS-EventLog"
            $CachedCriticalEvents.Count
        } else {
            Write-CollectorLog -Message "Querying System critical events directly (no cache available)" -Component "OS-EventLog"
            @(Get-WinEvent -FilterHashtable @{LogName='System'; Level=1; StartTime=$7DaysAgo} -ErrorAction SilentlyContinue).Count
        }

        # Count application crashes (last 7 days)
        $appCrashes = @(Get-WinEvent -FilterHashtable @{LogName='Application'; ID=1000; StartTime=$7DaysAgo} -ErrorAction SilentlyContinue).Count

        # Count service failures (last 7 days)
        $serviceFailures = @(Get-WinEvent -FilterHashtable @{LogName='System'; ID=7034; StartTime=$7DaysAgo} -ErrorAction SilentlyContinue).Count

        # Use cached authentication failures if available (last 7 days)
        $authFailures = if ($CachedFailedLogins) {
            Write-CollectorLog -Message "Using cached failed login events (performance optimization)" -Component "OS-EventLog"
            $CachedFailedLogins.Count
        } else {
            Write-CollectorLog -Message "Querying Security failed logins directly (no cache available)" -Component "OS-EventLog"
            @(Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=$7DaysAgo} -ErrorAction SilentlyContinue).Count
        }

        return [PSCustomObject]@{
            TimeRange = "Last 7 days"
            CriticalErrors = $criticalErrors
            ApplicationCrashes = $appCrashes
            ServiceFailures = $serviceFailures
            AuthenticationFailures = $authFailures
        }
    }
    catch {
        Write-Warning "Failed to analyze event logs: $_"
        return $null
    }
}

function Get-DomainAuthenticationStatus {
    <#
    .SYNOPSIS
        Gets comprehensive domain authentication status for enterprise troubleshooting
    #>
    param(
        [Parameter(Mandatory=$false)]
        $CachedFailedLogins
    )

    try {
        $domainAuth = [PSCustomObject]@{
            IsDomainJoined = $false
            DomainName = $null
            DomainController = $null
            DCConnectivity = "Unknown"
            KerberosStatus = "Unknown"
            LastKerberosRenewal = $null
            TrustRelationship = "Unknown"
            ComputerAccountStatus = "Unknown"
            TimeDrift = $null
            LastSuccessfulAuth = $null
            RecentAuthFailures = 0
            DNSResolution = "Unknown"
        }

        # Check if domain joined
        $computerInfo = Get-ComputerInfo -Property CsDomain, CsDomainRole -ErrorAction SilentlyContinue
        $domainAuth.DomainName = $computerInfo.CsDomain

        # Test secure channel (trust relationship) - this is the key metric
        $isDomainJoined = $false
        try {
            $trustTest = Test-ComputerSecureChannel -ErrorAction SilentlyContinue
            $isDomainJoined = $trustTest -eq $true
            $domainAuth.IsDomainJoined = $isDomainJoined
            $domainAuth.TrustRelationship = if ($trustTest) { "Healthy" } else { "Broken or Not Domain Joined" }
        } catch {
            $domainAuth.IsDomainJoined = $false
            $domainAuth.TrustRelationship = "Not Domain Joined"
        }

        if ($isDomainJoined) {

            # Check Kerberos ticket status
            try {
                $kerberosTickets = klist 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $domainAuth.KerberosStatus = "Healthy"
                    # Look for krbtgt ticket renewal time
                    $krbtgtTicket = $kerberosTickets | Where-Object { $_ -like "*krbtgt*" }
                    if ($krbtgtTicket) {
                        $domainAuth.KerberosStatus = "Healthy"
                    }
                } else {
                    $domainAuth.KerberosStatus = "No tickets"
                }
            } catch {
                $domainAuth.KerberosStatus = "Critical"
            }

            # Check DNS resolution for domain
            try {
                $dnsTest = Resolve-DnsName -Name $computerInfo.CsDomain -ErrorAction SilentlyContinue
                $domainAuth.DNSResolution = if ($dnsTest) { "Success" } else { "Failed" }
            } catch {
                $domainAuth.DNSResolution = "Failed"
            }

            # Check recent authentication failures
            try {
                # Use cached failed logins if available
                if ($CachedFailedLogins) {
                    Write-CollectorLog -Message "Using cached failed login events (performance optimization)" -Component "OS-DomainAuth"
                    $domainAuth.RecentAuthFailures = $CachedFailedLogins.Count
                } else {
                    Write-CollectorLog -Message "Querying Security failed logins directly (no cache available)" -Component "OS-DomainAuth"
                    $24HoursAgo = (Get-Date).AddHours(-24)
                    $authFailures = @(Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=$24HoursAgo} -ErrorAction SilentlyContinue)
                    $domainAuth.RecentAuthFailures = $authFailures.Count
                }

                # Look for last successful logon
                $24HoursAgo = (Get-Date).AddHours(-24)
                $successfulAuth = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624; StartTime=$24HoursAgo} -MaxEvents 1 -ErrorAction SilentlyContinue
                if ($successfulAuth) {
                    $domainAuth.LastSuccessfulAuth = $successfulAuth.TimeCreated
                }
            } catch {
                # Silent fail for event log access issues
            }
        }

        return $domainAuth
    }
    catch {
        Write-Warning "Failed to get domain authentication status: $_"
        return $null
    }
}

function Get-TimeSynchronizationStatus {
    <#
    .SYNOPSIS
        Gets comprehensive time synchronization status for enterprise troubleshooting
    #>

    try {
        $timeSync = [PSCustomObject]@{
            CurrentTime = Get-Date
            TimeZone = $null
            NTPSource = "Unknown"
            NTPStatus = "Unknown"
            LastSyncTime = $null
            TimeDrift = $null
            SyncInterval = $null
            TimeSourceType = "Unknown"
            W32TimeStatus = "Unknown"
        }

        # Get time zone info
        $timeSync.TimeZone = (Get-TimeZone).Id

        # Check W32Time service status
        $w32timeService = Get-Service W32Time -ErrorAction SilentlyContinue
        if ($w32timeService) {
            $timeSync.W32TimeStatus = $w32timeService.Status
        }

        # Get NTP configuration and status
        try {
            $w32timeConfig = w32tm /query /configuration 2>$null
            if ($LASTEXITCODE -eq 0) {
                # Extract NTP server
                $ntpServerLine = $w32timeConfig | Where-Object { $_ -like "*NtpServer*" }
                if ($ntpServerLine) {
                    $timeSync.NTPSource = ($ntpServerLine -split ":")[1].Trim() -replace ",.*", ""
                }

                # Extract type (NTP vs NT5DS for domain)
                $typeLine = $w32timeConfig | Where-Object { $_ -like "*Type*" }
                if ($typeLine) {
                    $type = ($typeLine -split ":")[1].Trim()
                    $timeSync.TimeSourceType = switch ($type) {
                        "NTP" { "NTP Server" }
                        "NT5DS" { "Domain Hierarchy" }
                        "NoSync" { "No Sync" }
                        default { $type }
                    }
                }
            }

            # Get last sync status
            $w32timeStatus = w32tm /query /status 2>$null
            if ($LASTEXITCODE -eq 0) {
                # Extract last sync time
                $lastSyncLine = $w32timeStatus | Where-Object { $_ -like "*Last Successful Sync Time*" }
                if ($lastSyncLine) {
                    $lastSyncStr = ($lastSyncLine -split ":")[1].Trim()
                    try {
                        $timeSync.LastSyncTime = [DateTime]::Parse($lastSyncStr)
                    } catch {
                        $timeSync.LastSyncTime = $lastSyncStr
                    }
                }

                # Extract sync interval
                $intervalLine = $w32timeStatus | Where-Object { $_ -like "*Poll Interval*" }
                if ($intervalLine) {
                    $timeSync.SyncInterval = ($intervalLine -split ":")[1].Trim()
                }

                # Determine overall status
                if ($lastSyncLine -and $lastSyncLine -notlike "*unspecified*") {
                    $timeSync.NTPStatus = "Synchronized"
                } else {
                    $timeSync.NTPStatus = "Not Synchronized"
                }
            }

            # Test time drift by comparing with reliable source
            try {
                $w32timeTest = w32tm /stripchart /computer:time.windows.com /samples:1 /dataonly 2>$null
                if ($LASTEXITCODE -eq 0 -and $w32timeTest) {
                    $driftLine = $w32timeTest | Where-Object { $_ -like "*,*" } | Select-Object -First 1
                    if ($driftLine) {
                        $driftValue = ($driftLine -split ",")[1].Trim()
                        if ($driftValue -match "([+-]?\d+\.?\d*)s") {
                            $timeSync.TimeDrift = [math]::Abs([double]$matches[1])
                        }
                    }
                }
            } catch {
                # Silent fail for external time check
            }

        } catch {
            $timeSync.NTPStatus = "Critical"
        }

        return $timeSync
    }
    catch {
        Write-Warning "Failed to get time synchronization status: $_"
        return $null
    }
}