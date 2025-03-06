Jira-integrated Git Automation Scripts

NOTE: In this manual and the scripts, BASE branches are referred to as "releases," while FEATURE branches are simply called "branches."

####### The commands overview:

There are three PowerShell commands for Git operations, each represented by a single letter — c, b, or d — to speed up typing:

c - Create branches
b - Backport commit
d - Delete branches

Each command accepts the ticket number as a parameter. The 'b' command also takes the source commit hash.
If any parameter is not provided, you'll be prompted to enter it.
So, you can simply type 'c', 'b', or 'd', press Enter and follow the on-screen instructions.
If any unexpected situations occur, the scripts will guide you on how to proceed.
Using these commands is straightforward — you don't need to study this manual in detail.

####### Error handling:

The scripts stop execution as soon as an error is encountered — you will see the error message immediately without needing to scroll.
You can launch a script and work on something else in the meantime, without worrying about missing an error buried among other messages.

If a script fails after processing some branches successfully, you can fix the issue and then run the script with the same parameter(s) again.
The branches that have already been processed (created, backported, or deleted) will be skipped without any errors.
That if useful in the next situations:
1. You have created branches, and then a new release is added to the ticket.
2. The backport script is aborted due to a conflict. After resolving the conflict, rerun 'b' to complete the remaining backports.
3. You have deleted some branches manually, but not all of them. The 'd' script will delete only those which still exist.

####### The supplied files:

The setup consists of 4 PowerShell files:

Commands.ps1 – the main logic of the commands.
HelperFunctions.ps1 – auxiliary functions refactored into a separate file.
RegisterCommands.ps1 – the script to make the commands available in PowerShell.
Settings.ps1 – personal customizations in the form of constants (the only file you can change); can be opened by running the 's' command.

####### Releases management:

The releases on which the commands operate are stored in the RELS_CSV constant.
 
'c' creates branches for all the releases in RELS_CSV.
'b' backports into all the releases in RELS_CSV except for the first (DEV) release.
'd' deletes all the branches which exist for the ticket, regardless of RELS_CSV.

OVERRIDING RELS_CSV:

The 'c' and 'b' commands can also accept a custom list of releases separated by comma as their additional, optional parameter.
The list will be used only on this specific run instead of RELS_CSV.
This option allows you to use non-standard releases in exceptional situations without having to temporarily change RELS_CSV.
You will rarely need to use this feature.
Be careful not to include spaces after the commas since space is a parameters separator.

####### Before you start:

1. Run RegisterCommands.ps1 in PowerShell (change C:\GIT_SCRIPTS to your actual path):
powershell.exe -ExecutionPolicy Bypass -File "C:\GIT_SCRIPTS\RegisterCommands.ps1"

2. Go to Settings.ps1 and populate all the constants which are NOT marked as OPTIONAL.

Notice the DEFAULT_TICKET_PREFIX constant. If you populate it, then you can provide only the digits to the commands.
For example, if it's "ABC", then you can send ABC-12345 or just 12345.

####### The 'c' command - Create branches:

c ABC-12345

Before creating the branches, 'c' Pulls the working repo. That ensures you will change the freshest version of the objects.
Tip: run 'c' just before you start working on the ticket, not in advance — to decrease the chance of future conflicts.

CONFIRMATION DIALOG:

Shows two lists to review - the releases, for which you are going to create branches, and the ticket's "Fix Version/s".
Pulls your attention if there is a mismatch in the releases' quantities.
If a mismatch is found, you want to abort the script and edit RELS_CSV to make the lists fit.
To speed this up, clicking No automatically opens the Settings file for you to set the correct releases.
The message is shown even if there is no mismatch in the releases' quantities - to review the releases themselves.

The purpose of the confirmation dialog is to prevent creation of branches for wrong releases in the next situations:
1. The standard releases set has changed; the ticket's "Fix Version/s" reflect the new set, but RELS_CSV still contains the old set.
2. The standard releases set has changed; RELS_CSV contains the new set, but the ticket still needs to be backported into the old set.
3. The ticket has different releases than the previously processed ticket, but RELS_CSV still contains the releases of the previous ticket.

If the standard releases set has changed, it’s important to update RELS_CSV immediately.
Otherwise, you might encounter a situation where there is no mismatch in the confirmation dialog, but both the lists are wrong.

The dialog’s header shows the current local repository, so you check it if you work with multiple repositories.

If everything is good and you click Yes to continue, the branches creation process starts, and the progress is shown.

AUTOMATIC RECOVERY:

The script solves some of the problems encountered by itself, saving you from having to do it manually in Git.

You can rerun 'c' for the same ticket to ensure that branches exist locally and remotely for all the releases of RELS_CSV. The recovery logic:
1. A branch, mistakenly deleted from locals, is re-created to point exactly where the remote branch is.
2. A branch, mistakenly deleted from remotes, is re-published from locals.
3. If a new release was added to RELS_CSV after the previous run of 'c', create a branch for it. If it's the first time a feature branch is being created for that bas branch, the script creates it locally, printing this message: "'<release name>' is not recognized on LOCALS. It could be a new release just added to the project. Downloading it..."
 
