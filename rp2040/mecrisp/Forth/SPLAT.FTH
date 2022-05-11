MECRISP

pub *SPLAT*        ." SPLAT - Serial Pico Logic Analyzer Terminal  220424-1320 " ;

2204240000 TME?		--- check if Tachyon Mecrisp Extensions are new enough

{
CHANGELOG:
220424	standardize timebase as tenths of ns
220420	Added current input state into left column
2204xx	Added measurement window (to do: measurements)
220411	Adding TRANSITIONAL ACQUISITION function (also updated TACHYON)

220404 	expand labels to 8 characters (up to 329 labels)
	Add pin function info
220331 Pico version
210812 Expanded to 64 channels display
	Automatic A or B or A+B capture
	Added peristent labels
	Added popup menu.
210811 Fixed zoom, optimized code.
210809 Got this working in TAQOZ on the P2
170309 Adapted for Tachyon V4
150915 Improved refresh speed, added division marker rows
150915 Experimenting with using cursor and function keys as they use ANSI escape sequences rather than a single keycode
150906 If baud sampling is set then cursor shows decoded ASCII if placed on start bit
150905 Allow settings to be remembered (via BACKUP) and not overridden on boot
150905 Changed help text so that it could be loaded into any area of EEPROM
150905 Various enhancements etc. Changed to V1.0
150903 Added input channels command I to set input channels from 8 to 32 - defaults to 28
150903 Changed some commands so that they are the same in the command line (i.e. Z instead of * etc)
150903 Moved <num> to top of stack to permit command line use.
150903 Changed KEY method to use standard KEY input plus maintain a latched copy in newkey
150903 Added aliases for ns us ms and baud as n u m b - so command line 115200 b will set the scale to baud rate

150902 Added: units can now be entered in ns us ms and baud modes to set the scale which is shown in ns/us
150902 Added: PASM capture function - it appears that 525ns is the fastest capture possible with one cog
150902 Added: PINLOAD function to display whether pin is pulled up/down or floating

TORefresh time 123ms for 28 channels 100 wide @2M or 510ms @115200
250ms for 75x16 @115200

CODE STATS:
10076  bytes use


save to SD inc config
Make HELP text a standard text file that can be pasted in and saved in EEPROM (esp 64k) or SD card
Include DUMP format listing for ASCII decode view mode


}

\ 		*** PATCHES ****
: 4*	2 << ;

(		*** DATA ***		)

--- VARIABLES ---


org@ constant spvars


\ 18 constant fastcycle

long timebase		--- timebase in ns/10
long scale		--- timebase in cycles
long lbaud		--- timebase in baud

long samples		--- address of displayed samples
long lcur		--- cursor column
long curadr		--- absolute address of cursor in samples

long trig		--- trigger masks
long triglev		--- trigger level (high/low)
long trigdly		--- delay after trigger

byte newkey
byte snew


byte ~width		--- width of display * 4
byte ~zoom		--- zoom factor
byte zoomo


byte first#	--- first channel to be displayed
byte last#	--- last channel to be displayed

pri channels		last# C@ 1+ first# C@ ;
pri width		~width C@ 4* ;
pri zoom		~zoom C@ ;

$D0000004 constant INPUTS	--- input port address

$20034000 constant CAPBUF
$1000 constant capsz		--- size in longs




(		*** TRIGGER & CAPTURE ***		)

--- set trigger but if no parameter then select all
pri TRIGGER	trig @ INPUTS begin OVER OVER @ AND 0= UNTIL 2DROP ;

{
TRANSITIONAL ACQUISITION
Use DELTA capture method where only transitions are saved
along with a microsecond cycle count
When this method is used then the buffer can be reduced also

If a spare low frequency PWM output is enabled it will force recording
even during inactiviy so this force a timeout without extra logic.
}
pri DELTACAP ( addr cnt -- )
---	dummy compare value before do loop
	0 -ROT BOUNDS
	DO
--- ( old ) update inputs & compare ( new )
	  BEGIN INPUTS @ ( 3 bic ) DUP ROT <> UNTIL
---	  save current inputs along with cycle count ( cycles,inps)
	  DUP cycles I 2!
	8 +LOOP DROP
