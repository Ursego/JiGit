using namespace System.Windows.Forms

Add-Type -AssemblyName System.Windows.Forms

[string] $DECORATIVE_LINE = "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
[string] $SILENTLY_HALT = "SILENTLY_HALT"
[string] $TICKET_TYPE = "TYPE"
[string] $TICKET_TITLE = "TITLE"
[string] $SETTINGS_FILE = "${PSScriptRoot}\Settings.ps1"

. "${SETTINGS_FILE}"

###################################################################################################################################################
# Functions to get releases & branches:
###################################################################################################################################################

function GetDefaultBackportRels () {
    return CsvToArray $DEFAULT_BACKPORT_RELS_CSV
} # GetDefaultBackportRels

function GetAllRelsFromSettings {
    [string[]] $allRelsFromSettings = @()
    if (IsPopulated $DEV_REL) {
        $allRelsFromSettings = @($DEV_REL)
    }
    if (IsPopulated $DEFAULT_BACKPORT_RELS_CSV) {
        $allRelsFromSettings += GetDefaultBackportRels
    }
    return $allRelsFromSettings
} # GetAllRelsFromSettings

function GetLocalCreatedBranches ([string] $ticket) {
    [string[]] $localCreatedBranches = git branch -l --list "${$DEVELOPER}*${ticket}*" | ForEach-Object {
        # Each returned branch name starts with "  " (if checked-out, then with "* "): "  Rel1", "* Rel2", "  Rel3"
        $_.Trim("*").Trim() # ==>> "Rel1", "Rel2", "Rel3"
    }
    if (-not $localCreatedBranches) { $localCreatedBranches = @() }
    return $localCreatedBranches
} # GetLocalCreatedBranches

function GetRemoteCreatedBranches ([string] $ticket, [bool] $gitFetch = $true) {
    if ($gitFetch) {
        [string] $msg = "Fetching $($WORKING_REPO.ToUpper()) to download the remote branches latest info"
        PrintMsg "${msg}..."
        [string] $gitResult = git fetch --prune 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "${msg} failed:`n${gitResult}"
        }
    }
    [string[]] $remoteCreatedBranches = git branch -r --list "${$DEVELOPER}*${ticket}*" | ForEach-Object {
        # Each returned branch name starts with "  origin/": "  origin/Rel1", "  origin/Rel2", "  origin/Rel3"
        $_.Trim("  origin/") # ==>> "Rel1", "Rel2", "Rel3"
    }
    if (-not $remoteCreatedBranches) { $remoteCreatedBranches = @() }
    return $remoteCreatedBranches
} # GetRemoteCreatedBranches

function GetCreatedBranches ([string] $ticket) { # call stack: ValidateBackport > GetRelsHavingBranches > GetCreatedBranches
    [string[]] $localCreatedBranches = GetLocalCreatedBranches $ticket
    [string[]] $remoteCreatedBranches = GetRemoteCreatedBranches $ticket
    if ($localCreatedBranches.Count -eq 0 -and $remoteCreatedBranches.Count -eq 0) { return @() }

    [string] $err = 
        if ($remoteCreatedBranches.Count -eq 0) {
            "On REMOTES:`nNo branches exist`n`nOn LOCALS:`n$(ArrayToNlsv $localCreatedBranches)"
        } elseif ($localCreatedBranches.Count -eq 0) {
            "On REMOTES:`n$(ArrayToNlsv $remoteCreatedBranches)`n`nOn LOCALS:`nNo branches exist"
        } elseif (Compare-Object $remoteCreatedBranches $localCreatedBranches) {
            "On REMOTES:`n$(ArrayToNlsv $remoteCreatedBranches)`n`nOn LOCALS:`n$(ArrayToNlsv $localCreatedBranches)"
        } else {
            $null
        }

    if (IsPopulated $err) {
        $err = "Ticket ${ticket} has different sets of feature branches on REMOTES and on LOCALS.`n`n${err}`n`nPlease sync both the sets "
        $err += if (IsPopulated $DEFAULT_BACKPORT_RELS_CSV) {
            "by running this command:`n`nc ${ticket}`n`nIt will publish unpublished local branches and/or re-create deleted local branches.`n"
        } else {
            "in a Git client and/or Jira.`n"
        }
        throw $err
    }

    return $remoteCreatedBranches
} # GetCreatedBranches

function GetRelsHavingBranches ([string] $ticket) {
    [string[]] $createdBranches = GetCreatedBranches $ticket
    if ($createdBranches.Count -eq 0) { return @() }
    [string[]] $relsHavingBranches = $createdBranches | ForEach-Object { ExtractRelFromBranch $_ }
    return $relsHavingBranches
} # GetRelsHavingBranches


