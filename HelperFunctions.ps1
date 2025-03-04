###################################################################################################################################################
# Auxiliary functions serving Commands.ps1
###################################################################################################################################################
# Developer: Michael Zuskin https://www.linkedin.com/in/zuskin/
# This project on GitHub: https://github.com/Ursego/JiGit
###################################################################################################################################################
using namespace System.Windows.Forms

Add-Type -AssemblyName System.Windows.Forms

[string] $DECOR_LINE = "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
[string] $SILENTLY_HALT = "SILENTLY_HALT"
[string] $ENV_VAR__TICKET_TYPE = "TYPE"
[string] $ENV_VAR__TICKET_TITLE = "TITLE"
[string] $SETTINGS_FILE = "${PSScriptRoot}\Settings.ps1"
[string] $OPEN_SETTINGS_FILE_MSG = "`nYou can open the Settings file (${SETTINGS_FILE}) by running the 's' command."

if (Test-Path -Path $SETTINGS_FILE) {
    . "${SETTINGS_FILE}"
} else {
    Write-Host "The file ${SETTINGS_FILE} is not found.`nTo use the Git Automation commands, restore the file and restart PowerShell.`n" -ForegroundColor Red
}

###################################################################################################################################################
# Validation functions:
###################################################################################################################################################

function ValidateCreate ([string] $ticket, [string[]] $rels) {
    ValidateRelsCsv

    [string[]] $fixVersions = GetFixVersions $ticket
    [string]   $relsNlsv = ArrayToNlsv $rels
    [string]   $es = if ($rels.Count -gt 1) { "es" } else { "" }
    
    switch ($fixVersions.Count) {
        $rels.Count { $msg = $null } # success
        0                   { $msg = "The ticket's 'Fix Version/s' field is empty." }
        default             { $msg = "The ticket's 'Fix Version/s':`n`n$(ArrayToNlsv $fixVersions)."
                              $msg += "`n`nIt seems like you need to create $($fixVersions.Count) branch"
                              $msg += if ($fixVersions.Count -gt 1) { "es." } else { "." }
        }
    }

    $msg += if (IsPopulated $msg) {
        "`n`nHowever, you requested to create $($rels.Count) branch${es}:" +
        "`n`n${relsNlsv}" +
        "`n`nDo you want to continue?"
    } else {
        "Looks good, $($rels.Count) branch${es} will be created under:" +
        "`n`n${relsNlsv}" +
        "`n`n$($rels.Count) is the correct NUMBER according to the ticket's 'Fix Version/s'." +
        "`n`nHowever, you might want to make sure that you are creating the CORRECT branch${es} by reviewing the 'Fix Version/s':" +
        "`n`n$(ArrayToNlsv $fixVersions)." +
        "`n`nDo you want to continue?"
    }

    if (UserRepliedNo $msg "Creating branch${es} for ${ticket} in $($WORKING_REPO.ToUpper())...") {
        Clear-Host
        PrintMsg "The creation of branch${es} for ${ticket} is aborted.`n"
        OpenSettingsFile
        throw $SILENTLY_HALT
    }
} # ValidateCreate