;
{
BEGIN INPUTS @ DUP ROT <> UNTIL
20020698: 20D0  movs r0 #D0
2002069A: 0600  lsls r0 r0 #18
2002069C: 6843  ldr r3 [ r0 #4 ]
2002069E: 42B3  cmp r3 r6
200206A0: 461E  mov r6 r3
200206A2: D0F9  beq 20020698
DUP cycles I 2!
200206A4: 2080  movs r0 #80
200206A6: 0300  lsls r0 r0 #C
200206A8: 30A8  adds r0 #A8
200206AA: 02C0  lsls r0 r0 #B
200206AC: 6A83  ldr r3 [ r0 #28 ]
200206AE: 0022  lsls r2 r4 #0
200206B0: 6013  str r3 [ r2 #0 ]
200206B2: 6056  str r6 [ r2 #4 ]
200206B4: 3F04  subs r7 #4
200206B6: 603E  str r6 [ r7 #0 ]
8 +LOOP
200206B8: 2608  movs r6 #8
200206BA: 2080  movs r0 #80
200206BC: 0600  lsls r0 r0 #18
200206BE: 1900  adds r0 r0 r4
200206C0: 19A4  adds r4 r4 r6
200206C2: 1B40  subs r0 r0 r5
200206C4: 1980  adds r0 r0 r6
200206C6: CF40  ldmia r7 [[ r6 ]]
200206C8: D7E6  bvc 20020698
}

{
8ns cycle time @125MHz
FASTCAP   144ns/sample = 18cycles
}
144 constant fastns

pri FASTCAP ( addr cnt -- )	INPUTS -ROT BOUNDS DO DUP @ I ! 4 +LOOP DROP ;

--- simple capture routine - needs asm/dma and/or other core for full-speed
pri LACAP ( addr cnt scale  -- )
	timebase @ 9999 > IF DROP  DELTACAP EXIT THEN
	?DUP
	IF
	  1 MAX -ROT BOUNDS INPUTS -ROT ( scale ioadr end src )
---	capture with delays
	  DO DUP @ I ! OVER 0 ?DO LOOP  4 +LOOP 2DROP
---	zero delay capture
	ELSE FASTCAP
	THEN
;


pub CAPTURE	CAPBUF CAPSZ scale @ LACAP ;



(		*** LABELS *** 		)

--- allow for persistent labels in code memory
CREATE clabels 256 ALLOT clabels 256 ERASE
pri @LABEL ( index -- adr )	3 << clabels + ;
--- Create a channel label of up to 8 characters in one long - usage: 6 LABEL RXD1
pre LABEL  ( <n> <name> -- )
	DUP 0 29 WITHIN IF TOKEN ROT @LABEL DUP 8 ERASE SWAP MOVE ELSE DROP THEN
;

0 LABEL TXD
1 LABEL RXD


(		*** DISPLAY ***			)


--- use 1 of 7 colors for channels, never black, with offset
pri LAHUE    		4 + 7 MOD 1+ PEN ;


pri COND		2 2 XY PEN REVERSE ." ** " ;
pri RUNNING		red COND ;
pri STOPPED		white COND ;
pri ARMED		yellow COND ;


pri .RULER.SP
	9 SPACES PLAIN width zoom / zoom *
	--- vertical division every 10th
	0 DO I 10 MOD 0= I AND IF ` | ELSE ` = THEN EMIT LOOP
	BOLD REVERSE SPACE CRLF
	;

pri GRID?			DUP 7 AND 0= SWAP first# C@ <> AND ;
pri .GRID			GRID? IF .RULER.SP THEN ;
pri GRID			1 3 XY channels  DO I .GRID CRLF LOOP ;


pri .STATES
	HOME CRLF CRLF
	white PEN REVERSE
	channels DO
	I GRID? IF CRLF THEN
\	width 9 + I 2+ XY
	INPUTS @ I |< AND IF ` 1 ELSE ` 0 THEN EMIT
	CRLF
	LOOP
	;

pri .LABEL ( CHAN -- )
	white PEN REVERSE SPACE
	--- fill in right border and label if set
	@LABEL DUP C@ IF 8 TYPE ELSE DROP THEN CRLF
	;

--- zoom scaling emit - simply repeats characters
pri ZEMIT ( ch -- )		zoom EMITS ;


pri .ns ( ns -- )
	DUP 999999 > IF 100000 U/ 5 1 .DP ." ms" EXIT THEN
	DUP 999 > IF  100 U/ 5 1 .DP ." us" EXIT THEN
	5 U.R ." ns"
;






(		*** METRICS ***		)

byte ~metrics
pri FREQ@			4* @ 20 BITS ;
pri .FREQ ( index -- )		FREQ@ 7 U.R ." Hz"  ;
pri .PW ( index -- )		FREQ@ 1000 M SWAP / .ns  ;

pri .METRIC ( index -- )
	width 11 - 3RD XY   SPACE DUP .FREQ SPACE .PW 2 SPACES
;
pri METRICS	---				23456789.123456789.
	white PAPER red PEN   width 11 - 2 XY PRINT"  FREQUENCY  PERIOD  "

	blue PAPER white PEN  3
	channels DO I GRID? IF 1+ THEN I .METRIC 1+ LOOP
	DROP
;

pri ?METRICS
	~metrics C@ IF METRICS THEN
;

32 longs freqs
{

pri edge? ( -- adr )
	0
	BEGIN
	  ant 8 + ant!
	  ant capbuf capsz + > ?EXIT
	  ant 4 - @ bat AND
	  ant 4 + @ bat AND <>
	UNTIL
	DROP ant
;

long lh
long hl
pub PERIOD ( ch -- min avg max )
	bat! 0 cat!
	CAPBUF ant!
	BEGIN
	ant 4 + @ bat AND 0=
	ant 12 + @ bat AND AND 0=
	WHILE
	ant 8 + ant!
	REPEAT
	ant 8 + ant!

	ant 8 + @ cat! THEN


	DO I 4 + @ OVER AND 0= I 12 + @ 3RD AND AND
	IF
	 8 +LOOP
	;

}

pri MEASURE


;




(		*** DECODE ***		)

--- return with serial character found from this start bit position assuming 3 samples per bit
pri ASCII? ( addr chan -- byte )
---	check framing
	|< OVER @ OVER AND 0=    3RD 4 - @ 3RD AND 0<> AND
	IF ( adr cha dat )
---	   extract data bits
	 0 10 1 DO 2/  3RD I 4* +  @  3RD AND
	 IF $100 OR THEN  LOOP
	 $100 XOR --- forces invalid if stop bit not set
	ELSE
	  $1FF
	THEN
	NIP NIP
;
pri .CURSOR ( addr chan -- offset )
	REVERSE	BOLD lbaud @
	IF ( ch BYTE )
          SWAP OVER ASCII? DUP $21 $7E WITHIN ( ch flg )
	  IF EMIT 4 ELSE DUP $FF > IF DROP SPACE 4 ELSE .BYTE 12 THEN THEN
	ELSE --- j bit
	  SWAP @ OVER |< AND IF ` 1 ELSE ` 0 THEN ZEMIT
	  4
	THEN
	SWAP PLAIN BOLD LAHUE
;
--- DIAGNOSTIC FOR ASCII DISPLAY
: .CH 	12 0 DO OVER I CELLS + @ OVER |< AND 0<> 1 AND PRINT LOOP ;

\ ` - variable chh
` - 8 << ` _ OR variable chlh

pri .BIT ( bit -- )		 IF chlh 1+ C@ ELSE chlh C@ THEN ZEMIT ;

{
__________________________________-----------------------------------

FASTCAP 69 for 10us = 144ns = 18 cycles
}
pri .ROWT ( addr longs -- )
	BOUNDS DO
	--- check for cursor column
	  curadr @ I =
          IF I bat .CURSOR
          ELSE I @ bat |< AND  .BIT 4
          THEN
	+LOOP
;
pri .ROWV
	5 / 2* BOUNDS
	DO I 8 + @ I @ - ABS 5 U.R 8 +LOOP
;

--- transitional acquistion display
pri .ROWD ( addr longs -- ) ( bat = row index bit )
	timebase @ 555 = IF .ROWV EXIT THEN
	2 >> cat! ant!
	BEGIN
	  ant 8 + @  ant @ - ABS ( us )
	  10000 timebase @ */ cat UMIN 1 UMAX
	  ant CELL+ @ bat |< AND ( us bit )
	  OVER 0 DO DUP .BIT LOOP DROP
	  cat SWAP - DUP cat! ( addr cols-us )
	  ant 8 + ant!
	0=
	UNTIL
;
pri .ROW.SP	timebase @ 9999 > IF .ROWD ELSE .ROWT THEN ;

--- DEBUG
pub .DELTAS ( cnt -- )
	CAPBUF SWAP 3 << BOUNDS
	DO CRLF I 8 + @ I @ - ABS 8 U.R ." us " I 4 + @ .BIN 8 +LOOP
	;



pri .CHAN ( index -- )
	DUP LAHUE
	REVERSE DUP 2 U.R
	white PEN REVERSE .FNC
	PLAIN BOLD
	;



(		*** MAIN DISPLAY ***		)

pri .TRIG	|< trig @ AND IF BLINK red PEN ` + EMIT ELSE SPACE THEN PLAIN ;

--- print LOGIC ANALYZER DISPLAY ---
pub .LAD ( addr lcnt --- )
	OFF CURSOR
	OVER lcur @ 4* + curadr !
	4* --- convert long count to bytes in byte memory
	1 3 XY REVERSE
 --- cycle through all the memory 1 bit position at a time - one line per bit
	channels
	DO
	  I bat!
	  I .GRID
	  SPACE
	  I .TRIG
	  I .CHAN
          I LAHUE
	  ( addr bcnt ) 2DUP .ROW.SP
	  I .LABEL
	LOOP
	2DROP     .RULER.SP PLAIN
	?METRICS
	;





(		*** CONFIGURATION ***		)


--- save old key in upper byte and clear current entry
pri !KEY		newkey C~ ; \ newkey H@ 8 << newkey H!  ;

--- add another digit to the current number
pri +ENTRY		$30 - SWAP 10 * + ;

pri CE			0 BEGIN DEPTH 2 > WHILE ROT DROP REPEAT ;
--- clear stack except for last item and also push 0
pri !ENTRY 		CE !KEY ;

\ pri .ts			0 <# # ` . HOLD #S #> TYPE ;

pri .dns ( ns*10 -- )
	10 /MOD OVER IF 3 U.R ` . EMIT 1 U.R ." ns"
	ELSE NIP .ns THEN
;

--- Print the scale in units of ns/us/ms etc - input is in tenths of ns - i.e. 28875 = 2.8875us
pri .SCALE ( ns*10 -- )
	timebase @ 9999 >
	IF timebase @ 10000 / PRINT ." us" DROP
	ELSE
         .dns
	THEN
	;
pri @footer ( x y --  )     channels - DUP 1- 3 >> + + XY ;

pub FOOTER
	PLAIN white PEN black PAPER REVERSE
	PRINT"  SCALE="
	lbaud @ ?DUP
	IF .DEC ." baud" ELSE timebase @ .SCALE THEN
	PRINT"  x" zoom PRINT
---	calulate time scale of cursor
	PRINT"  @" samples @ lcur @ 4* + CAPBUF - 2/ 2/ DUP PRINT
	PRINT"  =" timebase @ * .SCALE
	2 SPACES OVER 8 U.R SPACE DUP 8 U.R 4 SPACES
	;

--- draws frame etc - still need to move some stuff from .LAD to here
pub FRAME
	OFF CURSOR HOME PLAIN BOLD
	white PAPER black PEN ."  .:.:--TACHYON--:.:. "
	red PEN ." SPLAT "
	black PEN ." LOGIC ANALYZER V1.0 "
--- 	print top border
	PLAIN white PAPER black PEN
	1 2 XY ."   CH FNC "
--- 	print horizontal digit position (01234567890..)
	0 width zoom / 0 DO DUP 10 MOD ` 0 + ZEMIT 1+ LOOP SPACE DROP
--- 	bottom frame
	1 4 @footer width zoom / zoom * 10 + SPACES
--- 	stats
	1 4 @footer FOOTER
--- 	reset colors etc
	PLAIN black PAPER white PEN
	1 5 @footer *SPLAT*
	;


--- return with an entered parameter or else the default supplied
pri PR ( default -- res )        OVER DUP IF NIP ELSE DROP THEN ;

--- set trigger pattern - always allow console RXD to also trigger this so that it can escape
--- Enter >31 for all or toggle bits with <pin> T
pub SETTRIG
	DUP 32 <
	  IF |< trig @ XOR
	  ELSE DROP -1
	  THEN
	trig !
	;


pub SETCUR			DUP lcur ! ;

long _ps   --- picoseconds/cycle (calculated from CLKFREQ )


pri SCALE!			scale ! ;
pri SETSCALE			lbaud ~ SCALE! ;

pri SETps ( n mul -- )		_ps @ */ SCALE! lbaud ~ ;
pri SETns			fastns UMAX DUP 10 * timebase ! 1K SETps  ;
pri SETus			DUP 10000 * timebase ! 1 M SETps  ;
pri SETms			1k * SETus ; \ DUP 1K * timebase ! 1K M SETps ;

pri SETbaud			DUP lbaud ! clkfreq SWAP 3 * / SCALE! ;

pri SETWIDTH			40 UMAX 1024 UMIN 2 >> ~width C!  ;

pri SETZOOM			timebase @ 9999 > IF zoomo C! ELSE 1 10 LIMIT ~zoom C! THEN ;

pri SETchan ( from to -- )	2DUP < IF 1 31 LIMIT  last# C! 0 30 LIMIT first# C! ELSE 2DROP THEN ;

pri SETHL ( h l == )		?DUP IF chlh C! THEN ?DUP IF chlh 1+ C! THEN ;

pri FINDMATCH
	curadr @ @ curadr BEGIN CELL+ 2DUP @ = UNTIL lcur @ 4* - samples !
;





pri !!	( y s cnt -- y+1 )	20 4TH XY   SPACE 2DUP TYPE 40 SWAP - SPACES DROP   1+ ;

pub LAHELP
	white PAPER red PEN   3
	s"     *** MENU FUNCTIONS ***" 		!!
	blue PAPER white PEN
	s" s   SET SAMPLING RATE: 0s" 		!!
	s" n   ns SAMPLING RATE: 50n" 		!!
	s" u   us SAMPLING RATE: 100u" 		!!
	s" m   ms SAMPLING RATE: 5m" 		!!
	s" b   baud RATE: 19200b" 		!!
	s" r   CONTINUOUS CAPTURE & DISPLAY" 	!!
	s" >   SCROLL RIGHT: >" 		!!
	s" <   SCROLL LEFT: 2<" 		!!
	s" ;   ENTER COMMAND SEQUENCE " 	!!
	s" .   RIGHT CURSOR: 20." 		!!
	s" ,   LEFT CURSOR: 20," 		!!
	s" /   RESET DISPLAY TO HOME" 		!!
	s" @   POSITION CURSOR: 200@" 		!!
	s" +   FIND MATCH " 			!!
--- upper or lower OF keys
	s" z   ZOOM IN: 4z" 			!!
	s" w   SET WIDTH: 200W" 		!!
	s" t   SET TRIGGER " 			!!
	s" c   SET CURSOR: 100c" 		!!
	s" i   INPUT RANGE: 32 47i" 		!!
	s" TAB SINGLE SHOT ACQUISTION" 		!!
	s" BS  CORRECT DIGIT" 			!!
	s" SP  STOP or ENTER NEXT PARAMETER" 	!!
	s" ?   HELP MENU" 			!!
	s" CR  Exit to Forth console" 		!!
	s" ANY other key to refresh display" 	!!
	DROP
	KEY
	;


pri SHELL			1 4 @footer DISCARD ON CURSOR PLAIN QUIT ;

pub REFRESH.SP			FRAME samples @ width zoom / .LAD ;
pub PROCESS			!ENTRY REFRESH.SP ;

pri [CAPTURE]			RUNNING 5 ms TRIGGER CAPTURE MEASURE REFRESH.SP STOPPED ;





pri CUR-			1 PR NEGATE lcur @ + 0 MAX lcur ! PROCESS  ;
pri CUR+			1 PR lcur +! PROCESS ;

pri SHIFTS
	CASE
	` D OF lbaud @ IF 30 ELSE 10 THEN CUR- ENDOF
	` C OF lbaud @ IF 30 ELSE 10 THEN CUR+ ENDOF
	ENDCASE
	;
pri ALTS
	DROP
	;
pri CTLS
	CASE
	` D OF 1 ` < KEY!			ENDOF
	` C OF 1 ` > KEY!			ENDOF
	ENDCASE
	;
pri CTSHS
	DROP
	;

pri LAESC ( n -- )
	CASE KEY
	` 2 OF SHIFTS				ENDOF
	` 3 OF ALTS				ENDOF
	` 5 OF CTLS				ENDOF
	` 6 OF CTSHS				ENDOF
	ENDCASE
	DROP
	;

pri UPPER	DUP ` a ` z WITHIN IF $20 - THEN ;

pub LAKEY
	KEY? IF KEY UPPER newkey C! ELSE .STATES THEN
	newkey C@ ` 0 ` 9 WITHIN IF newkey C@ +ENTRY !KEY FRAME EXIT THEN	--- accumulate entry
	newkey C@ CASE
	$08 OF 10 / !KEY FRAME				ENDOF	--- BS clear last digit
	$7F OF !ENTRY FRAME				ENDOF	--- DEL to clear entry (was BACKSPACE )
	$20 OF !KEY PROCESS				ENDOF	--- stop, add entry and refresh screen
	$0D OF SHELL					ENDOF	--- exit to Forth shell
	^ I OF [CAPTURE] !KEY				ENDOF	--- TAB - take a sample
	` > OF 4 PR 4* samples +! CE REFRESH.SP 		ENDOF	--- scroll right
	` < OF 4 PR 4* NEGATE samples +! CE REFRESH.SP 	ENDOF	--- scroll left
	` ; OF KEY LAESC !ENTRY				ENDOF	--- ;n simulates ctl/shf/alt
	` . OF CUR+			 		ENDOF	--- move cursor by amount or 1
	$E8 OF CUR+			 		ENDOF	--- move cursor by amount or 1
	` , OF CUR- 					ENDOF
	$A2 OF CUR-					ENDOF
	` / OF CAPBUF samples ! PROCESS 		ENDOF
	` @ OF 4* CAPBUF + samples ! PROCESS 		ENDOF
	` + OF FINDMATCH PROCESS 			ENDOF
	\ A
	` B OF SETbaud PROCESS				ENDOF	--- set scale by 3*baudrate
	` C OF SETCUR PROCESS				ENDOF
\ D E F G
	` H OF SETHL PROCESS				ENDOF
	` I OF SETchan CLS PROCESS 			ENDOF
\ J K L
	` M OF SETms PROCESS				ENDOF
	` N OF SETns PROCESS				ENDOF
\ 0 P Q
	` R OF [CAPTURE]				ENDOF
	` S OF SETSCALE PROCESS				ENDOF	--- set scale in clock cycles
	` T OF SETTRIG PROCESS				ENDOF
	` U OF SETus PROCESS				ENDOF
\ V
	` W OF SETWIDTH CLS PROCESS 			ENDOF	--- RESET WIDTH & ZOOM or use entry
\ X Y
	` Z OF SETZOOM PROCESS				ENDOF
	` ? OF LAHELP PROCESS				ENDOF
	` \ OF ~metrics C++ PROCESS			ENDOF
	` | OF ~metrics C~ PROCESS			ENDOF
	ENDCASE
	;


org@ spvars - constant spsz

pub !SPLAT
	29 last# C! first# C~
	spvars spsz ERASE
	snew C@ $A5 <>
	IF
	  first# C~
	  29 last# C!
	  76 SETwidth	--- set defaults for 80 columns total
	  10 lcur ! 1 ~zoom C! 1 zoomo C!
	  1 SETus
	  trig ~
	  $A5 snew C!	--- used to detect that settings were backed up
	THEN
--- calculate constant used by scale
	1000000000000. clkfreq UM/MOD NIP _ps !
	CAPBUF samples !
	!ENTRY --- lnum is now on the stack to permit cli use
	;
pub RESUME
	snew C@ $A5 <> IF !SPLAT THEN
	STOPPED
	CLS PROCESS BEGIN LAKEY AGAIN
	;
pub SPLAT	!SPLAT RESUME ;

' RESUME ^ R CTRL!

: STIM	20 2 DO I PIN  I $FE AND 5000 * HZ  I 4* 100 DUTY LOOP ; \ 50 21 SERVO ;


\ 21 LABEL SERVO
\ 12 LABEL BACKLITE
25 LABEL PICOLED


snew C~  \ !SPLAT

*END*
