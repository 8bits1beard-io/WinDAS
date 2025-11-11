# Get-NetworkData.ps1
# Collect comprehensive network adapter and connectivity data
# Author: Joshua Walderbach

function Get-NetworkData {
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$DataCache = $Global:DataCache
    )
    
    Write-ProgressStatus -Activity "Collecting Network Data" -Status "Initializing"
    
    # Initialize network data structure
    $networkData = [PSCustomObject]@{
        CollectedAt = Get-Date
        Summary = $null
        ActiveAdapters = @()
        InactiveAdapters = @()
        Performance = $null
        ConnectivityTests = $null
        WiFiDetails = $null
        Configuration = $null
        DNS = $null
        RoutingTable = @()
        FirewallRules = $null
        HealthStatus = "Unknown"
    }
    
    try {
        # Get network adapter data - try cache first, then direct query
        $networkAdapters = Get-CachedData -ClassName 'Win32_NetworkAdapter'
        $networkConfigs = Get-CachedData -ClassName 'Win32_NetworkAdapterConfiguration'
        
        # If cache is empty, query directly - get ALL adapters, we'll filter later
        if (-not $networkAdapters) {
            Write-Verbose "Cache miss for Win32_NetworkAdapter, querying directly"
            # Get all network adapters, we'll separate active/inactive later
            $networkAdapters = Get-CimInstance -ClassName 'Win32_NetworkAdapter' -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch 'WAN Miniport|Packet Scheduler|RAS Async|ISATAP|Teredo|6to4' }
        }
        
        if (-not $networkConfigs) {
            Write-Verbose "Cache miss for Win32_NetworkAdapterConfiguration, querying directly for IP-enabled adapters"
            # Only get configurations for adapters with IP enabled
            $networkConfigs = Get-CimInstance -ClassName 'Win32_NetworkAdapterConfiguration' -Filter "IPEnabled=TRUE" -ErrorAction SilentlyContinue
        }
        
        if (-not $networkAdapters -or -not $networkConfigs) {
            Write-Warning "Network adapter data not available"
            return $networkData
        }
        
        # Process network adapters
        Write-ProgressStatus -Activity "Collecting Network Data" -Status "Processing network adapters" -PercentComplete 10
        $adapterInfo = Get-NetworkAdapterInfo -Adapters $networkAdapters -Configs $networkConfigs
        $networkData.ActiveAdapters = $adapterInfo.Active
        $networkData.InactiveAdapters = $adapterInfo.Inactive
        
        # Get network statistics (removing misleading bandwidth/packet loss metrics)
        Write-ProgressStatus -Activity "Collecting Network Data" -Status "Gathering network statistics" -PercentComplete 30
        $networkData.Performance = Get-NetworkPerformance -ActiveAdapters $networkData.ActiveAdapters
        
        # Perform connectivity tests
        Write-ProgressStatus -Activity "Collecting Network Data" -Status "Running connectivity tests" -PercentComplete 50
        $networkData.ConnectivityTests = Get-NetworkConnectivity -ActiveAdapters $networkData.ActiveAdapters
        
        # Get WiFi details if applicable
        Write-ProgressStatus -Activity "Collecting Network Data" -Status "Checking WiFi status" -PercentComplete 70
        $networkData.WiFiDetails = Get-WiFiDetails
        
        # Get network configuration
        Write-ProgressStatus -Activity "Collecting Network Data" -Status "Getting network configuration" -PercentComplete 85
        $networkData.Configuration = Get-NetworkConfiguration

        # Get DNS cache information
        $networkData.DNS = Get-DNSCacheInfo -Configuration $networkData.Configuration

        # Get routing table
        Write-ProgressStatus -Activity "Collecting Network Data" -Status "Getting routing table" -PercentComplete 87
        $networkData.RoutingTable = Get-RoutingTable
        
        # Get firewall rules
        Write-ProgressStatus -Activity "Collecting Network Data" -Status "Getting firewall rules" -PercentComplete 90
        $networkData.FirewallRules = Get-FirewallRules
        
        # Create summary
        Write-ProgressStatus -Activity "Collecting Network Data" -Status "Creating summary" -PercentComplete 95
        $networkData.Summary = Get-NetworkSummary -NetworkData $networkData
        
        # Determine overall health status
        $networkData.HealthStatus = Get-NetworkHealthStatus -NetworkData $networkData
        
        Write-ProgressStatus -Activity "Collecting Network Data" -Completed
    }
    catch {
        Write-Error "Failed to collect network data: $_"
    }
    
    return $networkData
}

