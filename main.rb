require './Drupal-GitHub.rb'

start = DrupalGitHubIssues.new
start.gh_Authenticate("USERNAME","PASSWORD") # ("GitHub Username","GitHub Password")
start.get_Drupal_Issues("wetkit", "StephenOTT/Test4") # ("durpal project name (name in url)", "Github OrgUser/RepoName")
