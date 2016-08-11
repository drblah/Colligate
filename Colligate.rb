# encoding: utf-8
require "yajl"
require "yaml"
require "thread"
require "date"
require "sequel"
require "mongo"

require_relative "Downloader"
require_relative "DBmanagerMongo"

begin

	realms = YAML.load_file("settings.yaml")
	
rescue => e
	
	puts "Failed to read settings.yaml. I cannot download data without knowing where to download it from.\n #{e}"
	exit
end

begin
	
	puts "Please enter your API key:"
	@apikey = ARGV[0]

rescue => e
	
	puts "#{e}"

end

dbConnection = Mongo::Client.new( [ "10.0.0.100:27017" ], :database => "colligate")

begin
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

				if iJSON.size == 2
				
					dbManager.insertItem(item, iJSON[0], iJSON[1])

				elsif iJSON == "not found"

					dbManager.setDeprecated(item)
					

				end

			end

			puts "#{(dbLastModified+(31*60)-Time.now)/60} minutes until next update for #{r["realm"]}."
			
			sleepTime = dbLastModified+(31*60)-Time.now

			sleepTime = 60 if dbLastModified+(31*60)-Time.now < 0

			sleep sleepTime

		end


		
	end
rescue Interrupt
	# Shutdown sequence
	puts "\n\n-----------------------"
	puts "Interrupt caught. Shutting down."
	puts "-----------------------\n\n"
	dbConnection.close
end
