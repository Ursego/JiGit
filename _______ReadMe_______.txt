JiGit - Jira-integrated Git automation PowerShell scripts to create/delete feature branches and backport (cherry-pick, retrofit) from DEV to other releases in an agile environment with many Jira tickets backported to many releases.

##################################################################################################################################
COMMANDS DESCRIPTION:
##################################################################################################################################

There are 3 commands. The name of each consists of only one letter - c, b or d:

c - "C"reate Branches
b - "B"ackport Commit
d - "D"elete Branches

REMARKS:
* In the context of these commands, BASE branches are always called "releases", and FEATURE branches - just "branches".
* The scripts for 3 the commands are in the Commands.ps1 file.
* All the constants, mentioned in this manual, are in the Settings.ps1 file.


####### c - 'C'REATE branches:

Accepts the tickets numbers CSV (Comma-Separated Values):

c ABCD-11111,ABCD-22222,ABCD-33333,ABCD-44444

Branches are created for all the tickets, each ticket - for all the releases in the DEV_REL and DEFAULT_BACKPORT_RELS_CSV constants combined.
In the beginning of the sprint, run the 'c' command for all the tickets you got.
Important! Each time the project's standard backport releases set is changed, don't forget to update DEFAULT_BACKPORT_RELS_CSV.

WHAT IF I NEED TO BACKPORT ONLY INTO A PART OF THE STANDARD BACKPORT RELEASES?

Don't worry about that when 'c'reating branches - the actual backport releases will be defined later, when you 'b'ackport.
In this scenario, some unnecessary branches are 'c'reated, but they will be 'd'eleted at the end.
This approach allows to always run 'c' for all new tickets at one stroke, without having to think about which ticket should be backported to where.

THE REMOTE/ POINTERS TO THE CREATED BRANCHES:

By default, they are added only to the repository whose name is in the WORKING_REPO constant.
If you want them in any repos other than the working, populate the REPOS_TO_REFRESH_CSV constant.

BONUS TRACK:

For each ticket, 'c' creates a dedicated folder to store any ticket-related files (see "FOLDERS FOR TICKETS' ARTEFACTS" below).


####### b - 'B'ACKPORT:

Accepts 3 parameters: the ticket number, the source commit hash and (optionally) the backport target releases CSV:

b ABCD-11111 da0b7e4 rel1,rel2,rel3

HOW TO OBTAIN THE COMMIT HASH:

In the DEV Pull Request, find (Ctrl+F) 'merged commit' - you will see '[your_name] merged commit [commit_hash] into [release]'.
Tip: immediately after creating the DEV Pull Request, grab its commit hash and run the 'b' command.

THE RELEASES PARAMETER:

If it's omitted, the releases are taken from DEFAULT_BACKPORT_RELS_CSV.
The parameter allows to backport into only a part of the releases in DEFAULT_BACKPORT_RELS_CSV, and into releases which are not in DEFAULT_BACKPORT_RELS_CSV.

There are 2 typical situations when you will pass the releases as a parameter since DEFAULT_BACKPORT_RELS_CSV is not good for the ticket.

PARTIAL BACKPORT:

The situation: the ticket is designed to be backported only into a part of the standard releases and has less "Fix Version/s" than DEFAULT_BACKPORT_RELS_CSV.
The solution: pass ONLY the relevant releases to 'b' as a parameter.
This situation is captured - a confirmation message is shown if you are backporting into a different number of backport releases than there are in "Fix Version/s".

A RELEASE WAS RECENTLY REMOVED FROM THE PROJECT:

The situation: you recently removed a release from DEFAULT_BACKPORT_RELS_CSV but it's still in the ticket's "Fix Version/s" and you need to backport into it.
The solution: pass ALL the releases to 'b' as a parameter (including the release removed from DEFAULT_BACKPORT_RELS_CSV).
Alternatively, you can temporarily restore that release in DEFAULT_BACKPORT_RELS_CSV and run 'b' with no releases parameter, but don't forget to clean up immediately after.
This situation is captured - a confirmation message is shown if you are NOT backporting into a release for which a feature branch exists.

There is another situation. It doesn't require sending the releases parameter but let's consider it for completeness.

A RELEASE WAS RECENTLY ADDED TO THE PROJECT:

