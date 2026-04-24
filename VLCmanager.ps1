<#
.SYNOPSIS
    PSADT script to manage VLC MSIX installation, uninstallation, repair, and Active Setup.
    File: VLCmanager.ps1
    App : VLC Media Player (MSIX) v3.0.8
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
[string]$appName = "VLC Media Player"
[string]$appVersion = "3.0.8"
[string]$appVendor = "VideoLAN"
[string]$appArch = "x64"
[string]$msixPath = "$dirFiles\vlc-3.0.8-win64.msix"
[string]$appPackageName = "VideoLAN.VLC"   # Adjust after checking with Get-AppxPackage

# Main Deployment logic
Try {
    Switch ($DeploymentType) {
        
        "Install" {
            Show-InstallationWelcome -CloseApps "vlc" -Silent
            Show-ProgressDialog -Message "Installing $appName $appVersion..."

            # Install MSIX
            Execute-Process -Path "powershell.exe" -Parameters "Add-AppxPackage -Path `"$msixPath`"" -WindowStyle Hidden
            
            # Active Setup (for user profile initialization)
            $activeSetupReg = "HKLM:\Software\Microsoft\Active Setup\Installed Components\VLCUserConfig"
            New-Item -Path $activeSetupReg -Force | Out-Null
            Set-ItemProperty -Path $activeSetupReg -Name "StubPath" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$env:ProgramFiles\VLC\ConfigureUser.ps1`""
            Set-ItemProperty -Path $activeSetupReg -Name "Version" -Value "1,0"

            Show-InstallationPrompt -Message "$appName $appVersion has been installed successfully." -ButtonRightText "OK"
        }

        "Uninstall" {
            Show-InstallationWelcome -CloseApps "vlc" -Silent
            Show-ProgressDialog -Message "Uninstalling $appName..."

            # Get package full name and uninstall
            $pkg = (Get-AppxPackage | Where-Object { $_.Name -like "*VLC*" }).PackageFullName
            If ($pkg) {
                Execute-Process -Path "powershell.exe" -Parameters "Remove-AppxPackage -Package `"$pkg`"" -WindowStyle Hidden
            }

            # Clean Active Setup
            Remove-Item -Path "HKLM:\Software\Microsoft\Active Setup\Installed Components\VLCUserConfig" -Recurse -Force -ErrorAction SilentlyContinue
            
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
