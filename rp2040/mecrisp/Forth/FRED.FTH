mecrisp
2205012200 tme?	--- make sure TACHYON.FTH is new enough

pub *FRED* 	PRINT" FORTH READY TEXT EDITOR 220510-2345" ;

{
TO DO:	Limit editing to file size
	Latch insert/delete mode?
	Use ^F10 to load from cursor
	add word wrap
220510	Add import function
	Refresh does not clear page (less flicker)
220503	Add narrow/wide view
	Add auto refresh
220502	Added hightlighting
220501	Added FLOAD
	Added autoindent
220430	Added page sized clipboard to allow copy&paste across pages
220429	Added ^B to ^C selection mode which also highlights selected text.
220427	ED without parameters will try to reopen the last file at the same position
	RE (redit) redundant
	Skip over terminator
	Rename functions to emphasize PAGE vs BLOCK mode
	Improve refresh ops - by line or by page as needed
	Simple HOME key - repeated operation goes to top of page then top of file
	Add page #
220426
220425
220424	Porting to RP2040-Mecrisp/Tachyon
210204  Fixed refresh, added ins & del etc.
210203
210202  check and clean up, factor
        Don't refresh display if adding text on same line.
        Improved hex display with highlight
210131  Add super sector BLOCK mode
210129  Added Flash and RAM as targets (4k pages to do)
        Added simple underline cursor to VGA
210128  Added ANSI sequences and hex mode

210126  Created ED to edit config files by sector
        Added addtional controls etc
        Added cursor key sequences etc


}

\ patches


--- --- --- --- --- --- --- --- --- ---







\ public
0 bytes _ed
\ private
long ~tcur      	--- cursor postion in file
long ~begin 	--- marks beginning of selection (default -1 = none)
long ~end   	--- marks end of select
long ~clipsz	--- size of content copied to clipboard
long ~ew	--- width
long ~pagesz
long ~edsect
long ~opts	--- option flags 0=indent 1=narrow 2=line#
long ~idle
long ~eflgs	--- general editor flags 0=update,
long ~seq	--- highlight sequence
long ~hflgs	--- highlight flags
long ~ecold

DATA $D000 + constant clipboard	--- 4kB clipboard holds up to 1 page
DATA $E000 + constant pagebuf --- allocate PAGEBUF near end of RAM

2 longs ~skeys
--- read a key and maintain a history  (debug)
\ pri EDKEY	KEY DUP ~skeys @ 8 << OR ~skeys ! ;
pri EDKEY ( -- ch )	KEY ~skeys DUP 1+ 7 MOVE DUP ~skeys C! ;



pri tcur@       	~tcur @ ;

pri tcur!       	~tcur ! ;
pri tcur+!      	tcur@ + 0 MAX tcur! ;
pri tcur-!      	NEGATE tcur+! ;

\ pri ew          ~ew C@ ;    --- editor width (default 64 )
pri ew		128 ;
--- editor print width
pri pw			1 ~opts BIT? IF 64 ELSE ew THEN ;

\ pri pagesz		~pagesz @ ;
pri pagesz		4096 ;

pri PAGE#		tcur@ pagesz / ;
pri PAGEADR		tcur@ pagesz 1- ANDN ;



pri BLK! ( width blksiz -- )	~pagesz ! ~ew C! ;

pri @x ( -- x ) 	tcur@ ew // ; --- current x position
pri LEFTLN ( -- row )	tcur@ ew 1- ANDN ;


pri HEXBLK      		16 512 BLK! ;
pri TXTBLK      		2048 BLK! ;


--- Takes about 13.2ms to read a page (8 sectors = 1.6ms/sector )
--- less than 1us otherwise
--- Read in a page from SD into the page buffer
pri SDRDPAGE ( sect bytes -- ram )
    OVER ~edsect @ <>
---   update edsect  buffer size
    IF OVER ~edsect ! pagebuf SWAP SDRDS
    ELSE 2DROP THEN   pagebuf
;
pri PAGE ( offset -- ram )
    DUP pagesz 1- ANDN
    SWAP OVER - SWAP 9 >>
    @FILE + pagesz SDRDPAGE +
