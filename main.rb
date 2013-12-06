require './Drupal-GitHub.rb'

start = DrupalGitHubIssues.new
start.gh_Authenticate("USERNAME","PASSWORD") # ("GitHub Username","GitHub Password")
# start.get_Drupal_Issues("wetkit", "StephenOTT/Test4") # ("durpal project name (name in url)", "Github OrgUser/RepoName")
dIssues = start.get_Drupal_Issues("wetkit", "StephenOTT/Test4", false) # ("durpal project name (name in url)", "Github OrgUser/RepoName")
ghIssues = start.get_GH_Issues("StephenOTT/Test4")

start.determine_Drupal_GH_Changes("StephenOTT/Test4",dIssues,ghIssues)	