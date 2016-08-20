# encoding: utf-8
require "yajl"
require "net/http"
require "open-uri"
require "date"
require "logger"

# The Downloader class handels all HTTP requests required to download auctions
class Downloader

	def initialize(region, realm, locale, apikey)
		@log = Logger.new("log.log")
		@regionURL = "#{region}.api.battle.net" # Region can be eu.battle.net for europe ur us.battle.net for us.
		@realm = realm # Server or realm. Note that spaces in the realm name is replaced by dash as in: "Argent dawn" becomes "argent-dawn".
		@locale = locale
		@apikey = apikey

		refreshRealmAPI
	end

	def getLastModified

		attempts = 1

		while @lastModified.nil?

			puts "Web lastModified not set. Refreshing realm API. #{attempts}. try..."

			refreshRealmAPI
			sleep 3

			attempts = attempts + 1
		end

		return @lastModified
	end

	def getDataURL
		return @dataURL		
	end

# Makes a request to the regional api for the URL to a specific server's auction database.
	def refreshRealmAPI
		begin
			uri = "https://" + @regionURL + "/wow/auction/data/" + @realm + "?locale=#{@locale}" + "&apikey=#{@apikey}"
			puts uri
			jsontemp = Yajl::Parser.parse(open(uri)) # Parse JSON to ruby object.

			@dataURL = jsontemp["files"][0]["url"]
			@lastModified = Time.at(jsontemp["files"][0]["lastModified"]/1000)

			puts "Successfully retrived data URL for #{uri}\nURL: #{@dataURL}\nLatest data is from #{@lastModified}"
			@log.info "Successfully retrived data URL for #{uri}\nURL: #{@dataURL}\nLatest data is from #{@lastModified}"

			return true

		rescue => e
			
			puts "Failed to get the Auction data URL."
			@log.error "Failed to get the Auction data URL."
			puts "Error message from the server:\n\n #{jsontemp}\n\n"
			@log.error "Error message from the server:\n\n #{jsontemp}\n\n"
			puts e
			@log.error e

			return false

		end
		
		
	end
# Downloads the actual auction database file from a specific server. The fileformat is JSON.
	def getAuctionJSON

		begin
			json = open(@dataURL).read

			if !json.include? "ownerRealm"
			
				raise "Recieved something unexpected: \n #{json} \n of class: #{json.class}"

			end

			return json

		rescue => e
			
			puts "Failed to download the Auction JSON data.\n #{e}"
			@log.error "Failed to download the Auction JSON data.\n #{e}"

			return false

		end

	end

	def getItemJSON(itemID) # Resolves an item's name from the battle.net api.
		retries = 0
		begin
			uri = "https://" + @regionURL + "/wow/item/" + String(itemID) + "?locale=#{@locale}" + "&apikey=#{@apikey}"
			puts "Item request #{uri}"
			itemJSON = open(uri).string

			if itemJSON.include? "Internal server error."
			
				puts "Failed to retrieve item JSON.\n Error message from the server: #{itemJSON}"
				@log.error "Failed to retrieve item JSON.\n Error message from the server: #{itemJSON}"

				return false

			elsif itemJSON.include? %{"availableContexts":["trade-skill"]}
				
				puts "Successfully retrived JSON for #{itemID}. Crafted item detected and treating it as such"
				@log.info "Successfully retrived JSON for #{itemID}. Crafted item detected and treating it as such"

				uri = "https://#{@regionURL}/wow/item/#{itemID}/trade-skill?locale=#{@locale}&apikey=#{@apikey}"

				itemJSON = open(uri).string

				return Yajl::Parser.parse(itemJSON)["name"], itemJSON

			else

				puts "Successfully retrived JSON for #{itemID}."
				@log.info "Successfully retrived JSON for #{itemID}."

				return Yajl::Parser.parse(itemJSON)["name"], itemJSON

			end

			

		rescue OpenURI::HTTPError => e
			
			if retries < 3 && e.include?("504 Gateway Timeout")
				puts "Failed to connect to battle.net:\n #{e}\nretrying: #{retries}..."
				@log.error "Failed to connect to battle.net:\n #{e}\nretrying: #{retries}..."

				retries = retries + 1

				sleep 2

				retry
			
			else

				puts "Item not fount on battle.net\n #{e}"
				@log.error "Item not fount on battle.net\n #{e}"

				return "not found"

			end

			

		end
	end
end