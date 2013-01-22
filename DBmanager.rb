# encoding: utf-8
require "sqlite3"
require "json"
require "pp"
# This class will handle all calls to the database.
class DBmanager

	def initialize()
			
			# Open database if it exists.
			@db = SQLite3::Database.open "Auctions.db" if File.exist?("Auctions.db")
			
			# Create database and the tables if the database does not exist
			if(not File.exist?("Auctions.db"))
				@db = SQLite3::Database.new "Auctions.db"

				@db.execute("CREATE TABLE Alliance (auctionNumber bigint NOT NULL,item int NULL,owner text NULL,bid bigint NULL,buyout bigint NULL,quantity int NULL,timeleft Text NULL,createdDate bigint NULL,lastmodified bigint NULL, PRIMARY KEY (auctionNumber))")
				@db.execute("CREATE TABLE AllianceLog (auctionNumber bigint NOT NULL,item int NULL,owner text NULL,bid bigint NULL,buyout bigint NULL,quantity int NULL,timeleft Text NULL,createdDate bigint NULL,lastmodified bigint NULL, PRIMARY KEY (auctionNumber))")
				@db.execute("CREATE TABLE Horde (auctionNumber bigint NOT NULL,item int NULL,owner text NULL,bid bigint NULL,buyout bigint NULL,quantity int NULL,timeleft Text NULL,createdDate bigint NULL,lastmodified bigint NULL, PRIMARY KEY (auctionNumber))")
				@db.execute("CREATE TABLE HordeLog (auctionNumber bigint NOT NULL,item int NULL,owner text NULL,bid bigint NULL,buyout bigint NULL,quantity int NULL,timeleft Text NULL,createdDate bigint NULL,lastmodified bigint NULL, PRIMARY KEY (auctionNumber))")
				@db.execute("CREATE TABLE Neutral (auctionNumber bigint NOT NULL,item int NULL,owner text NULL,bid bigint NULL,buyout bigint NULL,quantity int NULL,timeleft Text NULL,createdDate bigint NULL,lastmodified bigint NULL, PRIMARY KEY (auctionNumber))")
				@db.execute("CREATE TABLE NeutralLog (auctionNumber bigint NOT NULL,item int NULL,owner text NULL,bid bigint NULL,buyout bigint NULL,quantity int NULL,timeleft Text NULL,createdDate bigint NULL,lastmodified bigint NULL, PRIMARY KEY (auctionNumber))")
			end

			
	end

	# Load the downloaded server database into memory.
	def readAuctionJSON
		
		begin
			#Reads the JSON file containing the auction database download from the server

			auctions = JSON.parse(File.read("auctionJSONfile.json", :mode => 'r:utf-8'))


			return auctions
		rescue Exception => e
			
			puts e

			return nil

		end
		

	end
	# Writes the loaded aucitons into the SQLite3 database
	def writeAuctionsToDB

		begin

		auctions = readAuctionJSON

		@db.transaction

		#@db.execute("INSERT INTO Alliance values ( ?, ?, ?, ?, ?, ?, ?, ?)", auctions["alliance"]["auctions"][0]["auc"], auctions["alliance"]["auctions"][0]["item"], auctions["alliance"]["auctions"][0]["owner"], auctions["alliance"]["auctions"][0]["bid"], auctions["alliance"]["auctions"][0]["buyout"], auctions["alliance"]["auctions"][0]["quantity"], auctions["alliance"]["auctions"][0]["timeLeft"], 10)

			puts "Loading new Alliance auctions into database."

			auctions["alliance"]["auctions"].each do |auction|

				
				@db.execute("INSERT OR IGNORE INTO Alliance values ( :auctionNumber, :item, :owner, :bid, :buyout, :quantity, :timeLeft, :lastmodified , :lastmodified)", "auctionNumber" => auction["auc"], "item" => auction["item"], "owner" => auction["owner"], "bid" => auction["bid"], "buyout" => auction["buyout"], "quantity" => auction["quantity"], "timeLeft" => auction["timeLeft"], "lastmodified" => $lastModified)

			end

			puts "Updating existing Alliance auctions."

			auctions["alliance"]["auctions"].each do |auction|

				@db.execute("UPDATE Alliance SET bid = :bid, timeLeft = :timeLeft, lastmodified = :lastmodified WHERE auctionNumber = :auctionNumber", "bid" => auction["bid"], "timeLeft" => auction["timeLeft"], "lastmodified" => $lastModified, "auctionNumber" => auction["auc"])	

			end

			puts "Loading new Horde auctions into database."

			auctions["horde"]["auctions"].each do |auction|

				
				@db.execute("INSERT OR IGNORE INTO Horde values ( :auctionNumber, :item, :owner, :bid, :buyout, :quantity, :timeLeft, :lastmodified, :lastmodified)", "auctionNumber" => auction["auc"], "item" => auction["item"], "owner" => auction["owner"], "bid" => auction["bid"], "buyout" => auction["buyout"], "quantity" => auction["quantity"], "timeLeft" => auction["timeLeft"], "lastmodified" => $lastModified)

			end

			puts "Updating existing Horde auctions."

			auctions["horde"]["auctions"].each do |auction|

				@db.execute("UPDATE Horde SET bid = :bid, timeLeft = :timeLeft, lastmodified = :lastmodified WHERE auctionNumber = :auctionNumber", "bid" => auction["bid"], "timeLeft" => auction["timeLeft"], "lastmodified" => $lastModified, "auctionNumber" => auction["auc"])	

			end

			puts "Loading new Neutral auctions into database."

			auctions["neutral"]["auctions"].each do |auction|

				
				@db.execute("INSERT OR IGNORE INTO Neutral values ( :auctionNumber, :item, :owner, :bid, :buyout, :quantity, :timeLeft, :lastmodified, :lastmodified)", "auctionNumber" => auction["auc"], "item" => auction["item"], "owner" => auction["owner"], "bid" => auction["bid"], "buyout" => auction["buyout"], "quantity" => auction["quantity"], "timeLeft" => auction["timeLeft"], "lastmodified" => $lastModified)

			end

			puts "Updating existing Neutral auctions."

			auctions["neutral"]["auctions"].each do |auction|

				@db.execute("UPDATE Neutral SET bid = :bid, timeLeft = :timeLeft, lastmodified = :lastmodified WHERE auctionNumber = :auctionNumber", "bid" => auction["bid"], "timeLeft" => auction["timeLeft"], "lastmodified" => $lastModified, "auctionNumber" => auction["auc"])	

			end

		@db.commit

		

		rescue Exception => e

			puts e

		end

	end


	def deleteold

		if($lastModified !=0)

			puts "Deleting expired auctions."

			@db.execute("delete FROM Alliance WHERE lastmodified !=:lastmodified", "lastmodified" => $lastModified)
			@db.execute("delete FROM Horde WHERE lastmodified !=:lastmodified", "lastmodified" => $lastModified)
			@db.execute("delete FROM Neutral WHERE lastmodified !=:lastmodified", "lastmodified" => $lastModified)


		else

			puts "Please download new auction data to get an up-to-date lastmodified."

		end

		
	end


	def moveoldtolog

		puts "Moving old Auctions to log."

		@db.execute("INSERT OR IGNORE INTO AllianceLog SELECT * FROM Alliance WHERE lastmodified != 0 AND lastmodified < :lastModified", "lastModified" => $lastModified)
		@db.execute("INSERT OR IGNORE INTO HordeLog SELECT * FROM Horde WHERE lastmodified != 0 AND lastmodified < :lastModified", "lastModified" => $lastModified)
		@db.execute("INSERT OR IGNORE INTO NeutralLog SELECT * FROM Neutral WHERE lastmodified != 0 AND lastmodified < :lastModified", "lastModified" => $lastModified)
		
	end


	def test

		puts @db.execute("SELECT item FROM AllianceLog").length
		puts @db.execute("SELECT DISTINCT item FROM AllianceLog").length


		#puts @db.execute("SELECT DISTINCT item FROM Horde").length
		#puts @db.execute("SELECT DISTINCT item FROM Neutral").length

	end

end