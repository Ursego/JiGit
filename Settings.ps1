###################################################################################################################################################
# The file contains all the customizable stuff. No vars or constants in OTHER files are allowed to be changed by the user!
# Any change in the constants is in effect immediately after saving the file, you don't need to restart PowerShell.
###################################################################################################################################################

[bool] $Global:CONFIRM_DELETING_BRANCHES = $false
[bool] $Global:CREATE_BACKPORT_PRS = $true # $false -> after backports, print the PR creation URLs on the screen instead of opening them in the browser
[string] $Global:TICKETS_FOLDER_PATH = "" # OPTIONAL # see _______ReadMe_______.txt >>> "FOLDERS FOR TICKETS' ARTEFACTS"
[string] $Global:DEFAULT_TICKET_PREFIX = "" # OPTIONAL # the most frequent ticket prefix (with no dash) to be used if digits only are entered
[int] $Global:DIGITS_IN_TICKET_NUM = 5

###################################################################################################################################################
# Releases:
###################################################################################################################################################

# A comma-separated list of the releases (base branches).
# The first is the DEV release (mandatory), the others are backport releases (optional).
# Example: "dev-rel,first-backport-rel,second-backport-rel,third-backport-rel"
$Global:RELS_CSV = switch (1) { # change the number to the number of the set you want to use
  1 { "dev-rel,first-backport-rel,second-backport-rel,third-backport-rel" } # the standard set
  2 { "another-dev-rel,fourth-backport-rel" } # another standard set
  3 { "dev-rel,second-backport-rel,third-backport-rel" } # to re-run 'b' after the backport into first-backport-rel failed
  4 { "dev-rel,third-backport-rel" } # to re-run 'b' after the backport into second-backport-rel failed
}

###################################################################################################################################################
# Repositories:
###################################################################################################################################################

# The URL of the GitHub server repository WITHOUT the .git extension.
# For example, if the URL is  "https://github.com/my-repo.git", makse the constant "https://github.com/my-repo":
[string] $Global:REMOTE_GIT_REPO_URL = ""

# The full path of your local repositories folder (with NO slash at the end, like "C:\GitHub"):
[string] $Global:GIT_FOLDER_PATH = ""

# The name of the folder (under GIT_FOLDER_PATH) with the repository you normally use for commits and backports:
[string] $Global:WORKING_REPO = switch (1) { # change the number to the number of the repo you want to use
  1 { "repo-one" }
  2 { "repo-two" }
  3 { "repo-three" }
}

# Repos other than working which you want to refresh:
#   after creating branches (to download their remote/ pointers), and
#   after deleting branches (to prune their remote/ pointers).
# Refreshing takes time, but we usually don't need the remote/ pointers in repos other than working (if you need them one day, just Pull the repo).
# So, consider declaring the constant blank to make 'c' and 'd' commands faster:
[string[]] $Global:REPOS_TO_REFRESH_CSV = "" # OPTIONAL

###################################################################################################################################################
# Jira integration:
###################################################################################################################################################

# The organization's Jira URL (the highest-level link which opens the Jira Dashboard) with NO slash at the end.
# For example: if a ticket link is https://jira.atlassian.com/browse/JRASERVER-40549 then make it "https://jira.atlassian.com":
[string] $Global:JIRA_URL = ""

# Your Jira PAT (not the Git PAT!): Jira > click your pic in the upper right corner > Profile > Personal Access Tokens > Create token:
[string] $Global:JIRA_PAT = ""

# Your lowercase first and last names joined, like "billgates" for Bill Gates. MUST (!) be the same as in branches names created through Jira:
[string] $Global:DEVELOPER = ""