MECRISP ( ST7789 LCD DRIVER - requires RP2040, FONT16X32 )
compiletoflash

: *ST7789* 	PRINT" Text & Graphics driver for ST7789 240x240 IPS LCD 211202-0000" ;
{
 http://www.lcdwiki.com/1.3inch_IPS_Module
st7789 datasheet  8.8.40 4-Line Serial Interface

LCD MODULE PINOUT
1 gnd
2 vcc
3 scl
4 sda
5 res
6 dc
7 bl

Use LCDPINS to setup your configuration in your INIT
The backlite pin is not part of this but the PWM% word
will PWM the pin to the set percentage 0..100
50 12 PWM% --- Set backlite on GP12 to 50% brightness
or rather than creating a port pin constant, just create BACKLITE
: BACKLITE ( % -- )	12 PWM% ;

CHANGELOG:
211202	Removed pin constants and added LCDPINS
 }

$04050203 variable ~lcdpins
: *lcdclk	~lcdpins C@ ;
: *lcddat	~lcdpins 1+ C@ ;
: *lcddc	~lcdpins 2+ C@ ;
: *lcdres	~lcdpins 3 + C@ ;

--- with one lone set pins used by LCD (each byte is a pin)
: LCDPINS ( res.dc.dat.clk --- )	~lcdpins ! ;
\ $0B0D0F0E LCDPINS	( res.dc.dat.clk )

\ : BACKLITE ( % pin -- )	100 10000 ROT PWMHZ ;


{
	!!!deprecated!!!
2	constant *lcddat	--- spi data
3	constant *lcdclk	--- spi clock
4	constant *lcdres	--- low is reset
5	constant *lcddc		--- low is command
31	constant *lcdbl

--- make some fast I/O constants
*lcdclk bit constant &lcdclk
*lcddat bit constant &lcddat
--- bash out SPI bits as fast as possible (needs asm)
: LCDBITS ( dat bits -- )
	0 DO
	  ROL
---	  optimized bit-basher for speed
	  &lcdclk IOCLR SIO!
	  &lcddat OVER 1 AND IF IOSET ELSE IOCLR THEN SIO!
	  &lcdclk IOSET SIO!
	LOOP DROP
	;
}

: LCDBITS ( data bits -- )
	*lcdclk bit -ROT *lcddat bit -ROT ( clk dat data bits )
	0 DO ( clk dat data )
	  ROL
---	  optimized bit-basher for speed
	  2 PICK IOCLR SIO!
	  DUP 1 AND IF OVER IOSET ELSE OVER IOCLR THEN SIO!
	  2 PICK IOSET SIO!
	LOOP DROP 2DROP
	;

: LCDWRL		32 LCDBITS ;
: LCDWRD ( dat16 -- )	16 << 16 LCDBITS ;
: LCDWRB		24 << 8 LCDBITS ;
: LCDCMD		*lcddc LOW LCDWRB *lcddc HIGH  ;
: LCDRST		*lcdclk HIGH *lcdres LOW 20 us *lcdres HIGH ;

	( LCD COMMANDS )

: -NOP			0 LCDCMD ;
: -RES			1 LCDCMD ;
: -WAKE			$11 LCDCMD ;
: -NORM			$13 LCDCMD ; 	\ 9.1.14 NORON (13h): Normal Display Mode On

--- note: I swapped these around since they worked differntly to the datasheet
: -NON			$21 LCDCMD ;
: -INV			$20 LCDCMD ;	\ 9.1.16 INVON (21h): Display Inversion On

: -OFF			$28 LCDCMD ;
: -ON			$29 LCDCMD ;	\ 9.1.19 DISPON (29h): Display On

: -CA			$2A LCDCMD ;	\ 9.1.20 CASET (2Ah): Column Address Set
: -RA			$2B LCDCMD ;	\ 9.1.21 RASET (2Bh): Row Address Set
: -MW			$2C LCDCMD ;	\ 9.1.22 RAMWR (2Ch): Memory Write

\ : -COLMOD		$3A LCDCMD LCDDAT ;
pub -CONT		$3C LCDCMD ;	\ 9.1.33 WRMEMC (3Ch): Write Memory Continue

