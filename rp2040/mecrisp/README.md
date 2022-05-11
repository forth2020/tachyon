**INSTALL**

Load mecrisp-2.61-921600bd.uf2 onto the RP2040/Pico in the usual manner.

In a separate linux terminal startup minicom in ANSI mode 921600bd and ^AU to get it to add a CR (Mecrisp outputs a single LF instead of CRLF)

After booting do a  1 SAVE#  to make a backup of the clean kernel.
Load TACHYON.FTH with 7ms line-delay

LINUX s script uses ascii-xfr (no need to close minicom)
RP2040$ ./s TACHYON USB0 7

If you use Visual Studio Code, type that into it's built in terminal

Part way through the load it switches to the new source load mode so that only the definition names and any messages etc, then a final report.

For the MAKER PICO which has an SD socket create a new init in flash.
R00# compiletoflash
R00# : INIT MAKERPICO ;
R00#: compiletoram
R00#: SAVE
then switch back to ram and save  

Insert a FAT32 SD card - preferably blank or just 8.3 files but optional load the latest on-going incomplete HELP file onto the card.  

Hit ^C to get it to reboot and it also mount the card if your INIT is correct.
Then load FRED.FTH (with minicom still open) and SAVE
./s FRED USB0 5  
Now to create a new file called TEMP for example
R00#  EDNEW TEMP
This may take a moment as it claims clusters and creates a default 1MB file and preformats it with spaces and CR terminators. This TEMP can be your playground.
Type some code and ^S to save the 4K page then F10 to load it etc.
