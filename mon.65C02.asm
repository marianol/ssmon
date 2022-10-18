; Simple Serial Monitor
; (c) Mariano Luna
;
; Inspired on the Woz Mon for Apple 1

.target "65C02"
.encoding "ascii"


  .org $8000 ; fill first 8k since rom stats at $A000
  .text "ROM starts at $A000 (2000) "
  .text "v1 mon.asm ACIA at $8010 "
  .text "simple serial monitor"
  nop 

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
CR = $0D
LF = $0A

; zero page
ZP_START1 = $00
ZP_START2 = $0D

;.zeropage
  .org $0000
  .org ZP_START2
LINE_BUFFER:
  .storage $50

  .segment "Code"
  .org $A000 ; ROM Start

reset:
  cld
  ldx #$FF         ; init the stack
  txs 

  lda #%00000011 ; ACIA Master reset
  sta ACIA_CONTROL

  lda #%00010101 ; 0 Set No IRQ, 00 no RTS, 101 8 bit,NONE,1 stop AND 01 x16 clock 115200bps @ 1.8432Mhz
  sta ACIA_CONTROL
  jsr delay

start: 
; Display startup message
  ldy #0
showStartMsg:
  lda	startupMessage,y
  beq	waitForInput
  jsr   tx_data
  iny
  bne	showStartMsg

; Wait for line input
waitForInput:
  ldy #0
waitForKeypress:
  jsr rx_data
  bcc waitForKeypress
  jsr tx_data
  sta LINE_BUFFER,y
  iny
  cmp #LF			    ; compare with LF (enter will send CR+LF) 
  beq processLine

  and #$DF              ; convert to uppercase
  cmp #'Q'			    ; compare with [Q]uit
  beq endmsg
  jmp waitForKeypress

processLine:
  ; process line
  lda #'*'
  jsr tx_data
  jmp waitForKeypress

endmsg: 
; Display end message
  ldy #0
showEndMsg:
  lda	endMessage,y
  beq	donop
  jsr   tx_data
  iny
  bne	showEndMsg

donop:
    nop
    jmp donop

tx_data:
  pha	            ; Store A for TX later	
tx_wait:		
  lda ACIA_STATUS	; Load status
  and #ACIA_TDRE    ; check for Tx Data Register Empty a logical 1 here means EMPTY
  cmp #ACIA_TDRE
  bne tx_wait	    ; repeat until ready to TX	
  pla 
  sta ACIA_DATA     ; send char
  rts
	
rx_data:
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

startupMessage:
  .byte	$0C,"## YAsixfive02 Monitor ##",$0D,$0A,"type help for commands",$0D,$0A,$00

endMessage:
  .byte	$0D,$0A,">> Thanks !!",$0D,$0A,$00

  .org $fffa
  .word reset ; NMI
  .word reset ; RESET
  .word reset ; IRQ/BRK	