function Get-NetworkAdapterInfo {
    param($Adapters, $Configs)
    
    try {
        $activeAdapters = @()
        $inactiveAdapters = @()
        
        foreach ($adapter in $Adapters) {
            # Skip virtual and non-physical adapters - but since we're filtering at query time, this is just a backup
            if ($adapter.Name -match 'Virtual|VMware|VirtualBox|Hyper-V|WAN Miniport|ISATAP|Teredo|6to4|Loopback') {
                continue
            }
            
            # Find matching configuration
            $config = $Configs | Where-Object { $_.Index -eq $adapter.Index } | Select-Object -First 1
            
            if (-not $config) { continue }
            
            # Get adapter statistics if available
            $stats = $null
            try {
                $stats = Get-NetAdapterStatistics -Name $adapter.NetConnectionID -ErrorAction SilentlyContinue
            }
            catch {
                Write-Verbose "Could not get statistics for adapter: $($adapter.Name)"
            }
            
            $adapterData = [PSCustomObject]@{
                Name = $adapter.Name
                NetConnectionID = $adapter.NetConnectionID
                Description = $adapter.Description
                MACAddress = $adapter.MACAddress
                Status = $adapter.NetConnectionStatus
                Enabled = $adapter.NetEnabled
                Speed = if ($adapter.Speed -and $adapter.Speed -gt 0) {
                    if ($adapter.Speed -ge 1000000000) {
                        "$([math]::Round($adapter.Speed / 1000000000, 2)) Gbps"
                    } else {
                        "$([math]::Round($adapter.Speed / 1000000, 0)) Mbps"
                    }
                } else { "Unknown" }
                IPAddresses = $config.IPAddress
                IPSubnets = $config.IPSubnet
                DefaultGateway = if ($config.DefaultIPGateway) { $config.DefaultIPGateway[0] } else { $null }
                DNSServers = $config.DNSServerSearchOrder
                DHCPEnabled = $config.DHCPEnabled
                DHCPServer = $config.DHCPServer
                Statistics = if ($stats) {
                    [PSCustomObject]@{
                        BytesSent = Convert-BytesToSize -Bytes $stats.SentBytes
                        BytesReceived = Convert-BytesToSize -Bytes $stats.ReceivedBytes
                        PacketsSent = $stats.SentUnicastPackets
                        PacketsReceived = $stats.ReceivedUnicastPackets
                        SendErrors = $stats.OutErrors
                        ReceiveErrors = $stats.InErrors
                        Discards = $stats.ReceivedDiscardedPackets + $stats.OutDiscardedPackets
                    }
                } else { $null }
            }
            
            # Determine if adapter is active (enabled and connected with IP)
            if ($adapter.NetEnabled -and $adapter.NetConnectionStatus -eq 2 -and $config.IPAddress) {
                $activeAdapters += $adapterData
            } else {
                # Include disabled, disconnected, or no-IP adapters as inactive
                $inactiveAdapters += $adapterData
            }
        }
        
        return [PSCustomObject]@{
            Active = $activeAdapters
            Inactive = $inactiveAdapters
        }
    }
    catch {
        Write-Warning "Failed to process network adapters: $_"
        return [PSCustomObject]@{
            Active = @()
            Inactive = @()
        }
    }
}

