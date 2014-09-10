# encoding: utf-8
require 'yajl'

require_relative "Downloader"
require_relative "DBmanager"

#Command line input parser

while true
	puts("\nPlease choose an activity:\n\n")

	puts("1. Download, Load and store")
	puts("0. Exit program\n")
	

	if(ARGV.length == 0)

		input = gets.chomp

	else

		input = ARGV[0]

	end

	case input

	when "1"

		downloader = Downloader.new("eu.battle.net","argent-dawn")
		dbhandeler = DBmanager.new("eu", "argent-dawn")

		lastModified = 0
		oldLastModified = 0


		while true
		
			puts "Checking for new data. #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"

			dataInfo = downloader.getauctionURL

			lastModified = dataInfo[1] if (defined? dataInfo)

			if lastModified > oldLastModified

				puts "New data is available. Beginning work..."

				oldLastModified = lastModified
				
				downloader.downloadAuctionJSON(dataInfo[0])

				success = dbhandeler.writeAuctionsToDB(dbhandeler.readAuctionJSON,lastModified)
				
				if success
				
					success = dbhandeler.moveoldtolog(lastModified)

				end

				if success
					
					dbhandeler.deleteold(lastModified)

				end

				missingItems = dbhandeler.itemsNotInDB

				puts "Found #{missingItems.length} items not in item cache."

				itemJSON = Array.new

				missingItems.delete_if do |item|

					bnetdata = downloader.getItemJSON(item[0])


					if (defined? bnetdata) #Check if we got any data from downloader class. If not, skip the item untill next update.
					

						if bnetdata[0] == nil
							
							true

						else
							
							print "Inseting "
							puts item[0]

							itemJSON << bnetdata
							false

						end

					else

						true

					end

					

				end

				dbhandeler.insertMissingItems(missingItems,itemJSON)

			else

				puts "Nothing new yet."

			end
			GC.start
			puts "Sleeping..."
			sleep(300)

		end


	when "0"
		exit
	end

end