The situation: a new backport release was recently added to DEFAULT_BACKPORT_RELS_CSV and "Fix Version/s" but the ticket has no feature branch for it since you ran 'c' a while ago.
The solution:
	1. Create a branch for that release (just re-run 'c' for the ticket - releases with existing branches will be skipped).
	2. Re-run 'b' with no releases parameter.
This situation is captured - a hard error is shown if you try to backport into a release having no feature branch.

CONFLICTS:

If you get a conflict, a message is displayed suggesting to resolve it in a Git client (such as GitHub Desktop, Visual Studio or Visual Studio Code).
The message says what to do next and prints the 'b' command to complete the remaining backports (if any) after you resolve the conflict.

BONUS TRACK:

At the end, 'b' opens in the default browser the URLs to create Pull Requests for all successful backports.
PRs for failed backports should be created from the Git client where you resolve the problem and complete the backport.
The "base:" dropdown will be pre-populated with the correct release, so you only need to click "Create pull request".
If you don't want the browser to popup and interrupt your work, set CREATE_BACKPORT_PRS to $false.
In this case, the PowerShell commands to open the URLs will be printed on the screen, so you can execute them later.

####### d - 'D'ELETE branches:

Accepts the ticket number:

d ABCD-11111

Run it when you have squashed and merged ALL the backport PRs.

The script deletes ALL the branches 'c'reated for the ticket (including the DEV branch), from both remotes and locals.

##################################################################################################################################
REMARKS:
##################################################################################################################################

Run the commands in PowerShell, NOT in Windows Command Prompt.

There should be no spaces in the CSVs since spaces delimit parameters.

If your project has a most frequently used ticket prefix (such as "ABCD-"), store it in the DEFAULT_TICKET_PREFIX constant.
It will be added automatically if you provide only the digits part of the ticket number ("12345" => "ABCD-12345").

All the parameters (excluding the backport releases parameter to 'b') are mandatory.

If any of them is not provided, you will be prompted to enter it. So, you can simply type 'c', 'b' or 'd', press Enter and follow the instructions.

'b' can work only with branches created with 'c' (not through Jira). 'd' deletes any branches.

##################################################################################################################################
TO DO BEFORE YOU RUN A COMMAND:
##################################################################################################################################

Go to the Settings.ps1 file and populate all the constants which are NOT marked as OPTIONAL.

Make the 'c', 'b' and 'd' commands available by running the RegisterCommands.ps1 file - paste its full path into PowerShell and press Enter.

##################################################################################################################################
ERROR HANDLING:
##################################################################################################################################

The scripts stop execution after the first encountered error - you will see the error message immediately, with no need to scroll up.
So, you can launch a script and do another work meanwhile, with no fear of missing an error.
The error is also shown as a Windows popup (can be suppressed by setting DISPLAY_ERROR_POPUP to $false).

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

That XXXXX template folder will be cloned (with whatever inside) by 'c' for each ticket, with the folder name as the ticket name.

If your ticket folder doesn't contain a sub-folder named XXXXX, the script will create it on the first run, with the XXXXX.txt file within it.
For example, if the first run is "c ABCD-11111", you will get the following structure in your tickets folder:

XXXXX
	XXXXX.txt
ABCD-11111
	ABCD-11111.txt

After the next run (let's say, "c 22222,33333") you will have this structure:

XXXXX
	XXXXX.txt
ABCD-11111
	ABCD-11111.txt
ABCD-22222
	ABCD-22222.txt
ABCD-33333
	ABCD-33333.txt

The XXXXX.txt file, automatically created by the script, will have the next fragment:

_TICKET_NAME_ _TICKET_TITLE_
CLIENT: _TICKET_CLIENT_
<Jira URL taken from the JIRA_URL constant>/browse/_TICKET_NAME_
_DEV_PR_CREATION_URL_

When XXXXX.txt is cloned together with its parent XXXXX folder, the 'c' script will substitute the placeholders with the actual values.
The only thing you need to do manually within the created XXXXX.txt is change <write the tester name here> to the actual tester name.

EXPLANATION:

Line 1 can be copied to the required "Description" field when you commit.
Line 2 helps to recall the client while working within the txt file (with no need to open the ticket).
Line 3 allows to quickly open the ticket from Notepad++ by double-clicking the link - instead of searching in the Jira board.
Line 4 is the URL to double-click when it's time to create the DEV PR. You can create it from a Git client, but then you will need to populate the "base:" dropdown manually.

You can remove any placeholders from your XXXXX.txt or change their location.