# encoding: utf-8
require_relative "Downloader"
require_relative "DBmanager"

$lastModified = 0

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
		downloader.downloadAuctionJSON

	when "2"

		dbhandeler.readAuctionJSON

	when "3"

		dbhandeler.writeAuctionsToDB

	when "4"

		downloader.downloadAuctionJSON
		dbhandeler.readAuctionJSON
		dbhandeler.writeAuctionsToDB
		dbhandeler.moveoldtolog
		dbhandeler.deleteold

	when "5"

		downloader.downloadAuctionJSON
		dbhandeler.readAuctionJSON
		dbhandeler.writeAuctionsToDB
		dbhandeler.moveoldtolog
		dbhandeler.deleteold
		exit

	when "6"
		
		missingItems = dbhandeler.itemsNotInDB


		#missingItems.each do |item|

			#puts item[0]

			#dbhandeler.insertItem(item[0], downloader.getItemName(item[0]))

		#end

	when "0"
		exit
	end

end
