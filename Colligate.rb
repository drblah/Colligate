# encoding: utf-8
require "yajl"
require "logger"
require "yaml"
require "work_queue"

require_relative "Downloader"
require_relative "DBmanager"

log = Logger.new("log.log")

realms = YAML.load_file("settings.yaml")

while true
	puts("\nPlease choose an activity:\n\n")

	puts("1. Download, Load and store")
	puts("0. Exit program\n")
	

	if(ARGV.length == 0)

		input = gets.chomp

	else

		input = ARGV[0]

	end

	case input

	when "1"
		while true
		#downloader = Downloader.new("eu","argent-dawn")
		#dbhandeler = DBmanager.new("eu", "argent-dawn")
		workQueue = WorkQueue.new 4, nil

			realms.each do |r|

				workQueue.enqueue_b {

				downloader = Downloader.new(r["region"], r["realm"])
				dbhandeler = DBmanager.new(r["region"], r["realm"])

				lastModified = 0
				oldLastModified = 0
				
					puts "Checking for new data. #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"
					log.info "Checking for new data. #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"

					dataInfo = downloader.getauctionURL

					if dataInfo != nil
						lastModified = dataInfo[1]	
					end

					if lastModified > oldLastModified

						puts "New data is available. Beginning work..."
						log.info "New data is available. Beginning work..."


						oldLastModified = lastModified
						
						success = downloader.downloadAuctionJSON(dataInfo[0])

						if success
						
							success = dbhandeler.writeAuctionsToDB(dbhandeler.readAuctionJSON,lastModified)

						end
						
						if success
						
							success = dbhandeler.moveoldtolog(lastModified)

						end

						if success
							
							dbhandeler.deleteold(lastModified)

						end

						missingItems = dbhandeler.itemsNotInDB

						if missingItems != nil
							

							puts "Found #{missingItems.length} items not in item cache."
							log.info "Found #{missingItems.length} items not in item cache."
			
							itemJSON = Array.new
			
							missingItems.delete_if do |item|

							bnetdata = downloader.getItemJSON(item[0])


							if (defined? bnetdata) #Check if we got any data from downloader class. If not, skip the item untill next update.
							

								if bnetdata[0] == nil
									
									true

								else
									
									puts "Inserting #{item[0]}"
									log.info "Inserting #{item[0]}"
									

									itemJSON << bnetdata
									false

								end

							else

								true

							end
			
								
			
							end
			
							dbhandeler.insertMissingItems(missingItems,itemJSON)

						end

					else

						puts "Nothing new yet."
						log.info "Nothing new yet."

					end
				}		
			end
			puts "Waiting for threads to finish."
			log.info "Waiting for threads to finish."
			workQueue.join
			GC.start
			puts "Sleeping..."
			log.info "Sleeping..."
			sleep(300)
		end
	when "0"
		exit
	end

end
