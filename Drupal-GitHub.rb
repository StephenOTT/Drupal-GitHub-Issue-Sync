
require 'octokit'
require 'feedzirra'
require 'nokogiri'
require 'open-uri'
require 'uri'

class DrupalGitHubIssues

	def gh_Authenticate (username, password)
		@ghClient = Octokit::Client.new(:login => username.to_s, :password => password.to_s)
	end

	def create_GH_Issue (repo, title, body, options)
		@ghClient.create_issue(repo.to_s, title.to_s, body.to_s, options)
	end

	def close_GH_Issue (repo, issueNumber, closeCode)

		closeText = "Automated Close Message... <br> Close Code: #{closeCode.to_s}"
		
		@ghClient.add_comment(repo.to_s, issueNumber, closeText)
		@ghClient.close_issue(repo.to_s, issueNumber)
	end

	def get_Drupal_Issues (drupalProject, ghRepo, storeInGH = true)
		rssURL = "https://drupal.org/project/issues/rss/#{drupalProject}"
		feed = Feedzirra::Feed.fetch_and_parse(rssURL)

		entriesAll = feed.entries

		# puts "Number of Enteries:  #{entriesAll.count}"

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
				return entry, drupalIssueComponent, drupalIssueVersion, drupalIssueStatus, drupalIssuePriority, drupalIssueCategory
			end
		end
	end
end
