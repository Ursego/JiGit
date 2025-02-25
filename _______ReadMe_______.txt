Jira-integrated Git Automation Scripts

NOTE: In this manual and the scripts, BASE branches are referred to as "releases," while FEATURE branches are simply called "branches".

####### The commands overview:

There are three PowerShell commands for Git operations, each represented by a single letter — c, b, or d — to speed up typing:

c - Create branches
b - Backport commit
d - Delete branches

Each command accepts the ticket number as a parameter, and the 'b' command also takes the source commit hash.
If any parameter is not provided, you'll be prompted to enter it.
You can simply type 'c', 'b', or 'd', press Enter and follow the on-screen instructions.
If any unexpected situations occur, the scripts will guide you on how to proceed.
Using these commands is straightforward — you don't need to study this manual in detail.

####### Error handling:

The scripts stop execution as soon as an error is encountered — you will see the error message immediately without needing to scroll.
You can launch a script and work on something else in the meantime, without worrying about missing an error buried among other messages.

If a script fails after successfully processing some branches, you can fix the issue and re-run the script with the same parameter(s).
The branches that have already been processed (created, backported, or deleted) will be skipped without any errors.

####### The supplied files:

The setup consists of 4 PowerShell files:

Commands.ps1 – the main logic of the commands.
HelperFunctions.ps1 – auxiliary functions refactored into a separate file.
RegisterCommands.ps1 – the script to make the commands available in PowerShell.
Settings.ps1 – personal customizations in the form of constants (the only file you can change); can be opened by running the 's' command.

####### Releases management:

The releases are not passed to the commands as a parameter. Instead, they are stored in the RELS_CSV constant.

c – Creates branches for all the releases listed in RELS_CSV.
b – Backports the commit into all the releases in RELS_CSV except for the first (DEV) release.
d – Deletes all branches created for the ticket, regardless of RELS_CSV, which may change over time.

####### Do before you start:

1. Run RegisterCommands.ps1 in PowerShell (change C:\GIT_SCRIPTS to your actual path):
powershell.exe -ExecutionPolicy Bypass -File "C:\GIT_SCRIPTS\RegisterCommands.ps1"

2. Go to Settings.ps1 and populate all the constants which are NOT marked as OPTIONAL.
The DEFAULT_TICKET_PREFIX constant can be populated with the ticket prefix used most frequently (without the dash).
In this case, the commands can accept the ticket number as digits only — the prefix with the dash will be added automatically.
For example, if the constant contains 'ABC', the next two calls are identical:
c ABC-12345
c 12345

####### The 'c' command - Create branches:

c 12345

Pulls the repo before creating the branches. That ensures you will be working on the freshest version of the objects.
Run 'c' just before you start working on the ticket, not in advance—to decrease the chance of future conflicts.

CONFIRMATION DIALOG:

Shows two lists to review - the releases, for which you are going to create branches (from RELS_CSV), and the ticket's "Fix Version/s".
Pulls your attention if there is a mismatch in the releases' quantities.
 
If a mismatch is found, you want to abort the script and edit RELS_CSV to make the lists fit.
To speed this up, clicking No will automatically open the Settings file for you to set the correct releases.
 
Save the Settings file and run the 'c' command again.

The message is shown even if there is no mismatch in the releases' quantities, so you can review the releases themselves.

The purpose of the confirmation dialog is to prevent creation of branches for wrong releases in the next situations:

1. The standard releases set has changed; the ticket's "Fix Version/s" reflect the new set, but RELS_CSV still contains the old set.
2. The standard releases set has changed; RELS_CSV contains the new set, but the ticket still needs to be backported into the old set.
3. The ticket has different releases than the previously processed ticket, but RELS_CSV still contains the releases of the previous ticket.

If the standard releases set has changed, it’s important to update RELS_CSV immediately.
Otherwise, you might encounter a situation where there is no mismatch in the message, but both lists are wrong.
If the releases are good and you click Yes to continue, the branches creation process starts, and the progress is shown.
 
BONUS TRACK:

'c' also creates a dedicated folder to store any ticket-related files (see " Folders for tickets' artefacts" below).

####### The 'b' command – Backport commit:

Accepts the ticket's number and the source commit hash:
b 12345 4c11d95

HOW TO OBTAIN THE COMMIT HASH:

In the DEV Pull Request, find (Ctrl+F) 'merged commit' - you will see '[your_name] merged commit [commit_hash] into [release]'.
 
Tip: immediately after the DEV Pull Request’s "Squash & Merge ", grab its commit hash and run the 'b' command.

CONFIRMATION DIALOG:

Shows two lists to review - the releases, into which you are going to backport (from RELS_CSV), and the ticket's "Fix Version/s".
Pulls your attention if there is a mismatch in the releases quantities.

Again, if you abort the process, the Settings file is open automatically for you to edit RELS_CSV.

