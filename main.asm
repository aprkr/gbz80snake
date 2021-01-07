; https://eldred.fr/gb-asm-tutorial/hello-world.html
INCLUDE	"hardware.inc"
HeadStart	equ	0000
MaxY		equ	$98
MaxX		equ	$A0
MinY		equ	$10	
MinX		equ	$08
Direction	equ	$D000
dUp		equ	%11
dDown		equ	%10
dLeft		equ	%01
dRight		equ	%00

SECTION	"vBlank Interrupt", ROM0[$40]
	JP	_HRAM

SECTION	"Header", ROM0[$100]		; execution starts at $100

EntryPoint:
	DI
	JP	Start			; However header is at $104-$150

REPT	$150 - $104
	db	0
ENDR

SECTION	"Game code", ROM0

Start:
	LD	C, $80
	LD	B, DMATransferEnd - DMATransfer
	LD	HL, DMATransfer
CopyDMA:
	LDI	A, [HL]
	LD	[$FF00 + C], A
	INC	C
	DEC	B
	JR	NZ, CopyDMA
	LD	A, IEF_VBLANK
	LD	[rIE], A
	EI

	; Turn off the LCD
	Call	WaitVBlank

	

	XOR	A, A 			; ld a, 0 ; We only need to reset a value with bit 7 reset, but 0 does the job
	LD	[rLCDC], A 		; We will have to write to LCDC ($FF40) again later, so it's not a bother, really.
	LD	HL, $8000
	LD	DE, $9FFF - $8000
	CALL	ClearMap
	LD	HL, $C000
	LD	DE, 160
	CALL	ClearMap
	
	LD	HL, $9000		; $8000 + 16*256
	LD	DE, FontTiles
	LD	BC, FontTilesEnd - FontTiles
.copyFont
	LD	A, [DE]
	LDI	[HL], A
	INC	DE
	DEC	BC
	LD	A, B
	OR	C
	JR	NZ, .copyFont

	LD	C, 16
	LD	HL, $8000
	LD	DE, FontTiles + 16

.copyTile
	LD	A, [DE]
	LDI	[HL], A
	INC	DE
	DEC	C
	LD	A, C
	OR	A
	JR	NZ, .copyTile
	
	LD	HL, _RAM
	LD	A, 16
	LDI	[HL], A	; y
	LD	A, 8
	LDI	[HL], A	; x
	XOR	A
	LDI	[HL], A	; Tile No:
	LD	[HL], A	; attributes
	
	LD	HL, _SCRN0		; This will print the string at the top-left corner of the screen
	LD	DE, _SCRN1 - _SCRN0
	CALL	ClearMap
	LD	A, %11100100
	LD	[rBGP], A		; $FF47
	XOR	A, A
	LD	[rSCY], A		; $FF42
	LD	[rSCX], A		; $FF43
	
	; Shut sound down
	LD	[rNR52], A		; $FF26
	
	; Turn screen on, display background
	LD	A, %10000011
	; LD	A, LCDCF_ON + LCDCF_WIN9800 + LCDCF_WINOFF + LCDCF_BG8800 + LCDCF_BG9800 + LCDCF_OBJ16 + LCDCF_OBJOFF + LCDCF_BGON ; %1*000*01
	LD	[rLCDC], A		; $FF40
GameLoop:
	LD	DE, $1200
	LD	A, [Direction]
	AND	A, %00000011
	CP	dUp
	JR	Z, Up
	CP	dDown
	JR	Z, Down
	CP	dLeft
	JR	Z, Left
	JR	Right

Down:
	LD	A, [$C000]
	CP	MaxY
	JR	NC, WrapUp
	ADD	A, 8
	LD	[$C000], A
	JR	Read

WrapUp:
	LD	A, MinY
	LD	[$C000], A
	JR	Read

Up:
	LD	A, [$C000]
	CP	MinY
	JR	Z, WrapDown
	SUB	A, 8
	LD	[$C000], A
	JR	Read

WrapDown:
	LD	A, MaxY
	LD	[$C000], A
	JR	Read
	
Left:
	LD	A, [$C000 + 1]
	CP	MinX
	JR	Z, WrapRight
	SUB	A, 8
	LD	[$C000 + 1], A
	JR	Read

WrapRight:
	LD	A, MaxX
	LD	[$C000 + 1], A
	JR	Read

