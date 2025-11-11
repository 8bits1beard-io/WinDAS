# Common-Functions.ps1
# Helper functions for WinDAS collectors
# Author: Joshua Walderbach

function Test-Administrator {
    [CmdletBinding()]
    param()
    
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Convert-BytesToSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [double]$Bytes
    )
    
    process {
        if ($Bytes -ge 1TB) {
            return "{0:N2} TB" -f ($Bytes / 1TB)
        }
        elseif ($Bytes -ge 1GB) {
            return "{0:N2} GB" -f ($Bytes / 1GB)
        }
        elseif ($Bytes -ge 1MB) {
            return "{0:N2} MB" -f ($Bytes / 1MB)
        }
        elseif ($Bytes -ge 1KB) {
            return "{0:N2} KB" -f ($Bytes / 1KB)
        }
        else {
            return "{0:N2} B" -f $Bytes
        }
    }
}


function Get-AgeInDays {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$StartDate,
        
        [Parameter()]
        [datetime]$EndDate = (Get-Date)
    )
    
    $timeSpan = $EndDate - $StartDate
    return [math]::Round($timeSpan.TotalDays, 2)
}

function Get-StatusFromThreshold {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [double]$Value,
        
        [Parameter(Mandatory = $true)]
        [double]$WarningThreshold,
        
        [Parameter(Mandatory = $true)]
        [double]$CriticalThreshold,
        
        [Parameter()]
        [switch]$Reverse
    )
    
    if ($Reverse) {
        if ($Value -le $CriticalThreshold) {
            return 'Critical'
        }
        elseif ($Value -le $WarningThreshold) {
            return 'Warning'
        }
        else {
            return 'Healthy'
        }
    }
    else {
        if ($Value -ge $CriticalThreshold) {
            return 'Critical'
        }
        elseif ($Value -ge $WarningThreshold) {
            return 'Warning'
        }
        else {
            return 'Healthy'
        }
    }
}

function Write-CollectorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [string]$Level = "VERBOSE",
        
        [Parameter(Mandatory = $true)]
        [string]$Component,
        
        [Parameter()]
        [object]$Data = $null
    )
    
    # Only log if global logging is enabled
    if ($Global:LoggingEnabled -and $Global:WriteLog) {
        & $Global:WriteLog -Message $Message -Level $Level -Component $Component -Data $Data
    }
}

function Write-ProgressStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter()]
        [string]$Status,

        [Parameter()]
        [int]$PercentComplete = -1,

        [Parameter()]
        [int]$Id = 1,

        [Parameter()]
        [switch]$Completed,

        [Parameter()]
        [string]$Component = "Collector"
    )

    # Log detailed progress if logging is enabled
    if ($Global:LoggingEnabled -and $Global:WriteLog) {
        if ($Completed) {
            & $Global:WriteLog -Message "$Activity - Completed" -Level "VERBOSE" -Component $Component
        }
        else {
            $logMessage = $Activity
            if ($Status) {
                $logMessage += " - $Status"
            }
            if ($PercentComplete -ge 0) {
                $logMessage += " ($PercentComplete%)"
            }
            & $Global:WriteLog -Message $logMessage -Level "VERBOSE" -Component $Component
        }
    }

    if ($Completed) {
        Write-Progress -Activity $Activity -Status "Complete" -Id $Id -Completed
        Write-Verbose "$Activity - Complete"
    }
    else {
        $progressParams = @{
            Activity = $Activity
            Id = $Id
        }

        if ($Status) {
            $progressParams['Status'] = $Status
            Write-Verbose "$Activity - $Status"
        }

        if ($PercentComplete -ge 0) {
            $progressParams['PercentComplete'] = $PercentComplete
        }

        Write-Progress @progressParams
    }
}

function ConvertTo-StandardStatus {
    <#
    .SYNOPSIS
        Converts various status values to WinDAS standard status format.

    .DESCRIPTION
        Standardizes status values across all collectors to use:
        - "Healthy" for normal/good states
        - "Warning" for non-critical issues
        - "Critical" for serious problems
        - "Unknown" for indeterminate states

    .PARAMETER Status
        The status value to convert

    .PARAMETER Context
        Optional context to help determine appropriate mapping (e.g., "Service", "Device")

    .EXAMPLE
        ConvertTo-StandardStatus -Status "OK"
        Returns: "Healthy"

    .EXAMPLE
        ConvertTo-StandardStatus -Status "Error"
        Returns: "Critical"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$Status,

        [Parameter()]
        [string]$Context = ""
    )

    process {
        # Handle null or empty
        if ([string]::IsNullOrWhiteSpace($Status)) {
            return "Unknown"
        }

        # Normalize input
        $normalizedStatus = $Status.Trim().ToLower()

        # Map to standard values
        switch ($normalizedStatus) {
            # Healthy mappings
            { $_ -in @('ok', 'pass', 'passed', 'normal', 'active', 'good', 'healthy', 'success', 'enabled', 'running') } {
                return 'Healthy'
            }

            # Warning mappings
            { $_ -in @('warning', 'warn', 'degraded', 'limited', 'slow', 'inactive', 'disabled', 'stopped') } {
                # Context-specific: some "inactive" states are critical
                if ($Context -eq "Service" -and $_ -in @('inactive', 'disabled', 'stopped')) {
                    return 'Critical'
                }
                return 'Warning'
            }

            # Critical mappings
            { $_ -in @('critical', 'error', 'fail', 'failed', 'failure', 'bad', 'unhealthy', 'down', 'offline', 'missing') } {
                return 'Critical'
            }

            # Unknown mappings
            { $_ -in @('unknown', 'n/a', 'na', 'not available', 'not tested', 'skipped', 'pending') } {
                return 'Unknown'
            }

            # Default: return as-is if already standard
            { $_ -in @('healthy', 'warning', 'critical', 'unknown') } {
                # Capitalize first letter
                return $Status.Substring(0,1).ToUpper() + $Status.Substring(1).ToLower()
            }

            # Fallback
            default {
                Write-Verbose "ConvertTo-StandardStatus: Unmapped status '$Status' in context '$Context', returning 'Unknown'"
                return 'Unknown'
            }
        }
    }
}