function GetAnyRelFromSettings () {
    if (IsPopulated $DEV_REL) { return $DEV_REL }
    [string[]] $defaultBackportRels = GetDefaultBackportRels
    if ($defaultBackportRels.Count -gt 0) { return $defaultBackportRels[0] }
    return ""
} # GetAnyRelFromSettings

function AtLeastOneBranchIsCreatedFor ([string] $ticket) {
    return (EnvVarExists $ticket $TICKET_TYPE)
} # AtLeastOneBranchIsCreatedFor

###################################################################################################################################################
# Validation functions:
###################################################################################################################################################

function ValidateCreate () {
    if ((IsEmpty $DEV_REL) -and (IsEmpty $DEFAULT_BACKPORT_RELS_CSV)) {
        throw "DEV_REL and DEFAULT_BACKPORT_RELS_CSV are empty.`nAt lease one of them is required to create a branch."
    }
    
    [string] $msg
    if (IsEmpty $DEV_REL) {
        $msg = "DEV_REL is empty.`n`n"
        if (IsPopulated $TICKETS_FOLDER_PATH) {
            $msg += "So, the ticket folder will NOT be created.`n" +
                    "If you want it, click No and move at least one release`n" +
                    "from DEFAULT_BACKPORT_RELS_CSV to DEV_REL.`n`n"
        }
        $msg += "Do you want to continue and create "
        $msg += if ($DEFAULT_BACKPORT_RELS_CSV -match ",") {
            "branches only for the next releases?`n`n$(ArrayToNlsv (GetDefaultBackportRels))"
        } else {
            "a branch only for ${DEFAULT_BACKPORT_RELS_CSV}?"
        }
    } elseif (IsEmpty $DEFAULT_BACKPORT_RELS_CSV) {
        $msg = "DEFAULT_BACKPORT_RELS_CSV is empty.`n`nDo you want to continue and create only the DEV branch (under ${DEV_REL})?"
    }
    if ((IsPopulated $msg) -and (UserRepliedNo $msg)) {
        PrintMsg "`nThe branches creation is aborted.`n"
        throw $SILENTLY_HALT
    }
} # ValidateCreate

