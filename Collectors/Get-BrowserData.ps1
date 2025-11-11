# Get-BrowserData.ps1
# Collect comprehensive browser inventory and health data
# Author: Joshua Walderbach

function Get-BrowserData {
    [CmdletBinding()]
    param()
    
    Write-ProgressStatus -Activity "Collecting Browser Data" -Status "Initializing"
    
    # Initialize browser data structure
    $browserData = [PSCustomObject]@{
        CollectedAt = Get-Date
        DefaultBrowser = $null
        InstalledBrowsers = @()
        Summary = $null
        SecurityIssues = @()
        TotalCacheSize = 0
        TotalExtensions = 0
        HealthStatus = "Unknown"
    }
    
    try {
        # Fetch latest browser versions from vendor APIs
        Write-ProgressStatus -Activity "Collecting Browser Data" -Status "Fetching latest browser versions" -PercentComplete 5
        $latestVersions = Get-LatestBrowserVersions

        # Detect installed browsers
        Write-ProgressStatus -Activity "Collecting Browser Data" -Status "Detecting installed browsers" -PercentComplete 10
        $browsers = Get-InstalledBrowsers

        # Get default browser
        Write-ProgressStatus -Activity "Collecting Browser Data" -Status "Getting default browser" -PercentComplete 20
        $browserData.DefaultBrowser = Get-DefaultBrowser

        # Process each browser
        $percentStep = 60 / ([Math]::Max($browsers.Count, 1))
        $currentPercent = 20

        foreach ($browser in $browsers) {
            $currentPercent += $percentStep
            Write-ProgressStatus -Activity "Collecting Browser Data" -Status "Processing $($browser.Name)" -PercentComplete $currentPercent

            $browserInfo = switch ($browser.Type) {
                "Edge" { Get-EdgeData -BrowserPath $browser.Path -LatestVersions $latestVersions }
                "Chrome" { Get-ChromeData -BrowserPath $browser.Path -LatestVersions $latestVersions }
                "Firefox" { Get-FirefoxData -BrowserPath $browser.Path -LatestVersions $latestVersions }
                default { Get-GenericBrowserData -Browser $browser }
            }

            if ($browserInfo) {
                $browserData.InstalledBrowsers += $browserInfo
                $browserData.TotalCacheSize += $browserInfo.CacheSize
                $browserData.TotalExtensions += $browserInfo.ExtensionCount
            }
        }
        
        # Analyze security issues
        Write-ProgressStatus -Activity "Collecting Browser Data" -Status "Analyzing security" -PercentComplete 85
        $browserData.SecurityIssues = Get-BrowserSecurityIssues -Browsers $browserData.InstalledBrowsers
        
        # Create summary
        Write-ProgressStatus -Activity "Collecting Browser Data" -Status "Creating summary" -PercentComplete 95
        $browserData.Summary = Get-BrowserSummary -BrowserData $browserData
        
        # Determine health status
        $browserData.HealthStatus = Get-BrowserHealthStatus -BrowserData $browserData
        
        Write-ProgressStatus -Activity "Collecting Browser Data" -Completed
    }
    catch {
        Write-Error "Failed to collect browser data: $_"
    }
    
    return $browserData
}

function Get-LatestBrowserVersions {
    <#
    .SYNOPSIS
    Fetches latest stable browser versions from vendor APIs
    #>
    try {
        $latestVersions = @{
            Chrome = $null
            Edge = $null
            Firefox = $null
            Opera = $null
        }

        # Chrome - Google Version History API
        try {
            $chromeResponse = Invoke-RestMethod -Uri "https://versionhistory.googleapis.com/v1/chrome/platforms/win/channels/stable/versions?filter=version>0&order_by=version%20desc" -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($chromeResponse.versions -and $chromeResponse.versions.Count -gt 0) {
                $latestVersions.Chrome = $chromeResponse.versions[0].version
            }
        }
        catch {
            Write-Verbose "Failed to fetch Chrome latest version: $_"
        }

        # Edge - Microsoft Edge Update API
        try {
            $edgeResponse = Invoke-RestMethod -Uri "https://edgeupdates.microsoft.com/api/products" -TimeoutSec 5 -ErrorAction SilentlyContinue
            $stableEdge = $edgeResponse | Where-Object { $_.Product -eq "Stable" } | Select-Object -First 1
            if ($stableEdge -and $stableEdge.Releases) {
                $latestEdgeRelease = $stableEdge.Releases | Where-Object { $_.Platform -eq "Windows" -and $_.Architecture -eq "x64" } | Select-Object -First 1
                if ($latestEdgeRelease) {
                    $latestVersions.Edge = $latestEdgeRelease.ProductVersion
                }
            }
        }
        catch {
            Write-Verbose "Failed to fetch Edge latest version: $_"
        }

        # Firefox - Mozilla Product Details API
        try {
            $firefoxResponse = Invoke-RestMethod -Uri "https://product-details.mozilla.org/1.0/firefox_versions.json" -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($firefoxResponse.LATEST_FIREFOX_VERSION) {
                $latestVersions.Firefox = $firefoxResponse.LATEST_FIREFOX_VERSION
            }
        }
        catch {
            Write-Verbose "Failed to fetch Firefox latest version: $_"
        }

        # Opera - No official API, will mark as unknown
        # Could scrape from website but that's fragile

        return $latestVersions
    }
    catch {
        Write-Verbose "Error fetching latest browser versions: $_"
        return @{
            Chrome = $null
            Edge = $null
            Firefox = $null
            Opera = $null
        }
    }
}

