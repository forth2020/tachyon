# Installation of Mecrisp-Stellaris Forth kernel with Tachyon extension

This directory contains four utility shell scripts, it may be necessary to mark them as executable before you can use them:
```bash
RP2040$ chmod +x acm qt s usb
```

The utilities are:
* `acm`: script to start `minicom` on a /dev/ttyACM***x*** interface at 921600bd. To use specify the number of the ttyACM port that is being used (generally a digit 0-5). This is particularly used when operating with a separate Pico programmed as a multiport serial bridge.
* `usb`: as with `acm` above this will start a `minicom` session but on a /dev/ttyUSB***x*** interface. In use the number of the port is specified in the same way. This is most commonly found when using commercial USB-Serial adapters.
* `s`: script to send a file to a port it assumes that the port dynamics have already been set up by opening a `minicom` session in a separate window. `s` utilises the standard linux `ascii-xfr` utility. Use by passing three parameters:
   1. The trunk of the filename from the `Forth/` directory (i.e. without the `.FTH` extension);
   2. The name of the tty port to send to, e.g. `ACM0`, `ACM1`, `USB0`, and so on;
   3. The time in milliseconds to wait at the end of each line sent, e.g. 5 or 7.

* `qt`: script to sync host time with system time. Use required the name of the appropriate tty port as above.

## Main flash kernel

Load *mecrisp-2.61-921600bd.uf2* onto the RP2040/Pico by holding down the **BOOTSEL** button whilst connecting the board and then copying the .uf2 file to the revealed memory drive. Once the .uf2 file has been written to the flash memory on the RP2040/Pico it will reboot and start to communicate on the first UART (pins 1 and 2 of the Pico, or Grove port 1 of a Maker Pi Pico).  To communicate it is necessary to have a separate serial connection to your main computer, this can be achieved using an existing on board serial port, a commercial USB-Serial adapter or a second Pico programmed as a serial adapter.

In a separate linux terminal startup minicom in ANSI mode 921600bd and `^AU` to get it to add a CR (Mecrisp outputs a single LF instead of CRLF)

After booting do a `1 SAVE#` to make a backup of the clean kernel.

## Loading Tachyon extension

With the main kernel loaded and `minicom` being used to view it in a terminal window any command will be acknowledged with a simple 'ok.'. Adding in the Tachyon extensions will provide more feedback as well as extra functionality. One of the first and most obvious elements of the extensions is the provision of a command prompt consisting of a letter, a couple of digits and a hash symbol. The letter reflects the destination of any compiled definations, 'R' for ram and 'F' for flash; and the digits reflect the number of items on the parameter stack.

Leaving the `minicon` terminal open, open a second command terminal (of, if you're using **Visual Studio Code**, the use the built in terminal) at the RP2040 directory where the utility scripts are. Use the `s` utility script to load `TACHYON.FTH` with a 7ms line-delay. As an example, if you have a serial port running on /dev/ttyUSB0, the following command will send the file:
```bash
RP2040$ ./s TACHYON USB0 7
```

You can monitor the loading in the `minicom` window and will notice that part way through the load it switches to the new source load mode so that only the definition names and any messages are shown, then a final report.

## Extra action for the Maker Pi Pico

For the Maker Pi Pico which has an SD socket create a new init in flash by entering the following into the `minicom` terminal.
```forth
R00# compiletoflash
F00# : INIT MAKERPICO ;
F00# compiletoram
R00# SAVE
```

## Using an SD card

An SD card can be added by either using the Maker Pi Pico card or by adding a discrete card socket to the GP10-GP15 ports.

Insert a FAT32 SD card - preferably blank or just 8.3 files but optional load the latest on-going incomplete HELP file onto the card.  

Hit `^C` to get it to reboot and it also mount the card if your `INIT` is correct.

## Editing files on the SD card

Following the same procedure as for loading Tachyon, load `FRED.FTH`
```bash
RP2040$ ./s FRED USB0 5  
```
In the minicom terminal you should now `SAVE`.

Create a new file called TEMP for example
```forth
R00#  EDNEW TEMP
```
This may take a moment as it claims clusters and creates a default 1MB file and preformats it with spaces and CR terminators. This TEMP can be your playground.

Type some code and `^S` to save the 4K page then F10 to load it etc.

Return to editing by typing `ED`.