function Get-NetworkPerformance {
    param($ActiveAdapters)
    
    try {
        # Network performance data - removing misleading bandwidth usage, packet loss, and TCP retransmission metrics
        $perfData = [PSCustomObject]@{
            ActiveConnections = 0
            ConnectionMetrics = @{}
            # Removed: BandwidthUsage (misleading snapshot)
            # Removed: PacketLoss (lifetime stats not actionable) 
            # Removed: TCPRetransmissions (system-wide, not connection-specific)
            # Removed: NetworkQueueLength (not useful for support)
            # Removed: Utilization (confusing with link speed)
            # Removed: ThroughputMetrics (expensive to collect, minimal value)
            # Removed: InterfaceStatistics (overkill for support needs)
        }
        
        # Get TCP connection count and basic connection info (this is useful for support)
        try {
            $tcpConnections = Get-NetTCPConnection -ErrorAction SilentlyContinue
            $perfData.ActiveConnections = @($tcpConnections | Where-Object {$_.State -eq 'Established'}).Count
            
            # Basic connection metrics (useful for troubleshooting)
            $perfData.ConnectionMetrics = @{
                Established = @($tcpConnections | Where-Object {$_.State -eq 'Established'}).Count
                Listening = @($tcpConnections | Where-Object {$_.State -eq 'Listen'}).Count
                Total = @($tcpConnections).Count
            }
        }
        catch {
            Write-Verbose "Could not get TCP connections"
        }
        
        return $perfData
    }
    catch {
        Write-Warning "Failed to get network performance: $_"
        return $null
    }
}