The purpose of the confirmation dialog is to prevent backport into wrong releases in the next situations:
1. A release was removed from the project (and from RELS_CSV) after the feature branches creation, but it's still in "Fix Version/s" since the ticket needs to be backported into it. If you are in doubt, ask the BA - maybe, the ticket doesn't need to be backported into it, so the obsolete release must be removed from "Fix Version/s".
2. The ticket's "Fix Version/s" field could change after the feature branches creation if an initial mistake in that field was fixed.
3. The ticket has different releases than the previously processed ticket, but RELS_CSV still contains the releases of the previous ticket.

There can be another situation - a new backport release was added to both RELS_CSV and "Fix Version/s" after the feature branches creation.
Both the lists in the confirmation dialog are missing the new release, but the lists fit each other, so there is nothing suspicious.
If you click Yes to continue, this situation will be captured with a hard error since you are trying to backport into a release for which no feature branch exists.
The solution: Create the missing branch for the new release by re-running the 'c' command
It will create a branch for the new release, while the releases with already existing branches will be skipped.

VALIDATING BRANCHES:

Before backporting, the existence of all the feature branches in both locals and remotes is checked (some could be mistakenly deleted after the creation). If any is missing, an error is shown.
Running the 'c' command for the ticket restores any branches missing on either LOCALS or REMOTES.
After that, you can re-run 'b' with the same parameters.
If the releases and the branches are good, the backporting process starts, and the progress is shown.

CONFLICTS:

If you get a conflict, an error is displayed which suggests resolving the conflict in a Git client app.

If the failed release is not the last one to backport into, the message instructs you to run 'b' again to complete the remaining backport(s). 
Even though the already backported releases will be skipped, the script will still attempt to backport into them, which is time-consuming.
If you want to speed up the process, use partial backport sets for RELS_CSV, with the remaining releases only (besides the DEV release, of course).
 
You could ask: Wy to use the 'b' script to backport into one release only? Isn’t it easier just to backport in VS or GitHub Desktop?
Of course, you can do that. But I found that I preferred to use the script always - even for one release, when it doesn’t save my time.

BONUS TRACK:

At the end, 'b' opens the URLs to create Pull Requests for all successful backports in the default browser.
The "base:" dropdown will be pre-populated with the correct release, so you only need to click "Create pull request".
PRs for the failed backports should be created from the Git client where you resolve the problem and complete the backport.

If you don't want the browser to popup and interrupt your work, set CREATE_BACKPORT_PRS to $false.
In this case, the PowerShell commands to open the URLs will be printed on the screen, so you can execute them later.

####### The 'd' command - Delete branches:

Deletes ALL the branches of the ticket (including the DEV branch) from both REMOTES and LOCALS.
Run it when you have squashed and merged all the backport PRs.

d 12345

The confirmation dialog is displayed only if the CONFIRM_DELETING_BRANCHES constant is $true.

If one of the branches is current (checked-out) in the repo, it cannot be deleted.
The good news is that the command automatically switches to another branch and keeps deleting, so you don’t need to do anything.

####### Folders for tickets' artefacts:

Many developers manage tickets using dedicated folders where they place related files.
Each such folder usually has a text file named after the ticket - for remarks, related SQLs, TODOs etc.
In addition to creating the branches, the 'c' command creates a dedicated folder for each new ticket.
If you want to manage tickets with such folders, populate the TICKETS_FOLDER_PATH constant with yours (like "C:\DEV\Tickets"), otherwise leave it blank.

The 'c' script assumes that:
1. Your tickets folder contains a template folder named XXXXX.
3. The XXXXX folder contains the template XXXXX.txt file.

'c' clones that XXXXX folder (with whatever inside), with the folder name as the ticket's name (number) and title.

You don't need to create the XXXXX folder and file!
The script will create it on the first run, with the XXXXX.txt file within it.
For example, if the first run (when your tickets folder is still empty) is "c 11111", you will get the following structure:

ABC-11111 The ticket's title
  └── ABC-11111 The ticket's title.txt
XXXXX
  └── XXXXX.txt

After the next run (let's say, "c 22222") you will have this structure:

ABC-11111 The ticket's title
  └── ABC-11111 The ticket's title.txt
ABC-22222 The ticket's title
  └── ABC-22222 The ticket's title.txt
XXXXX
  └── XXXXX.txt

The ticket's title is added to make it easy to find the needed ticket when a few tickets are in progress simultaneously.
 
The XXXXX.txt file, automatically created by the script, will have this fragment:

_TICKET_NAME_ _TICKET_TITLE_
Hi <write the tester name here>, https://the-jira-url/browse/_TICKET_NAME_ is ready for peer review.
_DEV_PR_CREATION_URL_

When XXXXX.txt is cloned together with its parent XXXXX folder, the 'c' script will substitute the placeholders with the actual values.
The only thing you need to do manually within the created XXXXX.txt is change <write the tester name here> to the actual tester name.

EXPLANATION:
Line 1 can be copied to the required "Description" field when you commit.
Line 2 is the message for the tester when it's time for the peer review. It also allows to quickly open the ticket from Notepad++ by double-clicking the link.
Line 3 is the URL to double-click when it's time to create the DEV PR. You can create it from a Git client, but then you need to populate the "base:" dropdown manually.

You can do whatever you want with any placeholders in your XXXXX.txt – remove, change location, and add more occurrences.