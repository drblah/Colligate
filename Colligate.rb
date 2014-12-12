# encoding: utf-8
require "yajl"
require "logger"
require "yaml"
require "thread"

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

realms.each do |r|

	worker.addJob {

		downloader = Downloader.new(r["region"], r["realm"], r["locale"], @apikey)
		dbhandeler = DBmanager.new(r["region"], r["realm"])

		lastModified = 0
		oldLastModified = 0
		
		while $status != "stop"

			puts "Checking for new data. #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"
			log.info "Checking for new data. #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"

			dataInfo = downloader.getauctionURL

			if dataInfo != nil
				lastModified = dataInfo[1]	
			end

			if lastModified > oldLastModified
				@tokens.pop
				puts "New data is available. Beginning work..."
				log.info "New data is available. Beginning work..."

				oldLastModified = lastModified
				
				success = downloader.downloadAuctionJSON(dataInfo[0])

				if success
					
					success = dbhandeler.writeAuctionsToDB(dbhandeler.readAuctionJSONFile,lastModified)

				end
				
				if success
				
					success = dbhandeler.moveoldtolog(lastModified)

				end

				if success
					
					dbhandeler.deleteold(lastModified)

				end

#				missingItems = dbhandeler.itemsNotInDB
#
#				if missingItems != nil
#					
#
#					puts "Found #{missingItems.length} items not in item cache."
#					log.info "Found #{missingItems.length} items not in item cache."
#
#					itemJSON = Array.new
#
#					missingItems.delete_if do |item|
#
#					bnetdata = downloader.getItemJSON(item[0])
#
#					sleep 0.15 # Sleep a short while to make sure we do not exceed the limit of 10 requests per second.
#
#					if (defined? bnetdata) #Check if we got any data from downloader class. If not, skip the item untill next update.
#					
#
#						if bnetdata[0] == nil
#							
#							true
#
#						else
#							
#							puts "Inserting #{item[0]}"
#							log.info "Inserting #{item[0]}"
#							
#
#							itemJSON << bnetdata
#
#							false
#
#						end
#
#					else
#
#						true
#
#					end
#
#						
#
#					end
#
#					dbhandeler.insertMissingItems(missingItems,itemJSON)
#
#				end

				@tokens << 1
			else

				puts "Nothing new yet."
				log.info "Nothing new yet."

			end

			puts "Sleeping..."

			(0..99).each do

				sleep(3)

				Thread.exit if $status == "stop"

			end

			

		end
	}		
end
	
while true

	option = gets.chomp

	if option == "stop"
		
		worker.stopJobs

		exit
	end
	
end
