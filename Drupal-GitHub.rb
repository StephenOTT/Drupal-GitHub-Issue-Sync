require 'octokit'
require 'feedzirra'
require 'nokogiri'
require 'open-uri'

class DrupalGitHubIssues

	def initialize(ghUsername, ghPassword, ghRepo, drupalProject)
		self.gh_Authenticate(ghUsername, ghPassword)
		drupalData = self.get_Drupal_Issues(drupalProject)
		gitHubData = self.get_GH_Issues(ghRepo)
		self.determine_Drupal_GH_Changes(ghRepo, drupalData, gitHubData )
	end

	def gh_Authenticate(username, password)
		@ghClient = Octokit::Client.new(:login => username.to_s, :password => password.to_s, :auto_paginate => true)
	end

	def create_GH_Issue(drupalIssueStatus, ghRepo, title, body, options)

		case drupalIssueStatus.to_s
			when "Fixed"
				createdIssue = @ghClient.create_issue(ghRepo.to_s, title.to_s, body.to_s, options)
				self.close_GH_Issue(ghRepo.to_s, createdIssue.attrs[:number], drupalIssueStatus)
			when "Closed (fixed)"
				createdIssue = @ghClient.create_issue(ghRepo.to_s, title.to_s, body.to_s, options)
				self.close_GH_Issue(ghRepo.to_s, createdIssue.attrs[:number], drupalIssueStatus)
			when "Closed (works as designed)"
				createdIssue = @ghClient.create_issue(ghRepo.to_s, title.to_s, body.to_s, options)
				self.close_GH_Issue(ghRepo.to_s, createdIssue.attrs[:number], drupalIssueStatus)
			else
				createdIssue = @ghClient.create_issue(ghRepo.to_s, title.to_s, body.to_s, options)
		end
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

	def get_Drupal_Issues(drupalProject)
		rssURL = "https://drupal.org/project/issues/rss/#{drupalProject}?text=&status=All&priorities=All&categories=All&version=All&component=All"
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

			drupalIssues << {:issueNumber => drupalIssueID.to_i, :component => drupalIssueComponent.to_s, :version => drupalIssueVersion.to_s, :status => drupalIssueStatus.to_s, :priority => drupalIssuePriority.to_s, :category => drupalIssueCategory.to_s, :title => entry.title.to_s, :summary => entry.summary.to_s}
		end
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
		# puts issueIDs
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


	def get_Issue_Labels(repo, issueNumber)
		labelsSawyer = @ghClient.labels_for_issue(repo.to_s, issueNumber.to_i)
		labels = []
		labelsSawyer.each do |l|
			labels << l.attrs[:name]
		end
		return labels
	end

	def determine_Drupal_GH_Changes(repo, drupalData, gitHubData)

		closeStates = ["Fixed", "Closed (fixed)", "Closed (works as designed)"]
		
		drupalData.each do |dData|
			# ghLabels hows the new labels that are being pulled from Drupal.org
			ghLabels = []
			ghLabels.push(dData[:component],dData[:version],dData[:status],dData[:priority],dData[:category])
			puts ghLabels.sort.to_s
			
			# puts "Drupal issue Number from dData: #{dData[:issueNumber]}"
			newHash = gitHubData.find { |ghData| ghData[:drupalID] == dData[:issueNumber]}
			# puts "newHash Output:  #{newHash.to_s}"
			
			if newHash == nil
				# "null" is used as a plug -- refactor is needed for optional argument
				self.create_GH_Issue(dData[:status], repo, dData[:title], dData[:summary], :labels => ghLabels)
			else
				ghLabelsCurrentApplied = self.get_Issue_Labels(repo, newHash[:ghID])
				puts ghLabelsCurrentApplied.sort.to_s

				if newHash[:ghState] == "open"
					if ghLabelsCurrentApplied.sort != ghLabels.sort
						commentText = "Automated Message... <br> Issue metadata on Drupal.org has been changed. GitHub Labels have been updated to be equivalent to Drupal.org Issue Metadata. <br> Old Labels: #{ghLabelsCurrentApplied} <br> New Labels: #{ghLabels.sort}" 
						self.update_GH_Issue(repo, newHash[:ghID], commentText, ghLabels)	
						puts "Change made to GitHub Issue Number: #{newHash[:ghID]}"
					end
					if closeStates.include?(dData[:status].to_s) == true
						commentText = "Automated Message... <br> Issue status on Drupal.org has been changed to #{dData[:status]}.  GitHub Issue State has been updated to be equivalent" 
						self.update_GH_Issue(repo, newHash[:ghID], commentText, ghLabels)
						self.close_GH_Issue(repo, newHash[:ghID], dData[:status].to_s)
						puts "Change made to GitHub Issue Number: #{newHash[:ghID]}"
					end
				elsif newHash[:ghState] == "closed"
					if ghLabelsCurrentApplied.sort != ghLabels.sort
						commentText = "Automated Message... <br> Issue metadata on Drupal.org has been changed. GitHub Labels have been updated to be equivalent to Drupal.org Issue Metadata. <br> Old Labels: #{ghLabelsCurrentApplied} <br> New Labels: #{ghLabels.sort}" 
						self.update_GH_Issue(repo, newHash[:ghID], commentText, ghLabels)	
						puts "Change made to GitHub Issue Number: #{newHash[:ghID]}"
					end
					if closeStates.include?(dData[:status].to_s) == false
						reOpenText = "Automated Message... <br> Issue has been reopened, Drupal.org status is now: #{dData[:status]}."
						self.reOpen_GH_Issue(repo, newHash[:ghID],reOpenText)
						commentText = "Automated Message... <br> Issue status on Drupal.org has been changed to #{dData[:status]}.  GitHub Issue State has been updated to be equivalent" 
						self.update_GH_Issue(repo, newHash[:ghID], commentText, ghLabels)	
						puts "Change made to GitHub Issue Number: #{newHash[:ghID]}"
					end
				end
			end
		end
	end
end
