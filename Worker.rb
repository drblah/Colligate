require 'thread'

class Worker

	def initialize
		@jobList = []
		$status = "run"
	end

	def addJob

		@jobList << Thread.new { yield }
		
	end

	def stopJobs

		$status = "stop"

		@jobList.each do |job|

			job.join

		end

	end

end