function ValidateBackport ([string] $ticket, [string] $commitHash, [string[]] $backportRels) {
    ValidateRelsCsv

    if ($commitHash -notmatch '^[0-9a-fA-F]{7,40}$') {
        throw "'${commitHash}' is a wrong commit hash.`nIt must be a 7 to 40 digits long hexadecimal number."
    }

    if (-not (BackportRelExistsInSettings)) {
        throw "The RELS_CSV constant in the Settings file has no backport releases.`n${OPEN_SETTINGS_FILE_MSG}`n`n" +
                "Add the backport release(s) to RELS_CSV, and re-run the backport:`n`n" +
                "b ${ticket} ${commitHash}"
    }

    [string[]] $fixVersions = GetFixVersions $ticket
    [int]      $backportFixVersionsCount = $fixVersions.Count - 1 # supposing one is the DEV release
    [string]   $backportRelsNlsv = ArrayToNlsv $backportRels
    [string]   $backportRelsPluralEnding = if ($backportRels.Count -gt 1) { "s" } else { "" }
    [string]   $msg
    
    # Confirmation dialog to review the backports releases:
    switch ($backportFixVersionsCount) {
        $backportRels.Count { $msg = $null } # success
        -1                  { $msg = "The ticket's 'Fix Version/s' field is empty." }
        default             { $msg = "The ticket's 'Fix Version/s':`n`n$(ArrayToNlsv $fixVersions)."
                              $msg += "`n`nSupposing one of them is DEV, it seems like you need to backport into ${backportFixVersionsCount} release"
                              $msg += if ($backportFixVersionsCount -gt 1) { "s." } else { "." }
        }
    }
    $msg += if (IsPopulated $msg) {
        "`n`nHowever, you requested to backport into $($backportRels.Count) release${backportRelsPluralEnding}:" +
        "`n`n${backportRelsNlsv}" +
        "`n`nDo you want to continue?"
    } else {
        "Looks good, you are backporting into $($backportRels.Count) release${backportRelsPluralEnding}:" +
        "`n`n${backportRelsNlsv}" +
        "`n`n$($backportRels.Count) is the correct NUMBER according to the ticket's 'Fix Version/s'." +
        "`n`nHowever, you might want to make sure that you are backporting into the CORRECT release${backportRelsPluralEnding}." +
        "`n`n'Fix Version/s' (incluiding DEV):" +
        "`n`n$(ArrayToNlsv $fixVersions)." +
        "`n`nDo you want to continue?"
    }
    Clear-Host
    if (UserRepliedNo $msg "Check the backport releases of ${ticket} in $($WORKING_REPO.ToUpper())") {
        Clear-Host
        PrintMsg "The backport of ${ticket} is aborted.`n"
        OpenSettingsFile
        throw $SILENTLY_HALT
    }

    Clear-Host
    PrintMsg "####### BACKPORTING COMMIT ${commitHash} #######`n"

    EnsureBackportBranchesExistence $ticket
} # ValidateBackport

function EnsureBackportBranchesExistence ([string] $ticket) { # validate existence of all the backport feature branches on both LOCALS and REMOTES, and create any which is missing somewhere
    [string] $devRel = GetDevRel
    [string] $devBranch = BuildBranchName $ticket $devRel

    [string[]] $localCreatedBranches = GetLocalCreatedBranches $ticket
    [string[]] $localCreatedBackportBranches = RemoveValueFromArray $devBranch $localCreatedBranches

    [string[]] $remoteCreatedBranches = GetRemoteCreatedBranches $ticket
    [string[]] $remoteCreatedBackportBranches = RemoveValueFromArray $devBranch $remoteCreatedBranches

    [string[]] $backportRels = GetBackportRelsFromSettings
    foreach ($backportRel in $backportRels) {
        $backportBranch = BuildBranchName $ticket $backportRel

        $existsLocally = ArrayContainsValue $localCreatedBackportBranches $backportBranch
        $existsRemotely = ArrayContainsValue $remoteCreatedBackportBranches $backportBranch

        if (-not ($existsLocally -or $existsRemotely)) {
            PrintMsg "`n${backportBranch} doesn't exist."
            CreateLocalBranch $backportBranch $backportRel
            PublishBranch $backportBranch
        } elseif ((-not $existsLocally) -and $existsRemotely) {
            PrintMsg "`n${backportBranch} is not synchronized."
            RecreateLocalBranchFromRemotes $backportBranch
        } elseif ($existsLocally -and (-not $existsRemotely)) {
            PrintMsg "`n${backportBranch} is not synchronized.`n   It exists on LOCALS but was deleted from REMOTES."
            PublishBranch $backportBranch
        }
    }
} # EnsureBackportBranchesExistence

