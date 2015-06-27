# encoding: utf-8
require "yajl"
require "logger"
require "yaml"
require "thread"
require "date"
require "sequel"

require_relative "Downloader"
require_relative "DBmanager"
#require_relative "Worker"

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

dbConnection = Sequel.connect("postgres://cg:colligate@localhost/colligate")

while true

	realms.each do |r|

	dbManager = DBmanager.new(r["region"], r["realm"], dbConnection)
	downloader = Downloader.new(r["region"], r["realm"], r["locale"], @apikey)

	dbLastModified = dbManager.getLastModified
	webLastModified = downloader.getLastModified

	puts "#{r["realm"]} was last updated: #{dbLastModified}"

	# Begin update if the battle.net data is newer than the data we have in the database
	if webLastModified > dbLastModified
		
		auctions = false

		while auctions == false		
			auctions = downloader.getAuctionJSON
			sleep 1
		end

		if dbManager.writeAuctionsToDB(auctions,webLastModified)

			if dbManager.moveOldtoLog(webLastModified)
				
				dbManager.deleteOld(webLastModified)

			end
			
			
		end
		
		
	else

		puts "#{r["realm"]} is up to date. Next update will be at: #{dbLastModified+31*60}"

	end

	missingItems = dbManager.itemsNotInDB

	missingItems.each do |item|

		iJSON = downloader.getItemJSON(item)

		if iJSON == true
		
			dbManager.insertItem(item, iJSON[0], iJSON[1])

		elsif iJSON == "not found"

			dbManager.setDeprecated(item)
			

		end

	end

	puts "#{(dbLastModified+(31*60)-Time.now)/60} minutes til next update."
	
	sleepTime = dbLastModified+(31*60)-Time.now

	sleepTime = 60 if dbLastModified+(31*60)-Time.now < 0

	sleep sleepTime

end


	
end
