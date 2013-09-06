Colligate
=================
A program to download and store auctions from the World of Warcraft API

This project is an attempt at creating a local snapshot of the ingame Auction house on a World of Warcraft realm.
The snapshot data can then be used to visualize trends in the virtual economy or be used for statistical analysis.

Implemented Features
=================
Request all active auctions on a realm for all three factions.

Download and parse the JSON file containing auction data from the WoW API.

Save the data in a SQLite3 database.

Move outdated auctions to a secondary history database.

Dependencies
=================
This program relies on the following Ruby gems:
Sqlite3
JSON
gchart

How to use
=================
Run the main program “Colligate.rb” and follow the CLI.
