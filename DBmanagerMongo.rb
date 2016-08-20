# encoding: utf-8
require "yajl"
require "fileutils"
require "logger"
require "sequel"
require "mongo"

# This class will handle all calls to the database.
class DBmanager

    def initialize(region, realm, connection)

            @auctionsTable = "#{region}_#{realm}_auctions"
            @logTable = "#{region}_#{realm}_auctionsLog"

            @log = Logger.new("log.log")

            # Open database if it exists.
            @DB = connection
            
    end

    # Writes the loaded aucitons into the database
    def writeAuctionsToDB(json, lastModified)

        auctions = Yajl::Parser.parse(json)["auctions"]

        if auctions == nil
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

            # Create and populate list of downloaded auctions.
            alist = []
            auctions.each do |auction|

                    alist << { :update_many => {  :filter => {:auctionNumber => auction["auc"]},
                                
                                :update => {
                                    '$set' => {
                                        :auctionNumber => auction["auc"],
                                        :item => auction["item"], 
                                        :owner => auction["owner"], 
                                        :bid => auction["bid"], 
                                        :buyout => auction["buyout"], 
                                        :quantity => auction["quantity"],
                                        :timeLeft => auction["timeLeft"],
                                        :createdDate => lastModified,
                                        :lastModified => lastModified
                                            } },
                                :upsert => true }}


                

            end

            @DB[:argent_dawn].bulk_write(alist)

            puts "Done inserting. Quitting..."

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

            result = @DB[:argent_dawn].find("lastModified" => { "$ne" => lastModified}).delete_many

            puts "#{result.deleted_count} old auctions has been deleted from the database."
            @log.info "#{result.deleted_count} old auctions has been deleted from the database."

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

            result = @DB[:argent_dawn].find("lastModified" => { "$ne" => lastModified})

            result = @DB[:argent_dawn_log].insert_many(result)

            puts "Successfully moved all (#{result.inserted_count}) old auctions to the log tables."
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
            @DB[:items].insert_one( { :_id => itemID, :name => itemName, :json => itemJSON } )

        rescue => e
            
            puts "Failed to insert item into database.\ #{e}"
            @log.error "Failed to insert item into database.\ #{e}"

        end


    end

    def itemsNotInDB # Returns all times not found in the Items table.

        begin

            missingItems = []
            currentItems = []

            @DB[:items].find({ "deprecated" => {"$ne" => true} }).projection({"_id" => 1}).each do |i|
                currentItems << i["_id"]
            end

            @DB[:argent_dawn].find( {"item" => {"$nin" => currentItems}} ).projection({"item" => 1, "_id" => 0}).limit(20).each do |i|
                missingItems << i["item"]
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
        
        @DB[:item].update_one( { "_id" => itemID}, { "$set" => { "deprecated" => true } } )

    end

    def close

        @DB.close
        
    end

    def getLastModified
        
        time = nil

        @DB[:argent_dawn].find().sort({"lastModified" => -1}).limit(1).each do |result|
            time = result["lastModified"].getlocal
        end

        if time == nil
            time = Time.new(1970,1,1)    
        end

        return time

    end

end