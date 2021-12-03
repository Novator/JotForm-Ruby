@echo off

rem ===Download some forms:
rem ruby DnlFiles.rb f84e264df59951530a761763798b1c 434367750455542
rem ruby DnlFiles.rb f84e264df59951530a761763798b1c 563423065465454

rem ===Download ALL forms:
rem ruby DnlFiles.rb f84e264df59951530a761763798b1c all
ruby DnlFiles.rb f84e264df59951530a761763798b1c all "C:\MyData" >> "C:\run.log"


