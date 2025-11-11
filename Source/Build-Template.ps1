<#
.SYNOPSIS
    Builds the WinDAS report template from modular source files.
.DESCRIPTION
    Concatenates CSS and JavaScript modules into a single standalone HTML file.
#>

[CmdletBinding()]
param()

Write-Host "Building WinDAS Report Template..." -ForegroundColor Cyan

# Paths
$SourceRoot = $PSScriptRoot
$TemplateShell = Join-Path $SourceRoot "template-shell.html"
$OutputFile = Join-Path $SourceRoot "..\Templates\report-template.html"

# Validate source
if (-not (Test-Path $TemplateShell)) {
    Write-Error "Template shell not found: $TemplateShell"
    exit 1
}

Write-Host "Reading template shell..." -ForegroundColor Gray
$template = Get-Content $TemplateShell -Raw -Encoding UTF8

# CSS: Concatenate all stylesheets
Write-Host "Concatenating CSS modules..." -ForegroundColor Gray
$cssFiles = Get-ChildItem (Join-Path $SourceRoot "styles\*.css") | Sort-Object Name
$cssContent = ""

foreach ($cssFile in $cssFiles) {
    Write-Host "  + $($cssFile.Name)" -ForegroundColor DarkGray
    $cssContent += Get-Content $cssFile.FullName -Raw -Encoding UTF8
    $cssContent += "`n"
}

# Inject CSS
$styleOpen = "<" + "style" + ">"
$styleClose = "<" + "/style" + ">"
$styleTag = "$styleOpen`n$cssContent    $styleClose"
$template = $template -replace '<!--CSS-->', $styleTag

# JavaScript: Concatenate modules
Write-Host "Concatenating JavaScript modules..." -ForegroundColor Gray

# Utils + Core
$utilsFile = Join-Path $SourceRoot "js\utils.js"
$coreFile = Join-Path $SourceRoot "js\core.js"
$jsCore = ""

if (Test-Path $utilsFile) {
    Write-Host "  + utils.js" -ForegroundColor DarkGray
    $jsCore = Get-Content $utilsFile -Raw -Encoding UTF8
}

if (Test-Path $coreFile) {
    Write-Host "  + core.js" -ForegroundColor DarkGray
    $jsCore += "`n" + (Get-Content $coreFile -Raw -Encoding UTF8)
}

# Tabs
$tabFiles = Get-ChildItem (Join-Path $SourceRoot "js\tabs\*.js") | Sort-Object Name
$jsTabs = ""

foreach ($tabFile in $tabFiles) {
    Write-Host "  + $($tabFile.Name)" -ForegroundColor DarkGray
    $jsTabs += Get-Content $tabFile.FullName -Raw -Encoding UTF8
    $jsTabs += "`n"
}

# Inject JavaScript
$template = $template -replace '<!--JS_CORE-->', $jsCore
$template = $template -replace '<!--JS_TABS-->', $jsTabs

# Write output
Write-Host "Writing output..." -ForegroundColor Gray
Set-Content -Path $OutputFile -Value $template -Encoding UTF8

# Validation
Write-Host "Validating..." -ForegroundColor Gray

$outputInfo = Get-Item $OutputFile
$outputLines = (Get-Content $OutputFile -Encoding UTF8).Count
$outputSizeKB = [math]::Round($outputInfo.Length / 1KB, 1)

Write-Host ""
Write-Host "Build Statistics:" -ForegroundColor Cyan
Write-Host "  Lines: $outputLines" -ForegroundColor White
Write-Host "  Size: $outputSizeKB KB" -ForegroundColor White

# Check for placeholders
$outputContent = Get-Content $OutputFile -Raw -Encoding UTF8
$placeholders = @('<!--CSS-->', '<!--JS_CORE-->', '<!--JS_TABS-->')
$foundPlaceholders = $false

foreach ($placeholder in $placeholders) {
    if ($outputContent -match [regex]::Escape($placeholder)) {
        Write-Warning "Placeholder still exists: $placeholder"
        $foundPlaceholders = $true
    }
}

# Check for key functions
$requiredFunctions = @(
    'function loadOSTab',
    'function loadHardwareTab',
    'function formatNetDate',
    'function escapeHtml'
)

$missingFunctions = @()
foreach ($func in $requiredFunctions) {
    if ($outputContent -notmatch [regex]::Escape($func)) {
        $missingFunctions += $func
    }
}

if ($missingFunctions.Count -gt 0) {
    Write-Error "Missing functions:"
    $missingFunctions | ForEach-Object { Write-Error "  - $_" }
    exit 1
}

if ($foundPlaceholders) {
    Write-Error "Build completed with warnings"
    exit 1
}

Write-Host ""
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "Output: $OutputFile" -ForegroundColor White
Write-Host ""
Write-Host "Next: Run WinDAS.ps1 to test the report" -ForegroundColor Cyan
Write-Host ""
