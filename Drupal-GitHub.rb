
require 'octokit'
require 'feedzirra'
require 'nokogiri'
require 'open-uri'
require 'uri'

class DrupalGitHubIssues

	def gh_Authenticate(username, password)
		@ghClient = Octokit::Client.new(:login => username.to_s, :password => password.to_s, :auto_paginate => true)
	end

	def create_GH_Issue(repo, title, body, options)
		@ghClient.create_issue(repo.to_s, title.to_s, body.to_s, options)
	end

	def close_GH_Issue(repo, issueNumber, closeCode)
		closeText = "Automated Close Message... <br> Close Code: #{closeCode.to_s}"
		
		@ghClient.add_comment(repo.to_s, issueNumber, closeText)
		@ghClient.close_issue(repo.to_s, issueNumber)
	end

	def reOpen_GH_Issue(repo, issueNumber, reOpenComment)
		@ghClient.reopen_issue(repo.to_s, issueNumber)
		self.add_GH_Comment(repo, issueNumber, reOpenComment)
	end

	def add_GH_Comment(repo, issueNumber, commentText )
		@ghClient.add_comment(repo, issueNumber, commentText.to_s)
	end

	def get_Drupal_Issues(drupalProject, ghRepo, storeInGH = true, sync = true)
		rssURL = "https://drupal.org/project/issues/rss/#{drupalProject}"
		feed = Feedzirra::Feed.fetch_and_parse(rssURL)

		entriesAll = feed.entries

		drupalIssues = []
		
		entriesAll.each do |entry|
			page = Nokogiri::HTML(open(entry.url.to_s))
			drupalIssueID = URI(entry.url).path.split('/').last
			drupalIssueComponent = page.xpath(".//*[@id='block-project-issue-issue-metadata']/div/div/div[4]/div[2]/div/text()")
			drupalIssueVersion = page.xpath(".//*[@id='block-project-issue-issue-metadata']/div/div/div[3]/div[2]/div/text()")
			drupalIssueStatus = page.xpath(".//*[@id='block-project-issue-issue-metadata']/div/div/div[1]/div/div/text()") 
			drupalIssuePriority = page.xpath(".//*[@id='block-project-issue-issue-metadata']/div/div/div[5]/div[2]/div/text()")
			drupalIssueCategory = page.xpath(".//*[@id='block-project-issue-issue-metadata']/div/div/div[6]/div[2]/div/text()")
			drupalIssueCreateDateTime = page.xpath(".//*[@id='node-#{drupalIssueID}']/div[1]/time/text()")
			drupalIssueCreatedUserName = page.xpath(".//*[@id='node-#{drupalIssueID}']/div[1]/a/text()")

			entry.summary.concat("<br> <strong>To See Full Issue Go to: #{entry.url.to_s}</strong> <br><br> Issue Originally Created By: <strong>#{drupalIssueCreatedUserName.to_s}</strong>  at  <strong>#{drupalIssueCreateDateTime.to_s}</strong> <br> Component: #{drupalIssueComponent.to_s} <br> Version: #{drupalIssueVersion.to_s} <br> Priority: #{drupalIssuePriority.to_s} <br> Category: #{drupalIssueCategory.to_s} <br> Status: #{drupalIssueStatus.to_s} <br> Drupal Issue Node ID: #{drupalIssueID.to_s}")
			entry.title.concat("  (#{drupalIssueID})")

			if storeInGH == true
				case drupalIssueStatus.to_s
					when "Fixed"
						createdIssue = self.create_GH_Issue(ghRepo, entry.title, entry.summary, :labels => [drupalIssueComponent.to_s, drupalIssueCategory.to_s, drupalIssuePriority.to_s, drupalIssueVersion.to_s])
						close_GH_Issue(ghRepo.to_s, createdIssue.attrs[:number].to_s, drupalIssueStatus)
					when "Closed (fixed)"
						createdIssue = self.create_GH_Issue(ghRepo, entry.title, entry.summary, :labels => [drupalIssueComponent.to_s, drupalIssueCategory.to_s, drupalIssuePriority.to_s, drupalIssueVersion.to_s])
						close_GH_Issue(ghRepo.to_s, createdIssue.attrs[:number].to_s, drupalIssueStatus)
					when "Closed (works as designed)"
						createdIssue = self.create_GH_Issue(ghRepo, entry.title, entry.summary, :labels => [drupalIssueComponent.to_s, drupalIssueCategory.to_s, drupalIssuePriority.to_s, drupalIssueVersion.to_s])
						close_GH_Issue(ghRepo.to_s, createdIssue.attrs[:number].to_s, drupalIssueStatus)
					else
						createdIssue = self.create_GH_Issue(ghRepo, entry.title, entry.summary, :labels => [drupalIssueComponent.to_s, drupalIssueCategory.to_s, drupalIssuePriority.to_s, drupalIssueVersion.to_s])
				end
			else
				drupalIssues << {:issueNumber => drupalIssueID.to_i, :component => drupalIssueComponent.to_s, :version => drupalIssueVersion.to_s, :status => drupalIssueStatus.to_s, :priority => drupalIssuePriority.to_s, :category => drupalIssueCategory.to_s, :title => entry.title.to_s, :summary => entry.summary.to_s}
			end
		end
		puts drupalIssues
		return drupalIssues
	end

	def get_GH_Issues(repo)
		issueResultsOpen = @ghClient.list_issues(repo, {
			:state => :open
			})

		# Gets Closed Issues List - Returns Sawyer::Resource
		issueResultsClosed = @ghClient.list_issues(repo.to_s, {
			:state => :closed
			})

		mergedIssues = issueResultsOpen + issueResultsClosed
		issueIDs = []
		mergedIssues.each do |x|
			gitHubIssueTitle = x.attrs[:title]
			drupalIssueNumber = gitHubIssueTitle[gitHubIssueTitle.rindex('(')+1..gitHubIssueTitle.rindex(')')-1].to_i
			githubIssueNumber = x.attrs[:number].to_i
			githubIssueState = x.attrs[:state].to_s
			issueIDs << {:ghID => githubIssueNumber, :drupalID => drupalIssueNumber, :ghState => githubIssueState }
		end
		puts issueIDs
		return issueIDs
	end

	def update_GH_Issue(repo, issueNumber, commentText, labels = [])
		repo = repo.to_s
		issueNumber = issueNumber.to_i
		commentText = commentText.to_s
		self.add_GH_Comment(repo, issueNumber, commentText)

		@ghClient.remove_all_labels(repo, issueNumber)
		@ghClient.add_labels_to_an_issue(repo, issueNumber, labels)
		self.add_GH_Comment(repo, issueNumber, "Automated Message...<br>Labels have been updated to latest metadata from Drupal.org")
	end

	def determine_Drupal_GH_Changes(repo, drupalData, gitHubData)

		closeStates = ["Fixed", "Closed (fixed)", "Closed (works as designed"]
		
		drupalData.each do |dData|
			ghLabels = []
			ghLabels.push(dData[:component],dData[:version],dData[:status],dData[:priority],dData[:category])
			puts "Drupal issue Number from dData: #{dData[:issueNumber]}"
			newArray = gitHubData.find { |ghData| ghData[:drupalID] == dData[:issueNumber]}
			if newArray == nil
				self.create_GH_Issue(repo, dData[:title], dData[:summary], :labels => ghLabels)
			else
				if newArray[:ghState] == "open"
					if closeStates.include?(dData[:status].to_s) == true
						commentText = "Automated Message... <br> Issue status on Drupal.org has been changed to #{dData[:status]}.  GitHub Issue State has been updated to be equivalent" 
						self.update_GH_Issue(repo, newArray[:ghID], commentText, ghLabels)
						self.close_GH_Issue(repo, newArray[:ghID], dData[:status].to_s)
						puts "Change made to GitHub Issue Number: #{newArray[:ghID]}"
					end
				elsif newArray[:ghState] == "closed"
					if closeStates.include?(dData[:status].to_s) == false
						reOpenText = "Automated Message... <br> Issue has been reopened, Drupal.org status is now: #{dData[:status]}."
						self.reOpen_GH_Issue(repo, newArray[:ghID],reOpenText)
						commentText = "Automated Message... <br> Issue status on Drupal.org has been changed to #{dData[:status]}.  GitHub Issue State has been updated to be equivalent" 
						self.update_GH_Issue(repo, newArray[:ghID], commentText, ghLabels)	
						puts "Change made to GitHub Issue Number: #{newArray[:ghID]}"
					end
				end
			end
		end
	end
end
