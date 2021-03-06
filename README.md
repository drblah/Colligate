Colligate
=================
A program to download and store auctions from the World of Warcraft API

This project is an attempt at creating a local snapshot of the ingame Auction house on a World of Warcraft realm.
The snapshot data can then be used to visualize trends in the virtual economy or be used for statistical analysis.

Implemented Features
=================
Request all active auctions on a realm for all three factions.

Download and parse the JSON file containing auction data from the WoW API.

Save the data in a PostgreSQL database.

Store ended auctions in an archive.

Resolve item id numbers to actual item names and item info, such as stats etc.

Store item info in a local cache for faster lookup.

Dependencies
=================
This program requires on the following Ruby gems:
Sequel
sequel_pg
pg
Yajl

To install run:

```
gem install sequel sequel_pg yajl-ruby pg
```

How to use
=================
Edit settings.yaml to contain the realms you want to monitor.
The following is an example of a working configration. 

```
---
- realm: argent-dawn
  region: eu
  locale: en_GB
- realm: alakir
  region: eu
  locale: en_GB
```
Valid WoW api regions are:

```
us : US
eu : Europe
kr : Korea : untested, but should work
tw : Taiwan : untested, but should work
```

Locales and regions:

```
Region		Host							Available Locales

US			https://us.api.battle.net/		en_US
es_MX
pt_BR
Europe		https://eu.api.battle.net/		en_GB
es_ES
fr_FR
ru_RU
de_DE
pt_PT
it_IT
Korea		https://kr.api.battle.net/		ko_KR
Taiwan		https://tw.api.battle.net/		zh_TW
China		https://www.battlenet.com.cn/	zh_CN
```

Realm names need to be spelled a bit different than usual. An example of that is argent-dawn, which is normally spelled Argent Dawn. I cannot provide a full list of valid realm names, however you can find the name of your realm through the WoW api.

To find the api name of your realm, go to:

```
[region].battle.net/api/wow/realm/status
```
... and search for your realm. Look for the "slug": tag.

Example:

Say I want to find out the api name of a european realm called: Argent Dawn.
First I go to the following URL in my browser.
```
eu.battle.net/api/wow/realm/status
```
In the list, I search for argent dawn and find this:

```
..."status":false,"name":"Argent Dawn","slug":"argent-dawn"...
```
To make Colliage download data from Argent Dawn, I will have to insert "argent-dawn" as realm and eu as region into settings.yaml.

Run the main program “Colligate.rb” and add your battle.net api key as a launch parameter.

```
ruby Colligate.rb [you-api-key]
```
