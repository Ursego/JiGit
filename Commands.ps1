###################################################################################################################################################
# The file contains the scripts for the Git Automation commands:
# c - Create branches
# b - Backport commit
# d - Delete branches
# s - Open the Settings file
###################################################################################################################################################
# Developer: Michael Zuskin https://www.linkedin.com/in/zuskin/
# This project on GitHub: https://github.com/Ursego/JiGit
###################################################################################################################################################

[string] $HELPER_FUNC_FILE = "${PSScriptRoot}\HelperFunctions.ps1"

if (Test-Path -Path $HELPER_FUNC_FILE) {
    . $HELPER_FUNC_FILE
} else {
    Write-Host "The file '${HELPER_FUNC_FILE}' is not found.`nTo use the Git Automation commands, restore the file and restart PowerShell.`n" -ForegroundColor Red
}

###################################################################################################################################################
# The "Create branches" script
###################################################################################################################################################

function c ([string] $ticket, [string] $relsCsv) {
    [string] $msg
    [string] $msgTitle
    [bool]   $ticketFolderCreated = $false
    [bool]   $atLeastOneBranchIsPublishedByThisRun = $false

    try {
        Clear-Host
        ValidateSettings
        $ticket = AcceptFromUserIfNotProvided $ticket "Enter the ticket number"
        Clear-Host
        $ticket = AddPrefixIfNotProvided $ticket

        Clear-Host
        # PrintMsg "####### CREATING BRANCHES FOR ${ticket} #######`n"
        SwitchToWorkingRepo

        [string[]] $localCreatedBranches = GetLocalCreatedBranches $ticket
        [string[]] $remoteCreatedBranches = GetRemoteCreatedBranches $ticket
        [string[]] $rels = CsvToArray $RELS_CSV
        [bool] $existsLocally = $false
        [bool] $existsRemotely = $false

        if (IsEmpty $relsCsv) {
            $rels = CsvToArray $RELS_CSV
        } else {
            $relsCsv = $relsCsv.Trim() -replace ' ', ',' # if a CSV is passed with no quote marks, PowerShell replaces the commas with spaces - revert that change
            $rels = CsvToArray $relsCsv
            $rels = $rels | Select-Object -Unique
        }
        ValidateCreate $ticket $rels
        # throw "Going to create branches for:`n'${rels}'" #dbg - uncomment to debug only

        PrintMsg "####### CREATING BRANCHES FOR ${ticket} #######`n"
        PrintMsg "Pulling $($WORKING_REPO.ToUpper())..."
        [string] $gitResult = git pull 2>&1 # 2>&1 - don't throw an exception, just return the error message and make $LASTEXITCODE other than zero
        if ($LASTEXITCODE -ne 0) {
            throw "Cannot pull $($WORKING_REPO.ToUpper()).`n`n${gitResult}"
        }

        # -----------------------------------------------------------------------------------------------------------------------------------------
        # THE MAIN CREATION LOGIC:
        # -----------------------------------------------------------------------------------------------------------------------------------------

        foreach ($rel in $rels) {
            [string] $newBranch = BuildBranchName $ticket $rel
            PrintMsg "`n${newBranch}"

            $existsLocally = (ArrayContainsValue $localCreatedBranches $newBranch)
            $existsRemotely = (ArrayContainsValue $remoteCreatedBranches $newBranch)

            if (-not $existsLocally) {
                if (-not $existsRemotely) {
                    CreateLocalBranch $newBranch $rel
                } else {
                    RecreateLocalBranchFromRemotes $newBranch
                }
            } else {
                PrintMsg "   Creating on LOCALS is skipped since it already exists locally."
            }

            if (-not $existsRemotely) {
                PublishBranch $newBranch
                $atLeastOneBranchIsPublishedByThisRun = $true
            } else {
                PrintMsg "   Publishing to REMOTES is skipped since it's already published."
            }

            if (-not ($ticketFolderCreated)) {
                CreateTicketFolder $ticket $newBranch
                $ticketFolderCreated = $true
            }
        } # foreach ($rel in $rels)

        RefreshRepos "c" $atLeastOneBranchIsPublishedByThisRun
        DisplaySuccessMsg "All the requested branches are created."
    } catch {
        $msg = $_.Exception.Message
        if ($msg -eq $SILENTLY_HALT) { return }
        DisplayErrorMsg $msg
    }
} # c

###################################################################################################################################################
# The "Backport commit" script
###################################################################################################################################################