function ValidateDelete ([string] $ticket) {
    [string] $msg = if (-not (AtLeastOneBranchIsCreatedFor $ticket)) {
        "No branches exist for ${ticket}, nothing to delete.`n"
    } elseif ($CONFIRM_DELETING_BRANCHES -and (UserRepliedNo "Are you sure you want to delete all the feature branches of ${ticket}?")) {
        "The deletion of ${ticket} branches is aborted.`n"
    } else {
        $null
    }
    
    if ($msg) {
        Clear-Host
        PrintMsg $msg
        throw $SILENTLY_HALT
    }
} # ValidateDelete

function ValidateRelsCsv {
    if ($RELS_CSV -match '(^|,)\s*(,|$)') {
        throw "Each release in the RELS_CSV constant must be non-empty.${OPEN_SETTINGS_FILE_MSG}"
    }
} # ValidateRelsCsv

function ValidateSettings {
    [string[]] $constants = @('TICKETS_FOLDER_PATH', 'CONFIRM_DELETING_BRANCHES', 'CREATE_BACKPORT_PRS',
                                'RELS_CSV', 'GIT_FOLDER_PATH', 'WORKING_REPO', 'REPOS_TO_REFRESH_CSV', 'REMOTE_GIT_REPO_URL',
                                'DEFAULT_TICKET_PREFIX', 'DIGITS_IN_TICKET_NUM', 'JIRA_URL', 'JIRA_PAT', 'DEVELOPER')
    [string[]] $optionals = @('TICKETS_FOLDER_PATH', 'DEFAULT_TICKET_PREFIX', 'REPOS_TO_REFRESH_CSV')
    
    . "${SETTINGS_FILE}" # pick the latest settings (the user could change them during the current session)
    
    foreach ($constant in $constants) {
        try {
            $constantVal = Get-Variable -Name $constant -ValueOnly -ErrorAction Stop
        } catch {
            throw "Declare the ${constant} constant.${OPEN_SETTINGS_FILE_MSG}" # The error: "Cannot find a variable with the name '...'"
        }
        if ((IsEmpty $constantVal) -and -not ($optionals -contains $constant)) {
            throw "Populate the ${constant} mandatory constant.${OPEN_SETTINGS_FILE_MSG}"
        }
    }
} # ValidateSettings

###################################################################################################################################################
# Branches creation functions:
###################################################################################################################################################

function CreateLocalBranch ([string] $newBranch, [string] $rel) {
    PrintMsg "   Creating on LOCALS..."
    [string] $gitResult = git branch $newBranch $rel 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($gitResult.Contains("not a valid object name")) {
            PrintMsg "      '$rel' is not recognized on LOCALS. It could be a new release just added to the project. Downloading it..."
            [string] $gitResult = git branch $rel "origin/${rel}" 2>&1
            if ($LASTEXITCODE -ne 0) {
                if ($gitResult.Contains("not a valid object name")) {
                    PrintMsg "      '$rel' is not recognized on REMOTES too."
                    $gitResult = "'$rel' doesn't exist. Check its spelling in the RELS_CSV constant in ${SETTINGS_FILE}.`n"
                }
            } else {
                PrintMsg "      '$rel' is downloaded, creating the branch on LOCALS..."
                [string] $gitResult = git branch $newBranch $rel 2>&1
                if ($LASTEXITCODE -eq 0) { $gitResult = $null } # on success, don't throw an error
            }
        }
        if ($gitResult) { throw "Cannot create $newBranch on LOCALS.`n`n${gitResult}" }
    }
    PrintMsg "      Successfully created."
} # CreateLocalBranch