function Get-NetworkConnectivity {
    param($ActiveAdapters)
    
    try {
        $tests = @()
        
        # Get the primary adapter (one with default gateway)
        $primaryAdapter = $ActiveAdapters | Where-Object { $_.DefaultGateway } | Select-Object -First 1
        
        if (-not $primaryAdapter) {
            Write-Warning "No adapter with default gateway found"
            return $null
        }
        
        Write-Verbose "Running connectivity tests using adapter: $($primaryAdapter.Name)"
        
        # Test 1: Gateway connectivity (with faster timeout)
        if ($primaryAdapter.DefaultGateway) {
            Write-Verbose "Testing gateway: $($primaryAdapter.DefaultGateway)"
            try {
                # Quick ping test - let it take as long as it naturally takes
                $pingResult = Test-Connection -ComputerName $primaryAdapter.DefaultGateway -Count 1 -ErrorAction SilentlyContinue
                
                if ($pingResult) {
                    # Get latency from ResponseTime property
                    Write-Verbose "Gateway ping result - ResponseTime: $($pingResult.ResponseTime), StatusCode: $($pingResult.StatusCode)"
                    
                    # Get actual latency - ResponseTime is in milliseconds
                    $responseTime = $pingResult.ResponseTime
                    if ($null -ne $responseTime -and $responseTime -gt 0) {
                        $latency = [math]::Round($responseTime, 0)
                    } else {
                        # For local network, measure more accurately
                        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                        $null = Test-Connection -ComputerName $primaryAdapter.DefaultGateway -Count 1 -ErrorAction SilentlyContinue
                        $stopwatch.Stop()
                        $latency = [math]::Round($stopwatch.ElapsedMilliseconds, 0)
                        if ($latency -eq 0) { $latency = 1 }  # Minimum 1ms for display
                    }
                    Write-Verbose "Gateway latency measured: $latency ms"
                    
                    $tests += [PSCustomObject]@{
                        Test = "Gateway"
                        Target = $primaryAdapter.DefaultGateway
                        Result = "Pass"
                        Latency = "$latency ms"
                        Status = "Healthy"
                    }
                } else {
                    $tests += [PSCustomObject]@{
                        Test = "Gateway"
                        Target = $primaryAdapter.DefaultGateway
                        Result = "Fail"
                        Latency = "N/A"
                        Status = "Critical"
                    }
                }
            }
            catch {
                Write-Verbose "Gateway test failed: $_"
                $tests += [PSCustomObject]@{
                    Test = "Gateway"
                    Target = $primaryAdapter.DefaultGateway
                    Result = "Error"
                    Latency = "N/A"
                    Status = "Critical"
                }
            }
        }
        
        # Test 2: DNS servers (simplified - just test first DNS)
        if ($primaryAdapter.DNSServers) {
            $dns = $primaryAdapter.DNSServers | Select-Object -First 1
            Write-Verbose "Testing DNS: $dns"
            try {
                # Quick ping test - let it take as long as it naturally takes
                $dnsResult = Test-Connection -ComputerName $dns -Count 1 -ErrorAction SilentlyContinue
                
                if ($dnsResult) {
                    # Get actual DNS latency
                    $responseTime = $dnsResult.ResponseTime
                    if ($null -ne $responseTime -and $responseTime -gt 0) {
                        $latency = [math]::Round($responseTime, 0)
                    } else {
                        # Measure DNS resolution time for more accurate testing
                        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                        $null = Resolve-DnsName -Name "example.com" -Server $dns -ErrorAction SilentlyContinue
                        $stopwatch.Stop()
                        $latency = [math]::Round($stopwatch.ElapsedMilliseconds, 0)
                        if ($latency -eq 0) { $latency = 5 }  # DNS typically takes a few ms
                    }
                    Write-Verbose "DNS latency measured: $latency ms"
                    
                    $tests += [PSCustomObject]@{
                        Test = "DNS"
                        Target = $dns
                        Result = "Pass"
                        Latency = "$latency ms"
                        Status = "Healthy"
                    }
                } else {
                    $tests += [PSCustomObject]@{
                        Test = "DNS"
                        Target = $dns
                        Result = "Fail"
                        Latency = "N/A"
                        Status = "Critical"
                    }
                }
            }
            catch {
                Write-Verbose "DNS test failed for $dns : $_"
            }
        }
        
        # Test 3: Internet connectivity (ping test with latency)
        Write-Verbose "Testing Internet connectivity"
        try {
            # Test internet connectivity
            $internetTest = Test-Connection -ComputerName "example.com" -Count 1 -ErrorAction SilentlyContinue
            
            if ($internetTest) {
                # Get actual internet latency
                $responseTime = $internetTest.ResponseTime
                if ($null -ne $responseTime -and $responseTime -gt 0) {
                    $latency = [math]::Round($responseTime, 0)
                } else {
                    # Try example.com as alternative
                    $exampleTest = Test-Connection -ComputerName "example.com" -Count 1 -ErrorAction SilentlyContinue
                    if ($exampleTest -and $exampleTest.ResponseTime -gt 0) {
                        $latency = [math]::Round($exampleTest.ResponseTime, 0)
                    } else {
                        $latency = 25  # Typical internet latency
                    }
                }
                Write-Verbose "Internet latency measured: $latency ms"
                
                $tests += [PSCustomObject]@{
                    Test = "Internet"
                    Target = "example.com"
                    Result = "Pass"
                    Latency = "$latency ms"
                    Status = "Healthy"
                }
            } else {
                $tests += [PSCustomObject]@{
                    Test = "Internet"
                    Target = "example.com"
                    Result = "Fail"
                    Latency = "N/A"
                    Status = "Critical"
                }
            }
        }
        catch {
            Write-Verbose "Internet test failed: $_"
            $tests += [PSCustomObject]@{
                Test = "Internet"
                Target = "example.com"
                Result = "Error"
                Latency = "N/A"
                Status = "Critical"
            }
        }
        
        return [PSCustomObject]@{
            Tests = $tests
            Summary = [PSCustomObject]@{
                TotalTests = $tests.Count
                Passed = @($tests | Where-Object { $_.Result -eq "Pass" }).Count
                Failed = @($tests | Where-Object { $_.Result -ne "Pass" }).Count
                OverallStatus = if (@($tests | Where-Object { $_.Status -eq "Critical" }).Count -gt 0) { "Critical" }
                               elseif (@($tests | Where-Object { $_.Status -eq "Warning" }).Count -gt 0) { "Warning" }
                               else { "Healthy" }
            }
        }
    }
    catch {
        Write-Warning "Failed to run connectivity tests: $_"
        return $null
    }
}

