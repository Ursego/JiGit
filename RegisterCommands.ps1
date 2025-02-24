###################################################################################################################################################
# This script makes the Git Automation commands available by registering them in your PowerShell profile file.
# If the PowerShell profile file doesn't exist, the script creates it.
# To execute the script, run the next command in PowerShell (change C:\GIT_SCRIPTS to your actual path):
# powershell.exe -ExecutionPolicy Bypass -File "C:\GIT_SCRIPTS\RegisterCommands.ps1"
# REMARK: to see the contents of the PowerShell profile file, run:
# notepad $PROFILE
###################################################################################################################################################

try {
    [bool] $profileFileExists = (Test-Path -Path $PROFILE)
    if (-not $profileFileExists) {
        [string] $profileFolder = Split-Path -Path $PROFILE -Parent
        [bool] $profileFolderExists = (Test-Path -Path $profileFolder)
        if (-not $profileFolderExists) {
            Write-Host "Creating the profile folder..." -ForegroundColor Green
            New-Item -ItemType Directory -Path $profileFolder -Force | Out-Null
        }
        Write-Host "Creating the profile file..." -ForegroundColor Green
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }

    [string] $fragment = ". `"$PSScriptRoot\Commands.ps1`""
    Write-Host "Checking if the commands are already registered in the profile file..." -ForegroundColor Green
    [string] $profileFileContent = Get-Content -Path $PROFILE -Raw
    [bool] $fragmentAlreadyInProfile = ($profileFileContent -match [regex]::Escape($fragment))
    if ($fragmentAlreadyInProfile) {
        Write-Host "SUCCESS! The 'c', 'b', 'd' and 's' commands are already registered and available." -ForegroundColor Green
        return
    }

    Write-Host "Not registered, so registering them now..." -ForegroundColor Green
    Add-Content -Path $PROFILE -Value $fragment
    Write-Host "SUCCESS! The 'c', 'b', 'd' and 's' commands are registered. They will be available after restarting PowerShell." -ForegroundColor Green
}
catch {
    Write-Host "An error occurred:`r`n$($_.Exception.Message)" -ForegroundColor Red
}