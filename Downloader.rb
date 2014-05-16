# encoding: utf-8
require "json"
require "net/http"

# The Downloader class handels all HTTP requests required to download auctions
class Downloader

	def initialize(region, server)
		@region = region # Region can be eu.battle.net for europe ur us.battle.net for us.
		@server = server # Server or realm. Note that spaces in the realm name is replaced my dash as in: "Argent dawn" becomes "argent-dawn".
	end
# Makes a request to the regional api for the URL to a specific server's auction database.
	def getauctionURL
		begin
			uri = URI("http://" + @region + "/api/wow/auction/data/" + @server)

			jsontemp = JSON.parse(Net::HTTP.get(uri)) # Parse JSON to ruby object.

			@dataURL = jsontemp["files"][0]["url"]
			$lastModified = jsontemp["files"][0]["lastModified"]/1000

			puts @dataURL

			return @dataURL

		rescue Exception => e
			
			puts "Failed to get the Auction data URL."
			puts "Error message from the server:\n\n #{jsontemp}\n\n"
			puts e

		end
		
		
	end
# Downloads the actual auction database file from a specific server. The fileformat is JSON.
	def downloadAuctionJSON

		begin
			uri = URI(getauctionURL)

			auctionJSONfile = File.new("auctionJSONfile.json", "w+") # Due to the size of the database it is stored as a file on disk.

			auctionJSONfile.write(Net::HTTP.get(uri))
			auctionJSONfile.close()


		rescue Exception => e
			
			puts "Failed to download the Auction JSON data."
			puts e

		end

	end

	def getItemJSON(itemID) # Resolves an item's name from the battle.net api.

		begin
			uri = URI("http://" + @region + "/api/wow/item/" + String(itemID))

			itemJSON = Net::HTTP.get(uri)

			return JSON.parse(itemJSON)["name"], itemJSON

		rescue Exception => e
			
			puts "Failed to resolve itemID remotely."
			puts e

		end
	end
end