BONUS TRACK:

'c' also creates a dedicated folder to store any ticket-related files (see " Folders for tickets' artefacts" below).

####### The 'b' command – Backport commit:

Accepts the ticket's number and the source commit hash:
b ABC-12345 4411d95

HOW TO OBTAIN THE COMMIT HASH:

In the DEV Pull Request, find (Ctrl+F) 'merged commit' - you will see '[your_name] merged commit [commit_hash] into [release]'.
Tip: immediately after the DEV Pull Request’s "Squash & Merge ", grab its commit hash and run the 'b' command.

CONFIRMATION DIALOG:

Shows two lists to review - the releases, into which you are going to backport, and the ticket's "Fix Version/s".
Pulls your attention if there is a mismatch in the releases' quantities.
   
Again, if you abort the process, the Settings file is opened automatically for you to edit RELS_CSV.

The purpose of the confirmation dialog is to prevent backport into wrong releases in the next situations:
1. RELS_CSV was changed after the ticket’s branches creation, but the ticket’s "Fix Version/s" still reflect the old picture.
2. The "Fix Version/s" were changed after the branches creation since it was decided to backport the ticket to other releases.
3. The ticket has different releases than the previously processed ticket, but RELS_CSV still contains the releases of the previous ticket.

If everything is good and you click Yes to continue, the backporting process starts, and the progress is shown.

CONFLICTS:

If a conflict occurs, a message is printed suggesting that you resolve it using a Git client app.
If the failed release was not the last one to backport into, you are provided with the ready-to-use command to complete the remaining backports.
Additionally, a dialog appears, allowing you to click Yes to complete the remaining backports immediately, without manually re-running 'b'.

AUTOMATIC RECOVERY:

If a new backport release was added to RELS_CSV in the time between creating branches and backporting, no branch exists for it.
But you are relieved of worries in this regard - the script will automatically create the missing branch and include it in the backports.
Also, 'b' restores any branches which were mistakenly deleted from either locals or remotes - the same way the 'c' command does it.

BONUS TRACK:

At the end, 'b' opens the URLs to create Pull Requests for all successful backports in the default browser.
The "base:" dropdown will be pre-populated with the correct release, so you only need to click "Create pull request".

PRs for the failed backports should be created from the Git client where you resolve the problem and complete the backport.
That’s why the conflict error message reminds: "create the pull request also there".

If you don't want the browser to popup and interrupt your work, set CREATE_BACKPORT_PRS to $false.
In this case, the PowerShell commands to open the URLs will be printed on the screen, so you can execute them later.

####### The 'd' command - Delete branches:

Deletes ALL the branches of the ticket (including the DEV branch) from both REMOTES and LOCALS.
Run it when you have squashed and merged all the backport PRs.

d ABC-12345

The confirmation dialog is displayed only if the CONFIRM_DELETING_BRANCHES constant is $true.
 
If one of the branches is current (checked-out) in the repo, it cannot be deleted.
The good news is that the command automatically switches to another branch to remove the stopper, so you don’t need to do anything.

####### Folders for tickets' artefacts:

Many developers manage tickets using dedicated folders where they place related files.
Each such folder usually has a text file named after the ticket - for remarks, related SQLs, TODOs etc.
In addition to creating the branches, the 'c' command creates a dedicated folder for each new ticket.
If you want to manage tickets with such folders, populate the TICKETS_FOLDER_PATH constant with yours (like "C:\DEV\Tickets").
Otherwise leave it blank.

For this functionality to work, two conditions must be met:
1. Your tickets folder contains a template folder XXXXX.
3. That folder contains a template file named XXXXX.txt.

For each new ticket, the XXXXX folder is cloned with whatever inside (so you can create any files or sub-folders within it).
The cloned folder name is generated as the ticket's name (number) + title.

You don't need to create the XXXXX folder and file!
When the 'c' script is executed for the first time and doesn’t find them in your tickets folder, it creates them automatically.
For example, if the first run is "c 11111", you will get the following structure:

ABC-11111 The ticket's title
  └── ABC-11111 The ticket's title.txt
XXXXX
  └── XXXXX.txt

After the next run (let's say, "c 22222"):

ABC-11111 The ticket's title
  └── ABC-11111 The ticket's title.txt
ABC-22222 The ticket's title
  └── ABC-22222 The ticket's title.txt
XXXXX
  └── XXXXX.txt

THE XXXXX.txt FILE:

The script creates it with this content:

_TICKET_NAME_ _TICKET_TITLE_
_DEV_PR_CREATION_URL_

When XXXXX.txt is cloned together with its parent XXXXX folder for each new ticket, the placeholders are substituted with the actual values.

EXPLANATION:

Line 1:
Ready to be copied to the required "Description" field of your Git client app when you commit.

Line 2:
The URL to double-click when it's time to create the DEV PR.
You can create it from a Git client, but then you need to populate the "base:" dropdown manually.

You can add to that template any stuff you want, and do whatever with the placeholders – remove, change location, or add more occurrences.