;
--- save the current page to file
pri SAVEPAGE      	RW ~edSect @ IF pagebuf ~edsect @ pagesz SDWRS THEN ;

pri FORMAT.PAGE --- convert block to CR delimited lines and replace nulls with spaces
    pagebuf pagesz BOUNDS DO I C@ 0= IF $20 I C! THEN
      I pagesz // ?DUP   IF 1+ ew // 0=   IF $0D I C! THEN THEN
    LOOP
;
pri WIPE.PAGE		pagebuf pagesz $20 FILL FORMAT.PAGE ;
--- format the whole file as pages (blanks with CRs)
pri FORMAT.BLK
    @FILE 0EXIT
--- Write over whole file
    RW FSIZE@ 0
    DO
      I PAGE DUP pagesz $20 FILL
      pagesz BOUNDS DO $0D I ew 1- + C! ew +LOOP
      SAVEPAGE SPINNER
      pagesz
    +LOOP
    RO
;
pri ?FORMAT.BLK		."  Format? " KEY $0D = IF FORMAT.BLK THEN ;

--- Open a file as temporary using Mecrisp strings (does not replace file$ name)
pub EDOPEN ( str len -- )	OVER + 1- C~ FIND-FILE FSECTOR OPEN-SECTOR ;


--- fetch long from SD virtual memory in current file
pri BC@        		PAGE C@ ;
pri BC!			PAGE C! ;   \ wrflg C~~ ;

pri SFADR ;
pri FLASH@      	SFADR C@ ;
pri FLASH!      	SFADR C! ;

pri ED@        		BC@  ;
pri ED!        		BC!  ;

pri FILE? 		file$ SWAP C$= ;
pri FLASH?      	s" FLASH" FILE? ;
pri RAM?        	s" RAM" FILE? ;
pri SECTOR?     	s" SECTOR" FILE? ;

\ pri [b]         	CON? IF BOLD red PEN ELSE red PEN THEN ;
\ pri [/b]        	CON? IF PLAIN ELSE white PEN THEN ;

byte ~ey
pri TEXTXY@ ( -- x y )	tcur@ 0 MAX pagesz // ew U/MOD DUP ~ey C! ;
pri !TEXTXY 		TEXTXY@ SWAP 9 + SWAP 3 + XY ;
pri @STATUS ( n -- )   	1+ pagesz ew / 3 + XY ;

	--- THEME ---
long ~edcols
pub edcols ( i -- )	~edcols + ;

pub THEME		8 << OR 8 << OR 8 << OR ~edcols ! ;
---			text paper info frame
pub -C64		white blue  blue white THEME ;
---			text paper info frame
pub -MINT		blue white black green THEME ;

pri -HDRS        	2 edcols C@ PEN 3 edcols C@ PAPER ;

pri -TEXT        	PLAIN 0 edcols C@ PEN 1 edcols C@ PAPER ;

	--- HEADER INFO ---

pri .FILE
    1 1 XY PRINT" FILE: " file$ PRINT$ 3 SPACES
    SECTOR? IF @FILE .L THEN
;
pri .SIZE
    28 1 XY ." SIZE: " pagesz SPACE 4 U.R PRINT"  x" ew 3 U.R
;
pri .CLIP
    46 1 XY ." CLIP: " ~clipsz @ 4 U.R
;
--- display the clock in the top right corner ( use quick time software clock )
pri .CLOCK
    63 1 XY QTIME@ 0 <# # # ` : HOLD # # ` : HOLD # # #> TYPE
;
{
\ 0....|....1....|....2....|....3....|....4....|....5....|....6....|....7....|....8....|....9....|....1....|....1....|....2.......<
pri .TXTRULE
    ew 0 DO I 10 // 0= IF I 10 /MOD NIP 1 U.R ELSE I 5 // IF ` . ELSE ` | THEN EMIT THEN LOOP
;
}
pri .TXTRULE
    pw 0 DO I 7 AND 0= IF I 3 >> 1 U.R ELSE I 3 AND IF ` . ELSE ` | THEN EMIT THEN LOOP
;
pri .HEXRULE
    pw 0 DO I >N 0 1 .HEX LOOP
    pw 16 = IF 16 0 DO SPACE I .BYTE LOOP THEN