function b ([string] $ticket, [string] $commitHash, [string] $backportRelsCsv) {
    [string]   $msg
    [string]   $prompt
    [string]   $failedRel
    [string[]] $relsBackportedByThisRun = @()
    [string[]] $relsBackportedPreviously = @()
    [string[]] $prCreationUrls = @()

    try {
        Clear-Host
        ValidateSettings
        SwitchToWorkingRepo
        $ticket = AcceptFromUserIfNotProvided $ticket "Enter the ticket you want to backport"
        Clear-Host
        $ticket = AddPrefixIfNotProvided $ticket
        Clear-Host

        $prompt = "Enter the hash of the commit to backport.`n`n" +
                    "HOW TO OBTAIN IT:`n" +
                    "In the DEV Pull Request, find (Ctrl+F) 'merged commit'.`n" +
                    "You will see '[your_name] merged commit [commit_hash] into [release]'.`n" +
                    "Copy the [commit_hash] and paste it here"
        $commitHash = AcceptFromUserIfNotProvided $commitHash $prompt
        Clear-Host

        if (IsEmpty $backportRelsCsv) {
            $backportRels = GetBackportRelsFromSettings
        } else {
            $backportRelsCsv = $backportRelsCsv.Trim() -replace ' ', ',' # if a CSV is passed with no quote marks, PowerShell replaces the commas with spaces - revert that change
            $backportRels = CsvToArray $backportRelsCsv
            [string] $devRel = GetDevRel
            if (ArrayContainsValue $backportRels $devRel) {
                if (UserRepliedNo "${devRel} is the DEV branch.`nAre you sure you want to backport ${commitHash} into it?" "Confirm backport into the DEV branch") {
                    Clear-Host
                    "The backport of ${ticket} is aborted.`n"
                    throw $SILENTLY_HALT
                }
            }
            $backportRels = $backportRels | Select-Object -Unique
        }

        ValidateBackport $ticket $commitHash
        #throw "The final backportRels:`n${backportRels}" #dbg - uncomment to debug only

        PrintMsg "Pulling $($WORKING_REPO.ToUpper())..."
        [string] $gitResult = git pull 2>&1
        if ($LASTEXITCODE -ne 0) {
            # The error could be caused by a cherry-pick which was not pushed:
            PrintMsg "`nThe pull failed. Aborting a possible not-pushed cherry-pick and pulling again..."
            git cherry-pick --abort
            [string] $gitResult = git pull 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Cannot pull $($WORKING_REPO.ToUpper()).`n`n${gitResult}"
            }
        }
    } catch {
        $msg = $_.Exception.Message
        if ($msg -eq $SILENTLY_HALT) { return }
        DisplayErrorMsg $msg
        return
    }

    # -----------------------------------------------------------------------------------------------------------------------------------------
    # THE MAIN BACKPORT LOGIC:
    # -----------------------------------------------------------------------------------------------------------------------------------------

    try {
        foreach ($backportRel in $backportRels) {
            [string] $targetFeatBranch = BuildBranchName $ticket $backportRel
            PrintMsg "`nTARGET: ${targetFeatBranch}"

            PrintMsg "   Checking out..."
            [string] $gitResult = git checkout $targetFeatBranch 2>&1
            if ($LASTEXITCODE -eq 0) {
                PrintMsg "      Successfully checked out."
            } else {
                if ($gitResult.Contains("did not match any file(s) known to git")) { # in fact, after adding ValidateAndSyncCreatedBackportBranches, that must never happen...
                    PrintMsg "      The branch doesn't exist, so the backport into it is skipped."
                    continue
                } else {
                    $failedRel = $backportRel
                    throw "Cannot check out ${targetFeatBranch}`n`n${gitResult}"
                }
            }

            PrintMsg "   Cherry-picking..."

            [string] $gitResult = git cherry-pick $commitHash 2>&1
            if ($LASTEXITCODE -eq 0) {
                PrintMsg "      Successfully cherry-picked."
            } else {
                $failedRel = $backportRel
                if ($gitResult.Contains("The previous cherry-pick is now empty, possibly due to conflict resolution")) {
                    PrintMsg "      The cherry-pick is skipped since commit ${commitHash} has already been cherry-picked into this branch."
                    # Don't "continue" - proceed to Pushing. Most probably, the cherry-pick is already pushed.
                    # However, communication with Git could be lost on the previous run after cherry-pick but before push. In this scenario, we still need to push.
                } elseif ($gitResult.Contains("conflict")) {
                    throw "Conflict on backporting into ${backportRel}."
                } elseif ($gitResult.Contains("bad revision")) {
                    throw "Commit ${commitHash} doesn't exist."
                } else {
                    # Abort the cherry pick to avoid this error on the next repo pull:
                    # "You have not concluded your cherry-pick (CHERRY_PICK_HEAD exists). Please, commit your changes before you merge."
                    git cherry-pick --abort
                    throw "The cherry-pick into ${targetFeatBranch} failed:`n`n${gitResult}"
                }
            }

            PrintMsg "   Pushing..."
            [string] $gitResult = git push --set-upstream origin $targetFeatBranch 2>&1
            if ($LASTEXITCODE -eq 0) {
                if ($gitResult.Contains("Everything up-to-date")) {
                    PrintMsg "      The push is skipped since this cherry-pick has already been pushed."
                     $relsBackportedPreviously += $backportRel
                    continue
                }
                PrintMsg "      Successfully pushed."
            } else {
                $failedRel = $backportRel
                if ($gitResult.Contains("conflict")) {
                    throw "Conflict on backporting into ${backportRel}."
                } else {
                    git cherry-pick --abort
                    throw "The push of the ${targetFeatBranch} cherry-pick failed:`n`n${gitResult}"
                }
            }
            
            $prCreationUrls += BuildPrCreationUrl -rel $backportRel -featBranch $targetFeatBranch
            $relsBackportedByThisRun += $backportRel
        } # foreach ($backportRel in $backportRels)
        
        $msg = if ($relsBackportedByThisRun.Count -gt 0) { "${ticket} is backported." } else { "No backports were done for ${ticket} by this 'b' command execution." }
        DisplaySuccessMsg $msg
    } catch {
        $msg = $_.Exception.Message
        if ($msg -eq $SILENTLY_HALT) { return }

        $msg += if ($msg -like "Conflict on backporting into*") {
            "`n`nResolve it in a Git client app. Complete that backport and create the pull request also there."
        } else {
            "`n`nResolve the error in a Git client app."
        }

        [bool] $failedRelIsLast = ($relsBackportedByThisRun.Count -eq ($backportRels.Count - 1))
        if ($failedRelIsLast) {
            $msg += "`n`nThe failed ${failedRel} was the last release to backport into.`n"
        } else {
            [string[]] $remainingRels = $backportRels | Where-Object { $_ -notin ($relsBackportedByThisRun + $relsBackportedPreviously) -and $_ -ne $failedRel }
            $msg += "`n`nThen, do the remaining backport"
            if ($remainingRels.Count -gt 1) { $msg += "s" }
            $msg += " by running the next command:`n`nb ${ticket} ${commitHash} $(ArrayToCsv $remainingRels)`n"
        }

        DisplayErrorMsg $msg
    } finally {
        if ($prCreationUrls.Count -gt 0) {
            if ($CREATE_BACKPORT_PRS) {
                # Create Pull Requests for all the successful backport branches by opening the PR-creating URLs in the default browser.
                # Using a separate loop to prevent the browser from popping up multiple times during the backporting:
                $prCreationUrls | ForEach-Object { Start-Process $_ }
            } else {
                PrintMsg "`nTo create the backport Pull Requests, copy the next fragment (with the empty line after it), paste it and press Enter:`n"
                $prCreationUrls | ForEach-Object { Write-Host "Start-Process $_"}
                Write-Host "`n"
            }
        }
    }
} # b

