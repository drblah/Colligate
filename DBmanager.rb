# encoding: utf-8
require "yajl"
require "fileutils"
require "logger"
require "sequel"

# This class will handle all calls to the database.
class DBmanager

    def initialize(region, realm, connection)

            @region = region
            @realm = realm

            @auctionsTable = "#{region}_#{realm}_auctions"
            @logTable = "#{region}_#{realm}_auctionsLog"

            @log = Logger.new("log.log")
            dbPath = "databases/#{region}/#{realm}/#{realm}.db"

            # Open database if it exists.
            #@DB = Sequel.connect("postgres://cg:colligate@localhost/colligate")
            @DB = connection
            #@DB.loggers << Logger.new(STDOUT)
            
            # Create database and the tables if the database does not exist

            if not @DB.table_exists?(@auctionsTable)
                
                @DB.create_table(@auctionsTable) do
                    Bignum      :auctionNumber, :primary_key => true
                    Integer     :item, :index => true
                    String      :owner, :text => true
                    Bignum      :bid
                    Bignum      :buyout
                    Integer     :quantity
                    String      :timeLeft, :text => true
                    DateTime    :createdDate
                    DateTime    :lastModified, :index => true
                    Integer     :bidCount
                end

            end

            if not @DB.table_exists?(@logTable)
                
                @DB.create_table(@logTable) do
                    Bignum      :auctionNumber, :primary_key => true
                    Integer     :item, :index => true
                    String      :owner, :text => true
                    Bignum      :bid
                    Bignum      :buyout
                    Integer     :quantity
                    String      :timeLeft, :text => true
                    DateTime    :createdDate
                    DateTime    :lastModified, :index => true
                    Integer     :bidCount
                end

            end

            if not @DB.table_exists?(:items)
                
                @DB.create_table(:items) do
                    Integer     :id, :primary_key => true
                    String      :name, :text => true, :index => true
                    String      :JSON, :text => true
                end

            end

            
    end

    def readAuctionJSONFile(json)

        begin

            f = json
            f = f.lines.to_a[3..-1].join # Remove 3 first lines
            f = f.gsub!( /\r\n?/, "\n" ) # Replace windows line endings with unix ( CRFL to FL )
            f = f.chomp("]}\n}").gsub!(",\n", "\n") # Remove ending of file and remove trailing ',' on each line

            puts "Auction JSONfile successfully read."
            @log.info "Auction JSONfile successfully read."

            return f

        rescue => e
            
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

            puts "Loading new auctions into the database and updating old."
            @log.info "Loading new auctions into the database and updating old."

            
            auctionsTBL = @DB.from(@auctionsTable)

            start = Time.now

            @DB.transaction do

                auctions.lines.each do |line|

                    auction = Yajl::Parser.parse(line)

                    query = %{}

                    @DB.run

#                    if 1 != auctionsTBL.where(:auctionNumber => auction["auc"]).update( :bid => auction["bid"], 
#                                                                                        :buyout => auction["buyout"],
#                                                                                        :timeLeft => auction["timeLeft"],
#                                                                                        :lastModified => lastModified
#                                                                                    )
#
#                        auctionsTBL.exclude(:auctionNumber => auction["auc"]).insert(   :auctionNumber => auction["auc"],
#                                                                                        :item => auction["item"], 
#                                                                                        :owner => auction["owner"], 
#                                                                                        :bid => auction["bid"], 
#                                                                                        :buyout => auction["buyout"], 
#                                                                                        :quantity => auction["quantity"], 
#                                                                                        :timeLeft => auction["timeLeft"],
#                                                                                        :createdDate => lastModified,
#                                                                                        :lastModified => lastModified
#                                                                                    )
#                    end

                end


            end

            puts "Auction import complete."
            @log.info "Auction import complete."
            puts "Done in #{Time.now - start}"
            return true

        rescue => e

            puts "Failed to import auctions\n #{e}"
            @log.error "Failed to import auctions\n #{e}"
            
            return false

        end

    end


    def deleteold(lastModified)

        if(lastModified !=0)

            puts "Deleting expired auctions."
            @log.info "Deleting expired auctions."

            auctionDataset = @DB.from(@auctionsTable)

            auctionDataset.exclude(:lastModified => lastModified).delete

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

            logDataset = @DB.from(@logTable)
            auctionDataset = @DB.from(@auctionsTable)

            #whereClause = '"' + @logTable + '"."auctionNumber" IS NULL'

            #logDataset.insert([:auctionNumber, :item, :owner, :bid, :buyout, :quantity, :timeLeft, :createdDate, :lastModified, :bidCount], auctionDataset.left_outer_join(@logTable, :auctionNumber => :auctionNumber).where(whereClause).qualify )

            #logDataset.insert(auctionDataset.where('"lastModified" < ?', lastModified).exclude(:auctionNumber => logDataset.select(:auctionNumber)))

            query = %{INSERT INTO "#{@logTable}"
                    SELECT source."auctionNumber",
                        source.item,
                        source.owner,
                        source.bid,
                        source.buyout,
                        source.quantity,
                        source."timeLeft",
                        source."createdDate",
                        source."lastModified"
                    FROM "#{@auctionsTable}" AS source
                    LEFT JOIN "#{@logTable}" AS destination ON source."auctionNumber" = destination."auctionNumber"
                    WHERE destination."auctionNumber" IS NULL AND source."lastModified" < '#{lastModified.strftime("%Y-%m-%e %H:%M:%S")'}}

            @DB.run(query)

            #logDataset.insert_ignore.insert(auctionDataset.where('lastModified < ?', lastModified))

            puts "Successfully moved all old auctions to the log tables."
            @log.info "Successfully moved all old auctions to the log tables."

            return true

        rescue => e
            
            puts "Failed to move old auctions to log table\n #{e}"
            @log.error "Failed to move old auctions to log table\n #{e}"
            return false

        end

            
        
    end

    def itemExistsInDB?(itemID) # Check if a single item exists in the Items table

        begin
            
            @db.execute("SELECT COUNT(*) FROM items WHERE ID = :ID", "ID" => itemID) do |item|

                return true if item[0] == 1

                return false
        
            end


        rescue => e
            
            puts "Failed to check if item exists in the database."
            puts e

        end

    end

    def insertItem(itemID, itemName, itemJSON) # Inserts an item into the Items table for name resolusion.

        begin
            
            @DB[:items].insert(:id => itemID, :name => itemName, :JSON => itemJSON)

        rescue => e
            
            puts "Failed to insert item into database.\ #{e}"
            @log.error "Failed to insert item into database.\ #{e}"

        end


    end

    def itemsNotInDB # Returns all times not found in the Items table.

        begin

            missingItems = []

            logDataset = @DB.from(@logTable)

            logDataset.distinct(:item).exclude(:item => @DB[:items].select(:id)).limit(20).each do |item|

                missingItems << item[:item]

            end

            return missingItems

        rescue => e
            
            puts "Failed to determine which items are not in the database.\n #{e}"
            @log.error "Failed to determine which items are not in the database.\n #{e}"

            return nil

        end

        
    end

    def insertMissingItems(missingItems,itemJSON)

            missingItems.each_with_index do |item,i|

                self.insertItem(item[0], itemJSON[i][0], itemJSON[i][1])

            end
        
    end

    def close

        @DB.disconnect
        
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