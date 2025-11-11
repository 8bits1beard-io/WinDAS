# Initialize-DataCollection.ps1
# Initialize global CIM session and data cache for WinDAS collectors
# Author: Joshua Walderbach

function Initialize-DataCollection {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME,
        
        [Parameter()]
        [int]$TimeoutSeconds = 30
    )
    
    Write-ProgressStatus -Activity "Initializing Data Collection" -Status "Setting up environment"
    
    # Initialize global data cache
    $Global:DataCache = @{
        InitializedAt = Get-Date
        ComputerName = $ComputerName
        Collections = @{}
    }
    
    # Initialize CIM session
    try {
        Write-ProgressStatus -Activity "Initializing Data Collection" -Status "Creating CIM session" -PercentComplete 25
        
        # Test if CIM is available first with a simple query
        # For local computer, don't specify ComputerName to avoid WinRM requirement
        if ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq 'localhost' -or $ComputerName -eq '.') {
            $testCIMParams = @{
                ClassName = 'Win32_OperatingSystem'
                ErrorAction = 'Stop'
            }
        } else {
            $testCIMParams = @{
                ClassName = 'Win32_OperatingSystem'
                ComputerName = $ComputerName
                ErrorAction = 'Stop'
            }
        }
        
        # Create timeout job for CIM test
        $job = Start-Job -ScriptBlock {
            param($params)
            Get-CimInstance @params
        } -ArgumentList $testCIMParams
        
        $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
        
        if (-not $completed) {
            Stop-Job -Job $job
            Remove-Job -Job $job -Force
            throw "CIM connection timeout after $TimeoutSeconds seconds"
        }
        
        $testResult = Receive-Job -Job $job -ErrorAction Stop
        Remove-Job -Job $job -Force
        
        if (-not $testResult) {
            throw "CIM test query returned no results"
        }
        
        Write-ProgressStatus -Activity "Initializing Data Collection" -Status "Creating persistent CIM session" -PercentComplete 50
        
        # Create persistent CIM session
        # For local computer, use local CIM (doesn't require WinRM)
        if ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq 'localhost' -or $ComputerName -eq '.') {
            $Global:CIMSession = New-CimSession -ErrorAction Stop
        } else {
            # For remote computers, use DCOM protocol
            $sessionOption = New-CimSessionOption -Protocol Dcom
            $Global:CIMSession = New-CimSession -ComputerName $ComputerName -SessionOption $sessionOption -ErrorAction Stop
        }
        
        # Verify session is working
        Write-ProgressStatus -Activity "Initializing Data Collection" -Status "Verifying CIM session" -PercentComplete 75
        
        $verifyParams = @{
            CimSession = $Global:CIMSession
            ClassName = 'Win32_ComputerSystem'
            ErrorAction = 'Stop'
        }
        
        $verifyResult = Get-CimInstance @verifyParams
        
        if (-not $verifyResult) {
            throw "CIM session verification failed"
        }
        
        # Store session info in cache
        $Global:DataCache.CIMSession = @{
            Created = Get-Date
            ComputerName = $ComputerName
            SessionId = $Global:CIMSession.Id
            Protocol = 'DCOM'
            Status = 'Connected'
        }
        
        Write-ProgressStatus -Activity "Initializing Data Collection" -Status "Initialization complete" -PercentComplete 100
        Write-ProgressStatus -Activity "Initializing Data Collection" -Completed
        
        Write-Host "Data collection initialized successfully" -ForegroundColor Green
        Write-Verbose "CIM Session ID: $($Global:CIMSession.Id)"
        Write-Verbose "Target Computer: $ComputerName"
        
        return @{
            Success = $true
            SessionId = $Global:CIMSession.Id
            ComputerName = $ComputerName
            Message = "Data collection initialized successfully"
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        
        # Clean up any partial session
        if ($Global:CIMSession) {
            try {
                Remove-CimSession -CimSession $Global:CIMSession -ErrorAction SilentlyContinue
            }
            catch {
                # Ignore cleanup errors
            }
            $Global:CIMSession = $null
        }
        
        # CIM failed - no WMI fallback
        Write-Error "CIM initialization failed: $errorMessage"
        
        # Check WinRM status for diagnostics
        $winrmStatus = "Unknown"
        $winrmDetails = @{}
        try {
            $winrmService = Get-Service -Name WinRM -ErrorAction SilentlyContinue
            if ($winrmService) {
                $winrmStatus = $winrmService.Status.ToString()
                $winrmDetails.ServiceStatus = $winrmStatus
                $winrmDetails.StartType = $winrmService.StartType.ToString()
            } else {
                $winrmStatus = "Service Not Found"
            }
            
            # Check if WinRM is configured
            $winrmConfig = winrm enumerate winrm/config/listener 2>&1
            if ($LASTEXITCODE -eq 0) {
                $winrmDetails.ListenersConfigured = $true
            } else {
                $winrmDetails.ListenersConfigured = $false
                $winrmDetails.ConfigError = "No listeners configured. Run 'winrm quickconfig' to configure."
            }
        } catch {
            $winrmStatus = "Unable to check status"
        }
        
        Write-ProgressStatus -Activity "Initializing Data Collection" -Completed
        
        return @{
            Success = $false
            SessionId = $null
            ComputerName = $ComputerName
            Message = "Failed to initialize CIM session: $errorMessage"
            CIMError = $errorMessage
            WinRMStatus = $winrmStatus
            WinRMDetails = $winrmDetails
        }
    }
}

function Test-DataCollection {
    [CmdletBinding()]
    param()
    
    # Check if already initialized
    if ($Global:DataCache -and $Global:DataCache.CIMSession) {
        if ($Global:CIMSession) {
            # Test if session is still valid
            try {
                $test = Get-CimInstance -CimSession $Global:CIMSession -ClassName Win32_OperatingSystem -ErrorAction Stop
                if ($test) {
                    Write-Verbose "Data collection is initialized and functional"
                    return $true
                }
            }
            catch {
                Write-Warning "CIM session is no longer valid"
                return $false
            }
        }
    }
    
    Write-Verbose "Data collection is not initialized"
    return $false
}

function Clear-DataCollection {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Cleaning up data collection resources"
    
    # Remove CIM session
    if ($Global:CIMSession) {
        try {
            Remove-CimSession -CimSession $Global:CIMSession -ErrorAction SilentlyContinue
            Write-Verbose "CIM session removed"
        }
        catch {
            Write-Warning "Failed to remove CIM session: $_"
        }
        $Global:CIMSession = $null
    }
    
    # Clear cache
    if ($Global:DataCache) {
        $Global:DataCache = $null
        Write-Verbose "Data cache cleared"
    }
    
    Write-Host "Data collection resources cleaned up" -ForegroundColor Yellow
}