;
{
pri .RULER
    1 2 XY ." PAGE"  PAGE# 1+ 3 U.R SPACE
    ew 16 = IF .HEXRULE ELSE .TXTRULE THEN
;
}
pri .RULER
    -HDRS
    1 2 XY 8 SPACES CR ." PG# "  PAGE# 1+ .
    9 2 XY pw 16 = IF .HEXRULE ELSE .TXTRULE THEN
;
pri .INDENT
    OFF CURSOR 20 1 XY
    0 ~opts BIT? IF white PEN red PAPER ." INDENT" ELSE ." undent" THEN
;

--- display header  - reset term - plain - clear
pri HEADER
    15 EMIT PLAIN -HDRS
    1 1 XY pw 8 + SPACES
    .FILE .CLIP .SIZE .CLOCK .INDENT .RULER
;

pri ?SELECT
    ~end @
    IF --- selection is active if ~end is non-zero
      ~begin @ ~end @ WITHIN
        IF red PEN ELSE 0 edcols C@ PEN THEN
    ELSE DROP
    THEN
;

: hflgs? ( b -- f )
    DUP ~hflgs BIT? DUP IF SWAP ~hflgs CLRB ELSE SWAP ~hflgs SETB THEN
;
: MATCH?	( b s -- f )
    ~seq SWAP C$=
    IF   hflgs? IF -TEXT 0 ELSE 1 THEN
    ELSE DROP 0
    THEN
;

: ?CODE
		7 ~hflgs BIT? IF ~seq C@ $20 = IF -TEXT 7 ~hflgs CLRB THEN THEN
		7 s" ( " DROP 2 MATCH? IF -TEXT THEN
		7 s"  bup" MATCH? IF red pen THEN
		7 s"  irp" MATCH? IF black pen THEN
		;
: ?BOLD    	0 s"  ***" MATCH? IF BOLD THEN ;
: ?UL		1 s"  ___" MATCH? IF UL THEN ;
: ?BLINK	2 s"  !!!" MATCH? IF BLINK THEN ;
: ?COMMENT	3 s"  ---" MATCH? IF magenta PEN THEN
		3 s"  \" DROP 2 MATCH? IF magenta pen THEN
;
: ?REVERSE	4 s"  ..." MATCH? IF REVERSE THEN ;
: ?PARA		5 s" (" DROP 1 MATCH? IF magenta PEN THEN
		5 s" )" DROP 1 MATCH? IF -TEXT THEN  ;
: ?BRACES	6 s" {" DROP 1 MATCH? IF magenta PEN THEN
		6 s" }" DROP 1 MATCH? IF -TEXT THEN  ;

: ?HIGHLIGHT ( ch -- )
    ~seq @ 8 << OR ~seq !
    ?BOLD ?UL ?BLINK ?COMMENT ?REVERSE ?PARA \ ?BRACES
    ?CODE
;
--- Start each row with address offset
pri .ROW ( index -- )
    -HDRS PLAIN CR DUP  2 ~opts BIT?
    IF 7 >> 2 SPACES Z 4 U.R
    ELSE L>W .B .H
    THEN
    ." :" SPACE
    -TEXT ~hflgs C~
    pw BOUNDS
      DO I ?SELECT  I ED@ DUP ?HIGHLIGHT
---   indicate CR terminators anywhere in the line
      DUP $0D = IF DROP REVERSE ` < EMIT -TEXT ELSE ` . AEMIT THEN
      LOOP
    -TEXT \ REVERSE SPACE REVERSE PLAIN
;

(	*** PAGE ***	)

pri .PAGE
--- page offset    for page size
    PAGEADR pagesz BOUNDS
      DO CRLF I .ROW  ew +LOOP
;

pri REFRESH
    OFF CURSOR PLAIN HOME
    HEADER   .PAGE
--- current cursor
    !TEXTXY ON CURSOR
--- refresh timer
    cycles ~idle !  0 ~eflgs CLRB
;

long ~page
--- check if block needs to be refreshed
pri ?REFRESH
    KEY? ?EXIT --- don't bother if more input is available
    ~page @ ~edsect @ <>
      IF ~edsect @ ~page ! REFRESH THEN
