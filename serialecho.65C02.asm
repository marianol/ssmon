; Simple Serial Echo
; Version 0.1
; (c) Mariano Luna
;
; lets you enter a line and will repet it from the buffer
; Target System: YAsixfive02

; TEST IN  0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f  A  B  C  D  E  F  CR LF
; TEST OUT 30 31 32 33 34 35 36 37 38 39 61 62 63 64 65 66 41 42 43 44 45 46 0D 0A
.target "65C02"
.encoding "ascii"


  .org $8000          ; fill first 8k since rom stats at $A000
  
  .text "ROM starts at $A000 (2000) " ; This is a comment for reference when you load the BIN file
  .text " serialecho.asm ACIA at $8010 "
  .text " v0.1 serial echo"
  NOP 

; Herdware
; ACIA MC60B50
ACIA_BASE     = $8010
ACIA_STATUS   = ACIA_BASE
ACIA_CONTROL  = ACIA_BASE
ACIA_DATA     = ACIA_BASE + 8   ; why did I do this in the memory map is beyond me 
ACIA_TDRE     = %00000010
ACIA_RDRF     = %00000001
ACIA_CONFIG   = %00010101       ; 0/ Set No IRQ; 00/ no RTS; 101/ 8 bit,NONE,1 stop; 01/ x16 clock -> CLK 1.8432Mhz >> 115200bps 

; Constants
CR    = $0D
LF    = $0A
BS    = $08
DEL   = $7F 
SPACE = $20
ESC   = $1B
BUFFER_START = $0200

; zero page
ZP_START1 = $00


;.zeropage
  .org $0000
  .org BUFFER_START
LINE_BUFFER:          ; is this the right way?
  .storage $50


; Main program code
  .segment "Code"
  .org $A000          ; ROM Start

reset:
; standard 6502 housekeeping
  cld                 ; Clear Decimal
  ldx #$FF            ; init the stack
  txs 

; Configure ACIA
  lda #%00000011      ; ACIA Master reset
  sta ACIA_CONTROL
  lda #ACIA_CONFIG    ; 115200bps 8,N,1
  sta ACIA_CONTROL

  jsr delay           ; no reason but is here.


; Top entry of the monitor
start: 
  ldy #0
showStartMsg:         ; Display startup message
  lda	startupMessage,y
  beq waitForInput    ; Messaage done jump and wait for user input
  jsr tx_char
  iny
  bne showStartMsg

; Wait for user to enter a line
waitForInput:
  jsr tx_endline      ; spit the prompt 
  lda #'.'
  jsr tx_char

  ldy #0              ; set y=0 to index the Line Buffer
waitForKeypress:
  jsr rx_char
  bcc waitForKeypress
  jsr tx_char

  cmp #SPACE          ; ignore spaces
  beq waitForKeypress

  sta LINE_BUFFER,y
  iny                 ; @todo #1 check for buffle overflow
  cmp #LF			        ; end of line? (enter will send CR+LF) 
  beq processLine

  jmp waitForKeypress ; keep going until we get a LF

; Process line in the LINE_BUFFER
processLine:
  ; process line
  lda #'p'  ; show that I got here
  jsr tx_char
  jsr tx_endline 

  ldy #0              ; go to top of Line Buffer
nextChar:
  lda LINE_BUFFER,y   ; get the char from line buffer
  iny
  jsr tx_char           ; echo char

  cmp #LF
  beq waitForInput      ; line ended > return

  ;and #$DF            ; convert to uppercase % 1101 1111
  cmp #'Q'			      ; compare with [Q]uit
  beq endmsg

  jmp nextChar       ; try another one

; +-------------------------+---------------------+
; |     CMP                 |  N       Z       C  |
; +-------------------------+---------------------+
; | A, X, or Y  <  Memory   |  1       0       0  |
; | A, X, or Y  =  Memory   |  0       1       1  |
; | A, X, or Y  >  Memory   |  0       0       1  |
; +-----------------------------------------------+

abortLine:
  ; something is not right show error @todo #2 make this better
  lda #'*'
  jsr tx_char
  lda #'E'
  jsr tx_char
  lda #'R'
  jsr tx_char
  jsr tx_endline 

  jmp waitForInput


; Emtry point for show end message and do nothing
endmsg: 
  ldy #0
showEndMsg: ; Display end message
  lda	endMessage,y
  beq allupper
  jsr tx_char
  iny
  bne showEndMsg
  jsr tx_endline 
  ; print last line in CAPS
allupper:
  ldy #0              ; go to top of Line Buffer
nextCaps:
  lda LINE_BUFFER,y   ; get the char from line buffer
  iny
  and #$DF            ; convert to uppercase % 1101 1111

  jsr tx_char           ; echo char

  cmp #LF
  beq waitForInput      ; line ended > return

  jmp nextCaps       ; not M or Q and those are the only things I know do error out


donop:
    nop
    jmp donop

; Transmit one the charcter stored in A
tx_char:
  pha	                ; Store A for TX later	
tx_wait:		
  lda ACIA_STATUS	    ; Load status
  and #ACIA_TDRE      ; check for Tx Data Register Empty a logical 1 here means EMPTY
  cmp #ACIA_TDRE
  bne tx_wait	        ; repeat until ready to TX	
  pla 
  sta ACIA_DATA       ; send char
  rts

; Receives one character and store it in A
; Carry is set if data was received and cleared otherwise
rx_char:
  lda ACIA_STATUS     ; load status 
  and #ACIA_RDRF      ; Check for RX Data empty, a 1 here means FULL
  cmp #ACIA_RDRF
  bne rx_noDataIn     ; jump if there is Nothing in RX Buffler
  lda ACIA_DATA       ; read the RX byte
  sec                 ; set cary to indicate there is a char read 
  rts

rx_noDataIn:
  clc                 ; clear carry to signal no data RX
  rts

; send CR+LF
tx_endline:
  pha                 ; preserve the Accumulator
  lda #CR             ; send CR
  jsr tx_char
  lda #LF             ; send LF
  jsr tx_char
  pla
  rts

; Handy delay routine with room for improvement
delay:
  sta $40             ; save state
  lda #$00
  sta $41             ; high byte
delayloop:
  adc #01
  bne delayloop
  clc
  inc $41
  bne delayloop
  clc
  ; exit
  lda $40             ; restore state
  rts

; Program Data
startupMessage:
  .byte	$0C,"## YAsixfive02 Serial Echo ##",$0D,$0A,"type and press enter",$0D,$0A,$00

endMessage:
  .byte	$0D,$0A,">> Bye !!",$0D,$0A,$00

; IRQ and NMI handling
nmi_entry:
irq_entry:
  rts

; 6502 Vectors 
  .segment "Vectors"
  .org $fffa
  .word nmi_entry       ; NMI
  .word reset           ; RESET
  .word irq_entry       ; IRQ/BRK	