Right:
	LD	A, [$C000 + 1]
	CP	MaxX
	JR	NC, WrapLeft
	ADD	A, 8
	LD	[$C000 + 1], A
	JR	Read

WrapLeft:
	LD	A, MinX
	LD	[$C000 + 1], A
	JR	Read

Read:
	CALL	ReadPadFull
	OR	A
	JR	NZ, KeyPressed
	DEC	DE
	LD	A, D
	OR	E
	JR	NZ, Read
	JP	GameLoop
KeyPressed:
	LD	L, A
PostPressLoop:
	CALL	ReadPadFull
	XOR	A
	JR	NZ, PostPressLoop
	DEC	DE
	LD	A, D
	OR	E
	JR	NZ, PostPressLoop

	LD	A, L
	BIT	7, A
	JR	NZ, .ChangeDown
	BIT	6, A
	JR	NZ, .ChangeUp
	BIT	5, A
	JR	NZ, .ChangeLeft
	BIT	4, A
	JR	NZ, .ChangeRight
	JP	GameLoop

.ChangeDown
	LD	A, dDown
	JR	.LoadDirection
.ChangeUp
	LD	A, dUp
	JR	.LoadDirection
.ChangeLeft
	LD	A, dLeft
	JR	.LoadDirection
.ChangeRight
	LD	A, dRight
.LoadDirection
	LD	[Direction], A
	JP	GameLoop
.Wait
	DEC	DE
	LD	A, D
	OR	E
	JR	NZ, .Wait
	JP	GameLoop



WaitDE:
	DEC	DE
	LD	A, D
	OR	E
	JR	NZ, WaitDE
	RET
; MoveSnake:
; 	LD	BC, $4000
; 	CALL	WaitBC
; 	CALL	WaitVBlank
; 	XOR	A
; 	LD	[rLCDC], A
; 	LD	HL, HeadStart
; 	INC	[HL]
; 	LD	A, [HL]
; 	LD	HL, _SCRN0
; 	LD	L, A
; 	XOR	A
; 	DEC	HL
; 	LD	[HL], A
; 	INC	HL
; 	LD	DE, SnakeBlock
; 	CALL	CopyString
; 	LD	A, %10000001
; 	LD	[rLCDC], A
; 	JR	MoveSnake

ReadPadFull:	; Puts keypad input into A: down 7, up 6, left 5, right 4, start 3, select 2, b 1, a 0, 1 means pressed
.readLoop
	LD	A, P1F_GET_DPAD
	LD	[rP1], A
	LD	A, [rP1]
	LD	A, [rP1]
	LD	A, [rP1]
	LD	A, [rP1]
	AND	A, %00001111
	SWAP	A
	LD	B, A

	LD	A, P1F_GET_BTN
	LD	[rP1], A
	LD	A, [rP1]
	LD	A, [rP1]
	LD	A, [rP1]
	LD	A, [rP1]
	AND	A, %00001111
	ADD	A, B
	XOR	A, %11111111
	RET

WaitVBlank:
	LD	A, [rLY]		; $FF44 (LCDC y-coord)
	CP	144 			; Check if the LCD is past VBlank
	JR	C, WaitVBlank		; LY ranges from 0-153, 144-153 is VBlank
	RET

; CopyString:
; 	LD	A, [DE]
; 	LDI	[HL], A
; 	INC	DE
; 	AND	A			; Check if the byte we just copied is zero
; 	JR	NZ, CopyString		; Continue if it's not
; 	RET
ClearMap: ; clear DE bytes at HL
	LD	A, 0
	LDI	[HL], A
	DEC	DE
	LD	A, D
	OR	E
	JR	NZ, ClearMap
	RET

; WaitBC: ; A loop
; 	DEC	BC
; 	LD	A, B
; 	OR	C
; 	JR	NZ, WaitBC
; 	RET

DMATransfer: ; transfer bytes from $C000 to OAM
	PUSH	AF
	LD	A, $C0
	LD	[rDMA], A
	LD	A, $28
.DMAWait
	DEC	A
	JR	NZ, .DMAWait
	POP	AF
	RETI
DMATransferEnd:

SECTION	"Font", ROM0

FontTiles:
INCBIN	"font.chr"
FontTilesEnd:

SECTION	"Hello World string", ROM0

HelloWorldStr:
	db	"Hello World!", 0
UpString:
	db	"Up button", 0
SnakeBlock:
	db	1, 0