function ValidateBackport ([string] $ticket, [string] $commitHash, [string[]] $backportRels, [bool] $backportRelsArePassedAsParam) {
    function LetUserConfirm ($msg) {
        if (IsEmpty $msg) { return }
        if (UserRepliedYes $msg "Check the backport releases of ${ticket}") { return }
        PrintMsg "`nThe backport of ${ticket} is aborted.`n"
        throw $SILENTLY_HALT
    }

    if ($commitHash -notmatch '^[0-9a-fA-F]{7,40}$') {
        throw "'${commitHash}' is a wrong commit hash.`nIt must be a 7 to 40 digits long hexadecimal number."
    }
    
    if ((-not $backportRelsArePassedAsParam) -and (IsEmpty $DEFAULT_BACKPORT_RELS_CSV)) {
        throw "DEFAULT_BACKPORT_RELS_CSV is empty.`n`n" +
                "It's required when you don't pass the backport releases as a parameter.`n`n" +
                "Either populate DEFAULT_BACKPORT_RELS_CSV or pass the desired releases, like:`n`n" +
                "b ${ticket} ${commitHash} rel1,rel2,rel3`n"
    }

    [string] $msg # in confirmation messages, blank denotes success ("don't display confirmation box")
    
    # Error message if the ticket has no feature branches at all:
    if (-not (AtLeastOneBranchIsCreatedFor $ticket)) {
        $msg = "${ticket} has no feature branches to backport into."
        if ($backportRelsArePassedAsParam) { $msg += " Make sure you passed a correct ticket number." }
        throw $msg
    }

    # Confirmation message if the user passed a release which is not in $DEFAULT_BACKPORT_RELS_CSV:
    if ($backportRelsArePassedAsParam) {
        [string[]] $backportRelsNotInDefault = $backportRels | Where-Object { $_ -notin (GetDefaultBackportRels) }
        $msg = switch ($backportRelsNotInDefault.Count) {
            0       { $null } # success
            1       { "$($backportRelsNotInDefault[0]) is not in DEFAULT_BACKPORT_RELS_CSV.`n`nAre you sure you want to backport into it?" }
            default { "These releases are not in DEFAULT_BACKPORT_RELS_CSV:`n`n$(ArrayToNlsv $backportRelsNotInDefault)`n`nAre you sure you want to backport into them?" }
        }
        LetUserConfirm $msg
    }

    [string[]] $fixVersions = GetFixVersions $ticket
    [int]      $backportFixVersionsCount = $fixVersions.Count - 1 # supposing one is the DEV release
    [string]   $backportRelsNlsv = ArrayToNlsv $backportRels
    [string]   $pluralEnding = if ($backportRels.Count -gt 1) { "s" } else { "" }
    
    # Confirmation messages to review the backports releases:
    switch ($backportFixVersionsCount) {
        $backportRels.Count { $msg = $null } # success
        -1                  { $msg = "The ticket's 'Fix Version/s' field is empty." }
        default             { $msg = "The ticket's 'Fix Version/s':`n`n$(ArrayToNlsv $fixVersions)."
                              $msg += "`n`nSupposing one of them is DEV, it seems like you need to backport into ${backportFixVersionsCount} release"
                              $msg += if ($backportFixVersionsCount -gt 1) { "s." } else { "." }
        }
    }
    $msg += if (IsPopulated $msg) {
        "`n`nHowever, you are backporting into $($backportRels.Count) release${pluralEnding}:" +
        "`n`n${backportRelsNlsv}" +
        "`n`nDo you want to continue?"
    } else {
        "Everything looks good, you are backporting into $($backportRels.Count) release${pluralEnding}:" +
        "`n`n${backportRelsNlsv}" +
        "`n`n$($backportRels.Count) is the correct NUMBER according to the ticket's 'Fix Version/s'." +
        "`n`nHowever, you might want to make sure that you are backporting into the CORRECT release${pluralEnding}." +
        "`n`n'Fix Version/s' (one of them is DEV):" +
        "`n`n$(ArrayToNlsv $fixVersions)." +
        "`n`nDo you want to continue?"
    }
    LetUserConfirm $msg
    
    # Error message if the user is backporting into a release which has no feature branch:
    [string[]] $relsHavingBranches = GetRelsHavingBranches $ticket
    [string[]] $branchlessBackportRels = $backportRels | Where-Object { $_ -notin $relsHavingBranches }
    if ($branchlessBackportRels.Count -eq 1) {
        $msg = "You cannot backport into $($branchlessBackportRels[0]) since it has no feature branch. Run if you need to backport into it:" +
                "`n`nc ${ticket}" +
                "`nb ${ticket} ${commitHash}"
        $msg += if ($backportRelsArePassedAsParam) { " $(ArrayToCsv $backportRels)`n" } else { "`n" }
        throw $msg
    } elseif ($branchlessBackportRels.Count -gt 1) {
        $msg = "You cannot backport into these releases since they have no feature branches:" +
                "`n`n$(ArrayToNlsv $branchlessBackportRels)" +
                "`n`nRun if you need to backport into them:" +
                "`n`nc ${ticket}" +
                "`nb ${ticket} ${commitHash}"
                $msg += if ($backportRelsArePassedAsParam) { " $(ArrayToCsv $backportRels)`n" } else { "`n" }
        throw $msg
    }
} # ValidateBackport

function ValidateDelete ([string] $ticket) {
    if (-not (AtLeastOneBranchIsCreatedFor $ticket)) {
        throw "${ticket} has no branches to delete. Make sure you passed a correct ticket number."
    }
    if ($CONFIRM_DELETING_BRANCHES -and (UserRepliedNo "Are you sure you want to delete all the branches of ${ticket}?")) {
        PrintMsg "`nThe deletion of ${ticket} branches is aborted.`n"
        throw $SILENTLY_HALT
    }
} # ValidateDelete

function ValidateSettings {
    [string[]] $constants = @('DISPLAY_ERROR_POPUP', 'DISPLAY_SUCCESS_POPUP', 'CONFIRM_DELETING_BRANCHES', 'CREATE_BACKPORT_PRS',
                                'TICKETS_FOLDER_PATH', 'DEFAULT_TICKET_PREFIX', 'DIGITS_IN_TICKET_NUM',
                                'DEV_REL', 'DEFAULT_BACKPORT_RELS_CSV',
                                'REMOTE_GIT_REPO_URL', 'GIT_FOLDER_PATH', 'WORKING_REPO', 'REPOS_TO_REFRESH_CSV',
                                'JIRA_URL', 'JIRA_PAT', 'DEVELOPER')
    [string[]] $optionals = @('TICKETS_FOLDER_PATH', 'DEFAULT_TICKET_PREFIX', 'DEV_REL', 'DEFAULT_BACKPORT_RELS_CSV', 'REPOS_TO_REFRESH_CSV')
    
    . "${SETTINGS_FILE}" # pick the latest settings (the user could change them during the current session)
    
    foreach ($constant in $constants) {
        try {
            $constantVal = Get-Variable -Name $constant -ValueOnly -ErrorAction Stop
        } catch {
            throw "Declare the ${constant} constant in ${SETTINGS_FILE}" # The error: "Cannot find a variable with the name '...'"
        }
        if ((IsEmpty $constantVal) -and -not ($optionals -contains $constant)) {
            throw "Populate the ${constant} constant in ${SETTINGS_FILE}"
        }
    }
} # ValidateSettings

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
            401 { $err = "Wrong Jira PAT.`nFix the JIRA_PAT constant in ${SETTINGS_FILE}." } # "Unauthorized"
        }
        throw $err
    }
    return $jiraResponse
} # InvokeJiraApi