###################################################################################################################################################
# The "Delete branches" script
###################################################################################################################################################

function d ([string] $ticket) {
    [bool]     $atLeastOneBranchIsDeleted = $false
    [string[]] $undeletedBranches = @()
    [string]   $SOFT_DELETE = "d" # throw "The branch '<branch-name>' is not fully merged" if the branch contains unmerged changes
    [string]   $HARD_DELETE = "D" # don't check for unmerged changes
    [string]   $msg

    try {
        Clear-Host
        ValidateSettings
        SwitchToWorkingRepo

        $ticket = AcceptFromUserIfNotProvided $ticket "Enter the ticket to delete its branches"
        Clear-Host
        $ticket = AddPrefixIfNotProvided $ticket
        ValidateDelete $ticket
        Clear-Host
        PrintMsg "####### DELETING BRANCHES OF ${ticket} #######`n"

        [string[]] $localCreatedBranches = GetLocalCreatedBranches $ticket
        [string[]] $remoteCreatedBranches = GetRemoteCreatedBranches $ticket
        [string[]] $branchesToDelete = ($localCreatedBranches + $remoteCreatedBranches) | Select-Object -Unique # a branch could exist only locally or only remotely - delete everything
        #throw "Going to delete branches:`n'${branchesToDelete}'" #dbg - uncomment to debug only

        [string] $checkedOutBranch = git branch --show-current 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Cannot define checked out branch:`n`n${checkedOutBranch}" }

        # -----------------------------------------------------------------------------------------------------------------------------------------
        # THE MAIN DELETION LOGIC:
        # -----------------------------------------------------------------------------------------------------------------------------------------

        foreach ($branchToDelete in $branchesToDelete) {
            PrintMsg "`n${branchToDelete}"

            if ($branchToDelete -eq $checkedOutBranch) {
                [string] $devRel = GetDevRel

                $msg = "`n   This branch is currently checked-out in $($WORKING_REPO.ToUpper()).`n" +
                         "   Checking out another branch (${devRel}) in order to enable the deletion...`n"
                PrintMsg $msg
                [string] $gitResult = git checkout $devRel 2>&1
                if ($LASTEXITCODE -ne 0) { throw "Cannot check out ${devRel}.`n`n${gitResult}`n`nCheck out another branch in a Git client app, and re-run:`nd ${ticket}`n" }
            }

            if (ArrayContainsValue $localCreatedBranches $branchToDelete) {
                PrintMsg "   Deleting from LOCALS..."

                # If the REMOTE counterpart of the LOCAL branch doesn't exist, you will get "The branch '<branch-name>' is not fully merged". To prevent that, delete hard:
                [bool] $remoteCounterpartExists = (ArrayContainsValue $remoteCreatedBranches $branchToDelete)
                [string] $delOption = if ($remoteCounterpartExists) { $SOFT_DELETE } else { $HARD_DELETE }
                [string] $gitResult = git branch -$delOption $branchToDelete 2>&1
                if ($LASTEXITCODE -ne 0) {
                    if ($gitResult.Contains("is not fully merged")) {
                        # Maybe, the branch really has unmerged changes.
                        # But sometimes Git shows this error for no reason. It even suggests to force the deletion using capital -D instead of -d in the error message:
                        # "The branch '<branch-name>' is not fully merged. If you are sure you want to delete it, run 'git branch -D <branch-name>'"
                        $msg = "${branchToDelete} is not fully merged." +
                                "`n`nAre you sure you want to delete it?" +
                                "`n`nYes - I am sure it's fully merged." +
                                "`n`nNo - Skip the deletion, I will merge it." +
                                "`n`nIf you are unsure, click No. After this script finishes executing, double-check in a Git client app and merge unmerged changes if they exist."
                        if (UserRepliedYes $msg) {
                            [string] $gitResult = git branch -$HARD_DELETE $branchToDelete 2>&1
                            if ($LASTEXITCODE -ne 0) { throw "Cannot delete ${branchToDelete} from LOCALS.`n`n${gitResult}" }
                        } else {
                            PrintMsg "      Deletion of this branch is skipped.`n" +
                                        "      After you merge it (or make sure it's fully merged),`n" +
                                        "      re-run this command to complete the deleting: d ${ticket}"
                            $undeletedBranches += $branchToDelete
                            continue
                        }
                    } else {
                        throw "Cannot delete ${branchToDelete} from LOCALS.`n`n${gitResult}"
                    }
                }

                PrintMsg "      Successfully deleted."
                $atLeastOneBranchIsDeleted = $true
            } else {
                PrintMsg "   Deleting from LOCALS is skipped since it doesn't exists locally."
            }
            
            if (ArrayContainsValue $remoteCreatedBranches $branchToDelete) {
                PrintMsg "   Deleting from REMOTES..."
                [string] $gitResult = git push origin --delete $branchToDelete 2>&1
                if ($LASTEXITCODE -ne 0) { throw "Cannot delete ${branchToDelete} from REMOTES.`n`n${gitResult}" }
                PrintMsg "      Successfully deleted."
                $atLeastOneBranchIsDeleted = $true
            } else {
                PrintMsg "   Deleting from REMOTES is skipped since it doesn't exists remotely."
            }
        } # foreach ($branchToDelete in $branchesToDelete)
        
        RefreshRepos "d" $atLeastOneBranchIsDeleted
        
        if ($undeletedBranches.Count -eq 0) {
            CleanUpEnvVars $ticket
            DisplaySuccessMsg "All the branches of ${ticket} are deleted."
        } else {
            DisplaySuccessMsg "The branches of ${ticket} are deleted except of:`n$(ArrayToNlsv $undeletedBranches)"
        }
    } catch {
        $msg = $_.Exception.Message
        if ($msg -eq $SILENTLY_HALT) { return }
        DisplayErrorMsg $msg
    }
} # d

###################################################################################################################################################
# The "Open the Settings file" script
###################################################################################################################################################

function s () {
    Start-Process -FilePath $SETTINGS_FILE
} # s