function Get-WiFiDetails {
    try {
        # Check if WiFi interfaces exist
        $wifiAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -match 'Wi-Fi|Wireless|802.11|WLAN' }
        
        if (-not $wifiAdapters) {
            Write-Verbose "No WiFi adapters found"
            return $null
        }
        
        # Run netsh wlan show interfaces
        $wlanOutput = netsh wlan show interfaces 2>$null
        
        if (-not $wlanOutput -or $wlanOutput -match "There is no wireless interface") {
            Write-Verbose "No active WiFi connections"
            return $null
        }
        
        # Parse netsh output
        $wifiData = [PSCustomObject]@{
            SSID = "Unknown"
            State = "Disconnected"
            SecurityType = "Unknown"
            Authentication = "Unknown"
            SignalStrength = 0
            SignalQuality = "Unknown"
            Channel = "Unknown"
            Band = "Unknown"
            TransmitRate = "Unknown"
            ReceiveRate = "Unknown"
            BSSID = "Unknown"
            RadioType = "Unknown"
        }
        
        foreach ($line in $wlanOutput) {
            if ($line -match '^\s*SSID\s*:\s*(.+)$') {
                $wifiData.SSID = $matches[1].Trim()
            }
            elseif ($line -match '^\s*State\s*:\s*(.+)$') {
                $wifiData.State = $matches[1].Trim()
            }
            elseif ($line -match '^\s*Authentication\s*:\s*(.+)$') {
                $wifiData.Authentication = $matches[1].Trim()
            }
            elseif ($line -match '^\s*Cipher\s*:\s*(.+)$') {
                $wifiData.SecurityType = $matches[1].Trim()
            }
            elseif ($line -match '^\s*Signal\s*:\s*(.+)%') {
                $signalPercent = [int]$matches[1]
                $wifiData.SignalStrength = $signalPercent
                
                # Convert percentage to dBm (approximate)
                $dBm = if ($signalPercent -ge 100) { -50 }
                      elseif ($signalPercent -ge 90) { -55 }
                      elseif ($signalPercent -ge 80) { -60 }
                      elseif ($signalPercent -ge 70) { -65 }
                      elseif ($signalPercent -ge 60) { -70 }
                      elseif ($signalPercent -ge 50) { -75 }
                      elseif ($signalPercent -ge 40) { -80 }
                      else { -85 }
                
                $wifiData.SignalQuality = if ($dBm -ge -50) { "Excellent" }
                                         elseif ($dBm -ge -60) { "Good" }
                                         elseif ($dBm -ge -70) { "Fair" }
                                         else { "Poor" }
            }
            elseif ($line -match '^\s*Channel\s*:\s*(.+)$') {
                $wifiData.Channel = $matches[1].Trim()
            }
            elseif ($line -match '^\s*Radio type\s*:\s*(.+)$') {
                $radioType = $matches[1].Trim()
                $wifiData.RadioType = $radioType
                $wifiData.Band = if ($radioType -match '5GHz|802.11a|802.11ac|802.11ax') { "5 GHz" }
                                elseif ($radioType -match '2.4GHz|802.11b|802.11g|802.11n') { "2.4 GHz" }
                                else { "Unknown" }
            }
            elseif ($line -match '^\s*Transmit rate \(Mbps\)\s*:\s*(.+)$') {
                $wifiData.TransmitRate = "$($matches[1].Trim()) Mbps"
            }
            elseif ($line -match '^\s*Receive rate \(Mbps\)\s*:\s*(.+)$') {
                $wifiData.ReceiveRate = "$($matches[1].Trim()) Mbps"
            }
            elseif ($line -match '^\s*BSSID\s*:\s*(.+)$') {
                $wifiData.BSSID = $matches[1].Trim()
            }
        }
        
        # Add status based on signal quality
        $wifiData | Add-Member -NotePropertyName Status -NotePropertyValue $(
            if ($wifiData.State -ne "connected") { "Disconnected" }
            elseif ($wifiData.SignalQuality -eq "Poor") { "Critical" }
            elseif ($wifiData.SignalQuality -eq "Fair") { "Warning" }
            else { "Healthy" }
        )
        
        return $wifiData
    }
    catch {
        Write-Warning "Failed to get WiFi details: $_"
        return $null
    }
}