\ : -BRIGHT		$53 LCDCMD $2C LCDWRB $51 LCDCMD LCDWRB ;
: -ENHANCE		$55 LCDCMD $B2 LCDWRB ;


CREATE initbl
    $36 C, 1 C, $60 C,	\ 9.1.28 MADCTL (36h): Memory Data Access Control (rotate - pins on left)
    $3A C, 1 C, $05 C,	\ 9.1.32 COLMOD (3Ah): Pixel Format  - 16-bit/pixel
    $B2 C, 5 C, $0C C, $0C C, $00 C, $33 C, $33 C, \ 9.2.3 PORCTRL (B2h): Porch Setting
    $B7 C, 1 C, $35 C,	\ 9.2.6 GCTRL (B7h): Gate Control (def = $35 )
    $BB C, 1 C, $19 C,	\ 9.2.9 VCOMS (BBh): VCOM Setting
    $C0 C, 1 C, $2C C,	\ 9.2.12 LCMCTRL (C0h): LCM Control (def)
    $C2 C, 1 C, $01 C,
    $C3 C, 1 C, $12 C,
    $C4 C, 1 C, $20 C,
    $C6 C, 1 C, $0F C,
    $D0 C, 2 C, $A4 C, $A1 C,
    $E0 C, 14 C, $D0 C, $04 C, $0D C, $11 C, $13 C, $2B C, $3F C, $54 C, $4C C, $18 C, $0D C, $0B C, $1F C, $23 C,
    $E1 C, 14 C, $D0 C, $04 c, $0C C, $11 C, $13 C, $2C C, $3F C, $44 C, $51 C, $2F C, $1F C, $1F C, $20 C, $23 C,
    0 C,

pub !LCD
    *lcdclk HIGH *lcddat LOW
    LCDRST 10 ms
    -WAKE 5 ms
    initbl BEGIN DUP C@ WHILE C@++ LCDCMD C@++ 0 DO C@++ LCDWRB LOOP REPEAT DROP
    -NON
    -ON
;

pub LCDXYS ( x y xend yend--- )
	-RA ROT LCDWRD LCDWRD
	-CA SWAP LCDWRD LCDWRD
	-MW
	;
pub LCDHOME		!LCD 0 0 239 239 LCDXYS ;

--- PIXEL FORMAT: rrrr rggg gggb bbbb

--- write to LCD screen from memory
pub LCDWRS ( src -- )	LCDHOME 240 240 * 2* BOUNDS DO I H@ LCDWRD 2 +LOOP ;

--- fill and clear the screen
pub LCDFILL		-OFF 0 0 239 239 lcdxys 240 240 * 0 DO DUP LCDWRD LOOP DROP -ON ;
pub LCDCLS		0 LCDFILL ;

	( *** BMP VIEWER *** )

\ 1024 BUFFER: palette
SDBUF $400 + constant palette	--- use upper 1k of SDBUF for temp palette

0 	variable xres
0 	variable yres
0 	variable bpp

$FFFF 	variable pixand
0 	variable pixor
0 	variable pixxor

pub LCDPIX	pixxor @ XOR pixand @ AND DUP IF pixor @ OR THEN LCDWRD ;

pub VIEW240
	LCDHOME
	$0A SDH@ 240 240 * 2* + --- start from end
	240 0 DO 480 -		--- read from start of line
	  240 0 DO dup SDH@ LCDPIX 2+ LOOP
	  480 -			--- previous line
	LOOP
	DROP
;
pri ?PALETTE
	bpp C@ 8 =
	IF palette 14 SDH@ 14 + 1024 BOUNDS
	   DO I SDH@ OVER H! 2+ 2 +LOOP DROP
	THEN
;
pub VIEW ( -- )
---	check if BM header and proceed
	0 SDH@ $4D42 = 0EXIT
---	read resolution and colors
	18 SDH@ xres ! 22 SDH@ yres ! 28 SDC@ bpp C!
---	check if it is optimized for this 240x240
	xres @ 240 = yres @ 240 = AND bpp C@ 16 = AND
	IF VIEW240 EXIT THEN
---	otherwise assume it is 256 color bmp 640xYSIZE
	?PALETTE LCDCLS LCDHOME
