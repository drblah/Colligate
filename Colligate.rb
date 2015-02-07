# encoding: utf-8
require "yajl"
require "logger"
require "yaml"
require "thread"
require "date"

require_relative "Downloader"
require_relative "DBmanager"
require_relative "Worker"

log = Logger.new("log.log")

begin

	realms = YAML.load_file("settings.yaml")
	
rescue => e
	
	puts "Failed to read settings.yaml. I cannot download data without knowing where to download it from.\n #{e}"
	exit
end

begin
	
	puts "Please enter your API key:"
	@apikey = gets.chomp

rescue => e
	
	puts "#{e}"

end

@tokens = Queue.new

(1..2).each do

	@tokens << 1

end

puts @apikey

worker = Worker.new
timeTable = []

realms.each do |r|

	timeTable << {realm: r["realm"], lastModified: Date.new(1970,1,1).to_datetime}

end

while true
	
	realms.each do |r|

		lastModified = Date.new(1970,1,1).to_datetime

		downloader = Downloader.new(r["region"], r["realm"], r["locale"], @apikey)

		# Get url to the auction data. Also returns the time/date of when the data was last updated.
		dataInfo = downloader.getauctionURL

		if dataInfo != false
			lastModified = dataInfo[1]
		
			# Find the last modified time for the realm we are looking at now.
			oldLastModified = timeTable.find {|t| t[:realm] == r["realm"]}[:lastModified]

			if lastModified > oldLastModified

				dbhandeler = DBmanager.new(r["region"], r["realm"])

				# Find index at which the time is stored for this realm in the timeTable
				index = timeTable.find_index(timeTable.find {|t| t[:realm] == r["realm"]})

				# Update lastmodified
				timeTable[index][:lastModified] = lastModified

				worker.addJob {

					@tokens.pop

					puts "New data is available. Beginning work..."
					log.info "New data is available. Beginning work..."
					
					json = downloader.downloadAuctionJSON(dataInfo[0])

					success = false

					if json != false
						
						success = dbhandeler.writeAuctionsToDB(dbhandeler.readAuctionJSONFile(json),lastModified)

					end
					
					if success
					
						success = dbhandeler.moveoldtolog(lastModified)

					end

					if success
						
						dbhandeler.deleteold(lastModified)

					end

					dbhandeler.close

					@tokens << 1

				}

				
			end

		end



	end

	worker.join

	puts "Update jobs finished at #{Time.now}"

	worker.addJob {

		realms.each do |r|

			downloader = Downloader.new(r["region"], r["realm"], r["locale"], @apikey)
			dbhandeler = DBmanager.new(r["region"], r["realm"])

			missingItems = dbhandeler.itemsNotInDB

			missingItems.each do |item|

				iJSON = downloader.getItemJSON(item)

				dbhandeler.insertItem(item, iJSON[0], iJSON[1]) if iJSON != false

			end

			dbhandeler.close

		end
		puts "Item name lookup finished for this run."
	}


	needUpdate = false

	while true

		# Break out of loop if one of the realms have not been updated in 30 minutes
		timeTable.each do |time|
			
			if (Time.now - time[:lastModified].to_time) > (60*30)
				needUpdate = true
				puts "#{time[:realm]} has not been updated for 30 minutes."
			end

		end

		break if needUpdate

		sleep 10
			
	end


end
	
while true

	option = gets.chomp

	if option == "stop"
		
		worker.stopJobs

		exit
	end
	
end