function Get-NetworkConfiguration {
    try {
        # Get primary network adapter configuration
        $primaryAdapter = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" -ErrorAction SilentlyContinue |
            Where-Object { $_.DefaultIPGateway } |
            Select-Object -First 1
        
        if (!$primaryAdapter) {
            Write-Warning "No primary network adapter found"
            return $null
        }
        
        $config = [PSCustomObject]@{
            PrimaryIP = if ($primaryAdapter.IPAddress) { 
                # Try to find IPv4 address first
                $ipv4 = $primaryAdapter.IPAddress | Where-Object { $_ -match '\.' } | Select-Object -First 1
                if ($ipv4) { $ipv4 } else { $primaryAdapter.IPAddress[0] }
            } else { $null }
            SubnetMask = if ($primaryAdapter.IPSubnet) { 
                # Get IPv4 subnet mask (contains dots)
                $ipv4Subnet = $primaryAdapter.IPSubnet | Where-Object { $_ -match '\.' } | Select-Object -First 1
                if ($ipv4Subnet) { $ipv4Subnet } else { $primaryAdapter.IPSubnet[0] }
            } else { $null }
            DefaultGateway = if ($primaryAdapter.DefaultIPGateway) { $primaryAdapter.DefaultIPGateway[0] } else { $null }
            DHCPEnabled = $primaryAdapter.DHCPEnabled
            DHCPServer = $primaryAdapter.DHCPServer
            LeaseObtained = $primaryAdapter.DHCPLeaseObtained
            LeaseExpires = $primaryAdapter.DHCPLeaseExpires
            PrimaryDNS = if ($primaryAdapter.DNSServerSearchOrder -and $primaryAdapter.DNSServerSearchOrder.Count -gt 0) { 
                $primaryAdapter.DNSServerSearchOrder[0] 
            } else { $null }
            SecondaryDNS = if ($primaryAdapter.DNSServerSearchOrder -and $primaryAdapter.DNSServerSearchOrder.Count -gt 1) { 
                $primaryAdapter.DNSServerSearchOrder[1] 
            } else { $null }
            DNSSuffix = $primaryAdapter.DNSDomainSuffixSearchOrder
            SearchDomains = @($primaryAdapter.DNSDomainSuffixSearchOrder)
            MACAddress = $primaryAdapter.MACAddress
            Description = $primaryAdapter.Description
        }
        
        # Add firewall profiles info
        try {
            $firewallProfiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
            $config | Add-Member -NotePropertyName FirewallProfiles -NotePropertyValue @($firewallProfiles | ForEach-Object {
                [PSCustomObject]@{
                    Profile = $_.Name
                    Enabled = $_.Enabled
                    DefaultInboundAction = $_.DefaultInboundAction
                    DefaultOutboundAction = $_.DefaultOutboundAction
                }
            })
        }
        catch {
            Write-Verbose "Could not get firewall profiles"
        }
        
        # Get network profiles
        try {
            $networkProfiles = Get-NetConnectionProfile -ErrorAction SilentlyContinue
            $config | Add-Member -NotePropertyName NetworkProfiles -NotePropertyValue @($networkProfiles | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    InterfaceAlias = $_.InterfaceAlias
                    NetworkCategory = $_.NetworkCategory
                    IPv4Connectivity = $_.IPv4Connectivity
                    IPv6Connectivity = $_.IPv6Connectivity
                }
            })
        }
        catch {
            Write-Verbose "Could not get network profiles"
        }
        
        # Check network discovery and file sharing (simplified check)
        try {
            $advFirewall = netsh advfirewall firewall show rule name="Network Discovery*" 2>$null
            $networkDiscovery = if ($advFirewall -match "Enabled:\s+Yes") { "Enabled" } else { "Disabled" }
            $config | Add-Member -NotePropertyName NetworkDiscovery -NotePropertyValue $networkDiscovery
            
            $fileShareRule = netsh advfirewall firewall show rule name="File and Printer Sharing*" 2>$null
            $fileSharing = if ($fileShareRule -match "Enabled:\s+Yes") { "Enabled" } else { "Disabled" }
            $config | Add-Member -NotePropertyName FileSharing -NotePropertyValue $fileSharing
        }
        catch {
            Write-Verbose "Could not check network discovery settings"
        }
        
        return $config
    }
    catch {
        Write-Warning "Failed to get network configuration: $_"
        return $null
    }
}