function PopulateEnvVarsFromJira ([string] $ticket) {
    [bool] $alreadyRetrieved = (atLeastOneBranchIsCreatedFor $ticket)
    if ($alreadyRetrieved) { return }
    PrintMsg "Getting ticket info from Jira..."
    [PSCustomObject] $jiraResponse = InvokeJiraApi $ticket
    [string] $ticketType = ($jiraResponse.fields.issuetype.name -replace ' ', '').ToLower() # "Contract Modification" > "contractmodification"
    if (IsEmpty $ticketType) { throw "The 'Type' field is empty in ${ticket}." }
    SetEnvVar $ticket $TICKET_TYPE $ticketType
    SetEnvVar $ticket $TICKET_TITLE $jiraResponse.fields.summary
    # To find a Jira field name, go to https://tylerjira.tylertech.com/rest/agile/latest/issue/CLT-78487 and find the field by its contents.
} # PopulateEnvVarsFromJira

function GetFixVersions ([string] $ticket) {
    # Returns the ticket's 'Fix Version/s' as an array. It uses their Descriptions which pop up when you are hooviring (they are more informative and often contain the release name).
    # The Fix Version/s are not stored in an env var since 'b' must get the freshest version - the field could change after 'c' called PopulateEnvVarsFromJira (through BuildBranchName).
    PrintMsg "`nGetting ticket's Fix Version/s from Jira for validating..."
    [PSCustomObject] $jiraResponse = InvokeJiraApi $ticket
    [string[]] $fixVersions = $jiraResponse.fields.fixVersions | ForEach-Object { $_.description }
    if (-not $fixVersions) { $fixVersions = @() } 
    return $fixVersions
} # GetFixVersions

###################################################################################################################################################
# Branch name building functions:
###################################################################################################################################################

function BuildBranchName ([string] $ticket, [string] $rel) {
    $ticketType = GetTicketType $ticket
    return "${DEVELOPER}/${rel}/${ticketType}/${ticket}"
} # BuildBranchName

function GetTicketType ([string] $ticket){
    PopulateEnvVarsFromJira $ticket
    return GetEnvVar $ticket $TICKET_TYPE
} # GetTicketType

function GetTicketTitle ([string] $ticket) {
    PopulateEnvVarsFromJira $ticket
    return GetEnvVar $ticket $TICKET_TITLE
} # GetTicketTitle

###################################################################################################################################################
# Messages functions:
###################################################################################################################################################

function PrintMsg ([string] $msg) {
    Write-Host $msg -ForegroundColor Green # to distinguish from white Git output
} # PrintMsg

function DisplayPopup ([string] $msg, [string] $title) {
    [MessageBox]::Show($msg, $title) > $null # > $null avoids printing the clicked button's text to the terminal
} # DisplayPopup

function DisplaySuccessMsg ([string] $msg) {
    Write-Host "`n${DECORATIVE_LINE}`n${msg}`n${DECORATIVE_LINE}`n" -ForegroundColor Green
    if ($DISPLAY_SUCCESS_POPUP) { DisplayPopup $msg "SUCCESS!!!" }
} # DisplaySuccessMsg

function DisplayErrorMsg ([string] $msg, [string] $msgTitle) {
    Write-Host "`n${DECORATIVE_LINE}`n${msg}`nThe operation is aborted.`n${DECORATIVE_LINE}`n" -ForegroundColor Red
    if ($DISPLAY_ERROR_POPUP) { DisplayPopup $msg $msgTitle }
} # DisplayErrorMsg

function UserRepliedYes ([string] $msg, [string] $title = "Confirm") {
    [DialogResult] $userReply = [MessageBox]::Show(
        $msg,
        $title,
        [MessageBoxButtons]::YesNo,
        [MessageBoxIcon]::Question
        #[MessageBoxDefaultButton]::Button2 # commented out since in many messages the safe option is Yes
    )
    return ($userReply -eq [DialogResult]::Yes)
} # UserRepliedYes