;
pri ?PAGE		tcur@ PAGE DROP ?REFRESH ;

(	*** CHARACTER STORE ***		)

--- write a char to the page and set modified flag
pri EDCHAR! ( ch -- ) 	tcur@ ED!  0 ~eflgs SETB ;
--- write new char but skip over any CR terminators
pri EDCHAR!!		EDCHAR! 1 tcur+! tcur@ ED@ $0D = IF 1 tcur+! THEN ;
--- write character to file      forward but skip any embedded CR    then check refresh
pri EDCHAR     		DUP EMIT EDCHAR!! ?REFRESH ;

--- refresh line
pri .LINE		LEFTLN .ROW ;


(	*** NAVIGATION ***	)

--- go to start of next line or auto-indent
pri EDCR
    LEFTLN 0 ~opts BIT?
    IF
    BEGIN DUP BC@ $20 = WHILE 1+ REPEAT
    DUP BC@ $0D = IF DROP LEFTLN THEN
    THEN
    ew + tcur!
;
--- smart tab will jump to comments column
pri EDTAB
	tcur@ 1- ED@ $20 > tcur@ ew 1- AND 8 > AND
	IF LEFTLN 48 +	ELSE tcur@ 8 + 7 ANDN THEN tcur!
;


pri GOUP		~ey C@ ew tcur-! ?PAGE ;
pri GODN		~ey C@ 1+ pagesz ew / <>   ew tcur+! ?PAGE ;
pri PGUP		pagesz tcur-! ;
pri PGDN		pagesz tcur+! ;
--- go to last char in line -
pri ENDLN		LEFTLN ew + BEGIN 1- DUP ED@ $20 > UNTIL 1+ tcur! ;

pri ENDTEXT		tcur@ BEGIN 1+ DUP ED@ 0= UNTIL tcur! REFRESH ;

pri ENDKEY		tcur@ ENDLN tcur@ = IF ENDTEXT THEN ;


--- If cursor is already on left then go to page or file home
pri ?HOME
    PAGEADR tcur@ = IF 0 tcur! REFRESH EXIT THEN
    LEFTLN tcur@ = IF PAGEADR tcur! REFRESH ELSE LEFTLN tcur! THEN
;

(	*** EDIT ***	)
pri CLRLN ( ch -- )	LEFTLN PAGE ew 1- ROT FILL ;
--- Insert and Delete mode - just inserts/deletes spaces for now - might latch mode
pri tINS  		tcur@ PAGE DUP 1+ ew @x - 2- MOVE $20 EDCHAR! ;
pri tDEL  		tcur@ PAGE DUP 1+ SWAP ew @x - 2- MOVE ;
--- Insert a line in the page
pri INSLN		LEFTLN PAGE DUP ew + pagebuf pagesz + OVER - MOVE $20 CLRLN ;
--- Delete a line in the page (need to clear last line)
pri DELLN		LEFTLN PAGE DUP ew + SWAP   OVER pagesz 1- AND pagesz SWAP - MOVE ;


pri REVERT		file$ FOPEN$ DROP tcur@ pagesz + ED@ DROP CLS REFRESH ~end ~ ;
--- just revert the page for an undo for the present
pri UNDO		REVERT ;

pri SAVEFILE
\    RAM? FLASH? OR ?EXIT
    SAVEPAGE RO MODIFIED
    0 @STATUS ." SAVED    "
    file$ FOPEN$ DROP		--- RE-OPEN
;

pri !CLIP		~end ~ ~begin ~~ ~clipsz ~ ;

--- save selected text
pri SAVECLIP
	~begin @ PAGE clipboard ~end @ ~begin @ - DUP ~clipsz ! MOVE
;

--- simply make the end of the text to indicate selection
pri COPY
--- if begin is set - select block else  just select the current line
    ~begin @ 1+
    IF tcur@ ~end !   ~end @ ~begin @ <=
---    swap begin and end if wrong way around (why not?)
      IF ~end @ ~begin @ SWAP  ~begin ! ~end ! THEN
    ELSE LEFTLN DUP ~begin ! ew 1- + ~end !
    THEN
    SAVECLIP
