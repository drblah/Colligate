# encoding: utf-8
require "yajl"
require "fileutils"
require "logger"
require "sequel"

# This class will handle all calls to the database.
class DBmanager

    def initialize(region, realm, connection)

            @auctionsTable = "#{region}_#{realm}_auctions"
            @logTable = "#{region}_#{realm}_auctionsLog"

            @log = Logger.new("log.log")

            # Open database if it exists.
            @DB = connection
            
            # Create tables if they do not exist.
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
                    json        :JSON
                    boolean     :deprecated
                end

            end

            
    end

    def trimAuctionJSON(json)

        begin

            f = json
            f = f.lines.to_a[3..-1].join # Remove 3 first lines
            f = f.gsub!( /\r\n?/, "\n" ) # Replace windows line endings with unix ( CRFL to FL )
            f = f.chomp("]}\n}").gsub!(",\n", "\n") # Remove ending of file and remove trailing ',' on each line

            puts "Auction JSONfile successfully trimmed."
            @log.info "Auction JSONfile successfully trimmed."

            return f

        rescue => e
            
            puts "Failed to trim auction JSON file\n #{e}"
            @log.error "Failed to trim auction JSON file\n #{e}"

            return false

        end
        
    end

    # Writes the loaded aucitons into the SQLite3 database
    def writeAuctionsToDB(json, lastModified)

        auctions = trimAuctionJSON(json)

        if auctions == false
            return false
        end

        if lastModified == nil
            puts "lastmodified variable not set! Please make sure to load in a fresh set of data."
            @log.warn "lastmodified variable not set! Please make sure to load in a fresh set of data."
            return false
        end

        begin

            puts "Loading new auctions into the database and updating old."
            @log.info "Loading new auctions into the database and updating old."

            start = Time.now

            @DB.transaction do

                query = %{  
                    CREATE TEMPORARY TABLE tmp
                       (
                        "auctionNumber" bigint NOT NULL,
                        item integer,
                        owner text,
                        bid bigint,
                        buyout bigint,
                        quantity integer,
                        "timeLeft" text,
                        "createdDate" timestamp without time zone,
                        "lastModified" timestamp without time zone
                       ) 
                       ON COMMIT DROP;
                            }   

                @DB.run(query)

                alist = []

                auctions.lines.each do |line|


                    auction = Yajl::Parser.parse(line)

                        alist << {  :auctionNumber => auction["auc"],
                                    :item => auction["item"], 
                                    :owner => auction["owner"], 
                                    :bid => auction["bid"], 
                                    :buyout => auction["buyout"], 
                                    :quantity => auction["quantity"],
                                    :timeLeft => auction["timeLeft"],
                                    :createdDate => lastModified,
                                    :lastModified => lastModified
                                    }  

                    

                end

                @DB[:tmp].multi_insert(alist)
                    query = %{
                        INSERT INTO "eu_argent-dawn_auctions"
                        SELECT source."auctionNumber",
                            source.item,
                            source.owner,
                            source.bid,
                            source.buyout,
                            source.quantity,
                            source."timeLeft",
                            source."createdDate",
                            source."lastModified"
                        FROM tmp AS source
                        LEFT JOIN "eu_argent-dawn_auctions" AS target ON target."auctionNumber" = source."auctionNumber"
                        WHERE target."auctionNumber" IS NULL;
                    }

                    @DB.run(query)

                    query = %{
                        UPDATE "eu_argent-dawn_auctions" AS target
                           SET "auctionNumber"=source."auctionNumber", 
                            item=source.item, 
                            owner=source.owner, 
                            bid=source.bid, 
                            buyout=source.buyout, 
                            quantity=source.quantity, 
                               "timeLeft"=source."timeLeft", 
                               "createdDate"=source."createdDate", 
                               "lastModified"=source."lastModified"
                         FROM tmp AS source
                         WHERE target."auctionNumber" = source."auctionNumber";
                    }

                    @DB.run(query)


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


    def deleteOld(lastModified)

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


    def moveOldtoLog(lastModified)

        begin
            
            puts "Moving old auctions to log."
            @log.info "Moving old auctions to log."

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
                 WHERE destination."auctionNumber" IS NULL AND source."lastModified" < '#{lastModified.strftime("%Y-%m-%d %H:%M:%S")}' }

            @DB.run(query)

            puts "Successfully moved all old auctions to the log tables."
            @log.info "Successfully moved all old auctions to the log tables."

            return true

        rescue => e
            
            puts "Failed to move old auctions to log table\n #{e}"
            @log.error "Failed to move old auctions to log table\n #{e}"
            return false

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

    def setDeprecated(itemID)
        
        @DB.run(%{INSERT INTO items(id, deprecated) VALUES (#{itemID}, #{true})})

    end

    def close

        @DB.disconnect
        
    end

    def getLastModified
        
        result = @DB.fetch(%{SELECT "lastModified" FROM "#{@auctionsTable}" ORDER BY "lastModified" DESC LIMIT 1})

        time = nil

        result.each do |timestamp|

            time = timestamp[:lastModified]

        end

        if time == nil
            time = Time.new(1970,1,1)    
        end

        

        return time

    end

end