function RecreateLocalBranchFromRemotes ([string] $branch) {
    PrintMsg "   It exists on REMOTES but was deleted from LOCALS. Re-creating it on LOCALS from REMOTES..."
    # Restore the missing local branch to point exactly where the remote branch is:
    [string] $gitResult = git branch --track $branch "origin/${branch}" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "${branch} was deleted on LOCALS. The script tried to re-create it on LOCALS from REMOTES but unsuccessfully:`n${gitResult}"
    }
    PrintMsg "      Successfully re-created."
} # RestoreLocalBranchFromRemote

function PublishBranch ([string] $branch) {
    PrintMsg "   Publishing to REMOTES..."
    [string] $gitResult = git push -u origin $branch 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot publish $backportBranch.`n`n${gitResult}"
    }
    PrintMsg "      Successfully published."
} # PublishBranch

###################################################################################################################################################
# Functions to return releases & branches info:
###################################################################################################################################################

function GetDevRel () {
    return $RELS_CSV -split ',' | Select-Object -First 1
} # GetDevRel

function BackportRelExistsInSettings () {
    return ($RELS_CSV.IndexOf(',') -gt 0)
} # BackportRelExistsInSettings

function GetBackportRelsFromSettings () {
    if (-not (BackportRelExistsInSettings)) { return @() }
    return CsvToArray $RELS_CSV.Substring($RELS_CSV.IndexOf(',') + 1)
} # GetBackportRelsFromSettings

function GetLocalCreatedBranches ([string] $ticket) {
    [string[]] $localCreatedBranches = git branch -l --list "${$DEVELOPER}*${ticket}*" | ForEach-Object {
        # Each returned branch name starts with "  " (if checked-out, then with "* "): "  Rel1", "* Rel2", "  Rel3"
        $_.Trim("*").Trim() # ==>> "Rel1", "Rel2", "Rel3"
    }
    if (-not $localCreatedBranches) { $localCreatedBranches = @() }
    return $localCreatedBranches
} # GetLocalCreatedBranches

function GetRemoteCreatedBranches ([string] $ticket) {
    PrintMsg "Fetching $($WORKING_REPO.ToUpper())..."
    [string] $gitResult = git fetch --prune 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Fetching $($WORKING_REPO.ToUpper()) failed:`n${gitResult}"
    }

    [string[]] $remoteCreatedBranches = git branch -r --list "${$DEVELOPER}*${ticket}*" | ForEach-Object {
        # Each returned branch name starts with "  origin/": "  origin/Rel1", "  origin/Rel2", "  origin/Rel3"
        $_.Trim("  origin/") # ==>> "Rel1", "Rel2", "Rel3"
    }
    if (-not $remoteCreatedBranches) { $remoteCreatedBranches = @() }
    return $remoteCreatedBranches
} # GetRemoteCreatedBranches

function AtLeastOneBranchIsCreatedFor ([string] $ticket) {
    return (EnvVarExists $ticket $ENV_VAR__TICKET_TYPE)
} # AtLeastOneBranchIsCreatedFor

function ExtractRelFromBranch ([string] $branch) {
    [int]    $firstSlashIndex = $branch.IndexOf('/') + 1
    [int]    $lastSlashIndex = $branch.LastIndexOf('/')
    [int]    $beforeLastSlashIndex = $branch.LastIndexOf('/', $lastSlashIndex - 1)
    [string] $rel = $branch.Substring($firstSlashIndex, $beforeLastSlashIndex - $firstSlashIndex)
    return $rel
} # ExtractRelFromBranch

###################################################################################################################################################
# Jira integration functions:
###################################################################################################################################################

function InvokeJiraApi ([string] $ticket) {
    [string] $jiraApiUrl = "${JIRA_URL}/rest/agile/latest/issue/${ticket}"
    $headers = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $headers["Authorization"] = "Bearer ${JIRA_PAT}"
    try {
        [PSCustomObject] $jiraResponse = Invoke-RestMethod -Uri $jiraApiUrl -Method Get -Headers $headers 2>&1
    } catch {
        [string] $err = $_.Exception.Message
        switch ($_.Exception.Response.StatusCode.value__) {
            404 { $err = "Ticket '${ticket}' doesn't exist." } # "Not Found"
            401 { $err = "Wrong Jira PAT.`nFix the JIRA_PAT constant.${OPEN_SETTINGS_FILE_MSG}" } # "Unauthorized"
        }
        throw $err
    }
    return $jiraResponse
} # InvokeJiraApi

