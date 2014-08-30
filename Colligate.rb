# encoding: utf-8
require 'json'

require_relative "Downloader"
require_relative "DBmanager"

@lastModified = 0

downloader = Downloader.new("eu.battle.net","argent-dawn")
dbhandeler = DBmanager.new()

#Command line input parser

while true
	puts("\nPlease choose an activity:\n\n")

	puts("1. Download newest data from the server\n")
	puts("2. Load auctions into memory\n")
	puts("3. Store auctions into the database")
	puts("4. Download, Load and store")
	puts("5. AutoMode")
	puts("6. Test")
	puts("0. Exit program\n")
	

	if(ARGV.length == 0)

		input = gets.chomp

	else

		input = ARGV[0]

	end

	case input
	when "1"
		dataInfo = downloader.getauctionURL

		@lastModified = dataInfo[1]

		downloader.downloadAuctionJSON(dataInfo[0])

	when "2"

		dbhandeler.readAuctionJSON

	when "3"

		dbhandeler.writeAuctionsToDB(dbhandeler.readAuctionJSON,@lastModified)

	when "4"

		dataInfo = downloader.getauctionURL

		@lastModified = dataInfo[1]

		downloader.downloadAuctionJSON(dataInfo[0])


		success = dbhandeler.writeAuctionsToDB(dbhandeler.readAuctionJSON,@lastModified)

		if success
			success = dbhandeler.moveoldtolog(@lastModified)	
		end

		if success
			dbhandeler.deleteold(@lastModified)
		end

	when "5"

		oldLastModified = 0

		while true
		
			puts "Checking for new data. #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"

			dataInfo = downloader.getauctionURL

			@lastModified = dataInfo[1]

			if @lastModified > oldLastModified

				puts "New data is available. Beginning work..."

				oldLastModified = @lastModified
				
				downloader.downloadAuctionJSON(dataInfo[0])

				success = dbhandeler.writeAuctionsToDB(dbhandeler.readAuctionJSON,@lastModified)
				
				if success
				
					success = dbhandeler.moveoldtolog(@lastModified)

				end

				if success
					
					dbhandeler.deleteold(@lastModified)

				end

				missingItems = dbhandeler.itemsNotInDB

				puts missingItems.length

				itemJSON = Array.new

				missingItems.each do |item|

					print "Inseting "
					puts item[0]

					itemJSON << downloader.getItemJSON(item[0])

				end

				dbhandeler.insertMissingItems(missingItems,itemJSON)

			else

				puts "Nothing new yet."

			end
			GC.start
			puts "Sleeping..."
			sleep(300)

		end

	when "6"
		
		
		missingItems = dbhandeler.itemsNotInDB

		puts missingItems.length

		itemJSON = Array.new

		missingItems.each do |item|

			print "Inseting "
			puts item[0]

			itemJSON << downloader.getItemJSON(item[0])

			#dbhandeler.insertItem(item[0], nameAndJSON[0], nameAndJSON[1])

		end

		dbhandeler.insertMissingItems(missingItems,itemJSON)


	when "0"
		exit
	end

end
