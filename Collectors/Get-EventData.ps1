function Get-EventData {
    param(
        [Parameter(Mandatory=$false)]
        [hashtable]$DataCache = @{}
    )
    
    Write-Verbose "Collecting Windows Event Log data..."
    $startTime = Get-Date
    
    # Initialize results structure
    $results = @{
        Summary = @{}
        Events = @{}
        Categories = @{}
        TopSources = @()
    }
    
    # Helper function to get friendly event names
    function Get-FriendlyEventName {
        param([int]$EventId)
        
        $eventNames = @{
            41 = "Unexpected Shutdown"
            1000 = "Application Crash"
            1001 = "Windows Error Reporting"
            1002 = "Application Hang"
            4625 = "Failed Login Attempt"
            4740 = "Account Lockout"
            4776 = "Authentication Failure"
            6008 = "Previous Shutdown Was Unexpected"
            7034 = "Service Crashed Unexpectedly"
            7035 = "Service Control Manager"
            7036 = "Service State Changed"
            10016 = "DCOM Permission Error"
            10028 = "DCOM Server Start Error"
            10029 = "DCOM Activation Error"
            19 = "Windows Update Installed"
            20 = "Windows Update Installation Started"
            43 = "Windows Update Download Started"
            44 = "Windows Update Download Complete"
            1074 = "System Shutdown/Restart"
            6005 = "Event Log Service Started"
            6006 = "Event Log Service Stopped"
            6013 = "System Uptime"
        }
        
        if ($eventNames.ContainsKey($EventId)) {
            return $eventNames[$EventId]
        }
        return ""
    }
    
    # Helper function to get relative time string
    function Get-RelativeTime {
        param([DateTime]$EventTime)
        
        $span = (Get-Date) - $EventTime
        if ($span.TotalMinutes -lt 60) {
            return "$([Math]::Round($span.TotalMinutes)) minutes ago"
        } elseif ($span.TotalHours -lt 24) {
            return "$([Math]::Round($span.TotalHours)) hours ago"
        } else {
            return "$([Math]::Round($span.TotalDays)) days ago"
        }
    }
    
    
    # Define event categories
    $categories = @{
        SystemCrashes = @(41, 6008, 1001, 1074)
        ApplicationErrors = @(1000, 1002)
        ServiceIssues = @(7034, 7035, 7036)
        UpdateEvents = @(19, 20, 43, 44)
        SecurityEvents = @(4625, 4740, 4776)
        HardwareEvents = @(10016, 10028, 10029)
    }
    
    # Calculate time range (last 24 hours)
    $queryStartTime = (Get-Date).AddHours(-24)
    
    # Query System and Application logs
    Write-Verbose "Querying System and Application event logs..."
    $allEvents = @()
    
    $systemAppFilter = @{
        LogName = 'System','Application'
        Level = 1,2,3  # Critical, Error, Warning
        StartTime = $queryStartTime
    }
    
    try {
        $events = Get-WinEvent -FilterHashtable $systemAppFilter -MaxEvents 500 -ErrorAction Stop
        $allEvents += $events
        Write-Verbose "Retrieved $($events.Count) events from System and Application logs"
    } catch {
        Write-Verbose "Error querying System/Application events: $_"
    }
    
    # Query Security log if running as admin
    if (Test-Administrator) {
        Write-Verbose "Querying Security event log (admin access available)..."
        $securityFilter = @{
            LogName = 'Security'
            ID = 4625,4740,4776  # Failed logins, account lockouts, auth failures
            StartTime = $queryStartTime
        }
        
        try {
            $securityEvents = Get-WinEvent -FilterHashtable $securityFilter -MaxEvents 100 -ErrorAction Stop
            # Convert security events to have Level property for consistency
            foreach ($event in $securityEvents) {
                Add-Member -InputObject $event -NotePropertyName 'Level' -NotePropertyValue 3 -Force
                Add-Member -InputObject $event -NotePropertyName 'LevelDisplayName' -NotePropertyValue 'Warning' -Force
            }
            $allEvents += $securityEvents
            Write-Verbose "Retrieved $($securityEvents.Count) security events"
        } catch {
            Write-Verbose "Error querying Security events: $_"
        }
    } else {
        Write-Verbose "Not running as administrator - Security log access limited"
    }
    
    # Process events by severity level
    $criticalEvents = @()
    $errorEvents = @()
    $warningEvents = @()
    
    foreach ($event in $allEvents) {
        # Skip known noisy events
        if ($event.Id -eq 10016 -and $event.Message -like "*application-specific permission settings*") {
            continue
        }
        
        # Create structured event object
        $eventObj = @{
            TimeCreated = $event.TimeCreated
            RelativeTime = Get-RelativeTime $event.TimeCreated
            ProviderName = $event.ProviderName
            Id = $event.Id
            EventName = Get-FriendlyEventName $event.Id
            Level = $event.Level
            LevelDisplayName = $event.LevelDisplayName
            Message = if ($event.Message -and $event.Message.Length -gt 500) { 
                $event.Message.Substring(0, 497) + "..." 
            } else { 
                $event.Message 
            }
            LogName = $event.LogName
            MachineName = $event.MachineName
        }
        
        # Categorize by severity
        switch ($event.Level) {
            1 { $criticalEvents += $eventObj }
            2 { $errorEvents += $eventObj }
            3 { $warningEvents += $eventObj }
        }
    }
    
    # Sort and limit events by severity - ensure arrays are always returned
    $results.Events = @{
        Critical = @($criticalEvents | Sort-Object TimeCreated -Descending | Select-Object -First 50)
        Error = @($errorEvents | Sort-Object TimeCreated -Descending | Select-Object -First 50)
        Warning = @($warningEvents | Sort-Object TimeCreated -Descending | Select-Object -First 50)
    }
    
    # Categorize events by type
    Write-Verbose "Categorizing events by type..."
    $categoryResults = @{}
    
    foreach ($categoryName in $categories.Keys) {
        $categoryEventIds = $categories[$categoryName]
        $categoryEvents = @()
        
        foreach ($event in ($criticalEvents + $errorEvents + $warningEvents)) {
            if ($categoryEventIds -contains $event.Id) {
                $categoryEvents += $event
            }
        }
        
        $categoryResults[$categoryName] = @($categoryEvents | 
            Sort-Object TimeCreated -Descending | 
            Select-Object -First 20)
    }
    
    $results.Categories = $categoryResults
    
    # Get top event sources
    if ($allEvents.Count -gt 0) {
        $results.TopSources = $allEvents | 
            Group-Object ProviderName | 
            Sort-Object Count -Descending | 
            Select-Object -First 10 @{Name='Source';Expression={$_.Name}}, Count
    }
    
    # Check for special critical events (BSODs/BugChecks)
    Write-Verbose "Checking for critical system events..."
    $bugCheckFilter = @{
        LogName = 'System'
        ID = 1001  # BugCheck events
        StartTime = $queryStartTime
    }
    
    try {
        $bugCheckEvents = Get-WinEvent -FilterHashtable $bugCheckFilter -MaxEvents 10 -ErrorAction Stop
        if ($bugCheckEvents) {
            Write-Verbose "Found $($bugCheckEvents.Count) BugCheck (BSOD) events"
            $results.BugCheckEvents = @($bugCheckEvents | ForEach-Object {
                @{
                    TimeCreated = $_.TimeCreated
                    RelativeTime = Get-RelativeTime $_.TimeCreated
                    Message = $_.Message
                }
            })
        }
    } catch {
        # No BugCheck events found
    }
    
    # Perform pattern analysis
    Write-Verbose "Performing pattern analysis..."
    $patternAnalysis = @{
        Patterns = @()
        Insights = @()
        Recommendations = @()
    }
    
    # Analyze for recurring crashes
    $crashEvents = @($criticalEvents + $errorEvents | Where-Object { $_.Id -in @(41, 1000, 1001, 6008) })
    if ($crashEvents.Count -gt 3) {
        $crashPattern = @{
            Type = "Recurring Crashes"
            Count = $crashEvents.Count
            Severity = "High"
            FirstOccurrence = ($crashEvents | Sort-Object TimeCreated | Select-Object -First 1).TimeCreated
            LastOccurrence = ($crashEvents | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated
            EventIds = @($crashEvents.Id | Select-Object -Unique)
            Message = "System experienced $($crashEvents.Count) crash-related events in the last 48 hours"
        }
        $patternAnalysis.Patterns += $crashPattern
        $patternAnalysis.Recommendations += "Investigate system stability - check for driver issues or hardware problems"
    }
    
    # Analyze for authentication failures
    $authFailures = @($allEvents | Where-Object { $_.Id -in @(4625, 4776) })
    if ($authFailures.Count -gt 10) {
        $authPattern = @{
            Type = "Authentication Issues"
            Count = $authFailures.Count
            Severity = "Medium"
            FirstOccurrence = ($authFailures | Sort-Object TimeCreated | Select-Object -First 1).TimeCreated
            LastOccurrence = ($authFailures | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated
            EventIds = @(4625, 4776)
            Message = "Detected $($authFailures.Count) authentication failures"
        }
        $patternAnalysis.Patterns += $authPattern
        
        # Check if failures are from same source
        $authSources = $authFailures | Group-Object MachineName
        if ($authSources.Count -eq 1) {
            $patternAnalysis.Insights += "All authentication failures from same source - possible brute force attempt"
            $patternAnalysis.Recommendations += "Review account security policies and consider enabling account lockout"
        }
    }
    
    # Analyze service failures
    $serviceFailures = @($allEvents | Where-Object { $_.Id -eq 7034 })
    if ($serviceFailures.Count -gt 5) {
        $failedServices = $serviceFailures | Group-Object ProviderName | Sort-Object Count -Descending
        $topFailedService = $failedServices | Select-Object -First 1
        
        $servicePattern = @{
            Type = "Service Instability"
            Count = $serviceFailures.Count
            Severity = "Medium"
            FirstOccurrence = ($serviceFailures | Sort-Object TimeCreated | Select-Object -First 1).TimeCreated
            LastOccurrence = ($serviceFailures | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated
            TopService = $topFailedService.Name
            TopServiceFailures = $topFailedService.Count
            Message = "Services crashed $($serviceFailures.Count) times, '$($topFailedService.Name)' failed most often"
        }
        $patternAnalysis.Patterns += $servicePattern
        $patternAnalysis.Recommendations += "Review service dependencies and check application event logs for $($topFailedService.Name)"
    }
    
    # Analyze DCOM errors
    $dcomErrors = @($allEvents | Where-Object { $_.Id -in @(10016, 10028, 10029) })
    if ($dcomErrors.Count -gt 20) {
        $patternAnalysis.Insights += "High volume of DCOM errors ($($dcomErrors.Count)) - may indicate permission issues"
        $patternAnalysis.Recommendations += "Review DCOM permissions for affected applications"
    }
    
    # Time-based pattern analysis
    if ($allEvents.Count -gt 50) {
        # Group events by hour to find patterns
        $hourlyEvents = $allEvents | Group-Object { $_.TimeCreated.Hour } | Sort-Object Count -Descending
        $peakHour = $hourlyEvents | Select-Object -First 1
        
        if ($peakHour.Count -gt ($allEvents.Count * 0.3)) {
            $patternAnalysis.Insights += "Significant event clustering at hour $($peakHour.Name):00 ($($peakHour.Count) events)"
        }
        
        # Check for after-hours activity
        $afterHoursEvents = $allEvents | Where-Object { 
            $_.TimeCreated.Hour -lt 6 -or $_.TimeCreated.Hour -gt 20 
        }
        if ($afterHoursEvents.Count -gt ($allEvents.Count * 0.4)) {
            $patternAnalysis.Insights += "High after-hours activity detected ($('{0:P0}' -f ($afterHoursEvents.Count / $allEvents.Count)) of events)"
        }
    }
    
    # Add pattern analysis to results
    $results.PatternAnalysis = $patternAnalysis
    
    # Create summary statistics
    $results.Summary = @{
        TotalEvents = $allEvents.Count
        Critical = $criticalEvents.Count
        Errors = $errorEvents.Count
        Warnings = $warningEvents.Count
        TimeRange = "Last 48 hours"
        StartTime = $queryStartTime
        EndTime = Get-Date
        CollectedAt = Get-Date
        HasBugChecks = $null -ne $results.BugCheckEvents
        IsAdmin = Test-Administrator
        HasPatterns = $patternAnalysis.Patterns.Count -gt 0
    }
    
    # Add most recent critical event if any exist
    if ($criticalEvents.Count -gt 0) {
        $results.Summary.MostRecentCritical = @{
            Time = $criticalEvents[0].TimeCreated
            RelativeTime = $criticalEvents[0].RelativeTime
            Event = $criticalEvents[0].EventName
            Id = $criticalEvents[0].Id
        }
    }
    
    # Calculate collection time
    $duration = (Get-Date) - $startTime
    Write-Verbose "Event data collection completed in $([Math]::Round($duration.TotalSeconds, 2)) seconds"
    
    return $results
}