function PopulateEnvVarsFromJira ([string] $ticket) {
    [bool] $alreadyRetrieved = (atLeastOneBranchIsCreatedFor $ticket)
    if ($alreadyRetrieved) { return }
    PrintMsg "Getting ticket's info from Jira..."
    [PSCustomObject] $jiraResponse = InvokeJiraApi $ticket
    [string] $ticketType = ($jiraResponse.fields.issuetype.name -replace ' ', '').ToLower() # "Contract Modification" > "contractmodification"
    if (IsEmpty $ticketType) { throw "The 'Type' field is empty in ${ticket}." }
    SetEnvVar $ticket $ENV_VAR__TICKET_TYPE $ticketType
    SetEnvVar $ticket $ENV_VAR__TICKET_TITLE $jiraResponse.fields.summary
    # To find a Jira field name, go to https://tylerjira.tylertech.com/rest/agile/latest/issue/CLT-78487 and find the field by its contents.
} # PopulateEnvVarsFromJira

function BuildBranchName ([string] $ticket, [string] $rel) {
    PopulateEnvVarsFromJira $ticket
    $ticketType = GetEnvVar $ticket $ENV_VAR__TICKET_TYPE
    return "${DEVELOPER}/${rel}/${ticketType}/${ticket}"
} # BuildBranchName

function GetTicketTitle ([string] $ticket) {
    PopulateEnvVarsFromJira $ticket
    return GetEnvVar $ticket $ENV_VAR__TICKET_TITLE
} # GetTicketTitle

function GetFixVersions ([string] $ticket) {
    # Returns the ticket's 'Fix Version/s' as an array. It uses their Descriptions which pop up when you are hooviring (they are more informative and often contain the release name).
    # The Fix Version/s are not stored in an env var since the validations must get the freshest version - the field could change after 'c' called PopulateEnvVarsFromJira (through BuildBranchName).
    PrintMsg "Getting ticket's Fix Version/s from Jira...`n"
    [PSCustomObject] $jiraResponse = InvokeJiraApi $ticket
    [string[]] $fixVersions = $jiraResponse.fields.fixVersions | ForEach-Object { $_.description }
    if (-not $fixVersions) { $fixVersions = @() } 
    return $fixVersions
} # GetFixVersions

###################################################################################################################################################
# Messages functions:
###################################################################################################################################################

function PrintMsg ([string] $msg) {
    Write-Host $msg -ForegroundColor Green # to distinguish from white Git output
} # PrintMsg

function PrintSuccessMsg ([string] $msg) {
    PrintMsg "`n${DECOR_LINE}`n${msg}`n${DECOR_LINE}`n"
} # PrintSuccessMsg

# function PrintSuccessMsg ([string] $msg) {
#     Write-Host "`n${DECOR_LINE}`n${msg}`n${DECOR_LINE}`n" -ForegroundColor Green
# } # PrintSuccessMsg

function PrintErrorMsg ([string] $msg) {
    Write-Host "`n${DECOR_LINE}`n${msg}`nThe operation is aborted.`n${DECOR_LINE}`n" -ForegroundColor Red
} # PrintErrorMsg

function UserRepliedYes ([string] $msg, [string] $title = "Confirm") {
    PrintMsg "A dialog box is displayed.`nIf you don't see it:`n* Look at other monitors.`n* Move this PowerShell window to a side.`n* Minimize all windows by pressing 'Windows Key + M'.`n"
    [DialogResult] $userReply = [MessageBox]::Show(
        $msg,
        $title,
        [MessageBoxButtons]::YesNo,
        [MessageBoxIcon]::Question
        #[MessageBoxDefaultButton]::Button2 # commented out since in some messages the safe option is Yes
    )
    return ($userReply -eq [DialogResult]::Yes)
} # UserRepliedYes

