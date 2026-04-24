<#
Invoke-AppDeployToolkit.ps1
Simple compatibility launcher for PSAppDeployToolkit when module files (.psm1/.psd1) exist
Place this file in the same folder as your PSADT .psm1/.psd1 and run it (Run as Admin).
#>

[CmdletBinding()]
param()

# Helpers
function Log { param($m) Write-Host "[Invoke-ADTK] $m" }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Log "ScriptDir: $ScriptDir"

# Find module file
$psm1 = Get-ChildItem -Path $ScriptDir -Filter *.psm1 -File -ErrorAction SilentlyContinue | Select-Object -First 1
$psd1 = Get-ChildItem -Path $ScriptDir -Filter *.psd1 -File -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $psm1 -and -not $psd1) {
    Log "ERROR: No .psm1 or .psd1 found in folder. Aborting."
    exit 2
}

# Import module (prefer psm1)
try {
    if ($psm1) {
        Log "Importing module from $($psm1.Name)"
        Import-Module -Name $psm1.FullName -Force -ErrorAction Stop
    } else {
        Log "Importing module from $($psd1.Name)"
        Import-Module -Name $psd1.FullName -Force -ErrorAction Stop
    }
    Log "Module imported."
} catch {
    Log "ERROR: Module import failed: $($_.Exception.Message)"
    exit 3
}

# Known possible entrypoint names (ordered)
$entryNames = @(
    'Deploy-Application',
    'Install-Application',
    'Execute-Application',
    'Start-Deployment',
    'Start-Installation',
    'Invoke-Deployment'
)

# Check if any of those exist in module
$foundEntry = $null
foreach ($n in $entryNames) {
    if (Get-Command -Name $n -ErrorAction SilentlyContinue) {
        $foundEntry = $n
        break
    }
}

# If not found, try to find any function exported by module that ends with '-Application' or contains 'Deploy'/'Install'
if (-not $foundEntry) {
    $moduleFuncs = Get-Command -CommandType Function | Where-Object { $_.ModuleName -and ($_.ModuleName -eq ( (Get-Module | Where-Object { $_.Path -and ($psm1 -and $_.Path -eq $psm1.FullName) -or ($psd1 -and $_.Path -eq $psd1.FullName) } ).Name )) } 2>$null
    if (-not $moduleFuncs) {
        # fallback: list functions loaded from any module (less strict)
        $moduleFuncs = Get-Command -CommandType Function
    }
    foreach ($f in $moduleFuncs) {
        if ($f.Name -match 'Deploy|Install|Execute' -and $f.Name -match 'Application|App|Deployment|Install') {
            $foundEntry = $f.Name
            break
        }
    }
}

if ($foundEntry) {
    Log "Found entrypoint function: $foundEntry  — invoking it."
    try {
        & $foundEntry
        $rc = $LASTEXITCODE
        Log "Entrypoint finished. Exit code: $rc"
        exit 0
    } catch {
        Log "ERROR: Entrypoint threw: $($_.Exception.Message)"
        exit 4
    }
}

# No function found in module — fallback to external deploy scripts in same folder
Log "No module entrypoint found. Searching for common deploy scripts in folder."

$preferred = @('Deploy-Application.ps1','Install-Application.ps1','InstallApplication.ps1','DeployApplication.ps1','Invoke-Deployment.ps1')
$foundScript = $null
foreach ($n in $preferred) {
    $p = Join-Path $ScriptDir $n
    if (Test-Path $p) { $foundScript = $p; break }
}

if (-not $foundScript) {
    # generic patterns
    $c = Get-ChildItem -Path $ScriptDir -Filter '*deploy*.ps1' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { $foundScript = $c.FullName }
}
if (-not $foundScript) {
    $c = Get-ChildItem -Path $ScriptDir -Filter '*install*.ps1' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { $foundScript = $c.FullName }
}

if ($foundScript) {
    Log "Executing script: $foundScript"
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $foundScript
        Log "Script finished."
        exit 0
    } catch {
        Log "ERROR: Script execution failed: $($_.Exception.Message)"
        exit 5
    }
}

# Last-ditch: attempt simple package install if package file present (msix/msi/exe)
Log "No deploy script found. Looking for package files (msix/msi/exe)."
$pkg = Get-ChildItem -Path $ScriptDir -Include *.msix,*.appx,*.msi,*.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pkg) {
    Log "Found package: $($pkg.Name) - attempting best-effort install."
    switch ($pkg.Extension.ToLower()) {
        '.msix' { Add-AppxPackage -Path $pkg.FullName -ErrorAction Stop; Log "Add-AppxPackage succeeded." }
        '.appx' { Add-AppxPackage -Path $pkg.FullName -ErrorAction Stop; Log "Add-AppxPackage succeeded." }
        '.msi'  { Start-Process msiexec.exe -ArgumentList "/i `"$($pkg.FullName)`" /qn /norestart" -Wait; Log "msi launched." }
        '.exe'  { Start-Process -FilePath $pkg.FullName -Wait; Log "exe launched." }
        default { Log "Unknown package type." }
    }
    exit 0
}

Log "Nothing to run. Exiting."
exit 6
