; Simple Serial Monitor
; Version 0.1
; (c) Mariano Luna
;
; Inspired on the Woz Mon for Apple 1
; Target System: YAsixfive02

.target "65C02"
.encoding "ascii"


  .org $8000 ; fill first 8k since rom stats at $A000
  
  .text "ROM starts at $A000 (2000) " ; This is a comment for reference when you load the BIN file
  .text "v1 mon.asm ACIA at $8010 "
  .text "simple serial monitor"
  NOP 

; Herdware
VIA1_PORTB   = $9000
VIA1_PORTA   = $9001
VIA1_DDRB    = $9002
VIA1_DDRA    = $9003
ACIA_BASE = $8010
ACIA_STATUS = ACIA_BASE
ACIA_CONTROL = ACIA_BASE
ACIA_DATA = ACIA_BASE + 8
ACIA_TDRE = %00000010
ACIA_RDRF = %00000001
; 0/ Set No IRQ; 00/ no RTS; 101/ 8 bit,NONE,1 stop; 01/ x16 clock -> CLK 1.8432Mhz >> 115200bps
ACIA_CONFIG = %00010101 

; Constants
CR = $0D
LF = $0A

; zero page
ZP_START1 = $00
BUFFER_START = $200

;.zeropage
  .org $0000
  .org BUFFER_START
LINE_BUFFER:
  .storage $50


; Main program code
  .segment "Code"
  .org $A000 ; ROM Start

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
  ldy #0
waitForKeypress:
  jsr rx_char
  bcc waitForKeypress
  jsr tx_char
  sta LINE_BUFFER,y
  iny
  cmp #LF			        ; compare with LF (enter will send CR+LF) 
  beq processLine

  and #$DF            ; convert to uppercase
  cmp #'Q'			      ; compare with [Q]uit
  beq endmsg
  jmp waitForKeypress

; Process line in the LINE_BUFFER @todo
processLine:
  ; process line
  lda #'*'
  jsr tx_char
  jmp waitForInput


; Emtry point for show end message and do nothing
endmsg: 
  ldy #0
showEndMsg: ; Display end message
  lda	endMessage,y
  beq donop
  jsr tx_char
  iny
  bne showEndMsg

donop:
    nop
    jmp donop

; Transmit one the charcter stored in A
tx_char:
  pha	            ; Store A for TX later	
tx_wait:		
  lda ACIA_STATUS	; Load status
  and #ACIA_TDRE    ; check for Tx Data Register Empty a logical 1 here means EMPTY
  cmp #ACIA_TDRE
  bne tx_wait	    ; repeat until ready to TX	
  pla 
  sta ACIA_DATA     ; send char
  rts

; Receives one character and store it in A
; Carry is set if data was received and cleared otherwise
rx_char:
  lda ACIA_STATUS   ; load status 
  and #ACIA_RDRF    ; Check for RX Data empty, a 1 here means FULL
  cmp #ACIA_RDRF
  bne rx_noDataIn   ; jump if there is Nothing in RX Buffler
  lda ACIA_DATA     ; read the RX byte
  sec               ; set cary to indicate there is a char read 
  rts

rx_noDataIn:
  clc               ; clear carry to signal no data RX
  rts

; Handy delay routine with room for improvement
delay:
  sta $40  ; save state
  lda #$00
  sta $41  ; high byte
delayloop:
  adc #01
  bne delayloop
  clc
  inc $41
  bne delayloop
  clc
  ; exit
  lda $40  ; restore state
  rts

; Program Data
startupMessage:
  .byte	$0C,"## YAsixfive02 SSMonitor ##",$0D,$0A,"type help for commands",$0D,$0A,$00

endMessage:
  .byte	$0D,$0A,">> Bye !!",$0D,$0A,$00

; IRQ and NMI handling
nmi:
irq:
  rts

; 6502 Vectors 
  .segment "Vectors"
  .org $fffa
  .word nmi ; NMI
  .word reset ; RESET
  .word irq ; IRQ/BRK	
