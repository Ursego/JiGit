###################################################################################################################################################
# This script makes the 'c', 'b' and 'd' commands available by registering them in your PowerShell profile file.
# You can obtain that file's path by running $PROFILE in PowerShell.
# If the file doesn't exist, the script creates it.
# To run the script, paste its full path to PowerShell and press Enter.
###################################################################################################################################################

try {
    $profileFileExists = (Test-Path -Path $PROFILE)
    if (-not $profileFileExists) {
        $profileFolder = Split-Path -Path $PROFILE -Parent
        $profileFolderExists = (Test-Path -Path $profileFolder)
        if (-not $profileFolderExists) {
            New-Item -ItemType Directory -Path $profileFolder -Force | Out-Null
        }
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }

    $profileFileContent = Get-Content -Path $PROFILE -Raw
    $fragment = ". $PSScriptRoot\Commands.ps1"
    $fragmentAlreadyInProfile = ($profileFileContent -match [regex]::Escape($fragment))
    if ($fragmentAlreadyInProfile) {
        Write-Host "SUCCESS! The 'c', 'b' and 'd' commands are available."
        return
    }

    Add-Content -Path $PROFILE -Value $fragment
    
    # Load Commands.ps1 to make the commands available in the current session:
    #. $PSScriptRoot\Commands.ps1 <<< doesn't work for some reason
    # Write-Host "SUCCESS! The 'c', 'b' and 'd' commands are available."

    $prompt = "SUCCESS! The 'c', 'b' and 'd' commands will be available after you restart PowerShell.`r`nDo you want to restart now? Enter y or n"
    $userAnswer = Read-Host $prompt
    if ($userAnswer.ToLower() -eq 'y') {
        $currentProcessID = $PID
        $commandString = "`$currentProcessID = $currentProcessID; while (Get-Process -Id `$currentProcessID -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 1 }; Start-Process powershell -ArgumentList '-NoExit'"
        # Start a new PowerShell process that waits for the current one to closed:
        Start-Process -FilePath "powershell" -ArgumentList "-Command $commandString"
        # Close the current PowerShell window:
        Stop-Process -Id $currentProcessID
    }
}
catch {
    Write-Host "An error occurred:`r`n$($_.Exception.Message)" -ForegroundColor Red
}