function UserRepliedNo ([string] $msg, [string] $title = "Confirm") {
    return (-not (UserRepliedYes $msg $title))
} # UserRepliedNo

# function DisplayPopup ([string] $msg, [string] $title) {
#     [MessageBox]::Show($msg, $title) > $null # > $null avoids printing the clicked button's text to the terminal
# } # DisplayPopup

###################################################################################################################################################
# Parameters manipulation functions:
###################################################################################################################################################

function AcceptFromUserIfNotProvided ([string] $val, [string] $prompt) {
    if (IsEmpty $val) {
        $val = Read-Host $prompt
        if (IsEmpty $val) {
            PrintMsg "`nNo value entered. The operation is aborted.`n"
            throw $SILENTLY_HALT
        }
    }
    return $val
} # AcceptFromUserIfNotProvided

function AddPrefixIfNotProvided ([string] $ticket) {
    if ($ticket.Contains(" ")) { throw "Pass a single ticket, not a comma-separated list." }
    [bool] $prefixIsProvided = $ticket.Contains("-")
    if ($prefixIsProvided) { # like "ABC-11111"
        $ticket = $ticket.ToUpper()
        if (-not ($ticket -match "^[A-Z]+-\d{${DIGITS_IN_TICKET_NUM}}$")) {
            throw "'${ticket}' is a wrong ticket name. It must consist of an alphabetic prefix and a ${DIGITS_IN_TICKET_NUM}-digits number divided by a dash."
        }
    } else { # like "11111"
        if (-not ($ticket -match "^\d{${DIGITS_IN_TICKET_NUM}}$")) {
            throw "'${ticket}' is a wrong ticket number. It must consist of ${DIGITS_IN_TICKET_NUM} digits."
        }
        if (IsEmpty $DEFAULT_TICKET_PREFIX) {
            throw "'${ticket}' is a wrong ticket name.`n" +
                    "It must start with an alphabetic prefix and a dash.`n" +
                    "To add the ability to pass the digits alone, populate`n" +
                    "the DEFAULT_TICKET_PREFIX constant.${OPEN_SETTINGS_FILE_MSG}"
        }
        $ticket = "${DEFAULT_TICKET_PREFIX}-${ticket}"
    }
    return $ticket
} # AddPrefixIfNotProvided

###################################################################################################################################################
# String checking functions:
###################################################################################################################################################

function IsEmpty ([string] $val) {
    return ([string]::IsNullOrWhiteSpace($val))
} # IsEmpty

function IsPopulated ([string] $val) {
    return (-not (IsEmpty $val))
} # IsPopulated

###################################################################################################################################################
# Array manipulation functions:
###################################################################################################################################################

function ArrayToCsv ([string[]] $array) { # CSV - comma separated values
    return ($array -join ",")
} # ArrayToCsv

function ArrayToNlsv ([string[]] $array) { # NLSV - new-line separated values
    [string] $BULLET = [char]0x2022
    return ($array | ForEach-Object { "${BULLET} ${_}" }) -join "`n"
} # ArrayToNlsv

function CsvToArray ([string] $csv) {
    if (IsEmpty $csv) { return @() }
    $csv = $csv -replace ' ', ''
    $csv = $csv.Trim(',')
    return @($csv -split ',' -ne '')
} # CsvToArray

function ArrayContainsValue ([string[]] $array, [string] $value) { # same as the -contains operator but checks is the array is instantiated, otherwise -contains fails
    if (-not $array) { return $false }
    return ($array -contains $value)
} # ArrayContainsValue

