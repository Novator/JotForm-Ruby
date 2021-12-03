
===JotForm-Ruby

This is the utility for downloading JotForm uploaded files in European zone.
Enhanced standard library JotForm is included.

Command line format:

  ruby DnlFiles.rb <api_key> [<form_id>] [<base_dir>] [<start_time>] [<sub_id>]

    <api_key> - api-key from "Settings/API" in web-cabinet
    <form_id> - not mandatory parameter, form's ID or word "ALL"
    <base_dir> - not mandatory parameter, for set saving directory (can be "default")
    <start_time> - not mandatory parameter, will load files from this date/time
    <sub_id> - not mandatory parameter, submission id

Examples:
  ruby DnlFiles.rb f84e264df59951530a761763798b1c 232525643543748
  ruby DnlFiles.rb f84e264df59951530a761763798b1c all
  ruby.exe DnlFiles.rb f84e264df59951530a761763798b1c all "/home/user/MyData"
  ruby.exe DnlFiles.rb f84e264df59951530a761763798b1c all "default" "2021-07-30"
  ruby.exe DnlFiles.rb f84e264df59951530a761763798b1c all "C:/MyData" "2020.12.31 23:59:55"
  ruby.exe DnlFiles.rb f84e264df59951530a761763798b1c 324323863549362 "default" "2021-07-30" 4546889675119265290

You can get api-key from "API/apiKeys" section in JotForm web cabinet.


SYSTEM REQUIREMENTS

- Linux, Windows or Mac OS
- Ruby2.7 or higher script engine
- Prawn PDF library (optional)

Ask author for help:

  http://facebook.com/robux
  http://vk.com/robux
  robux@mail.ru
  tox: D7A2E3FAFA7F001B80EC0676B2F6E57A9E89FA9424A1B5F9C10347418F174D387825CF48196F
  Michael Galyuk

Support development:

  PayPal: robux@mail.ru
  Visa card: 5106 2180 3378 8423
  Yoomoney: 410016271392944
  BitCoin: 1PanDR1Q6TL3qE1TSs2Zagt2ihhEiCBHZB
  Actual payment details: http://robux.perm.ru/pandora.html

