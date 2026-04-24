<#
.SYNOPSIS
    PSADT script to manage Greenshot MSIX installation, uninstallation, repair, and Active Setup.
    File: GreenshotManager.ps1
    App : Greenshot (MSIX) v1.2.10.6
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("Install","Uninstall","Repair")]
    [string]$DeploymentType = "Install"
)

## Import the PSADT functions
Try {
    Import-Module "$PSScriptRoot\AppDeployToolkit\AppDeployToolkitMain.ps1" -Force
}
Catch {
    Write-Log -Message "Failed to import PSADT module." -Severity 3
    Exit-Script -ExitCode 1
}

## Define app variables
[string]$appName = "Greenshot"
[string]$appVersion = "1.2.10.6"
[string]$appVendor = "Greenshot Team"
[string]$appArch = "x64"
[string]$msixPath = "$dirFiles\Greenshot-1.2.10.6-x64.msix"
[string]$appPackageName = "Greenshot.Greenshot"   # Adjust after checking with Get-AppxPackage

# Main Deployment logic
Try {
    Switch ($DeploymentType) {
        
        "Install" {
            Show-InstallationWelcome -CloseApps "Greenshot" -Silent
            Show-ProgressDialog -Message "Installing $appName $appVersion..."

            # Install MSIX
            Execute-Process -Path "powershell.exe" -Parameters "Add-AppxPackage -Path `"$msixPath`"" -WindowStyle Hidden
            
            # Active Setup (for user profile initialization, e.g. shortcut/registry)
            $activeSetupReg = "HKLM:\Software\Microsoft\Active Setup\Installed Components\GreenshotUserConfig"
            New-Item -Path $activeSetupReg -Force | Out-Null
            Set-ItemProperty -Path $activeSetupReg -Name "StubPath" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$env:ProgramFiles\Greenshot\ConfigureUser.ps1`""
            Set-ItemProperty -Path $activeSetupReg -Name "Version" -Value "1,0"

            Show-InstallationPrompt -Message "$appName $appVersion has been installed successfully." -ButtonRightText "OK"
        }

        "Uninstall" {
            Show-InstallationWelcome -CloseApps "Greenshot" -Silent
            Show-ProgressDialog -Message "Uninstalling $appName..."

            # Get package full name and uninstall
            $pkg = (Get-AppxPackage | Where-Object { $_.Name -like "*Greenshot*" }).PackageFullName
            If ($pkg) {
                Execute-Process -Path "powershell.exe" -Parameters "Remove-AppxPackage -Package `"$pkg`"" -WindowStyle Hidden
            }

            # Clean Active Setup
            Remove-Item -Path "HKLM:\Software\Microsoft\Active Setup\Installed Components\GreenshotUserConfig" -Recurse -Force -ErrorAction SilentlyContinue
            
            Show-InstallationPrompt -Message "$appName has been uninstalled successfully." -ButtonRightText "OK"
        }

        "Repair" {
            Show-InstallationWelcome -Silent
            Show-ProgressDialog -Message "Repairing $appName..."

            # Reinstall MSIX
            Execute-Process -Path "powershell.exe" -Parameters "Add-AppxPackage -Path `"$msixPath`" -ForceApplicationShutdown -ForceUpdateFromAnyVersion" -WindowStyle Hidden

            Show-InstallationPrompt -Message "$appName has been repaired successfully." -ButtonRightText "OK"
        }
    }
}
Catch {
    Write-Log -Message "Deployment failed with error: $_" -Severity 3
    Exit-Script -ExitCode 1
}
Finally {
    Exit-Script -ExitCode 0
}
