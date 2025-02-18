Jira-integrated Git automation PowerShell scripts to create/delete feature branches and backport commits to other releases.

There are 3 PowerShell commands for the Git operations. The name of each consists of only one letter - c, b or d:

c - "C"reate Branches
b - "B"ackport Commit
d - "D"elete Branches

Also, there is an additional command:

s - Open the "S"ettings file (Settings.ps1) which contains all the constants, mentioned in this manual.

REMARKS:
* The scripts for 4 the commands are in the Commands.ps1 file.
* In the context of these commands, BASE branches are always called "releases", and FEATURE branches - just "branches".

##################################################################################################################################
STEPS TO DO BEFORE YOU START:
##################################################################################################################################

Make the 'c', 'b', 'd' and 's' commands available by running the RegisterCommands.ps1 file - just paste its full path into PowerShell and press Enter.

Go to the Settings.ps1 file (by running the 's' command) and populate all the constants which are NOT marked as OPTIONAL.

##################################################################################################################################
RELS_CSV:
##################################################################################################################################

The RELS_CSV constant must contain a comma-separated list of the releases (base branches).
The first is the DEV release (mandatory), the others are backport releases (optional).
Example: "dev-rel,first-backport-rel,second-backport-rel,third-backport-rel"

##################################################################################################################################
COMMANDS DESCRIPTION:
##################################################################################################################################

####### c - 'C'REATE branches:

Accepts the ticket's number:

c ABC-11111

Creates branches for all the releases in RELS_CSV.
Important! Don't forget to update RELS_CSV each time the project's standard releases change.

The command pulls the repo before it creates the branches. That ensures you will be working on the freshest version of the objects.
So, run 'c' just before you start working on the ticket, not in advance - to decrease a chance of future conflicts.

CONFIRMATION MESSAGE

When you run 'c', a confirmation message is displayed.
It shows two lists for you to review - the releases, for which you are going to create branches (RELS_CSV), and the ticket's "Fix Version/s".
If there is a discrepancy, you can abort and fix RELS_CSV to make the lists fit.
After you abort, another message is shown which suggests to open the Settings file for you.

THE REMOTE/ POINTERS TO THE CREATED BRANCHES:

By default, they are added only to the repository whose name is in the WORKING_REPO constant.
If you want them in any other repos, populate the REPOS_TO_REFRESH_CSV constant.

BONUS TRACK:

'c' also creates a dedicated folder to store any ticket-related files (see "FOLDERS FOR TICKETS' ARTEFACTS" below).


####### b - 'B'ACKPORT:

Accepts the ticket's number and the source commit hash:

b ABC-11111 aa11bb2

Backports into all the releases in RELS_CSV other than the DEV release.
For the example above, will backport into first-backport-rel, second-backport-rel and third-backport-rel.

HOW TO OBTAIN THE COMMIT HASH:

In the DEV Pull Request, find (Ctrl+F) 'merged commit' - you will see '[your_name] merged commit [commit_hash] into [release]'.
Tip: immediately after squashing & merging the DEV Pull Request, copy its commit hash and run the 'b' command.

CONFIRMATION MESSAGE

When you run 'b', a confirmation message is displayed very similar to the message in the 'c' command.
Its purpose is to prevent backport into wrong releases in the next situations:
1. The project has more than one standard releases set, and RELS_CSV could contain another set, remained after the previous ticket.
2. A release was removed from the project (and from RELS_CSV) after the feature branches 'c'reation, but it's still in "Fix Version/s" since the ticket needs to be backported into it. If you are in doubt, ask the BA - maybe, the ticket doesn't need to be backported into it, so the obsolete release must be removed from "Fix Version/s".
3. The ticket's "Fix Version/s" field could change after the feature branches 'c'reation, especially if an initial mistake was fixed.

There can be another situation - a new backport release was added to both RELS_CSV and "Fix Version/s" after the feature branches 'c'reation.
Both the lists in the confirmation message are missing it, but they fit each other, so there is nothing suspicious.
If you decide to continue, this situation will be captured with a hard error since you try to backport into a release for which no feature branch exists.
The solution: Create the missing branch for the new release by re-running the 'c' command - releases with already existing branches will be skipped.

CONFLICTS:

If you get a conflict, a message is displayed suggesting resolving it in a Git client (such as GitHub Desktop, Visual Studio or Visual Studio Code).
If the failed release is not the last one, the message instructs you to run 'b' again to complete the remaining backports.

BONUS TRACK:

At the end, 'b' opens in the default browser the URLs to create Pull Requests for all successful backports.
The "base:" dropdown will be pre-populated with the correct release, so you only need to click "Create pull request".
PRs for the failed backports should be created from the Git client where you resolve the problem and complete the backport.
If you don't want the browser to popup and interrupt your work, set CREATE_BACKPORT_PRS to $false.
In this case, the PowerShell commands to open the URLs will be printed on the screen, so you can execute them later.


####### d - 'D'ELETE branches:

Accepts the ticket number:

d ABC-11111

Run it when you have squashed and merged ALL the backport PRs.

The script deletes ALL the branches 'c'reated for the ticket (including the DEV branch), from both remotes and locals - regardless of RELS_CSV.

##################################################################################################################################
REMARKS:
##################################################################################################################################

If your project has a most frequently used ticket prefix (such as "ABC-"), store it in the DEFAULT_TICKET_PREFIX constant.
That prefix will be added automatically if you provide only the digits - "12345" will be interpreted same as "ABC-12345".

If any parameter is not provided, you will be prompted to enter it. So, you can simply type 'c', 'b' or 'd', press Enter and follow the instructions.

'b' can work only with branches created with 'c' (not through Jira). 'd' deletes any branches.

##################################################################################################################################
ERROR HANDLING:
##################################################################################################################################

The scripts stop execution after the first encountered error - you will see the error message immediately, with no need to scroll up.
So, you can launch a script and do another work meanwhile, with no fear of missing an error.

If any script fails after some branches were processed successfully, you can fix the issue and re-run the script with the same parameter(s).
The already processed ('c'reated, 'b'ackported or 'd'eleted) branches will be skipped with no errors.

##################################################################################################################################
FOLDERS FOR TICKETS' ARTEFACTS:
##################################################################################################################################

Many developers manage tickets using dedicated folders where they place related files.
Each such folder usually has a text file named after the ticket - for remarks, related SQLs, TODOs etc.
In addition to creating the branches, the 'c' command creates a dedicated folder for each new ticket.
If you want to manage tickets with such folders, populate the TICKETS_FOLDER_PATH constant with yours (like "C:\DEV\Tickets").

The 'c' script assumes that:

1. Your tickets folder contains a template folder named XXXXX.
3. The XXXXX folder contains the template XXXXX.txt file.

That XXXXX template folder will be cloned (with whatever inside) by 'c' for each ticket, with the folder name as the ticket's name (number) and title.

You don't need to create the XXXXX folder and file!
The script will create it on the first run, with the XXXXX.txt file within it.
For example, if the first run (when your tickets folder is empty) is "c ABC-11111", you will get the following structure in the tickets folder:

XXXXX
	XXXXX.txt
ABC-11111 The ticket's title
	ABC-11111 The ticket's title.txt

After the next run (let's say, "c 22222") you will have this structure:

XXXXX
	XXXXX.txt
ABC-11111 The ticket's title
	ABC-11111 The ticket's title.txt
ABC-22222 The ticket's title
	ABC-22222 The ticket's title.txt

The ticket's title is added to make it easy to find the needed folder in the file explorer, or the file among the tabs of Notepad++ when a few tickets are in progress simultaneously.

The XXXXX.txt file, automatically created by the script, will have the next fragment:

_TICKET_NAME_ _TICKET_TITLE_
Hi <write the tester name here>, https://tylerjira.tylertech.com/browse/_TICKET_NAME_ is ready for peer review.
_DEV_PR_CREATION_URL_

When XXXXX.txt is cloned together with its parent XXXXX folder, the 'c' script will substitute the placeholders with the actual values.
The only thing you need to do manually within the created XXXXX.txt is change <write the tester name here> to the actual tester name.

EXPLANATION:

Line 1 can be copied to the required "Description" field when you commit.
Line 2 is the message ready to be copied to Teams when it's time for the peer review. It also allows to quickly open the ticket from Notepad++ by double-clicking the link.
Line 3 is the URL to double-click when it's time to create the DEV PR. You can create it from a Git client, but then you will need to populate the "base:" dropdown manually.

You can remove any placeholders from your XXXXX.txt or change their location.