###################################################################################################################################################
# The file contains all the customizable stuff. No vars or constants in OTHER files are allowed to be changed by the user!
# Any change in the constants is in effect immediately, with no need to restart PowerShell.
###################################################################################################################################################

[bool] $Global:DISPLAY_ERROR_POPUP = $true
[bool] $Global:DISPLAY_SUCCESS_POPUP = $false
[bool] $Global:CONFIRM_DELETING_BRANCHES = $true
[bool] $Global:CREATE_BACKPORT_PRS = $true # $false -> after backports, print the PR creation URLs on the screen instead of opening them in the browser
[string] $Global:TICKETS_FOLDER_PATH = "" # OPTIONAL # see _______ReadMe_______.txt >>> "FOLDERS FOR TICKETS' ARTEFACTS"
[string] $Global:DEFAULT_TICKET_PREFIX = "" # OPTIONAL # the most frequently used ticket prefix (with no dash) to be used if digits only are entered
[int] $DIGITS_IN_TICKET_NUM = 5 # the quantity of digits in ticket numbers

###################################################################################################################################################
# Releases:
###################################################################################################################################################

# The DEV release (base branch) into which you normally commit your changes:
[string] $Global:DEV_REL = "" # OPTIONAL

# The releases (base branches) into which you normally backport (the elements order defines the backports order):
[string] $Global:DEFAULT_BACKPORT_RELS_CSV = "" # OPTIONAL (like "rel1,rel2,rel3")

# REMARKS:
# 'c' creates branches for all the releases in DEV_REL & DEFAULT_BACKPORT_RELS_CSV.
# 'b' backports into all the releases in DEFAULT_BACKPORT_RELS_CSV (if the releases are not passes to it as a parameter).
# 'b' doesn't work with DEV_REL - the actual backport source release is defined by the commit hash.
# 'd' doesn't work with DEV_REL & DEFAULT_BACKPORT_RELS_CSV - it deletes all the ticket's branches which actually exist.

###################################################################################################################################################
# Repositories:
###################################################################################################################################################

# The URL of the GitHub server repository WITHOUT the .git extension.
# For example, if the URL is  "https://github.com/my-repo.git", make the constant "https://github.com/my-repo":
[string] $Global:REMOTE_GIT_REPO_URL = ""

# The full path of your local repositories folder (with NO slash at the end, like "C:\GitHub"):
[string] $Global:GIT_FOLDER_PATH = ""

# The name of the folder (under GIT_FOLDER_PATH) with the repository you normally use for commits and backports:
[string] $Global:WORKING_REPO = ""

# Repos other than working which you want to refresh:
#   after creating branches (to download their remote/ pointers), and
#   after deleting branches (to prune their remote/ pointers).
# Refreshing takes time, but we usually don't need the remote/ pointers in repos other than working (if you need them one day, just Pull the repo).
# So, consider declaring the constant blank to make 'c' and 'd' commands faster:
[string[]] $Global:REPOS_TO_REFRESH_CSV = "" # OPTIONAL (like "repo1,repo2,repo3")

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