;
--- paste text marked by ^B and ending in ^C to current cursor - skip terminators
pri PASTE
	~clipsz @ clipboard + clipboard ( to from )
	BEGIN
	  DUP C@ DUP $0D = IF DROP ELSE EDCHAR!! THEN
	  1+ DUP 3RD > UNTIL
	2DROP
;
pri CUT
	COPY ~begin @ tcur!  ~end @ ~begin @ DO $20 EDCHAR!! LOOP
	~begin @ tcur!
	!CLIP
;

--- PORTING UTILITY  from/to page files


pub IMPORT ( <from> <to> -- )
    OPEN-FILE FSIZE@ ( sect size )
    OPEN-FILE ( sect1 size sect2 )
    3RD OVER AND 0= IF 2DROP EXIT THEN
--- reopen source as main file - setup dest
    ROT OPEN-SECTOR         ~edsect ! 0 tcur! MUTED
    WIPE.PAGE   0 SWAP 0 ( prevch size 0 )
    DO
--- process a single character checking for tabs
        FGET DUP $09 =
	IF tcur@ 7 ANDN 8 + tcur!
--- else handle CR/LF or characters
        ELSE DUP $0A $0D WITHIN
	  IF OVER $0D = OVER $0A = AND NOT IF LEFTLN ew + tcur! THEN
--- write the character directly to the page buffer
          ELSE DUP pagebuf tcur@ + C! 1 tcur+! THEN
        THEN
--- replace prev   save one full page
	NIP 	  tcur@ pagesz >= IF SAVEPAGE
--- adjust dest sector to next page  reset to start of page
          pagesz 9 >> ~edsect +!     WIPE.PAGE 0 tcur! THEN
    LOOP
--- terminate text with a null line & flush
    DROP LEFTLN ew + pagebuf + ew 1- 0 FILL SAVEPAGE UNMUTED
;



pri EXPORT
;




pri HELP
	s" HELP       " EDOPEN 0 tcur! REFRESH
;

pri OPTIONS
	s" OPTIONS    " EDOPEN REFRESH
	EDKEY REVERT
;



pri FNC1 	HELP ;
pri FNC2 ;
pri FNC3 ;
pri FNC4 ;
pri FNC5 ;
pri FNC6 ;
pri FNC7 ;
pri FNC8 ;
pri FNC9 	1 ~opts TOGB CLS REFRESH ;
pri FNC10 	PLAIN CLS -FLOAD QUIT ;
pri FNC11 	;
pri FNC12 	OFF CURSOR CLS HEADER PLAIN CRLF DIR KEY DROP file$ FOPEN$ DROP REFRESH ;

pri QUITED
    FCLOSE 0 @STATUS white PEN red PAPER file$ PRINT$ PRINT"  CLOSED " PLAIN
    !SP   QUIT
;




\ ****************************************************
(		*** KEY COMMANDS ***		)
\ ****************************************************


\ 1B 5B 31 3B 35 46	^END
pri ESC1 ;
{
1B 5B 32 31 3B 32 7E 		_F10
1B 5B 32 31 3B 35 7E		^F10
1B 5B 32 31 7E 			F10
}
pri ESC2  ( 1B 5B 32 )
    CASE
      $7E OF tINS .LINE 		ENDOF
      ` 1 OF EDKEY $7E = IF FNC10 THEN	ENDOF
    ENDCASE
;
pri ESC3
    CASE
      $7E OF tDEL .LINE 		ENDOF
    ENDCASE
;

--- CSI - control sequence introducer ESC [
pri ESC5B
    CASE --- ANSI KEY SEQUENCES USE $1B $5B ?? ??
      ` A OF GOUP ?REFRESH		ENDOF	--- UP
      ` B OF GODN ?REFRESH		ENDOF	--- DOWN
      ` C OF 1 tcur+! 	 		ENDOF	--- RIGHT
      ` D OF 1 tcur-! 	 		ENDOF	--- LEFT
      ` H OF ?HOME			ENDOF	--- HOME
      ` F OF FSIZE@ ew - tcur! 		ENDOF
      ` 5 OF PGUP REFRESH		ENDOF	--- PGUP VT100
      ` 6 OF PGDN REFRESH		ENDOF	--- PGDN VT100
      ` U OF PGDN REFRESH		ENDOF	--- PGDN ANSI
      ` V OF PGUP REFRESH		ENDOF	--- PGUP ANSI
      ` @ OF tINS .LINE			ENDOF	--- INS
      ` 1 OF EDKEY ESC1			ENDOF
      ` 2 OF EDKEY ESC2			ENDOF
      ` 3 OF EDKEY ESC3			ENDOF
      ` Z OF tcur@ 8 - 7 ANDN tcur! 	ENDOF --- shift+TAB
    ENDCASE
