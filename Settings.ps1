###################################################################################################################################################
# This file contains all the customizable settings. No vars or constants in OTHER files are allowed to be changed by the user!
# Any change in the constants is in effect immediately after saving the file, with no need to restart PowerShell.
# This file can be open by running the 's' command.
###################################################################################################################################################
# Developer: Michael Zuskin https://www.linkedin.com/in/zuskin/
# This project on GitHub: https://github.com/Ursego/JiGit
###################################################################################################################################################

# A comma-separated list of releases. The first is the DEV release (mandatory), the others are backport releases (optional):
$Global:RELS_CSV = switch (2) { # <- change this number to the number of the set you want to use with the 'c' and 'b' commands
  1 { "dev-rel,bp-rel-1,bp-rel-2,bp-rel-3" } # the standard set
  4 { "another-dev-rel,bp-rel-4,bp-rel-5" }  # another standard set
}

###################################################################################################################################################
# Repositories:
###################################################################################################################################################

# The full path of your local repositories folder (with NO slash at the end, like "C:\GitHub"):
[string] $Global:GIT_FOLDER_PATH = ""

# The name of the folder (under GIT_FOLDER_PATH) with the repository you want to use for commits and backports:
[string] $Global:WORKING_REPO = switch (1) { # <- change this number to the number of the repo
  1 { "repo-one" }
  2 { "repo-two" }
  3 { "repo-three" }
}

# Repos (i.e. folder names under GIT_FOLDER_PATH) which you want to refresh (pull):
#   * after creating branches (to download their remote/<branch-name> pointers), and
#   * after deleting branches (to prune their remote/<branch-name> pointers).
# The working repo will be pulled anyway, so you don't need to add it.
# But you can add it if you frequently switch between working repos and want all other repos to be always refreshed. In this case, the working repo will not be pulled twice:
[string[]] $Global:REPOS_TO_REFRESH_CSV = "" # OPTIONAL
#[string[]] $Global:REPOS_TO_REFRESH_CSV = "repo-one,repo-two,repo-three" # OPTIONAL

# The URL of the GitHub server repository WITHOUT the .git extension.
# For example, if the URL is  "https://github.com/my-repo.git", make the constant "https://github.com/my-repo":
[string] $Global:REMOTE_GIT_REPO_URL = ""

###################################################################################################################################################
# Misc:
###################################################################################################################################################

[string] $Global:TICKETS_FOLDER_PATH = "" # OPTIONAL # if provided, the 'c' script will create folders for tickets' artefacts there

[bool] $Global:CONFIRM_DELETING_BRANCHES = $false # make the 'd' command show a confirmation dialog

[bool] $Global:CREATE_BACKPORT_PRS = $true # define how the 'b' command handles creating PRs for successfully backported releases:
      # $true  - open the PR-creating URLs in the default browser (which will pop up and interrupt your current work);
      # $false - print the PR-creating PowerShell command on the screen so you can copy and execute it later.

###################################################################################################################################################
# Jira integration:
###################################################################################################################################################

# The ticket prefix used most frequently (with no dash) to be used if digits only are entered.
# Example: if it's "ABC", the next two calls are identical: 'c ABC-12345', 'c 12345':
[string] $Global:DEFAULT_TICKET_PREFIX = "ABC" # OPTIONAL

# The organization's Jira URL (the highest-level link which opens the Jira Dashboard) with NO slash at the end.
# For example: if a ticket link is https://jira.atlassian.com/browse/JRASERVER-40549 then make it "https://jira.atlassian.com":
[string] $Global:JIRA_URL = ""

# Your Jira PAT (not the Git PAT!): Jira > click your pic in the upper right corner > Profile > Personal Access Tokens > Create token:
[string] $Global:JIRA_PAT = ""

# Your lowercase first and last names joined, like "billgates" for Bill Gates. MUST (!) be the same as in branches names created through Jira:
[string] $Global:DEVELOPER = ""

[int] $Global:DIGITS_IN_TICKET_NUM = 5