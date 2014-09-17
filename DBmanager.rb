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

				@db.execute("CREATE TABLE Alliance (
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

				@db.execute("CREATE TRIGGER AbidCounter
									AFTER UPDATE
									ON Alliance
								BEGIN
									UPDATE Alliance 
									SET bidCount = bidCount + 1
									WHERE bid > OLD.bid AND NEW.auctionNumber = auctionNumber;
								END")


				@db.execute("CREATE TABLE AllianceLog (
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
				
				@db.execute("CREATE TABLE Horde (
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

				@db.execute("CREATE TRIGGER HbidCounter
									AFTER UPDATE
									ON Horde
								BEGIN
									UPDATE Horde 
									SET bidCount = bidCount + 1
									WHERE bid > OLD.bid AND NEW.auctionNumber = auctionNumber;
								END")
				
				@db.execute("CREATE TABLE HordeLog (
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
				
				@db.execute("CREATE TABLE Neutral (
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

				@db.execute("CREATE TRIGGER NbidCounter
									AFTER UPDATE
									ON Neutral
								BEGIN
									UPDATE Neutral 
									SET bidCount = bidCount + 1
									WHERE bid > OLD.bid AND NEW.auctionNumber = auctionNumber;
								END")

				
				@db.execute("CREATE TABLE NeutralLog (
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
				
				@db.execute("CREATE TABLE Items (
								 ID int NOT NULL,
								 Name text NULL, 
								 JSON text NULL, 
								 PRIMARY KEY (id))")


				@db.execute("CREATE INDEX almod ON AllianceLog( lastmodified )")
				@db.execute("CREATE INDEX hlmod ON HordeLog( lastmodified )")
				@db.execute("CREATE INDEX nlmod ON NeutralLog ( lastmodified )")
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
	# Writes the loaded aucitons into the SQLite3 database
	def writeAuctionsToDB(auctions, lastModified)

		if lastModified == 0
			puts "lastmodified variable not set! Please make sure to load in a fresh set of data."
			@log.warn "lastmodified variable not set! Please make sure to load in a fresh set of data."
			return nil
		end

		begin

		@db.transaction

			puts "Loading new Alliance auctions into database."
			@log.info "Loading new Alliance auctions into database."

			auctions["alliance"]["auctions"].each do |auction|

				
				@db.execute("INSERT OR IGNORE INTO Alliance (
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

			end

			puts "Updating existing Alliance auctions."
			@log.info "Updating existing Alliance auctions."

			auctions["alliance"]["auctions"].each do |auction|

				@db.execute("UPDATE Alliance 
								SET bid = :bid, 
								timeLeft = :timeLeft, 
								lastmodified = :lastmodified 
								WHERE auctionNumber = :auctionNumber", 
								"bid" => auction["bid"], 
								"timeLeft" => auction["timeLeft"], 
								"lastmodified" => lastModified, 
								"auctionNumber" => auction["auc"])	

			end

			puts "Loading new Horde auctions into database."
			@log.info "Loading new Horde auctions into database."


			auctions["horde"]["auctions"].each do |auction|

				
				@db.execute("INSERT OR IGNORE INTO Horde (
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

			end

			puts "Updating existing Horde auctions."
			@log.info "Updating existing Horde auctions."

			auctions["horde"]["auctions"].each do |auction|

				@db.execute("UPDATE Horde SET 
								bid = :bid, 
								timeLeft = :timeLeft, 
								lastmodified = :lastmodified 
								WHERE auctionNumber = :auctionNumber", 
								"bid" => auction["bid"], 
								"timeLeft" => auction["timeLeft"], 
								"lastmodified" => lastModified, 
								"auctionNumber" => auction["auc"])	

			end

			puts "Loading new Neutral auctions into database."
			@log.info "Loading new Neutral auctions into database."

			auctions["neutral"]["auctions"].each do |auction|

				
				@db.execute("INSERT OR IGNORE INTO Neutral (
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

			end

			puts "Updating existing Neutral auctions."
			@log.info "Updating existing Neutral auctions."

			auctions["neutral"]["auctions"].each do |auction|

				@db.execute("UPDATE Neutral SET 
								bid = :bid,
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

			return false

		end

	end


	def deleteold(lastModified)

		if(lastModified !=0)

			puts "Deleting expired auctions."
			@log.info "Deleting expired auctions."

			@db.transaction

			@db.execute("delete FROM Alliance 
						 WHERE lastmodified !=:lastmodified",
						 "lastmodified" => lastModified)

			@db.execute("delete FROM Horde 
						 WHERE lastmodified !=:lastmodified", 
						 "lastmodified" => lastModified)

			@db.execute("delete FROM Neutral 
						 WHERE lastmodified !=:lastmodified",
						 "lastmodified" => lastModified)


			@db.execute("DELETE
						 FROM AllianceLog
						 WHERE lastmodified < strftime('%s','now', '-2 months')")

			@db.execute("DELETE
						 FROM HordeLog
						 WHERE lastmodified < strftime('%s','now', '-2 months')")

			@db.execute("DELETE
						 FROM NeutralLog
						 WHERE lastmodified < strftime('%s','now', '-2 months')")

			@db.commit

			puts "Old auctions has been deleted from the database."
			@log.info "Old auctions has been deleted from the database."

			return true

		else

			puts "Please download new auction data to get an up-to-date lastmodified."
			@log.warn "Please download new auction data to get an up-to-date lastmodified."

			return false

		end

		
	end


	def moveoldtolog(lastModified)

		begin
			
			puts "Moving old auctions to log."
			@log.info "Moving old auctions to log."

			@db.execute("INSERT OR IGNORE INTO AllianceLog 
							 SELECT * FROM Alliance 
							 WHERE lastmodified != 0 AND lastmodified < :lastModified", 
							 "lastModified" => lastModified)

			@db.execute("INSERT OR IGNORE INTO HordeLog 
							 SELECT * FROM Horde WHERE lastmodified != 0 AND lastmodified < :lastModified",
							 "lastModified" => lastModified)

			@db.execute("INSERT OR IGNORE INTO NeutralLog 
							 SELECT * FROM Neutral WHERE lastmodified != 0 AND lastmodified < :lastModified", 
							 "lastModified" => lastModified)

			puts "Successfully moved all old auctions to the log tables."
			@log.info "Successfully moved all old auctions to the log tables."

			return true

		rescue Exception => e
			
			puts "Failed to move old auctions to log table\ #{e}"
			@log.error "Failed to move old auctions to log table\ #{e}"

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

			@db.execute("SELECT item FROM AllianceLog EXCEPT SELECT ID FROM Items") do |item|

				missingItems << item

			end

			@db.execute("SELECT item FROM HordeLog EXCEPT SELECT ID FROM Items") do |item|

				missingItems << item

			end


			@db.execute("SELECT item FROM NeutralLog EXCEPT SELECT ID FROM Items") do |item|

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