;

{
m0m[0mmm4m34m4m47m7m[47mm[0m4m[47m47mmm0m7m0m0m0mm0m47mm34m47m34m47m34m0m[47mm[47m[3

1B 5B 41		up
1B 5B 66		down
1B 5B 44		left
1B 5B 43		right
1B 5B 31		home
1B 5B 40		INS
1B 5B 32 7E		INS	VT100
1B 5B 33 7E		DEL	VT100
1B 5B 35		PGUP
1B 5B 36 7E		PGDN	VT100

1B 5B 55		PGDN	ANSI
1B 5B 56		PGUP	ANSI
1B 5B 36 3B 35 7E 	^PGDN
1B 5B 35 3B 35 7E	^PGUP
1B 5B 31 3B 35 48	^HOME	to start of file
1B 5B 32 3B 35 7E  	^INS
1B 5B 33 3B 35 7E	^DEL
1B 5B 31 3B 35 43	^RIGHT
1B 5B 31 3B 35 44 	^LEFT
1B 5B 31 3B 35 41 	^UP
1B 5B 31 3B 35 42	^DN
1B 5B 31 3B 35 46	^END	ESC [1;5F
1B 5B 32 31 7E 		F10
}


pri FNCKEY --- 1B 4F XX
    CASE
      ` F OF ENDKEY 		ENDOF --- END
      ` M OF DELLN REFRESH	ENDOF --- SHIFT+ENTER
      ` P OF FNC1 		ENDOF
      ` Q OF FNC2 		ENDOF
      ` R OF FNC3 		ENDOF
      ` S OF FNC4 		ENDOF
      ` T OF FNC5 		ENDOF
      ` U OF FNC6 		ENDOF
      ` V OF FNC7 		ENDOF
      ` W OF FNC8 		ENDOF
      ` X OF FNC9 		ENDOF
      ` Y OF FNC12 		ENDOF
    ENDCASE
;

{
: ESS BEGIN KEY DUP 3 <> WHILE .B SPACE REPEAT ;
ansi
1B 5B 41	up
1B 5B 66	down
1B 5B 44	left
1B 5B 43	right
1B 5B 31	home
1B 5B 32	INS
1B 5B 33	DEL
1B 5B 35	PGUP
1B 5B 36	PGDN

FNC
1B4F46	END
1B4F50	F1
1B4F51
1B4F52
1B4F53
1B4F54
1B4F55
1B4F56
1B4F57
1B4F58	F9
1B5B32	F10
1B4F59	F12
}

pri EDESC
    a>A CASE --- ESC <KEY> COMMANDS
    $0D OF INSLN REFRESH	ENDOF 	--- ALT+ENTER
    $5B OF EDKEY ESC5B 		ENDOF
    $4F OF EDKEY FNCKEY 	ENDOF
    $7F OF tDEL .LINE		ENDOF	--- DEL
    $1B OF !CLIP REFRESH	ENDOF	--- ESC ESC
    ENDCASE
;

pri ED^Y
    a>A CASE
    ` I OF 0 ~opts TOGB .INDENT			ENDOF
    ` L OF 2 ~opts TOGB REFRESH			ENDOF
\    ` W OF 					ENDOF
    ` H OF HEXBLK 				ENDOF
    ` N OF 32 TXTBLK 				ENDOF
    ` T OF 64 TXTBLK 				ENDOF
\    ` W OF 128 4096 BLK!			ENDOF

    ` X OF 0 CLRLN 				ENDOF	--- erase current line (nulls)
    ` Z OF WIPE.PAGE REFRESH 			ENDOF	--- wipe & format page
    ^ Q OF 0 @STATUS PLAIN QUIT			ENDOF	--- special debug quit
    ^ Z OF ?FORMAT.BLK				ENDOF
    $0D OF FORMAT.PAGE REFRESH			ENDOF
    $20 OF $20 CLRLN 				ENDOF	--- blank current line (spaces)
    ENDCASE
    ;

pri EDKEY:
    ?DUP 0EXIT
    CASE
      ^ A OF 1 tcur+! 				ENDOF
      ^ B OF tcur@ ~begin ! ~end ~		ENDOF	--- mark beginning of selection block
      ^ C OF COPY REFRESH			ENDOF	--- mark end of block and copy
\     ^ D OF 					ENDOF
\     ^ E OF 					ENDOF
\     ^ F OF 					ENDOF
\     ^ G OF 					ENDOF
      ^ H OF 1 tcur-! $20 EDCHAR! .LINE	ENDOF
      ^ I OF EDTAB		 		ENDOF
      ^ J OF ( ignore ) 			ENDOF
\     ^ K OF					ENDOF
      ^ L OF pagesz tcur+! REFRESH 		ENDOF	--- page down
      ^ M OF EDCR ?REFRESH 			ENDOF	--- CR new line
      ^ N OF HEXBLK REFRESH 			ENDOF
      ^ O OF OPTIONS				ENDOF
\     ^ P OF 					ENDOF
      ^ Q OF QUITED 				ENDOF
      ^ R OF REVERT 				ENDOF
      ^ S OF SAVEFILE 				ENDOF
      ^ T OF 64 TXTBLK REFRESH 			ENDOF
\     ^ U OF					ENDOF
      ^ V OF PASTE REFRESH			ENDOF
      ^ W OF ew tcur-! REFRESH 			ENDOF
      ^ X OF CUT REFRESH			ENDOF
      ^ Y OF EDKEY ED^Y REFRESH 		ENDOF
      ^ Z OF  UNDO	 			ENDOF
---	an escape key itself cancels any selections and always refreshes the page
      $1B OF 4 ms KEY? IF EDKEY EDESC  ELSE CLS REFRESH THEN  ENDOF
    ~skeys C@  EDCHAR
    ENDCASE
;


--- main editor loop
pri EDTASK ( <addr>  -- )
    tcur! CLS REFRESH cycles ~idle !
    BEGIN
      !SP -TEXT KEY?
        IF cycles ~idle ! EDKEY EDKEY: !TEXTXY
	ELSE cycles ~idle @ - ABS 500000 >
	  0 ~eflgs BIT? AND IF REFRESH THEN
	THEN
    AGAIN
;

--- setup EDIT
pri !ED
    SD? 0= IF ."  No SD? " QUIT THEN
    ~ecold @ $A55A <>
    IF
    -MINT 128 4096 BLK! ~edsect ~~ ~hflgs ~ ~opts ~
    !CLIP
    $A55A ~ecold !
    THEN
;

pub ED ( ED <file> or 0 ED SECTOR or 0 ED FLASH )
    !ED GET$ DUP LEN$
    IF SPACE FOPEN$ IF 0 EDTASK THEN
--- try to reopen the last file at the same position
    ELSE file$ FOPEN$ IF tcur@ EDTASK THEN
    THEN
--- not a file, then check for ....
\    HEXBLK
--- or SECTOR
    SECTOR? IF FSECTOR 0 EDTASK THEN
--- don't know
    PRINT"  BAD COMMAND "
    ;

--- edit a sector (current in text mode)
: EDSECT	!ED OPEN-SECTOR file$ 16 ERASE s" SECTOR" file$ SWAP MOVE 0 EDTASK ;

--- Create a new preformatted file - default size = 1MB (else use "n FSIZE! NEWED <name>")
\ : NEWED		!ED RWC OPEN-FILE IF FORMAT.BLK 0 EDTASK THEN ;
--- deprecate NEWED and standardize EDxxx words
: EDNEW		!ED RWC OPEN-FILE IF FORMAT.BLK 0 EDTASK THEN ;


--- DEBUG KEY SEQUENCES - USE ^C to exit
{
: ESS 	BEGIN KEY DUP 3 <> WHILE .B SPACE REPEAT ;

}


*END*
