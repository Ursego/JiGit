###################################################################################################################################################
# The file contains the scripts for 3 the Git Automation commands:
#
# c - "C"reate Branches
# b - "B"ackport Commit
# d - "D"elete Branches
#
# The details are in _______ReadMe_______.txt
###################################################################################################################################################

. "${PSScriptRoot}\HelperFunctions.ps1"

###################################################################################################################################################
# The "C"reate Branches script
###################################################################################################################################################

function c ([string] $ticketsCsv, [string] $superfluousParam) {
    [string] $msg
    [string] $msgTitle
    [bool]   $firstIteration = $true
    [bool]   $atLeastOneBranchIsPublishedByThisRun = $false

    try {
        Clear-Host
        if (IsPopulated $superfluousParam) {
            throw "The '${superfluousParam}' parameter is superfluous.`n" +
                    "Pass only one parameter - the ticket number`nor a comma-separated list of the ticket numbers (with no spaces)."
        }
        ValidateSettings
        ValidateCreate
        SwitchToWorkingRepo

        $ticketsCsv = AcceptFromUserIfNotProvided $ticketsCsv "Enter the tickets numbers for which you want to create branches (separated by comma)"
        $ticketsCsv = ($ticketsCsv -replace ' ', ',') # if a CSV is passed with no quote marks, PowerShell replaces the commas with spaces - revert that change
        [string[]] $tickets = CsvToArray $ticketsCsv
        [string[]] $rels = GetAllRelsFromSettings

        #throw "Going to create branches:`n'${tickets}'`n'${rels}'" #dbg - uncomment to test

        Clear-Host
        PrintMsg "####### CREATING BRANCHES #######"

        # -----------------------------------------------------------------------------------------------------------------------------------------
        # THE MAIN CREATION LOGIC:
        # -----------------------------------------------------------------------------------------------------------------------------------------

        foreach ($ticket in $tickets) {
            $ticket = AddPrefixIfNotProvided $ticket

            PrintMsg "`n----------- ${ticket} -----------`n"

            [string[]] $localCreatedBranches = GetLocalCreatedBranches $ticket
            [string[]] $remoteCreatedBranches = GetRemoteCreatedBranches $ticket -gitFetch $firstIteration
            if ($firstIteration) {
                PrintMsg ""
                $firstIteration = $false
            }

            foreach ($rel in $rels) {
                [string] $newBranch = BuildBranchName $ticket $rel
            
                PrintMsg "`n$newBranch"
                [bool] $alreadyCreatedOnLocals = (ArrayContainsValue $localCreatedBranches $newBranch)
                if (-not $alreadyCreatedOnLocals) {
                    PrintMsg "   Creating on LOCALS..."
                    [string] $gitResult = git branch $newBranch $rel 2>&1 # 2>&1 - don't throw an exception, just return the error message and make $LASTEXITCODE other than zero
                    if ($LASTEXITCODE -ne 0) {
                        if ($gitResult.Contains("not a valid object name")) {
                            PrintMsg "      '$rel' is not recognized on LOCALS. It could be a new release just added to the project. Downloading it..."
                            [string] $gitResult = git branch $rel "origin/${rel}" 2>&1
                            if ($LASTEXITCODE -ne 0) {
                                if ($gitResult.Contains("not a valid object name")) {
                                    PrintMsg "      '$rel' is not recognized on REMOTES too."
                                    $gitResult = "'$rel' is misspelled in the "
                                    $gitResult += if ($rel -eq $DEV_REL) { "DEV_REL constant.`n" } else { "DEFAULT_BACKPORT_RELS constant.`n" }
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
                    [string] $gitResult = git push -u origin $newBranch 2>&1 # place [string] before each population of $gitResult, otherwise .Contains won't work
                    if ($LASTEXITCODE -ne 0) {
                        throw "Cannot publish $newBranch.`n`n${gitResult}"
                    }
                    $atLeastOneBranchIsPublishedByThisRun = $true
                } else {
                    PrintMsg "   Publishing to REMOTES is skipped since it's already published."
                }

                if ($rel = $DEV_REL) {
                    CreateTicketFolder $ticket $newBranch
                }
            } # foreach ($rel in $rels)
        } # foreach ($ticket in $tickets)

        if ($atLeastOneBranchIsPublishedByThisRun) {
            [string[]] $reposToRefresh = (CsvToArray $REPOS_TO_REFRESH_CSV)
            foreach ($repo in $reposToRefresh) {
                Set-Location "${GIT_FOLDER_PATH}\${repo}" -ErrorAction Stop
                PrintMsg "`nFetching $($repo.ToUpper()) to download the new branches info..."
                git fetch origin
                # Don't check $LASTEXITCODE. Even if the fetch failed, it's because of an unrelated issue - the remote/ pointers are downloaded.
            }
        }

        DisplaySuccessMsg "All the requested branches are created."
    } catch {
        $msg = $_.Exception.Message
        if ($msg -eq $SILENTLY_HALT) { return }
        DisplayErrorMsg $msg "ERROR"
    }
} # c

###################################################################################################################################################
# The "B"ackport Commit script
###################################################################################################################################################

function b ([string] $ticket, [string] $commitHash, [string] $backportRelsCsv, [string] $superfluousParam) {
    [string]   $msg
    [string]   $prompt
    [string]   $failedRel
    [string[]] $backportRels = @()
    [string[]] $relsBackportedByThisRun = @()
    [string[]] $relsBackportedPreviously = @()
    [string[]] $prCreationUrls = @()

    try {
        Clear-Host
        if (IsPopulated $superfluousParam) {
            throw "The '${superfluousParam}' parameter is superfluous.`n"+
                    "Pass up to 3 parameters - the ticket number,`nthe commit hash and a comma-separated list`nof the backport releases (with no spaces)."
        }
            #throw "Pass up to 3 parameters - the ticket number, the commit hash and a comma-separated list of the backport releases (with no spaces)."
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

        [bool] $backportRelsArePassedAsParam = (IsPopulated $backportRelsCsv)
        if ($backportRelsArePassedAsParam) {
            $backportRelsCsv = $backportRelsCsv.Trim() -replace ' ', ',' # if a CSV is passed with no quote marks, PowerShell replaces the commas with spaces - revert that change
            $backportRels = CsvToArray $backportRelsCsv
            $backportRels = $backportRels | Select-Object -Unique
        } else {
            $backportRels = GetDefaultBackportRels
        }
        
        PrintMsg "####### BACKPORTING COMMIT ${commitHash} #######"

        ValidateBackport $ticket $commitHash $backportRels $backportRelsArePassedAsParam

        #throw "The final backportRels:`n${backportRels}" #dbg - uncomment to test

        PrintMsg "`nPulling $($WORKING_REPO.ToUpper())..."
        [string] $gitResult = git pull 2>&1
        if ($LASTEXITCODE -ne 0) {
            # The error could be caused by a cherry-pick which was not pushed:
            PrintMsg "`nThe pull failed. Aborting a possible not-pushed cherry-pick and pulling again..."
            git cherry-pick --abort
            [string] $gitResult = git pull 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Cannot pull $($WORKING_REPO.ToUpper()).`n`n${gitResult}`n`nResolve the issue in a Git client app and re-run the backport script.`n"
            }
        }

        # -----------------------------------------------------------------------------------------------------------------------------------------
        # THE MAIN BACKPORT LOGIC:
        # -----------------------------------------------------------------------------------------------------------------------------------------

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
                    throw "Cannot check out ${targetFeatBranch}`n`n${gitResult}"
                }
            }

            PrintMsg "   Cherry-picking..."
            [string] $gitResult = git cherry-pick $commitHash 2>&1
            if ($LASTEXITCODE -ne 0) {
                if ($gitResult.Contains("The previous cherry-pick is now empty, possibly due to conflict resolution")) {
                    PrintMsg "      Commit ${commitHash} was already cherry-picked into this branch."
                    PrintMsg "   Push is skipped since the existing cherry-pick is pushed."
                    # Abort the cherry pick to avoid this error on the next repo pull:
                    # "You have not concluded your cherry-pick (CHERRY_PICK_HEAD exists). Please, commit your changes before you merge."
                    git cherry-pick --abort
                    $relsBackportedPreviously += $backportRel
                    continue
                } elseif ($gitResult.Contains("conflict")) {
                    $gitResult = "Conflict on backporting into ${backportRel}."
                } elseif ($gitResult.Contains("bad revision")) {
                    $gitResult = "Commit ${commitHash} doesn't exist."
                }
                $failedRel = $backportRel
                throw $gitResult
            }

            PrintMsg "   Pushing..."
            [string] $gitResult = git push --set-upstream origin $targetFeatBranch 2>&1
            if ($LASTEXITCODE -ne 0) {
                if ($gitResult.Contains("conflict")) {
                    $gitResult = "Conflict on backporting into ${backportRel}." 
                } else {
                    git cherry-pick --abort
                    $gitResult = "The push failed:`n`n${gitResult}`n`nThe cherry-pick is aborted. Re-run the backport." 
                }
                $failedRel = $backportRel
                throw $gitResult
            }
            
            $prCreationUrls += BuildPrCreationUrl -rel $backportRel -featBranch $targetFeatBranch
            $relsBackportedByThisRun += $backportRel
        } # foreach ($backportRel in $backportRels)
        
        $msg = if ($relsBackportedByThisRun.Count -gt 0) { "${ticket} is backported." } else { "No backports were done for ${ticket}." }
        DisplaySuccessMsg $msg
    } catch {
        $msg = $_.Exception.Message
        if ($msg -eq $SILENTLY_HALT) { return }

        [string] $whatHappened = if ($msg -like "Conflict on backporting into*") { "conflict" } else { "error" }

        if ($relsBackportedByThisRun.Count -gt 0) {
            $msg += "`n`nDespite the ${whatHappened} in ${failedRel}, the commit was successfully backported into:`n`n$(ArrayToNlsv $relsBackportedByThisRun)"
        }

        if ($whatHappened -eq "conflict") {
            $msg += "`n`nResolve the conflict in a Git client app, complete the backport into ${failedRel} and create a pull request there."

            [bool] $failedRelIsLast = ($relsBackportedByThisRun.Count -eq ($backportRels.Count - 1))
            if ($failedRelIsLast) {
                $msg += "`n`nThe failed ${failedRel} release is the last one to beckport into, no need to re-run this script again.`n"
            } else {
                [string[]] $remainingRels = $backportRels | Where-Object { $_ -notin ($relsBackportedByThisRun + $relsBackportedPreviously) -and $_ -ne $failedRel }
                $msg += "`n`nThen, complete the remaining backport"
                if ($remainingRels.Count -gt 1) { $msg += "s" }
                $msg += ":`n`nb ${ticket} ${commitHash} $(ArrayToCsv $remainingRels)`n"
            }
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
# The "D"elete Branches script
###################################################################################################################################################

function d ([string] $ticket, [string] $superfluousParam) {
    [string]   $msg
    [bool]     $atLeastOneBranchIsDeleted = $false
    [string[]] $undeletedBranches = @()
    [string]   $CHECK_UNMERGED_CHANGES = "d" # soft delete - throw "The branch '<branch-name>' is not fully merged" if the branch contains unmerged changes
    [string]   $DONT_CHECK_UNMERGED_CHANGES = "D" # hard delete

    try {
        Clear-Host
        if (IsPopulated $superfluousParam) {
            throw "The '${superfluousParam}' parameter is superfluous.`nPass only one parameter - the ticket number."
        }
        #if (IsPopulated $superfluousParam) { throw "Pass only one parameter - the ticket number." }
        ValidateSettings
        SwitchToWorkingRepo

        $ticket = AcceptFromUserIfNotProvided $ticket "Enter the ticket to delete its branches"
        Clear-Host
        $ticket = AddPrefixIfNotProvided $ticket
        PrintMsg "####### DELETING BRANCHES #######"
        ValidateDelete $ticket
        PrintMsg ""

        [string[]] $localCreatedBranches = GetLocalCreatedBranches $ticket
        [string[]] $remoteCreatedBranches = GetRemoteCreatedBranches $ticket
        [string[]] $branchesToDelete = ($localCreatedBranches + $remoteCreatedBranches) | Select-Object -Unique # a branch could exist only locally or only remotely - delete everything

        #throw "Going to delete branches:`n'${branchesToDelete}'" #dbg - uncomment to test

        [string] $checkedOutBranch = git branch --show-current 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Cannot define checked out branch:`n`n${checkedOutBranch}" }

        # -----------------------------------------------------------------------------------------------------------------------------------------
        # THE MAIN DELETION LOGIC:
        # -----------------------------------------------------------------------------------------------------------------------------------------

        foreach ($branchToDelete in $branchesToDelete) {
            PrintMsg "`n${branchToDelete}"

            if ($branchToDelete -eq $checkedOutBranch) {
                [string] $anyRel = GetAnyRelFromSettings
                if (IsEmpty $anyRel) {
                    throw "${branchToDelete} is currently checked-out in $($WORKING_REPO.ToUpper()).`n`n" +
                            "To enable its deletion, check out any other branch and re-run:`n`n" +
                            "d ${ticket}`n"
                }

                $msg = "`n   This branch is currently checked-out in $($WORKING_REPO.ToUpper()).`n" +
                        "   Checking out another branch (${anyRel}) in order to enable the deletion...`n`n" +
                        "   If you will get 'Please commit your changes or stash them before you switch branches',`n" +
                        "   resolve the issue in a Git client app and re-run:`n" +
                        "   d ${ticket}`n"
                PrintMsg $msg
                [string] $gitResult = git checkout $anyRel 2>&1
                if ($LASTEXITCODE -ne 0) { throw "Cannot check out ${anyRel}.`n`n${gitResult}" }
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
                            PrintMsg "      Deletion of this branch is skipped. After you merge it (or make sure it's fully merged), re-run this command to complete the deleting: d ${ticket}"
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
        
        if ($atLeastOneBranchIsDeleted) {
            [string[]] $reposToRefresh = @($WORKING_REPO) + (CsvToArray $REPOS_TO_REFRESH_CSV)
            foreach ($repo in $reposToRefresh) {
                Set-Location "${GIT_FOLDER_PATH}\${repo}" -ErrorAction Stop
                PrintMsg "`nFetching $($repo.ToUpper()) to prune the remote/ pointers to the deleted branches..."
                git fetch --prune
            }
        }
        
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