function RemoveValueFromArray ([string] $value, [string[]] $array) { #  returns the same array but without the element which contains $value
    if (-not $array -or $array.Count -eq 0) { return @() }
    
    $index = $array.IndexOf($array -match "^$([regex]::Escape($value))$")
    if ($index -ge 0) {
        $array = $array[0..($index-1)] + $array[($index+1)..($array.Length-1)]
    }
    
    if (-not $array -or $array.Count -eq 0) {
        $array = @()
    }
    
    return $array
} # RemoveValueFromArray

###################################################################################################################################################
# Environment variables functions:
###################################################################################################################################################

# REMARKS:
#   'c' gets the ticket data from Jira when creating the first branch, and saves it in env vars to re-use by all next BuildBranchName calls.
#   'd' cleans up all the env vars of the ticket after deleting the branches.

function BuildEnvVarName ([string] $ticket, [string] $key) {
    return "${ticket}-${key}"
} # BuildEnvVarName

function SetEnvVar ([string] $ticket, [string] $key, [string] $value) {
    [string] $envVarName = BuildEnvVarName $ticket $key
    # Set the var, making it persistent across sessions and reboots:
    [System.Environment]::SetEnvironmentVariable($envVarName, $value, [System.EnvironmentVariableTarget]::User)
    # Set the var for the current session so it's immediately available:
    Set-Item -Path "env:${envVarName}" -Value $value
} # SetEnvVar

function GetEnvVar ([string] $ticket, [string] $key) {
    [string] $envVarName = BuildEnvVarName $ticket $key
    return [System.Environment]::GetEnvironmentVariable($envVarName, [System.EnvironmentVariableTarget]::User)
} # GetEnvVar

function EnvVarExists ([string] $ticket, [string] $key) { # reports if an env var with the given name exists
    [string] $envVarName = BuildEnvVarName $ticket $key
    $dataType = Get-ChildItem Env: | Where-Object { $_.Name -eq $envVarName } # returns "System.Collections.DictionaryEntry" if the var exists
    return ($null -ne $dataType)
} # EnvVarExists

function CleanUpEnvVars ([string] $ticket) {
    Get-ChildItem env: | Where-Object { $_.Name -like "${$DEVELOPER}*${ticket}*" } | ForEach-Object {
	    # Remove the var, making the change persistent across sessions and reboots:
        [System.Environment]::SetEnvironmentVariable($_.Name, $null, [System.EnvironmentVariableTarget]::User)
        # Remove the var from the current session:
        Remove-Item -Path "env:$($_.Name)" -ErrorAction SilentlyContinue
    }
} # CleanUpEnvVars

function v ([string] $ticket) { # shows all env vars which currently exist for the ticket. FOR DEBUG ONLY!
    Get-ChildItem env: | Where-Object { $_.Name -like "${$DEVELOPER}*${ticket}*" } | ForEach-Object {
        PrintMsg "$($_.Name) = '$($_.Value)'"
    }
} # v

###################################################################################################################################################
# Repo functions:
###################################################################################################################################################

function SwitchToRepo ([string] $repo) {
    Set-Location "${GIT_FOLDER_PATH}\${repo}" -ErrorAction Stop
} # SwitchToRepo

function SwitchToWorkingRepo {
    SwitchToRepo $WORKING_REPO
} # SwitchToWorkingRepo

function RefreshRepos ([string] $command, [bool] $atLeastOneBranchAffected) { # $command: either "c" or "d"
    if (-not $atLeastOneBranchAffected) { return }
    [string] $fetchPurpose = if ($command -eq "c") { "download the new branches info" } else { "prune the remote/ pointers to the deleted branches" }

    [string[]] $reposToRefresh = (CsvToArray $REPOS_TO_REFRESH_CSV)
    if ($WORKING_REPO -notin $reposToRefresh) {
        $reposToRefresh += $WORKING_REPO
    }
    
    foreach ($repo in $reposToRefresh) {
        PrintMsg "`nFetching $($repo.ToUpper()) to ${fetchPurpose}..."
        SwitchToRepo $repo
        if ($command -eq "c") { git fetch origin } else { git fetch --prune }
        # Don't check $LASTEXITCODE. Even if the fetch failed, it's because of an unrelated issue - the remote pointers are downloaded/pruned.
    }
} # RefreshRepos