function UserRepliedNo ([string] $msg, [string] $title = "Confirm") {
    return (-not (UserRepliedYes $msg $title))
} # UserRepliedNo

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
                    "the DEFAULT_TICKET_PREFIX constant."
        }
        $ticket = "${DEFAULT_TICKET_PREFIX}-${ticket}"
    }
    return $ticket
} # AddPrefixIfNotProvided

###################################################################################################################################################
# Technical functions:
###################################################################################################################################################

function IsEmpty ([string] $val) {
    return ([string]::IsNullOrWhiteSpace($val))
} # IsEmpty

function IsPopulated ([string] $val) {
    return (-not (IsEmpty $val))
} # IsPopulated

function ExtractRelFromBranch ([string] $branch) {
    [int]    $firstSlashIndex = $branch.IndexOf('/') + 1
    [int]    $lastSlashIndex = $branch.LastIndexOf('/')
    [int]    $beforeLastSlashIndex = $branch.LastIndexOf('/', $lastSlashIndex - 1)
    [string] $rel = $branch.Substring($firstSlashIndex, $beforeLastSlashIndex - $firstSlashIndex)
    return $rel
} # ExtractRelFromBranch

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

function ArrayContainsValue ([string[]] $array, [string] $value) {
    if (-not $array) { return $false } # prevent "-contains" from failing if the array is not instantiated, that's why this function was created
    return ($array -contains $value)
} # ArrayContainsValue

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
# Misc functions:
###################################################################################################################################################

function SwitchToWorkingRepo {
    Set-Location "${GIT_FOLDER_PATH}\${WORKING_REPO}" -ErrorAction Stop
} # SwitchToWorkingRepo

function BuildPrCreationUrl ([string] $rel, [string] $featBranch) {
    return "${REMOTE_GIT_REPO_URL}/compare/${rel}...${featBranch}?expand=1"
} # BuildPrCreationUrl

function CreateTicketFolder ([string] $ticket, [string] $branch) { # see _______ReadMe_______.txt >>> "FOLDERS FOR TICKETS' ARTEFACTS")
    if (IsEmpty $TICKETS_FOLDER_PATH) { return }

    [string] $newTicketFolderPath = "${TICKETS_FOLDER_PATH}\${ticket}"
    [bool]   $newTicketFolderExists = Test-Path -Path $newTicketFolderPath -PathType Container
    if ($newTicketFolderExists) { return }

    [string] $templateFolderPath = "${TICKETS_FOLDER_PATH}\XXXXX"
    [bool]   $templateFolderExists = Test-Path -Path $templateFolderPath -PathType Container
    if (-not $templateFolderExists) {
        # ...create it:
        New-Item -Path $templateFolderPath -ItemType Directory -Force | Out-Null

        # Also, create the XXXXX.txt file within it:
        [string] $fileContent = "_TICKET_NAME_ _TICKET_TITLE_`n" +
                                "Hi <write the tester name here>, ${JIRA_URL}/browse/_TICKET_NAME_ is ready for peer review.`n" +
                                "_DEV_PR_CREATION_URL_"
        Set-Content -Path "${templateFolderPath}\XXXXX.txt" -Value $fileContent

        [string] $msg = "The ${templateFolderPath} folder is created.`n" +
                        "It will be used as a template to automatically create a working folder for each new ticket.`n" +
                        "You can add files and folders to it, they will be cloned too.`n" +
                        "This message will not be displayed again."
        DisplaySuccessMsg $msg
    }

    # Clone the XXXXX template folder naming it as the ticket:
    Copy-Item -Path $templateFolderPath -Destination $newTicketFolderPath -Recurse -ErrorAction Stop

    # Rename XXXXX.txt in the new folder to the ticket name:
    Rename-Item -Path "${newTicketFolderPath}\XXXXX.txt" -NewName "${ticket}.txt"

    # In that txt file, substitute the placeholders with the actual values:
    [string] $filePath = Join-Path -Path $TICKETS_FOLDER_PATH -ChildPath "${ticket}\${ticket}.txt"
    [string] $fileContent = Get-Content $filePath -Raw
    [string] $ticketTitle = GetTicketTitle $ticket
    [string] $devPrCreationUrl = BuildPrCreationUrl $DEV_REL $branch
    $fileContent = $fileContent -replace '_TICKET_NAME_', $ticket
    $fileContent = $fileContent -replace '_TICKET_TITLE_', $ticketTitle
    $fileContent = $fileContent -replace '_DEV_PR_CREATION_URL_', $devPrCreationUrl

    Set-Content $filePath -Value $fileContent
} # CreateTicketFolder