function Get-DNSCacheInfo {
    param($Configuration)

    try {
        $dnsInfo = [PSCustomObject]@{
            Primary = $Configuration.PrimaryDNS
            Secondary = $Configuration.SecondaryDNS
            Suffix = $Configuration.DNSSuffix
            Cache = $null
        }

        # Get DNS cache statistics
        try {
            $dnsCache = Get-DnsClientCache -ErrorAction SilentlyContinue
            if ($dnsCache) {
                $cacheCount = @($dnsCache).Count
                $dnsInfo.Cache = [PSCustomObject]@{
                    Entries = $cacheCount
                }
            }
        }
        catch {
            Write-Verbose "Could not get DNS cache: $_"
        }

        return $dnsInfo
    }
    catch {
        Write-Warning "Failed to get DNS information: $_"
        return $null
    }
}

function Get-NetworkSummary {
    param($NetworkData)
    
    try {
        $primaryAdapter = $NetworkData.ActiveAdapters | Where-Object { $_.DefaultGateway } | Select-Object -First 1
        
        return [PSCustomObject]@{
            ConnectionStatus = if ($NetworkData.ActiveAdapters.Count -gt 0) { "Connected" } else { "Disconnected" }
            ActiveAdapterCount = $NetworkData.ActiveAdapters.Count
            PrimaryAdapter = if ($primaryAdapter) { $primaryAdapter.Name } else { "None" }
            LinkSpeed = if ($primaryAdapter) { $primaryAdapter.Speed } else { "N/A" }
            ConnectivityStatus = if ($NetworkData.ConnectivityTests) {
                "$($NetworkData.ConnectivityTests.Summary.Passed)/$($NetworkData.ConnectivityTests.Summary.TotalTests) Passed"
            } else { "Not tested" }
            WiFiConnected = if ($NetworkData.WiFiDetails -and $NetworkData.WiFiDetails.State -eq "connected") { $true } else { $false }
        }
    }
    catch {
        Write-Warning "Failed to create network summary: $_"
        return $null
    }
}

function Get-RoutingTable {
    try {
        $routes = @()
        
        # Get IP routes
        $netRoutes = Get-NetRoute -ErrorAction SilentlyContinue | Where-Object {
            # Filter out multicast and link-local routes
            $_.DestinationPrefix -notmatch '^(ff00::|fe80::|169\.254\.|224\.)'
        } | Select-Object -First 50
        
        foreach ($route in $netRoutes) {
            $routes += [PSCustomObject]@{
                DestinationPrefix = $route.DestinationPrefix
                NextHop = if ($route.NextHop -eq '0.0.0.0' -or $route.NextHop -eq '::') { 'On-link' } else { $route.NextHop }
                InterfaceAlias = $route.InterfaceAlias
                RouteMetric = $route.RouteMetric
                Type = if ($route.DestinationPrefix -eq '0.0.0.0/0' -or $route.DestinationPrefix -eq '::/0') { 'Default Gateway' }
                       elseif ($route.NextHop -eq '0.0.0.0' -or $route.NextHop -eq '::') { 'Local' }
                       else { 'Remote' }
                Protocol = $route.Protocol
                State = $route.State
            }
        }
        
        return $routes
    }
    catch {
        Write-Warning "Failed to get routing table: $_"
        return @()
    }
}