--- 	point to the end of the pixel array
	10 SDH@   xres @ yres @ * + 1-
---	up to 240 lines
	yres @ 2/ 0 DO
--- 	  Read every 2nd pixel from start of line up to 480 pixels (clipped)
	  DUP xres @ 2- - 480 BOUNDS
	  DO
	    I SDC@
---	lookup 24-bit color from 8-bit color index
	    2* 2* palette +
--- 	read the 3 RGB 8-bit colors from the palette
	    C@++ SWAP C@++ SWAP C@
---	and mix down to 16-bit RGB565
	    3 >> 11 <<		   --- RED
	    SWAP 2 >> 5 << 	OR --- GRN
	    SWAP 3 >> 		OR --- BLU
	    LCDPIX		--- send pixel
	  2 +LOOP
	  xres @ 2* -
	LOOP
	DROP
;



	( *** LCD TEXT *** )

--- LCD PIXEL FORMAT: rrrr rggg gggb bbbb

--- convert ANSI 0 to 7 colors to a 16-bit color
create lcdcols
	0 , $F800 , $07E0 , $FFE0 , $001F , $F81F , $07FF , $FFFF ,

--- convert ANSI color to 16-bit
pri LCDCOL	DUP 8 < IF 2* 2* lcdcols + @ THEN ;

0 variable lcdx		--- text x
0 variable lcdy		--- text y

pri LCDXY		lcdy ! lcdx ! ;
pri LCDHOME1		0 0 LCDXY ;


1 variable lcdx*	--- text font x scale
1 variable lcdy*	--- text font y scale
1 variable lcdcs	--- text char space
2 variable lcdls	--- text line space

pri xsp			lcdx* C@ 4 << lcdcs C@ + ;

pub LCD* ( x y -- )	lcdy* C! lcdx* C! ;

pri LCDCR
    lcdx C~
    lcdy* C@ 5 << lcdls C@ + DUP lcdy +!
    lcdy @ + 239 > IF lcdy ~ THEN
\   lcdy @   240 lcdls C@ lcdy* C@ * - > IF lcdy ~ THEN
;

pri wrpix
    if PEN@ else PAPER@ then
    LCDCOL LCDPIX	\ lcdwrd
;
pri dopix
   lcdx* C@ 0 DO DUP 1 AND wrpix LOOP
;

{
Display and scale a character from the font table
This uses the raw 16x32 Parallax Propeller Font which interleaves bits
to do: convert this to native format
}
pub LCDCH ( ch -- )
---	position character
	lcdx C@   dup lcdx* C@ 4 << 1- +
	lcdy C@ SWAP OVER lcdy* C@ 5 << 1- + LCDXYS
	DUP 1 AND SWAP 2/ 7 << FONT16X32 + 128 bounds
	do
	    lcdy* C@ 0 DO
	    J @ OVER IF 2/ THEN
	    16 0 do dopix 2/ 2/ loop DROP
	    LOOP
	4 +loop DROP
	xsp lcdx +!
	lcdx @ 239 xsp - > IF LCDCR THEN
;

{
16x32 font - max 13 chars x 7 lines

}
0 variable ~lcdch --- backup of emit code
pub LCDEMIT ( ch -- )
--- skip ANSI sequences from ESC to m

	~lcdch C@ $1B = IF [CHAR] m = IF ~lcdch C~ THEN EXIT THEN
	DUP ~lcdch C!
--- check control or printing char
	DUP $1F >
	IF LCDCH
	ELSE CASE
	  $08 OF xsp negate lcdx +! ENDOF
	  $0D OF lcdx C~ ENDOF
	  $0A OF LCDCR ENDOF
	  $0B OF LCDHOME1 ENDOF
	  $0C OF !LCD LCDCLS LCDHOME1 ENDOF
	  $09 OF 4 0 DO $20 LCDCH LOOP ENDOF
	  $1B OF ENDOF
	  ~lcdch C@ LCDCH
	ENDCASE
	THEN
;
--- Make the LCD the character output device
pub LCD		['] LCDEMIT EMIT! ( 13 tw C! ) ;

compiletoram


*END*
