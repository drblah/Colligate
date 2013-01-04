# encoding: utf-8
require_relative "Downloader"
require_relative "DBmanager"

$lastModified = 0

downloader = Downloader.new("eu.battle.net","argent-dawn")
dbhandeler = DBmanager.new()



while true
	puts("Please choose an activity:\n\n")

	puts("1. Download newest data from the server\n")
	puts("2. Load auctions into memory\n")
	puts("3. Store auctions into the database")
	puts("4. Download, Load and store")
	puts("5. Test")
	puts("0. Exit program\n")
	
	input = gets.chomp

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
		dbhandeler.deleteold

	when "5"

		#dbhandeler.test

		dbhandeler.deleteold

	when "0"
		exit
	end

end