function Get-InstalledBrowsers {
    try {
        $browsers = @()
        
        # Check for Microsoft Edge
        $edgePaths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
        )
        foreach ($path in $edgePaths) {
            if (Test-Path $path) {
                $browsers += [PSCustomObject]@{
                    Name = "Microsoft Edge"
                    Type = "Edge"
                    Path = $path
                }
                break
            }
        }
        
        # Check for Google Chrome
        $chromePaths = @(
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        )
        foreach ($path in $chromePaths) {
            if (Test-Path $path) {
                $browsers += [PSCustomObject]@{
                    Name = "Google Chrome"
                    Type = "Chrome"
                    Path = $path
                }
                break
            }
        }
        
        # Check for Mozilla Firefox
        $firefoxPaths = @(
            "${env:ProgramFiles}\Mozilla Firefox\firefox.exe"
            "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
        )
        foreach ($path in $firefoxPaths) {
            if (Test-Path $path) {
                $browsers += [PSCustomObject]@{
                    Name = "Mozilla Firefox"
                    Type = "Firefox"
                    Path = $path
                }
                break
            }
        }
        
        # Check registry for other browsers
        $registryPaths = @(
            'HKLM:\SOFTWARE\Clients\StartMenuInternet'
            'HKLM:\SOFTWARE\WOW6432Node\Clients\StartMenuInternet'
        )
        
        foreach ($regPath in $registryPaths) {
            if (Test-Path $regPath) {
                $browserKeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue
                foreach ($key in $browserKeys) {
                    $browserName = (Get-ItemProperty "$($key.PSPath)\Capabilities" -ErrorAction SilentlyContinue).ApplicationName
                    $browserPath = (Get-ItemProperty "$($key.PSPath)\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
                    
                    if ($browserPath) {
                        # Extract exe path from command
                        if ($browserPath -match '^"([^"]+)"' -or $browserPath -match '^([^\s]+)') {
                            $exePath = $matches[1]
                            if (Test-Path $exePath) {
                                # Check if not already added
                                if (-not ($browsers | Where-Object { $_.Path -eq $exePath })) {
                                    $type = "Other"
                                    if ($browserName -match "Opera") { $type = "Opera" }
                                    elseif ($browserName -match "Brave") { $type = "Brave" }
                                    
                                    $browsers += [PSCustomObject]@{
                                        Name = if ($browserName) { $browserName } else { $key.PSChildName }
                                        Type = $type
                                        Path = $exePath
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return $browsers
    }
    catch {
        Write-Warning "Failed to detect installed browsers: $_"
        return @()
    }
}

function Get-DefaultBrowser {
    try {
        # Get default browser from user choice
        $userChoice = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice' -ErrorAction SilentlyContinue
        
        if ($userChoice -and $userChoice.ProgId) {
            $progId = $userChoice.ProgId
            
            # Map ProgId to browser name
            $browserName = switch -Wildcard ($progId) {
                "MSEdgeHTM" { "Microsoft Edge" }
                "ChromeHTML*" { "Google Chrome" }
                "FirefoxURL*" { "Mozilla Firefox" }
                "OperaStable*" { "Opera" }
                "BraveHTML*" { "Brave" }
                "IE.HTTP" { "Internet Explorer" }
                default { $progId }
            }
            
            return [PSCustomObject]@{
                Name = $browserName
                ProgId = $progId
            }
        }
        
        return $null
    }
    catch {
        Write-Warning "Failed to get default browser: $_"
        return $null
    }
}

function Get-EdgeData {
    param(
        [string]$BrowserPath,
        [hashtable]$LatestVersions
    )

    try {
        $edgeData = [PSCustomObject]@{
            Name = "Microsoft Edge"
            Type = "Edge"
            Version = "Unknown"
            LatestVersion = $null
            InstallPath = $BrowserPath
            InstallDate = $null
            IsDefault = $false
            ProfilePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
            CacheSize = 0
            Extensions = @()
            ExtensionCount = 0
            SecuritySettings = $null
            AutoUpdateEnabled = $null
            Architecture = "x64"
            ExecutableSize = $null
            SignatureValid = $null
            Certificate = $null
        }

        # Get version and file information
        if (Test-Path $BrowserPath) {
            $fileItem = Get-Item $BrowserPath
            $versionInfo = $fileItem.VersionInfo
            $edgeData.Version = $versionInfo.ProductVersion
            $edgeData.InstallDate = $fileItem.CreationTime

            # Get file size
            $dirPath = Split-Path $BrowserPath
            if (Test-Path $dirPath) {
                $totalSize = (Get-ChildItem $dirPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                if ($totalSize -gt 1GB) {
                    $edgeData.ExecutableSize = "{0:N2} GB" -f ($totalSize / 1GB)
                } else {
                    $edgeData.ExecutableSize = "{0:N0} MB" -f ($totalSize / 1MB)
                }
            }

            # Check digital signature
            try {
                $signature = Get-AuthenticodeSignature -FilePath $BrowserPath -ErrorAction SilentlyContinue
                if ($signature) {
                    $edgeData.SignatureValid = $signature.Status -eq 'Valid'
                    $edgeData.Certificate = $signature.SignerCertificate.Subject -replace 'CN=|,.*', ''
                }
            }
            catch {
                $edgeData.SignatureValid = $false
            }
        }

        # Set latest version from API
        if ($LatestVersions -and $LatestVersions.Edge) {
            $edgeData.LatestVersion = $LatestVersions.Edge
        }
        
        # Check if default
        $default = Get-DefaultBrowser
        $edgeData.IsDefault = $default -and $default.Name -eq "Microsoft Edge"
        
        # Check auto-update status
        $edgeData.AutoUpdateEnabled = Get-EdgeAutoUpdateStatus
        
        # Get profile data
        if (Test-Path $edgeData.ProfilePath) {
            # Read Preferences file
            $prefsFile = Join-Path $edgeData.ProfilePath "Preferences"
            if (Test-Path $prefsFile) {
                try {
                    $prefs = Get-Content $prefsFile -Raw | ConvertFrom-Json
                    
                    # Get security settings using actual detection
                    $edgeData.SecuritySettings = Get-EdgeSecuritySettings -PreferencesObject $prefs
                }
                catch {
                    Write-Verbose "Could not parse Edge preferences"
                }
            }
            
            # Get extensions
            $extensionsPath = Join-Path $edgeData.ProfilePath "Extensions"
            if (Test-Path $extensionsPath) {
                $extensions = Get-ChildItem $extensionsPath -Directory -ErrorAction SilentlyContinue
                foreach ($ext in $extensions) {
                    # Skip temp folders
                    if ($ext.Name -match '^Temp') { continue }
                    
                    # Get manifest for extension details
                    $manifestPath = Get-ChildItem "$($ext.FullName)\*\manifest.json" -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($manifestPath) {
                        try {
                            $manifest = Get-Content $manifestPath.FullName -Raw | ConvertFrom-Json
                            $edgeData.Extensions += [PSCustomObject]@{
                                Id = $ext.Name
                                Name = $manifest.name
                                Version = $manifest.version
                                Description = $manifest.description
                                Permissions = $manifest.permissions
                            }
                        }
                        catch {
                            Write-Verbose "Could not parse extension manifest: $($ext.Name)"
                        }
                    }
                }
                $edgeData.ExtensionCount = $edgeData.Extensions.Count
            }
            
            # Calculate cache size
            $cachePaths = @(
                Join-Path $edgeData.ProfilePath "Cache"
                Join-Path $edgeData.ProfilePath "Code Cache"
                Join-Path $edgeData.ProfilePath "Service Worker"
            )
            
            foreach ($cachePath in $cachePaths) {
                if (Test-Path $cachePath) {
                    $size = Get-FolderSize -Path $cachePath
                    $edgeData.CacheSize += $size
                }
            }
        }
        
        return $edgeData
    }
    catch {
        Write-Warning "Failed to get Edge data: $_"
        return $null
    }
}

function Get-ChromeData {
    param(
        [string]$BrowserPath,
        [hashtable]$LatestVersions
    )

    try {
        $chromeData = [PSCustomObject]@{
            Name = "Google Chrome"
            Type = "Chrome"
            Version = "Unknown"
            LatestVersion = $null
            InstallPath = $BrowserPath
            InstallDate = $null
            IsDefault = $false
            ProfilePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
            CacheSize = 0
            Extensions = @()
            ExtensionCount = 0
            SecuritySettings = $null
            AutoUpdateEnabled = $null
            Architecture = "x64"
            ExecutableSize = $null
            SignatureValid = $null
            Certificate = $null
        }

        # Get version and file information
        if (Test-Path $BrowserPath) {
            $fileItem = Get-Item $BrowserPath
            $versionInfo = $fileItem.VersionInfo
            $chromeData.Version = $versionInfo.ProductVersion
            $chromeData.InstallDate = $fileItem.CreationTime

            # Get file size
            $dirPath = Split-Path $BrowserPath
            if (Test-Path $dirPath) {
                $totalSize = (Get-ChildItem $dirPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                if ($totalSize -gt 1GB) {
                    $chromeData.ExecutableSize = "{0:N2} GB" -f ($totalSize / 1GB)
                } else {
                    $chromeData.ExecutableSize = "{0:N0} MB" -f ($totalSize / 1MB)
                }
            }

            # Check digital signature
            try {
                $signature = Get-AuthenticodeSignature -FilePath $BrowserPath -ErrorAction SilentlyContinue
                if ($signature) {
                    $chromeData.SignatureValid = $signature.Status -eq 'Valid'
                    $chromeData.Certificate = $signature.SignerCertificate.Subject -replace 'CN=|,.*', ''
                }
            }
            catch {
                $chromeData.SignatureValid = $false
            }
        }

        # Set latest version from API
        if ($LatestVersions -and $LatestVersions.Chrome) {
            $chromeData.LatestVersion = $LatestVersions.Chrome
        }
        
        # Check if default
        $default = Get-DefaultBrowser
        $chromeData.IsDefault = $default -and $default.Name -eq "Google Chrome"
        
        # Check auto-update status
        $chromeData.AutoUpdateEnabled = Get-ChromeAutoUpdateStatus
        
        # Get profile data
        if (Test-Path $chromeData.ProfilePath) {
            # Read Preferences file
            $prefsFile = Join-Path $chromeData.ProfilePath "Preferences"
            if (Test-Path $prefsFile) {
                try {
                    $prefs = Get-Content $prefsFile -Raw | ConvertFrom-Json
                    
                    # Get security settings using actual detection
                    $chromeData.SecuritySettings = Get-ChromeSecuritySettings -PreferencesObject $prefs
                }
                catch {
                    Write-Verbose "Could not parse Chrome preferences"
                }
            }
            
            # Get extensions
            $extensionsPath = Join-Path $chromeData.ProfilePath "Extensions"
            if (Test-Path $extensionsPath) {
                $extensions = Get-ChildItem $extensionsPath -Directory -ErrorAction SilentlyContinue
                foreach ($ext in $extensions) {
                    if ($ext.Name -match '^Temp') { continue }
                    
                    $manifestPath = Get-ChildItem "$($ext.FullName)\*\manifest.json" -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($manifestPath) {
                        try {
                            $manifest = Get-Content $manifestPath.FullName -Raw | ConvertFrom-Json
                            $chromeData.Extensions += [PSCustomObject]@{
                                Id = $ext.Name
                                Name = $manifest.name
                                Version = $manifest.version
                                Description = $manifest.description
                                Permissions = $manifest.permissions
                            }
                        }
                        catch {
                            Write-Verbose "Could not parse extension manifest: $($ext.Name)"
                        }
                    }
                }
                $chromeData.ExtensionCount = $chromeData.Extensions.Count
            }
            
            # Calculate cache size
            $cachePaths = @(
                Join-Path $chromeData.ProfilePath "Cache"
                Join-Path $chromeData.ProfilePath "Code Cache"
                Join-Path $chromeData.ProfilePath "Service Worker"
            )
            
            foreach ($cachePath in $cachePaths) {
                if (Test-Path $cachePath) {
                    $size = Get-FolderSize -Path $cachePath
                    $chromeData.CacheSize += $size
                }
            }
        }
        
        return $chromeData
    }
    catch {
        Write-Warning "Failed to get Chrome data: $_"
        return $null
    }
}

function Get-FirefoxData {
    param(
        [string]$BrowserPath,
        [hashtable]$LatestVersions
    )

    try {
        $firefoxData = [PSCustomObject]@{
            Name = "Mozilla Firefox"
            Type = "Firefox"
            Version = "Unknown"
            LatestVersion = $null
            InstallPath = $BrowserPath
            InstallDate = $null
            IsDefault = $false
            ProfilePath = $null
            CacheSize = 0
            Extensions = @()
            ExtensionCount = 0
            SecuritySettings = $null
            AutoUpdateEnabled = $null
            Architecture = "x64"
            ExecutableSize = $null
            SignatureValid = $null
            Certificate = $null
        }

        # Get version and file information
        if (Test-Path $BrowserPath) {
            $fileItem = Get-Item $BrowserPath
            $versionInfo = $fileItem.VersionInfo
            $firefoxData.Version = $versionInfo.ProductVersion
            $firefoxData.InstallDate = $fileItem.CreationTime

            # Get file size
            $dirPath = Split-Path $BrowserPath
            if (Test-Path $dirPath) {
                $totalSize = (Get-ChildItem $dirPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                if ($totalSize -gt 1GB) {
                    $firefoxData.ExecutableSize = "{0:N2} GB" -f ($totalSize / 1GB)
                } else {
                    $firefoxData.ExecutableSize = "{0:N0} MB" -f ($totalSize / 1MB)
                }
            }

            # Check digital signature
            try {
                $signature = Get-AuthenticodeSignature -FilePath $BrowserPath -ErrorAction SilentlyContinue
                if ($signature) {
                    $firefoxData.SignatureValid = $signature.Status -eq 'Valid'
                    $firefoxData.Certificate = $signature.SignerCertificate.Subject -replace 'CN=|,.*', ''
                }
            }
            catch {
                $firefoxData.SignatureValid = $false
            }
        }

        # Set latest version from API
        if ($LatestVersions -and $LatestVersions.Firefox) {
            $firefoxData.LatestVersion = $LatestVersions.Firefox
        }
        
        # Check if default
        $default = Get-DefaultBrowser
        $firefoxData.IsDefault = $default -and $default.Name -eq "Mozilla Firefox"
        
        # Check auto-update status
        $firefoxData.AutoUpdateEnabled = Get-FirefoxAutoUpdateStatus -ProfilePath $firefoxData.ProfilePath
        
        # Find Firefox profile
        $profilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
        if (Test-Path $profilesPath) {
            # Get default profile (usually has .default or .default-release suffix)
            $defaultProfile = Get-ChildItem $profilesPath -Directory | 
                             Where-Object { $_.Name -match '\.default' } | 
                             Select-Object -First 1
            
            if ($defaultProfile) {
                $firefoxData.ProfilePath = $defaultProfile.FullName
                
                # Read prefs.js for settings
                $prefsFile = Join-Path $firefoxData.ProfilePath "prefs.js"
                if (Test-Path $prefsFile) {
                    $prefsContent = Get-Content $prefsFile -Raw
                    
                    # Parse security settings from prefs.js
                    $firefoxData.SecuritySettings = [PSCustomObject]@{
                        SafeBrowsingEnabled = $prefsContent -match 'browser\.safebrowsing\.malware\.enabled["\s,]+true'
                        PasswordManagerEnabled = -not ($prefsContent -match 'signon\.rememberSignons["\s,]+false')
                        TrackingProtectionEnabled = $prefsContent -match 'privacy\.trackingprotection\.enabled["\s,]+true'
                        TrackingPreventionEnabled = ($prefsContent -match 'privacy\.trackingprotection\.enabled["\s,]+true') -or 
                                                   ($prefsContent -match 'privacy\.trackingprotection\.socialtracking\.enabled["\s,]+true') -or
                                                   ($prefsContent -match 'privacy\.trackingprotection\.cryptomining\.enabled["\s,]+true') -or
                                                   ($prefsContent -match 'privacy\.trackingprotection\.fingerprinting\.enabled["\s,]+true')
                        AutofillEnabled = -not ($prefsContent -match 'browser\.formfill\.enable["\s,]+false')
                    }
                }
                
                # Get extensions from extensions.json
                $extensionsFile = Join-Path $firefoxData.ProfilePath "extensions.json"
                if (Test-Path $extensionsFile) {
                    try {
                        $extData = Get-Content $extensionsFile -Raw | ConvertFrom-Json
                        foreach ($addon in $extData.addons) {
                            if ($addon.type -eq "extension") {
                                $firefoxData.Extensions += [PSCustomObject]@{
                                    Id = $addon.id
                                    Name = $addon.defaultLocale.name
                                    Version = $addon.version
                                    Description = $addon.defaultLocale.description
                                    Active = $addon.active
                                }
                            }
                        }
                        $firefoxData.ExtensionCount = $firefoxData.Extensions.Count
                    }
                    catch {
                        Write-Verbose "Could not parse Firefox extensions"
                    }
                }
                
                # Calculate cache size
                $cachePaths = @(
                    Join-Path $firefoxData.ProfilePath "cache2"
                    Join-Path $firefoxData.ProfilePath "OfflineCache"
                    Join-Path $firefoxData.ProfilePath "storage"
                )
                
                foreach ($cachePath in $cachePaths) {
                    if (Test-Path $cachePath) {
                        $size = Get-FolderSize -Path $cachePath
                        $firefoxData.CacheSize += $size
                    }
                }
            }
        }
        
        return $firefoxData
    }
    catch {
        Write-Warning "Failed to get Firefox data: $_"
        return $null
    }
}

function Get-GenericBrowserData {
    param($Browser)
    
    try {
        $browserData = [PSCustomObject]@{
            Name = $Browser.Name
            Type = $Browser.Type
            Version = "Unknown"
            InstallDate = $null
            IsDefault = $false
            ProfilePath = $null
            CacheSize = 0
            Extensions = @()
            ExtensionCount = 0
            SecuritySettings = $null
            AutoUpdateEnabled = $null
        }
        
        # Get version from exe
        if (Test-Path $Browser.Path) {
            $versionInfo = (Get-Item $Browser.Path).VersionInfo
            $browserData.Version = $versionInfo.ProductVersion
            $browserData.InstallDate = (Get-Item $Browser.Path).CreationTime
        }
        
        # Check if default
        $default = Get-DefaultBrowser
        $browserData.IsDefault = $default -and $default.Name -eq $Browser.Name
        
        # Check auto-update status for generic browsers
        $browserData.AutoUpdateEnabled = Get-GenericBrowserAutoUpdateStatus -Browser $Browser
        
        return $browserData
    }
    catch {
        Write-Warning "Failed to get data for $($Browser.Name): $_"
        return $null
    }
}

function Get-FolderSize {
    param([string]$Path)
    
    try {
        if (Test-Path $Path) {
            $size = (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue | 
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            return if ($size) { $size } else { 0 }
        }
        return 0
    }
    catch {
        Write-Verbose "Could not calculate folder size for: $Path"
        return 0
    }
}

function Get-BrowserSecurityIssues {
    param($Browsers)
    
    try {
        $issues = @()
        
        foreach ($browser in $Browsers) {
            # Check for outdated browser - only flag if version is significantly outdated
            if ($browser.Version -ne "Unknown") {
                $isOutdated = $false
                $currentVersion = $browser.Version
                
                # Check against minimum supported versions (these are conservative estimates)
                switch ($browser.Type) {
                    "Edge" {
                        # Microsoft Edge - check if version is older than 110 (very conservative)
                        if ($currentVersion -match '^(\d+)') {
                            $majorVersion = [int]$matches[1]
                            if ($majorVersion -lt 110) {
                                $isOutdated = $true
                            }
                        }
                    }
                    "Chrome" {
                        # Google Chrome - check if version is older than 110 (very conservative)
                        if ($currentVersion -match '^(\d+)') {
                            $majorVersion = [int]$matches[1]
                            if ($majorVersion -lt 110) {
                                $isOutdated = $true
                            }
                        }
                    }
                    "Firefox" {
                        # Mozilla Firefox - check if version is older than 100 (very conservative)
                        if ($currentVersion -match '^(\d+)') {
                            $majorVersion = [int]$matches[1]
                            if ($majorVersion -lt 100) {
                                $isOutdated = $true
                            }
                        }
                    }
                }
                
                if ($isOutdated) {
                    $issues += [PSCustomObject]@{
                        Browser = $browser.Name
                        Issue = "Outdated Version"
                        Severity = "Warning"
                        Description = "Browser version $currentVersion is significantly outdated"
                        Recommendation = "Update to latest version"
                    }
                }
            }
            
            # Check for excessive cache
            $cacheSizeMB = [math]::Round($browser.CacheSize / 1MB, 2)
            if ($cacheSizeMB -gt 5120) {  # 5GB
                $issues += [PSCustomObject]@{
                    Browser = $browser.Name
                    Issue = "Excessive Cache"
                    Severity = "Warning"
                    Description = "Cache size is $($cacheSizeMB) MB"
                    Recommendation = "Clear browser cache"
                }
            }
            
            # Check security settings if available
            if ($browser.SecuritySettings) {
                if (-not $browser.SecuritySettings.SafeBrowsingEnabled) {
                    $issues += [PSCustomObject]@{
                        Browser = $browser.Name
                        Issue = "Safe Browsing Disabled"
                        Severity = "Critical"
                        Description = "Safe browsing protection is disabled"
                        Recommendation = "Enable safe browsing in browser settings"
                    }
                }
            }
            
            # Check for suspicious extensions
            foreach ($ext in $browser.Extensions) {
                if ($ext.Permissions -contains "webRequest" -or 
                    $ext.Permissions -contains "webRequestBlocking" -or
                    $ext.Permissions -contains "<all_urls>") {
                    $issues += [PSCustomObject]@{
                        Browser = $browser.Name
                        Issue = "High-Permission Extension"
                        Severity = "Info"
                        Description = "Extension '$($ext.Name)' has extensive permissions"
                        Recommendation = "Review extension permissions if unfamiliar"
                    }
                }
            }
        }
        
        return $issues
    }
    catch {
        Write-Warning "Failed to analyze browser security: $_"
        return @()
    }
}

function Get-BrowserSummary {
    param($BrowserData)
    
    try {
        $totalCacheSizeGB = [math]::Round($BrowserData.TotalCacheSize / 1GB, 2)
        
        return [PSCustomObject]@{
            InstalledCount = $BrowserData.InstalledBrowsers.Count
            DefaultBrowser = if ($BrowserData.DefaultBrowser) { $BrowserData.DefaultBrowser.Name } else { "None" }
            TotalCacheSizeGB = $totalCacheSizeGB
            TotalExtensions = $BrowserData.TotalExtensions
            SecurityIssueCount = $BrowserData.SecurityIssues.Count
            CriticalIssues = @($BrowserData.SecurityIssues | Where-Object { $_.Severity -eq "Critical" }).Count
            WarningIssues = @($BrowserData.SecurityIssues | Where-Object { $_.Severity -eq "Warning" }).Count
            InfoIssues = @($BrowserData.SecurityIssues | Where-Object { $_.Severity -eq "Info" }).Count
        }
    }
    catch {
        Write-Warning "Failed to create browser summary: $_"
        return $null
    }
}

function Get-BrowserHealthStatus {
    param($BrowserData)
    
    try {
        # Only count Critical and Warning issues, not Info items
        if ($BrowserData.Summary.CriticalIssues -gt 0) {
            return "Critical"
        }
        
        if ($BrowserData.Summary.WarningIssues -gt 2) {
            return "Warning"
        }
        
        if ($BrowserData.Summary.TotalCacheSizeGB -gt 10) {
            return "Warning"
        }
        
        # Info items don't affect health status
        return "Healthy"
    }
    catch {
        Write-Warning "Failed to determine browser health status: $_"
        return "Unknown"
    }
}

function Get-ChromeAutoUpdateStatus {
    try {
        # Check Group Policy first (takes precedence)
        $policies = @(
            'HKLM:\SOFTWARE\Policies\Google\Update',
            'HKLM:\SOFTWARE\WOW6432Node\Policies\Google\Update'
        )
        
        foreach ($policyPath in $policies) {
            if (Test-Path $policyPath) {
                # UpdateDefault: 0=updates disabled, 1=manual updates only, 2=auto updates enabled (default), 3=auto updates only
                $updateDefault = (Get-ItemProperty -Path $policyPath -Name "UpdateDefault" -ErrorAction SilentlyContinue).UpdateDefault
                if ($updateDefault -ne $null) {
                    return ($updateDefault -eq 2 -or $updateDefault -eq 3)
                }
                
                # AutoUpdateCheckPeriodMinutes: if 0, auto-update is disabled
                $autoUpdatePeriod = (Get-ItemProperty -Path $policyPath -Name "AutoUpdateCheckPeriodMinutes" -ErrorAction SilentlyContinue).AutoUpdateCheckPeriodMinutes
                if ($autoUpdatePeriod -ne $null) {
                    return $autoUpdatePeriod -gt 0
                }
                
                # Update{application-id}: app-specific update policy
                $chromeUpdatePolicy = (Get-ItemProperty -Path $policyPath -Name "Update{8A69D345-D564-463C-AFF1-A69D9E530F96}" -ErrorAction SilentlyContinue)."Update{8A69D345-D564-463C-AFF1-A69D9E530F96}"
                if ($chromeUpdatePolicy -ne $null) {
                    return ($chromeUpdatePolicy -eq 1 -or $chromeUpdatePolicy -eq 3)
                }
            }
        }
        
        # Check user preferences (Local State file)
        $localStatePaths = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State",
            "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Local State"
        )
        
        foreach ($localStatePath in $localStatePaths) {
            if (Test-Path $localStatePath) {
                try {
                    $localState = Get-Content $localStatePath -Raw | ConvertFrom-Json
                    if ($localState.google -and $localState.google.update) {
                        # If auto_update is explicitly set to false
                        if ($localState.google.update.PSObject.Properties['auto_update'] -and $localState.google.update.auto_update -eq $false) {
                            return $false
                        }
                    }
                }
                catch {
                    Write-Verbose "Could not parse Chrome Local State file"
                }
                break
            }
        }
        
        # Check Google Update service via registry
        $googleUpdateServices = @("gupdate", "gupdatem", "GoogleUpdate")
        foreach ($serviceName in $googleUpdateServices) {
            $servicePath = "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName"
            if (Test-Path $servicePath) {
                $startValue = (Get-ItemProperty $servicePath -Name "Start" -ErrorAction SilentlyContinue).Start
                if ($startValue -ne $null -and $startValue -ne 4) {  # 4 = Disabled
                    return $true
                }
            }
        }
        
        # Check scheduled tasks
        $updateTask = Get-ScheduledTask -TaskName "GoogleUpdateTaskMachine*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($updateTask) {
            return $updateTask.State -ne "Disabled"
        }
        
        # Default Chrome behavior - auto-update is enabled by default
        # Only return true if Chrome is actually installed
        $chromePaths = @(
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        )
        
        $chromeInstalled = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($chromeInstalled) {
            return $true  # Default assumption if no explicit disable found
        }
        
        return $false
    }
    catch {
        Write-Warning "Failed to detect Chrome auto-update status: $_"
        return $null
    }
}

function Get-EdgeAutoUpdateStatus {
    try {
        # Check Group Policy first (takes precedence)
        $policies = @(
            'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate',
            'HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\EdgeUpdate'
        )
        
        foreach ($policyPath in $policies) {
            if (Test-Path $policyPath) {
                # UpdateDefault: 0=updates disabled, 1=manual updates only, 2=auto updates enabled (default), 3=auto updates only
                $updateDefault = (Get-ItemProperty -Path $policyPath -Name "UpdateDefault" -ErrorAction SilentlyContinue).UpdateDefault
                if ($updateDefault -ne $null) {
                    # 0 = disabled, 1+ = updates enabled (manual or auto)
                    return ($updateDefault -gt 0)
                }
                
                # AutoUpdateCheckPeriodMinutes: if 0, auto-update is disabled
                $autoUpdatePeriod = (Get-ItemProperty -Path $policyPath -Name "AutoUpdateCheckPeriodMinutes" -ErrorAction SilentlyContinue).AutoUpdateCheckPeriodMinutes
                if ($autoUpdatePeriod -ne $null) {
                    return $autoUpdatePeriod -gt 0
                }
                
                # Update{application-id}: app-specific update policy for Edge
                $edgeUpdatePolicy = (Get-ItemProperty -Path $policyPath -Name "Update{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" -ErrorAction SilentlyContinue)."Update{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}"
                if ($edgeUpdatePolicy -ne $null) {
                    return ($edgeUpdatePolicy -eq 1 -or $edgeUpdatePolicy -eq 3)
                }
            }
        }
        
        # Check Edge preferences for update settings
        $edgePrefsPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Preferences"
        if (Test-Path $edgePrefsPath) {
            try {
                $prefs = Get-Content $edgePrefsPath -Raw | ConvertFrom-Json
                # Edge typically doesn't store update preferences in user prefs like Chrome
                # Updates are controlled via Windows Update or Edge Update service
            }
            catch {
                Write-Verbose "Could not parse Edge preferences"
            }
        }
        
        # Check Microsoft Edge Update services via registry
        $edgeUpdateServices = @("edgeupdate", "edgeupdatem", "MicrosoftEdgeElevationService")
        foreach ($serviceName in $edgeUpdateServices) {
            $servicePath = "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName"
            if (Test-Path $servicePath) {
                $startValue = (Get-ItemProperty $servicePath -Name "Start" -ErrorAction SilentlyContinue).Start
                if ($startValue -ne $null -and $startValue -ne 4) {  # 4 = Disabled
                    return $true
                }
            }
        }
        
        # Check scheduled tasks for Edge updates (try multiple possible names)
        $updateTaskPatterns = @(
            "MicrosoftEdgeUpdate*",
            "*EdgeUpdate*",
            "*Edge*Update*"
        )
        
        foreach ($taskPattern in $updateTaskPatterns) {
            $tasks = Get-ScheduledTask -TaskName $taskPattern -ErrorAction SilentlyContinue
            foreach ($task in $tasks) {
                if ($task -and $task.State -ne "Disabled") {
                    return $true
                }
            }
        }
        
        # Check Edge update registry keys
        $edgeUpdateKeys = @(
            'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'
        )
        
        foreach ($updateKey in $edgeUpdateKeys) {
            if (Test-Path $updateKey) {
                # Check if updates are enabled in registry
                $updatePolicy = (Get-ItemProperty -Path $updateKey -Name "UpdatePolicy" -ErrorAction SilentlyContinue).UpdatePolicy
                if ($updatePolicy -ne $null -and $updatePolicy -gt 0) {
                    return $true
                }
            }
        }
        
        # Check Windows Update settings for Edge (Edge updates via Windows Update on Win11)
        $windowsUpdatePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
        if (Test-Path $windowsUpdatePolicy) {
            $noAutoUpdate = (Get-ItemProperty -Path $windowsUpdatePolicy -Name "NoAutoUpdate" -ErrorAction SilentlyContinue).NoAutoUpdate
            if ($noAutoUpdate -eq 1) {
                return $false  # Windows Updates disabled, affects Edge updates
            }
        }
        
        # Check if Windows Update service is enabled via registry (affects Edge updates on Win11)
        $wuServicePath = "HKLM:\SYSTEM\CurrentControlSet\Services\wuauserv"
        if (Test-Path $wuServicePath) {
            $startValue = (Get-ItemProperty $wuServicePath -Name "Start" -ErrorAction SilentlyContinue).Start
            if ($startValue -ne $null -and $startValue -ne 4) {  # 4 = Disabled
                # If Windows Update is enabled and no explicit disable found, Edge updates are likely enabled
                return $true
            }
        }
        
        # Default Edge behavior - auto-update is enabled by default via Windows Update or Edge Update
        # Only return true if Edge is actually installed
        $edgePaths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
        )
        
        $edgeInstalled = $edgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($edgeInstalled) {
            return $true  # Default assumption if no explicit disable found
        }
        
        return $false
    }
    catch {
        Write-Warning "Failed to detect Edge auto-update status: $_"
        return $null
    }
}

function Get-FirefoxAutoUpdateStatus {
    param([string]$ProfilePath)
    
    try {
        # Check Group Policy first (takes precedence)
        $firefoxPolicyPaths = @(
            'HKLM:\SOFTWARE\Policies\Mozilla\Firefox',
            'HKLM:\SOFTWARE\WOW6432Node\Policies\Mozilla\Firefox'
        )
        
        foreach ($policyPath in $firefoxPolicyPaths) {
            if (Test-Path $policyPath) {
                # DisableAppUpdate policy
                $disableUpdate = (Get-ItemProperty -Path $policyPath -Name "DisableAppUpdate" -ErrorAction SilentlyContinue).DisableAppUpdate
                if ($disableUpdate -eq 1) {
                    return $false
                }
                
                # AppUpdateAuto policy
                $autoUpdate = (Get-ItemProperty -Path $policyPath -Name "AppUpdateAuto" -ErrorAction SilentlyContinue).AppUpdateAuto
                if ($autoUpdate -ne $null) {
                    return $autoUpdate -eq 1
                }
            }
        }
        
        # Check enterprise policies.json file
        $firefoxInstallPaths = @(
            "${env:ProgramFiles}\Mozilla Firefox",
            "${env:ProgramFiles(x86)}\Mozilla Firefox"
        )
        
        foreach ($installPath in $firefoxInstallPaths) {
            $policiesPath = Join-Path $installPath "distribution\policies.json"
            if (Test-Path $policiesPath) {
                try {
                    $policies = Get-Content $policiesPath -Raw | ConvertFrom-Json
                    if ($policies.policies) {
                        if ($policies.policies.PSObject.Properties['DisableAppUpdate'] -and $policies.policies.DisableAppUpdate -eq $true) {
                            return $false
                        }
                        if ($policies.policies.PSObject.Properties['AppUpdateAuto'] -and $policies.policies.AppUpdateAuto -eq $false) {
                            return $false
                        }
                    }
                }
                catch {
                    Write-Verbose "Could not parse Firefox policies.json"
                }
            }
        }
        
        # Check user profile prefs.js
        if ($ProfilePath) {
            $prefsFile = Join-Path $ProfilePath "prefs.js"
            if (Test-Path $prefsFile) {
                $prefsContent = Get-Content $prefsFile -Raw
                
                # Check various Firefox update preferences
                if ($prefsContent -match 'app\.update\.auto["\s,]+false') {
                    return $false
                }
                
                if ($prefsContent -match 'app\.update\.enabled["\s,]+false') {
                    return $false
                }
                
                if ($prefsContent -match 'app\.update\.mode["\s,]+0') {
                    return $false  # 0 = disabled, 1 = enabled, 2 = background
                }
                
                # If auto update is explicitly enabled
                if ($prefsContent -match 'app\.update\.auto["\s,]+true') {
                    return $true
                }
            }
            
            # Check user.js override file
            $userJsFile = Join-Path $ProfilePath "user.js"
            if (Test-Path $userJsFile) {
                $userJsContent = Get-Content $userJsFile -Raw
                
                if ($userJsContent -match 'app\.update\.auto["\s,]+false' -or 
                    $userJsContent -match 'app\.update\.enabled["\s,]+false') {
                    return $false
                }
            }
        }
        
        # Check Firefox maintenance service via registry (used for auto-updates)
        $maintenanceServicePath = "HKLM:\SYSTEM\CurrentControlSet\Services\MozillaMaintenance"
        if (Test-Path $maintenanceServicePath) {
            $startValue = (Get-ItemProperty $maintenanceServicePath -Name "Start" -ErrorAction SilentlyContinue).Start
            if ($startValue -eq 4) {  # 4 = Disabled
                return $false
            }
            # If service exists and is not disabled, auto-update is likely enabled
        }
        
        # Default Firefox behavior - auto-update is enabled by default
        # Only return true if Firefox is actually installed
        $firefoxPaths = @(
            "${env:ProgramFiles}\Mozilla Firefox\firefox.exe",
            "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
        )
        
        $firefoxInstalled = $firefoxPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($firefoxInstalled) {
            return $true  # Default assumption if no explicit disable found
        }
        
        return $false
    }
    catch {
        Write-Warning "Failed to detect Firefox auto-update status: $_"
        return $null
    }
}

function Get-GenericBrowserAutoUpdateStatus {
    param($Browser)
    
    try {
        # Handle known browser types that might be detected as "Other"
        switch -Wildcard ($Browser.Name) {
            "*Opera*" {
                # Check Opera auto-update
                $operaUpdateService = Get-Service -Name "Opera*Update*" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($operaUpdateService) {
                    return $operaUpdateService.StartType -ne "Disabled"
                }
                
                # Check scheduled tasks
                $operaTask = Get-ScheduledTask -TaskName "*Opera*Update*" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($operaTask) {
                    return $operaTask.State -ne "Disabled"
                }
                
                return $true  # Opera typically has auto-update enabled by default
            }
            
            "*Brave*" {
                # Brave uses similar update mechanism to Chrome
                # Check for Brave update services via registry
                $braveServices = @("BraveUpdate", "BraveElevationService")
                foreach ($serviceName in $braveServices) {
                    $servicePath = "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName"
                    if (Test-Path $servicePath) {
                        $startValue = (Get-ItemProperty $servicePath -Name "Start" -ErrorAction SilentlyContinue).Start
                        if ($startValue -ne $null -and $startValue -ne 4) {  # 4 = Disabled
                            return $true
                        }
                    }
                }
                
                # Check Brave-specific scheduled tasks
                $braveTask = Get-ScheduledTask -TaskName "*Brave*Update*" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($braveTask) {
                    return $braveTask.State -ne "Disabled"
                }
                
                return $true  # Brave typically has auto-update enabled by default
            }
            
            "*Vivaldi*" {
                # Vivaldi auto-update check
                $vivaldiTask = Get-ScheduledTask -TaskName "*Vivaldi*Update*" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($vivaldiTask) {
                    return $vivaldiTask.State -ne "Disabled"
                }
                
                return $true  # Vivaldi typically has auto-update enabled by default
            }
            
            { $_ -like "*Internet Explorer*" -or $_ -like "*IE*" } {
                # IE updates via Windows Update
                $windowsUpdatePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
                if (Test-Path $windowsUpdatePolicy) {
                    $noAutoUpdate = (Get-ItemProperty -Path $windowsUpdatePolicy -Name "NoAutoUpdate" -ErrorAction SilentlyContinue).NoAutoUpdate
                    if ($noAutoUpdate -eq 1) {
                        return $false
                    }
                }
                
                return $true  # IE updates via Windows Update by default
            }
            
            default {
                # For unknown browsers, try to detect update mechanisms
                
                # Look for browser-specific update services via registry
                $browserBaseName = ($Browser.Name -replace '\s+', '').ToLower()
                $servicePaths = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services" -ErrorAction SilentlyContinue | 
                               Where-Object { $_.PSChildName -like "*$browserBaseName*" -and $_.PSChildName -like "*update*" }
                
                foreach ($servicePath in $servicePaths) {
                    $startValue = (Get-ItemProperty $servicePath.PSPath -Name "Start" -ErrorAction SilentlyContinue).Start
                    if ($startValue -ne $null -and $startValue -ne 4) {  # 4 = Disabled
                        return $true
                    }
                }
                
                # Look for browser-specific update scheduled tasks
                $updateTask = Get-ScheduledTask -TaskName "*$browserBaseName*update*" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($updateTask) {
                    return $updateTask.State -ne "Disabled"
                }
                
                # Check if browser executable is in a directory with update-related files
                if ($Browser.Path) {
                    $browserDir = Split-Path $Browser.Path -Parent
                    $updateFiles = @(
                        "updater.exe",
                        "update.exe",
                        "*update*.exe",
                        "maintenance_service.exe"
                    )
                    
                    foreach ($updateFile in $updateFiles) {
                        if (Get-ChildItem $browserDir -Name $updateFile -ErrorAction SilentlyContinue) {
                            return $true  # Assume auto-update is enabled if update mechanism exists
                        }
                    }
                }
                
                # If browser is installed but we can't determine update status, return null (unknown)
                return $null
            }
        }
    }
    catch {
        Write-Warning "Failed to detect auto-update status for $($Browser.Name): $_"
        return $null
    }
}


function Get-EdgeSecuritySettings {
    param($PreferencesObject)
    
    try {
        $securitySettings = [PSCustomObject]@{
            SafeBrowsingEnabled = $null
            PasswordManagerEnabled = $null
            AutofillEnabled = $null
            TrackingPreventionEnabled = $null
        }
        
        # Check Group Policy first (takes precedence)
        $edgePolicies = @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Edge',
            'HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Edge'
        )
        
        foreach ($policyPath in $edgePolicies) {
            if (Test-Path $policyPath) {
                # SafeBrowsingEnabled policy
                $safeBrowsingPolicy = (Get-ItemProperty -Path $policyPath -Name "SafeBrowsingEnabled" -ErrorAction SilentlyContinue).SafeBrowsingEnabled
                if ($safeBrowsingPolicy -ne $null) {
                    $securitySettings.SafeBrowsingEnabled = $safeBrowsingPolicy -eq 1
                }
                
                # PasswordManagerEnabled policy
                $passwordPolicy = (Get-ItemProperty -Path $policyPath -Name "PasswordManagerEnabled" -ErrorAction SilentlyContinue).PasswordManagerEnabled
                if ($passwordPolicy -ne $null) {
                    $securitySettings.PasswordManagerEnabled = $passwordPolicy -eq 1
                }
                
                # AutofillAddressEnabled policy
                $autofillPolicy = (Get-ItemProperty -Path $policyPath -Name "AutofillAddressEnabled" -ErrorAction SilentlyContinue).AutofillAddressEnabled
                if ($autofillPolicy -ne $null) {
                    $securitySettings.AutofillEnabled = $autofillPolicy -eq 1
                }
                
                # TrackingPrevention policy
                $trackingPreventionPolicy = (Get-ItemProperty -Path $policyPath -Name "TrackingPrevention" -ErrorAction SilentlyContinue).TrackingPrevention
                if ($trackingPreventionPolicy -ne $null) {
                    # 0=Off, 1=Basic, 2=Balanced, 3=Strict
                    $securitySettings.TrackingPreventionEnabled = $trackingPreventionPolicy -gt 0
                }
            }
        }
        
        # If not set by policy, check preferences file
        if ($PreferencesObject) {
            # Safe browsing detection
            if ($securitySettings.SafeBrowsingEnabled -eq $null) {
                if ($PreferencesObject.safebrowsing -and $PreferencesObject.safebrowsing.PSObject.Properties['enabled']) {
                    $securitySettings.SafeBrowsingEnabled = $PreferencesObject.safebrowsing.enabled
                } elseif ($PreferencesObject.safebrowsing -and $PreferencesObject.safebrowsing.PSObject.Properties['protection_level']) {
                    # Modern Edge uses protection_level: 0=off, 1=standard, 2=enhanced
                    $securitySettings.SafeBrowsingEnabled = $PreferencesObject.safebrowsing.protection_level -gt 0
                } elseif ($PreferencesObject.profile -and $PreferencesObject.profile.PSObject.Properties['safebrowsing'] -and $PreferencesObject.profile.safebrowsing.PSObject.Properties['enabled']) {
                    $securitySettings.SafeBrowsingEnabled = $PreferencesObject.profile.safebrowsing.enabled
                }
            }
            
            # Password manager detection
            if ($securitySettings.PasswordManagerEnabled -eq $null) {
                if ($PreferencesObject.PSObject.Properties['credentials_enable_service']) {
                    $securitySettings.PasswordManagerEnabled = $PreferencesObject.credentials_enable_service
                }
            }
            
            # Autofill detection
            if ($securitySettings.AutofillEnabled -eq $null) {
                if ($PreferencesObject.autofill -and $PreferencesObject.autofill.PSObject.Properties['enabled']) {
                    $securitySettings.AutofillEnabled = $PreferencesObject.autofill.enabled
                }
            }
            
            # Tracking Prevention detection
            if ($securitySettings.TrackingPreventionEnabled -eq $null) {
                if ($PreferencesObject.profile -and $PreferencesObject.profile.PSObject.Properties['tracking_prevention_level']) {
                    # Edge stores tracking prevention level: 0=off, 1=basic, 2=balanced, 3=strict
                    $securitySettings.TrackingPreventionEnabled = $PreferencesObject.profile.tracking_prevention_level -gt 0
                }
            }
        }
        
        # If still null, use documented Edge defaults (last resort)
        if ($securitySettings.SafeBrowsingEnabled -eq $null) {
            $securitySettings.SafeBrowsingEnabled = $true  # Edge default is enabled
        }
        if ($securitySettings.PasswordManagerEnabled -eq $null) {
            $securitySettings.PasswordManagerEnabled = $true  # Edge default is enabled
        }
        if ($securitySettings.AutofillEnabled -eq $null) {
            $securitySettings.AutofillEnabled = $true  # Edge default is enabled
        }
        if ($securitySettings.TrackingPreventionEnabled -eq $null) {
            $securitySettings.TrackingPreventionEnabled = $true  # Edge default is Balanced (enabled)
        }
        
        return $securitySettings
    }
    catch {
        Write-Warning "Failed to detect Edge security settings: $_"
        return [PSCustomObject]@{
            SafeBrowsingEnabled = $null
            PasswordManagerEnabled = $null
            AutofillEnabled = $null
            TrackingPreventionEnabled = $null
        }
    }
}

function Get-ChromeSecuritySettings {
    param($PreferencesObject)
    
    try {
        $securitySettings = [PSCustomObject]@{
            SafeBrowsingEnabled = $null
            PasswordManagerEnabled = $null
            AutofillEnabled = $null
            TrackingPreventionEnabled = $null
        }
        
        # Check Group Policy first (takes precedence)
        $chromePolicies = @(
            'HKLM:\SOFTWARE\Policies\Google\Chrome',
            'HKLM:\SOFTWARE\WOW6432Node\Policies\Google\Chrome'
        )
        
        foreach ($policyPath in $chromePolicies) {
            if (Test-Path $policyPath) {
                # SafeBrowsingEnabled policy
                $safeBrowsingPolicy = (Get-ItemProperty -Path $policyPath -Name "SafeBrowsingEnabled" -ErrorAction SilentlyContinue).SafeBrowsingEnabled
                if ($safeBrowsingPolicy -ne $null) {
                    $securitySettings.SafeBrowsingEnabled = $safeBrowsingPolicy -eq 1
                }
                
                # PasswordManagerEnabled policy
                $passwordPolicy = (Get-ItemProperty -Path $policyPath -Name "PasswordManagerEnabled" -ErrorAction SilentlyContinue).PasswordManagerEnabled
                if ($passwordPolicy -ne $null) {
                    $securitySettings.PasswordManagerEnabled = $passwordPolicy -eq 1
                }
                
                # AutofillAddressEnabled policy
                $autofillPolicy = (Get-ItemProperty -Path $policyPath -Name "AutofillAddressEnabled" -ErrorAction SilentlyContinue).AutofillAddressEnabled
                if ($autofillPolicy -ne $null) {
                    $securitySettings.AutofillEnabled = $autofillPolicy -eq 1
                }
                
                # BlockThirdPartyCookies policy (Chrome's tracking protection)
                $blockThirdPartyCookiesPolicy = (Get-ItemProperty -Path $policyPath -Name "BlockThirdPartyCookies" -ErrorAction SilentlyContinue).BlockThirdPartyCookies
                if ($blockThirdPartyCookiesPolicy -ne $null) {
                    $securitySettings.TrackingPreventionEnabled = $blockThirdPartyCookiesPolicy -eq 1
                }
            }
        }
        
        # If not set by policy, check preferences file
        if ($PreferencesObject) {
            # Safe browsing detection
            if ($securitySettings.SafeBrowsingEnabled -eq $null) {
                if ($PreferencesObject.safebrowsing -and $PreferencesObject.safebrowsing.PSObject.Properties['enabled']) {
                    $securitySettings.SafeBrowsingEnabled = $PreferencesObject.safebrowsing.enabled
                } elseif ($PreferencesObject.safebrowsing -and $PreferencesObject.safebrowsing.PSObject.Properties['protection_level']) {
                    # Modern Chrome uses protection_level: 0=off, 1=standard, 2=enhanced
                    $securitySettings.SafeBrowsingEnabled = $PreferencesObject.safebrowsing.protection_level -gt 0
                } elseif ($PreferencesObject.profile -and $PreferencesObject.profile.PSObject.Properties['safebrowsing'] -and $PreferencesObject.profile.safebrowsing.PSObject.Properties['enabled']) {
                    $securitySettings.SafeBrowsingEnabled = $PreferencesObject.profile.safebrowsing.enabled
                }
            }
            
            # Password manager detection
            if ($securitySettings.PasswordManagerEnabled -eq $null) {
                if ($PreferencesObject.PSObject.Properties['credentials_enable_service']) {
                    $securitySettings.PasswordManagerEnabled = $PreferencesObject.credentials_enable_service
                }
            }
            
            # Autofill detection
            if ($securitySettings.AutofillEnabled -eq $null) {
                if ($PreferencesObject.autofill -and $PreferencesObject.autofill.PSObject.Properties['enabled']) {
                    $securitySettings.AutofillEnabled = $PreferencesObject.autofill.enabled
                }
            }
            
            # Tracking Prevention detection (Third-party cookies blocking)
            if ($securitySettings.TrackingPreventionEnabled -eq $null) {
                if ($PreferencesObject.profile -and $PreferencesObject.profile.PSObject.Properties['block_third_party_cookies']) {
                    $securitySettings.TrackingPreventionEnabled = $PreferencesObject.profile.block_third_party_cookies -eq $true
                } elseif ($PreferencesObject.PSObject.Properties['block_third_party_cookies']) {
                    $securitySettings.TrackingPreventionEnabled = $PreferencesObject.block_third_party_cookies -eq $true
                }
            }
        }
        
        # If still null, use documented Chrome defaults (last resort)
        if ($securitySettings.SafeBrowsingEnabled -eq $null) {
            $securitySettings.SafeBrowsingEnabled = $true  # Chrome default is enabled
        }
        if ($securitySettings.PasswordManagerEnabled -eq $null) {
            $securitySettings.PasswordManagerEnabled = $true  # Chrome default is enabled
        }
        if ($securitySettings.AutofillEnabled -eq $null) {
            $securitySettings.AutofillEnabled = $true  # Chrome default is enabled
        }
        if ($securitySettings.TrackingPreventionEnabled -eq $null) {
            $securitySettings.TrackingPreventionEnabled = $false  # Chrome default is disabled
        }
        
        return $securitySettings
    }
    catch {
        Write-Warning "Failed to detect Chrome security settings: $_"
        return [PSCustomObject]@{
            SafeBrowsingEnabled = $null
            PasswordManagerEnabled = $null
            AutofillEnabled = $null
            TrackingPreventionEnabled = $null
        }
    }
}