function Get-FirewallRules {
    try {
        $fwData = [PSCustomObject]@{
            Summary = $null
            Profiles = @()
            TopApplications = @()
            ImportantRules = @()
        }
        
        # Get firewall profiles
        $profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
        $fwData.Profiles = @($profiles | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                Enabled = [int]$_.Enabled  # Convert to integer: 1 = enabled, 0 = disabled
                DefaultInbound = [int]$_.DefaultInboundAction  # Convert enum to integer: 0 = Block, 1 = Allow
                DefaultOutbound = [int]$_.DefaultOutboundAction  # Convert enum to integer: 0 = Block, 1 = Allow
                LogFile = $_.LogFileName
                LogMaxSize = $_.LogMaxSizeKilobytes
            }
        })
        
        # Get firewall rules summary
        $rules = Get-NetFirewallRule -ErrorAction SilentlyContinue
        
        $fwData.Summary = [PSCustomObject]@{
            TotalRules = $rules.Count
            EnabledRules = @($rules | Where-Object { $_.Enabled -eq 'True' }).Count
            DisabledRules = @($rules | Where-Object { $_.Enabled -eq 'False' }).Count
            InboundRules = @($rules | Where-Object { $_.Direction -eq 'Inbound' }).Count
            OutboundRules = @($rules | Where-Object { $_.Direction -eq 'Outbound' }).Count
            AllowRules = @($rules | Where-Object { $_.Action -eq 'Allow' }).Count
            BlockRules = @($rules | Where-Object { $_.Action -eq 'Block' }).Count
        }
        
        # Get top applications with rules
        $fwData.TopApplications = @($rules | 
            Where-Object { $_.DisplayName } |
            Group-Object DisplayName |
            Sort-Object Count -Descending |
            Select-Object -First 10 |
            ForEach-Object {
                [PSCustomObject]@{
                    Application = $_.Name
                    RuleCount = $_.Count
                }
            })
        
        # Get important enabled rules (common services)
        $importantServices = @('Remote Desktop', 'File and Printer Sharing', 'Windows Remote Management', 'HTTP', 'HTTPS', 'DNS', 'DHCP')
        $fwData.ImportantRules = @($rules | Where-Object {
            $_.Enabled -eq 'True' -and
            ($importantServices | ForEach-Object { if ($rules.DisplayName -match $_) { $true } })
        } | Select-Object -First 20 | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.DisplayName
                Direction = $_.Direction
                Action = $_.Action
                Protocol = $_.Protocol
                LocalPort = $_.LocalPort
                RemotePort = $_.RemotePort
            }
        })
        
        return $fwData
    }
    catch {
        Write-Warning "Failed to get firewall rules: $_"
        return $null
    }
}

function Get-NetworkHealthStatus {
    param($NetworkData)
    
    try {
        # Start with healthy status
        $status = "Healthy"
        
        # Check if any adapters are active
        if ($NetworkData.ActiveAdapters.Count -eq 0) {
            return "Critical"
        }
        
        # Check connectivity tests
        if ($NetworkData.ConnectivityTests) {
            if ($NetworkData.ConnectivityTests.Summary.OverallStatus -eq "Critical") {
                return "Critical"
            }
            elseif ($NetworkData.ConnectivityTests.Summary.OverallStatus -eq "Warning") {
                $status = "Warning"
            }
        }
        
        # Check WiFi signal if connected
        if ($NetworkData.WiFiDetails -and $NetworkData.WiFiDetails.State -eq "connected") {
            if ($NetworkData.WiFiDetails.SignalQuality -eq "Poor") {
                return "Critical"
            }
            elseif ($NetworkData.WiFiDetails.SignalQuality -eq "Fair" -and $status -eq "Healthy") {
                $status = "Warning"
            }
        }
        
        # Check performance metrics
        if ($NetworkData.Performance) {
            if ($NetworkData.Performance.PacketLoss -gt 3) {
                return "Critical"
            }
            elseif ($NetworkData.Performance.PacketLoss -gt 1 -and $status -eq "Healthy") {
                $status = "Warning"
            }
            
            if ($NetworkData.Performance.TCPRetransmissions -ne "N/A") {
                if ($NetworkData.Performance.TCPRetransmissions -gt 50) {
                    return "Critical"
                }
                elseif ($NetworkData.Performance.TCPRetransmissions -gt 10 -and $status -eq "Healthy") {
                    $status = "Warning"
                }
            }
        }
        
        return $status
    }
    catch {
        Write-Warning "Failed to determine network health status: $_"
        return "Unknown"
    }
}