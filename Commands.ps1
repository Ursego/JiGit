###################################################################################################################################################
# The scripts for the Git Automation commands:
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

function c ([string] $ticket) {
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
        ValidateCreate $ticket
        SwitchToWorkingRepo

        Clear-Host
        PrintMsg "####### CREATING BRANCHES FOR ${ticket} #######`n"

        [string[]] $localCreatedBranches = GetLocalCreatedBranches $ticket
        [string[]] $remoteCreatedBranches = GetRemoteCreatedBranches $ticket
        [string[]] $rels = CsvToArray $RELS_CSV
        #throw "Going to create branches for:`n'${rels}'" #dbg - uncomment to debug only

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
            [bool] $alreadyCreatedOnLocals = (ArrayContainsValue $localCreatedBranches $newBranch)
            if (-not $alreadyCreatedOnLocals) {
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
            } else {
                PrintMsg "   Creating on LOCALS is skipped since it already exists locally."
            }

            [bool] $alreadyPublished = (ArrayContainsValue $remoteCreatedBranches $newBranch)
            if (-not $alreadyPublished) {
                PrintMsg "   Publishing to REMOTES..."
                [string] $gitResult = git push -u origin $newBranch 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Cannot publish $newBranch.`n`n${gitResult}"
                }
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
        DisplayErrorMsg $msg "ERROR"
    }
} # c

###################################################################################################################################################
# The "Backport commit" script
###################################################################################################################################################

function b ([string] $ticket, [string] $commitHash) {
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

        [string[]] $backportRels = GetBackportRels
        ValidateBackport $ticket $commitHash $backportRels
        #throw "The final backportRels:`n${backportRels}" #dbg - uncomment to debug only
        
        Clear-Host
        PrintMsg "####### BACKPORTING COMMIT ${commitHash} #######"

        PrintMsg "`nPulling $($WORKING_REPO.ToUpper())..."
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
            if ($LASTEXITCODE -ne 0) {
                if ($gitResult.Contains("did not match any file(s) known to git")) {
                    PrintMsg "      The branch doesn't exist, so the backport into it is skipped."
                    continue
                } else {
                    $failedRel = $backportRel
                    throw "Cannot check out ${targetFeatBranch}`n`n${gitResult}"
                }
            }

            PrintMsg "   Cherry-picking..."
            [string] $gitResult = git cherry-pick $commitHash 2>&1
            if ($LASTEXITCODE -ne 0) {
                $failedRel = $backportRel
                if ($gitResult.Contains("The previous cherry-pick is now empty, possibly due to conflict resolution")) {
                    PrintMsg "      The cherry-pick is skipped since commit ${commitHash} has already been cherry-picked into this branch."
                    # Don't "continue" - proceed to Pushing. Most probably, the cherry-pick is already pushed.
                    # However, comminication with Git could be lost on the previous run after cherry-pick but before push. In this scenario, we still need to push.
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
            if ($LASTEXITCODE -ne 0) {
                $failedRel = $backportRel
                if ($gitResult.Contains("conflict")) {
                    throw "Conflict on backporting into ${backportRel}."
                } else {
                    git cherry-pick --abort
                    throw "The push of the ${targetFeatBranch} cherry-pick failed:`n`n${gitResult}"
                }
            }

            if ($gitResult.Contains("Everything up-to-date")) {
                PrintMsg "      The push is skipped since this cherry-pick has already been pushed."
                $relsBackportedPreviously += $backportRel
                continue
            }
            
            $prCreationUrls += BuildPrCreationUrl -rel $backportRel -featBranch $targetFeatBranch
            $relsBackportedByThisRun += $backportRel
        } # foreach ($backportRel in $backportRels)
        
        $msg = if ($relsBackportedByThisRun.Count -gt 0) { "${ticket} is backported." } else { "No backports were done for ${ticket} by this 'b' command execution." }
        DisplaySuccessMsg $msg
    } catch {
        $msg = $_.Exception.Message
        if ($msg -eq $SILENTLY_HALT) { return }

        [string] $whatHappened = if ($msg -like "Conflict on backporting into*") { "conflict" } else { "error" }

        if ($relsBackportedByThisRun.Count -gt 0) {
            $msg += "`n`nDespite the ${whatHappened} in ${failedRel}, the commit was successfully backported into:`n`n$(ArrayToNlsv $relsBackportedByThisRun)"
        }

        $msg += "`n`nResolve the ${whatHappened} in a Git client app"
        $msg += if ($whatHappened -eq "conflict") { ", complete the backport into ${failedRel} and create a pull request there." } else { "." }

        [bool] $failedRelIsLast = ($relsBackportedByThisRun.Count -eq ($backportRels.Count - 1))
        if ($failedRelIsLast) {
            $msg += "`n`nThe failed ${failedRel} was the last release to backport into.`n"
        } else {
            [string[]] $remainingRels = $backportRels | Where-Object { $_ -notin ($relsBackportedByThisRun + $relsBackportedPreviously) -and $_ -ne $failedRel }
            $msg += "`n`nThen, complete the remaining backport(s) by running the same command (it will skip the successfully backported releases):`n`nb ${ticket} ${commitHash}"
            $msg += "n`nTo save time, before that, you can open the Settings file by running the 's' command and change RELS_CSV to '$(GetDevRel),$(ArrayToCsv $remainingRels)'`n"
        }

        DisplayErrorMsg $msg $whatHappened.ToUpper()
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
    [string]   $msg
    [bool]     $atLeastOneBranchIsDeleted = $false
    [string[]] $undeletedBranches = @()
    [string]   $CHECK_UNMERGED_CHANGES = "d" # soft delete - throw "The branch '<branch-name>' is not fully merged" if the branch contains unmerged changes
    [string]   $DONT_CHECK_UNMERGED_CHANGES = "D" # hard delete

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
                         "   Checking out another branch (${devRel}) in order to enable the deletion..."
                PrintMsg $msg
                [string] $gitResult = git checkout $devRel 2>&1
                if ($LASTEXITCODE -ne 0) { throw "Cannot check out ${devRel}.`n`n${gitResult}`n`nCheck out another branch in a Git client app, and re-run:`nd ${ticket}`n" }
            }

            if (ArrayContainsValue $localCreatedBranches $branchToDelete) {
                PrintMsg "   Deleting from LOCALS..."

                # If the REMOTE counterpart of the LOCAL branch doesn't exist, you will get "The branch '<branch-name>' is not fully merged". To prevent that, delete hard:
                [bool] $remoteCounterpartExists = (ArrayContainsValue $remoteCreatedBranches $branchToDelete)
                [string] $delOption = if ($remoteCounterpartExists) { $CHECK_UNMERGED_CHANGES } else { $DONT_CHECK_UNMERGED_CHANGES }
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
                            [string] $gitResult = git branch -$DONT_CHECK_UNMERGED_CHANGES $branchToDelete 2>&1
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

                $atLeastOneBranchIsDeleted = $true
            } else {
                PrintMsg "   Deleting from LOCALS is skipped since it doesn't exists locally."
            }
            
            if (ArrayContainsValue $remoteCreatedBranches $branchToDelete) {
                PrintMsg "   Deleting from REMOTES..."
                [string] $gitResult = git push origin --delete $branchToDelete 2>&1
                if ($LASTEXITCODE -ne 0) { throw "Cannot delete ${branchToDelete} from REMOTES.`n`n${gitResult}" }
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
        DisplayErrorMsg $msg "ERROR"
    }
} # d

###################################################################################################################################################
# The "Open the Settings file" script
###################################################################################################################################################

function s () {
    Start-Process -FilePath $SETTINGS_FILE
} # s