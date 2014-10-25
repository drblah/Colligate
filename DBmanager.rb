# encoding: utf-8
require "sqlite3"
require "yajl"
require "fileutils"
require "logger"

# This class will handle all calls to the database.
class DBmanager

	def initialize(region, realm)

			@region = region
			@realm = realm

			@log = Logger.new("log.log")
			dbPath = "databases/#{region}/#{realm}/#{realm}.db"

			# Open database if it exists.
			@db = SQLite3::Database.open dbPath if File.exist?(dbPath)
			
			# Create database and the tables if the database does not exist
			if(not File.exist?(dbPath))
				FileUtils::mkdir_p "databases/#{region}/#{realm}"
				puts dbPath
				@db = SQLite3::Database.new dbPath

				@db.execute("CREATE TABLE auctions (
								 auctionNumber bigint NOT NULL,
								 item int NULL,
								 owner text NULL,
								 bid bigint NULL,
								 buyout bigint NULL,
								 quantity int NULL,
								 timeleft Text NULL,
								 createdDate bigint NULL,
								 lastmodified bigint NULL, 
								 bidCount int DEFAULT 0,
								 PRIMARY KEY (auctionNumber))")

				@db.execute("CREATE TRIGGER abidCounter
									AFTER UPDATE
									ON auctions
								BEGIN
									UPDATE auctions 
									SET bidCount = bidCount + 1
									WHERE bid > OLD.bid AND NEW.auctionNumber = auctionNumber;
								END")


				@db.execute("CREATE TABLE auctionsLog (
								 auctionNumber bigint NOT NULL,
								 item int NULL,
								 owner text NULL,
								 bid bigint NULL,
								 buyout bigint NULL,
								 quantity int NULL,
								 timeleft Text NULL,
								 createdDate bigint NULL,
								 lastmodified bigint NULL, 
								 bidCount int DEFAULT 0,
								 PRIMARY KEY (auctionNumber))")

				
				@db.execute("CREATE TABLE items (
								 ID int NOT NULL,
								 Name text NULL, 
								 JSON text NULL, 
								 PRIMARY KEY (id))")

				@db.execute("CREATE INDEX lastmodIDX ON auctions( lastModified)")
				@db.execute("CREATE INDEX itemIDX ON auctions( item )")
				@db.execute("CREATE INDEX lastmodLogIDX ON auctionsLog( lastmodified )")
				@db.execute("CREATE INDEX itemLogIDX ON auctionsLog( item )")
				@db.execute("CREATE INDEX nameidx ON Items ( Name )")

			end

			
	end

	# Load the downloaded server database into memory.
	def readAuctionJSON
		
		begin
			#Reads the JSON file containing the auction database download from the server
			puts "Parsing auction JSON."
			@log.info "Parsing auction JSON."
			auctions = Yajl::Parser.parse(File.read("#{@region}.#{@realm}.json", :mode => 'r:utf-8'))

			puts "Auction JSON successfully parsed."
			@log.info "Auction JSON successfully parsed."


			return auctions

		rescue Exception => e
			puts "Failed to parse auction JSON\n #{e}"
			@log.error "Failed to parse auction JSON\n #{e}"


			return nil

		end
		

	end

	def readAuctionJSONFile

		begin
			
			f = File.read("eu.argent-dawn.json", :mode => 'r:utf-8') # Open file as UTF-8

			f = f.lines.to_a[3..-1].join # Remove 3 first lines
			f = f.gsub!( /\r\n?/, "\n" ) # Replace windows line endings with unix ( CRFL to FL )
			f = f.chomp("]}\n}").gsub!(",\n", "\n") # Remove ending of file and remove trailing ',' on each line

			puts "Auction JSONfile successfully read."
			@log.info "Auction JSONfile successfully read."

			return f

		rescue Exception => e
			
			puts "Failed to read auction JSON file\n #{e}"
			@log.error "Failed to read auction JSON file\n #{e}"

		end
		
	end

	# Writes the loaded aucitons into the SQLite3 database
	def writeAuctionsToDB(auctions, lastModified)

		if lastModified == 0
			puts "lastmodified variable not set! Please make sure to load in a fresh set of data."
			@log.warn "lastmodified variable not set! Please make sure to load in a fresh set of data."
			return nil
		end

		begin

		@db.transaction

			puts "Loading new auctions into the database and updating old."
			@log.info "Loading new auctions into the database and updating old."

			auctions.lines.each do |line|
				
				auction = Yajl::Parser.parse(line)

				@db.execute("INSERT OR IGNORE INTO auctions (
								auctionNumber, 
								item, 
								owner, 
								bid, 
								buyout, 
								quantity, 
								timeleft, 
								createdDate, 
								lastmodified)
								values ( 
									:auctionNumber, 
									:item, 
									:owner, 
									:bid, 
									:buyout, 
									:quantity, 
									:timeLeft, 
									:lastmodified , 
									:lastmodified)", 
									"auctionNumber" => auction["auc"], 
									"item" => auction["item"], 
									"owner" => auction["owner"], 
									"bid" => auction["bid"], 
									"buyout" => auction["buyout"], 
									"quantity" => auction["quantity"], 
									"timeLeft" => auction["timeLeft"], 
									"lastmodified" => lastModified)

				@db.execute("UPDATE auctions 
								SET bid = :bid, 
								timeLeft = :timeLeft, 
								lastmodified = :lastmodified 
								WHERE auctionNumber = :auctionNumber", 
								"bid" => auction["bid"], 
								"timeLeft" => auction["timeLeft"], 
								"lastmodified" => lastModified, 
								"auctionNumber" => auction["auc"])	

			end

		@db.commit

		puts "Auction import complete."
		@log.info "Auction import complete."

		return true

		rescue Exception => e

			puts "Failed to import auctions\n #{e}"
			@log.error "Failed to import auctions\n #{e}"
			@db.rollback if @db.transaction_active?

			return false

		end

	end


	def deleteold(lastModified)

		if(lastModified !=0)

			puts "Deleting expired auctions."
			@log.info "Deleting expired auctions."

			@db.transaction

			@db.execute("delete FROM auctions 
						 WHERE lastmodified !=:lastmodified",
						 "lastmodified" => lastModified)

			@db.execute("DELETE
						 FROM auctionsLog
						 WHERE lastmodified < strftime('%s','now', '-2 months')")

			@db.commit

			puts "Old auctions has been deleted from the database."
			@log.info "Old auctions has been deleted from the database."

			return true

		else

			puts "Please download new auction data to get an up-to-date lastmodified."
			@log.warn "Please download new auction data to get an up-to-date lastmodified."

			@db.rollback if @db.transaction_active?
			return false

		end

		
	end


	def moveoldtolog(lastModified)

		begin
			
			puts "Moving old auctions to log."
			@log.info "Moving old auctions to log."
			@db.transaction

			@db.execute("INSERT OR IGNORE INTO auctionsLog 
							 SELECT * FROM auctions 
							 WHERE lastmodified != 0 AND lastmodified < :lastModified", 
							 "lastModified" => lastModified)

			@db.commit

			puts "Successfully moved all old auctions to the log tables."
			@log.info "Successfully moved all old auctions to the log tables."

			return true

		rescue Exception => e
			
			puts "Failed to move old auctions to log table\ #{e}"
			@log.error "Failed to move old auctions to log table\ #{e}"
			@db.rollback if @db.transaction_active?
			return false

		end

			
		
	end

	def itemExistsInDB?(itemID) # Check if a single item exists in the Items table

		begin
			
			@db.execute("SELECT COUNT(*) FROM items WHERE ID = :ID", "ID" => itemID) do |item|

				return true if item[0] == 1

				return false
		
			end


		rescue Exception => e
			
			puts "Failed to check if item exists in the database."
			puts e

		end

	end

	def insertItem(itemID, itemName, itemJSON) # Inserts an item into the Items table for name resolusion.

		begin
			
			@db.execute("INSERT OR IGNORE INTO items VALUES (:ID, :Name, :JSON)", "ID" => itemID, "Name" => itemName, "JSON" => itemJSON)

		rescue Exception => e
			
			puts "Failed to insert item into database.\ #{e}"
			@log.error "Failed to insert item into database.\ #{e}"

		end


	end

	def itemsNotInDB # Returns all times not found in the Items table.

		begin

			missingItems = Array.new

			@db.execute("SELECT item FROM auctionsLog EXCEPT SELECT ID FROM Items") do |item|

				missingItems << item

			end

			return missingItems.uniq[0..19]

		rescue Exception => e
			
			puts "Failed to determine which items are not in the database.\n #{e}"
			@log.error "Failed to determine which items are not in the database.\n #{e}"

			return nil

		end

		
	end

	def insertMissingItems(missingItems,itemJSON)

		@db.transaction

		missingItems.each_with_index do |item,i|

			self.insertItem(item[0], itemJSON[i][0], itemJSON[i][1])

		end

		@db.commit
		
	end


	def test

		puts "Items in AllianceLog:"
		puts @db.execute("SELECT COUNT(*) item FROM Alliance")[0]
		puts "Items in HordeLog:"
		puts @db.execute("SELECT COUNT(*) item FROM Horde")[0]
		puts "Items in NeutralLog:"
		puts @db.execute("SELECT COUNT(*) item FROM Neutral")[0]

	end

end