###################################################################################################################################################
# Misc functions:
###################################################################################################################################################

function BuildPrCreationUrl ([string] $rel, [string] $featBranch) {
    return "${REMOTE_GIT_REPO_URL}/compare/${rel}...${featBranch}?expand=1"
} # BuildPrCreationUrl

function OpenSettingsFile () {
    Start-Process -FilePath $SETTINGS_FILE
} # OpenSettingsFile

function CreateTicketFolder ([string] $ticket, [string] $branch) {
    if (IsEmpty $TICKETS_FOLDER_PATH) { return }

    [string] $templateFolderPath = "${TICKETS_FOLDER_PATH}\XXXXX"
    [bool]   $templateFolderExists = Test-Path -Path $templateFolderPath -PathType Container
    if (-not $templateFolderExists) {
        # ...then create it:
        New-Item -Path $templateFolderPath -ItemType Directory -Force | Out-Null

        # Also, create the XXXXX.txt file within it:
        [string] $fileContent = "_TICKET_NAME_ _TICKET_TITLE_`n" +
                                "Hi <write the tester name here>, ${JIRA_URL}/browse/_TICKET_NAME_ is ready for peer review.`n" +
                                "_DEV_PR_CREATION_URL_"
        Set-Content -Path "${templateFolderPath}\XXXXX.txt" -Value $fileContent
        
        [string] $msg = "The ${templateFolderPath} folder is created.`n" +
                        "It will be used as a template when the working folder is createed for a new ticket.`n" +
                        "You can add files and subfolders to it, they will be cloned too.`n`n" +
                        "The folder contains the XXXXX.txt template file.`n" +
                        "Change its content to fit to your needs.`n`n" +
                        "This message will not be displayed again."
        PrintSuccessMsg $msg
    }

    [string] $ticketTitle = GetTicketTitle $ticket
    [string] $ticketTitleClean = $ticketTitle -replace '[][\\\/:*?"<>|]', '' # remove symbols prohibited in folders & files names (square brackets are allowed but make troubles with PS commands)
    $ticketTitleClean = $ticketTitleClean -replace '\s{2,}', ' ' # if there are two or more spaces in a row, replace them with one space
    [string] $ticketFolderPath = "${TICKETS_FOLDER_PATH}\${ticket} ${ticketTitleClean}"
    [bool]   $ticketFolderExists = Test-Path -Path $ticketFolderPath -PathType Container
    if ($ticketFolderExists) { return }

    # Clone the XXXXX template folder for this ticket:
    Copy-Item -Path $templateFolderPath -Destination $ticketFolderPath -Recurse -ErrorAction Stop

    # Rename XXXXX.txt in the new folder:
    [string] $ticketFileName = "${ticket} ${ticketTitleClean}.txt"
    Rename-Item -Path "${ticketFolderPath}\XXXXX.txt" -NewName $ticketFileName

    # In that txt file, substitute the placeholders with the actual values:
    [string] $filePath = Join-Path -Path $ticketFolderPath -ChildPath $ticketFileName
    [string] $fileContent = Get-Content $filePath -Raw
    [string] $devRel = GetDevRel
    [string] $devPrCreationUrl = BuildPrCreationUrl $devRel $branch
    $fileContent = $fileContent -replace '_TICKET_NAME_', $ticket
    $fileContent = $fileContent -replace '_TICKET_TITLE_', $ticketTitle
    $fileContent = $fileContent -replace '_DEV_PR_CREATION_URL_', $devPrCreationUrl

    Set-Content $filePath -Value $fileContent
} # CreateTicketFolder
