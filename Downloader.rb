# encoding: utf-8
require "yajl"
require "net/http"
require "date"
require "logger"

# The Downloader class handels all HTTP requests required to download auctions
class Downloader

	def initialize(region, realm, locale, apikey)
		@log = Logger.new("log.log")
		@region = region
		@regionURL = "#{region}.api.battle.net" # Region can be eu.battle.net for europe ur us.battle.net for us.
		@realm = realm # Server or realm. Note that spaces in the realm name is replaced by dash as in: "Argent dawn" becomes "argent-dawn".
		@locale = locale
		@apikey = apikey
	end
# Makes a request to the regional api for the URL to a specific server's auction database.
	def getauctionURL
		begin
			uri = URI("https://" + @regionURL + "/wow/auction/data/" + @realm + "?locale=#{@locale}" + "&apikey=#{@apikey}")
			puts uri
			jsontemp = Yajl::Parser.parse(Net::HTTP.get(uri)) # Parse JSON to ruby object.

			dataURL = jsontemp["files"][0]["url"]
			lastModified = Time.at(jsontemp["files"][0]["lastModified"]/1000).to_datetime

			puts "Successfully retrived data URL for #{uri}\nURL: #{dataURL}\nLatest data is from #{lastModified}"
			@log.info "Successfully retrived data URL for #{uri}\nURL: #{dataURL}\nLatest data is from #{lastModified}"

			return URI(dataURL),lastModified

		rescue => e
			
			puts "Failed to get the Auction data URL."
			@log.error "Failed to get the Auction data URL."
			puts "Error message from the server:\n\n #{jsontemp}\n\n"
			@log.error "Error message from the server:\n\n #{jsontemp}\n\n"
			puts e
			@log.error e

			return nil

		end
		
		
	end
# Downloads the actual auction database file from a specific server. The fileformat is JSON.
	def downloadAuctionJSON(uri)

		begin

			auctionJSONfile = File.new("#{@region}.#{@realm}.json", "w+") # Due to the size of the database it is stored as a file on disk.

			auctionJSONfile.write(Net::HTTP.get(uri))
			auctionJSONfile.close()

			puts "Successfully downloaded auction data."
			@log.info "Successfully downloaded auction data."

			return true

		rescue => e
			
			puts "Failed to download the Auction JSON data.\n #{e}"
			@log.error "Failed to download the Auction JSON data.\n #{e}"

			return false

		end

	end

	def getItemJSON(itemID) # Resolves an item's name from the battle.net api.

		begin
			uri = URI("https://" + @regionURL + "/wow/item/" + String(itemID) + "?locale=#{@locale}" + "&apikey=#{@apikey}")

			itemJSON = Net::HTTP.get(uri)

			if itemJSON.include? "Internal server error."
			
				puts "Failed to retrieve item JSON.\n Error message from the server: #{itemJSON}"
				@log.error "Failed to retrieve item JSON.\n Error message from the server: #{itemJSON}"

				return nil, nil

			elsif itemJSON.include? "unable to get item information."
				
				puts "Item: #{itemID} cannot be found on battle.net.\nThis could mean this item is no longer obtainable ingame.\nGetting name from Wowhead instead."
				@log.info "Item: #{itemID} cannot be found on battle.net.\nThis could mean this item is no longer obtainable ingame.\nGetting name from Wowhead instead."

				html = Net::HTTP.get(URI("http://www.wowhead.com/item=#{itemID}"))

				name = html.scan(/<title>([^<>]*)<\/title>/)[0][0].split(' - Item - World of Warcraft').first

				return name,nil

			else

				puts "Successfully retrived item JSON."
				@log.info "Successfully retrived item JSON."

				return Yajl::Parser.parse(itemJSON)["name"], itemJSON

			end

			

		rescue => e
			
			puts "Failed to connect to battle.net\n #{e}"
			@log.error "Failed to connect to battle.net\n #{e}"

		end
	end
end