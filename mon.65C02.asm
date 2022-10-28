; Simple Serial Monitor
; Version 0.1
; (c) Mariano Luna
;
; Inspired on the SumerMon64 by  Jim Butterfield and Woz Mon for Apple 1 by Steve Wozniak
; Target System: YAsixfive02

.target "65C02"
.encoding "ascii"


  .org $8000          ; fill first 8k since rom stats at $A000
  
  .text "ROM starts at $A000 (2000) " ; This is a comment for reference when you load the BIN file
  .text "v1.13 mon.asm ACIA at $8010 "
  .text "simple serial monitor"
  NOP 

; Herdware
; VIA #1
VIA1_PORTB    = $9000
VIA1_PORTA    = $9001
VIA1_DDRB     = $9002
VIA1_DDRA     = $9003
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
ASCII_NUM_OFFSET = $30 ; check this 
ASCII_LIT_OFFSET = $37 ; check this 


; zero page
ZP_START1 = $00
ZP_MEMFROM = $10
ZP_MEMTO = $20
LSD = $30
MSD = $31


;.zeropage
  .org $0000
  .org ZP_MEMFROM
  .storage $2
  .org ZP_MEMTO
  .storage $2
  .org BUFFER_START
LINE_BUFFER:          ; is this the right way?
  .storage $50
CMD_ARG:
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
  jsr tx_endline      ; setup the prompt 
  lda #'.'
  jsr tx_char

  ldy #0              ; set y=0 to index the Line Buffer
waitForKeypress:
  jsr rx_char
  bcc waitForKeypress
  jsr tx_char

  ;cmp #SPACE          ; ignore spaces
  ;beq waitForKeypress

  sta LINE_BUFFER,y
  iny                 ; @todo #1 check for buffle overflow
  cmp #LF			        ; end of line? (enter will send CR+LF) 
  beq processLine

  cmp #BS          ; ignore spaces
  dey

  jmp waitForKeypress ; keep going until we get a LF

; Process line in the LINE_BUFFER
processLine:
  ; process line
  lda #'p'  ; dummy to see I got here
  jsr tx_char
  tya
  jsr tx_char
  jsr tx_endline

  ldy #0              ; go to top of Line Buffer
getChar:
  lda LINE_BUFFER,y   ; get the char from line buffer
  iny
    jsr tx_char
  and #$DF            ; convert to uppercase % 1101 1111
    jsr tx_char
  cmp #'M'			      ; [M]emory display > M from [to]
  beq parseMemArgs
  cmp #'W'			      ; [M]emory display > M from [to]
  beq parseMemArgs
  cmp #'R'			      ; [R]un from arg1
  beq parseMemArgs

  cmp #'Q'			      ; compare with [Q]uit
  beq endmsg

  jmp abortLine       ; not M or Q and those are the only things I know do error out
; Emtry point for show end message and do nothing

endmsg: 
  ldy #0
showEndMsg: ; Display end message
  lda	CMD_ARG,y
  beq donop
  jsr tx_char
  iny
  bne showEndMsg

donop:
    nop
    jmp donop

parseMemArgs:
  pha
  ldx #0 ; init arg offset
nextChar:
  lda LINE_BUFFER,y   ; get the char from line buffer
  iny
  ; is end of ARG (SPACE)
  cmp #SPACE		        
  beq nextARG  ; process next ARG
  ; is EOL (CR)
  cmp #CR			        
  beq lastARG  ; we are done here..
 
; A < 40: A >= 30: its a number!
; A < 47: A >= 41: letter ! 
  cmp #$3A          ; comp with 9 ascii + 1
  bcs notnum           ; not a number may be letter
  cmp #$30          ; compare with 0 (zero)
  bcs isnum         ; is a number >=$30 and <$3A
  jmp nextChar      ; no es nada fetch next

notnum: ; is not a number check for A..F
  and #$DF          ; convert to uppercase %1101 1111
  cmp #$47          ; compare with F + 1
  bcs nextChar      ; no es nada fetch next
  cmp #$41          ; compare with A
  bcs isAtoF        ; is A..F <$41 >$47
  jmp nextChar      ; no es nada fetch next

isnum:              ; A is 0..9
  ; convert num string to bin
  sec
  sbc #ASCII_NUM_OFFSET
  sta CMD_ARG, x    ; store in ARG
  jmp nextChar 

isAtoF:             ; A is A..F 
  ; convert A..F string to bin
  sec
  sbc #ASCII_LIT_OFFSET
  sta CMD_ARG, x    ; store in ARG
  jmp nextChar 

nextARG:            ; finish processing one ARG
  lda #SPACE        ;separate ARD with SPACE
  sta CMD_ARG, x 
  jmp parseMemArgs  ; keep processing

lastARG:
  lda #CR        ;separate ARD with SPACE
  sta CMD_ARG, x 
  jmp printMemOutput  ; keep processing 

num2hex:
  asl     ; move the digit to MSD 
  asl
  asl
  asl
  ldx #4  ; iterate 4 times
hexshift:
  asl
  rol LSD
  rol MSD
  dex
  bne hexshift    ; finish shifting?
  jmp nextChar 


; +-------------------------+---------------------+
; |     CMP                 |  N       Z       C  |
; +-------------------------+---------------------+
; | A, X, or Y  <  Memory   |  1       0       0  |
; | A, X, or Y  =  Memory   |  0       1       1  |
; | A, X, or Y  >  Memory   |  0       0       1  |
; +-----------------------------------------------+

printMemOutput:
  ; here I shoul print the memory from XX to YY
  lda #'O'
  jsr tx_char
  lda #':'
  jsr tx_char
  pha   ; recover A pushed in parseArgs should contain the commaand
  jsr tx_char
  jsr tx_endline

  ldy #0
looper:
  lda CMD_ARG, y
  iny
  jsr tx_char
  cmp #CR			        
  bne looper 

  jmp waitForInput

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
  .byte	$0C,"## YAsixfive02 SSMonitor ##",$0D,$0A,"type help for commands",$0D,$0A,$00

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
