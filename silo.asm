 /*
 Created: 28/5/2018 10:21:10
 Authors: Eleftheria Papaioannou
              George Vafiadis
	      */
 .include "m16def.inc"
 .device ATMega16


.def temp = r16
.def adh = r17
.def adl = r18
.def temp1= r19
.def temp2= r20
.def led = r21
.def leds=r22
.def time1secFlag = r23
.def time7secFlag = r24
.CSEG
.MACRO OUTI ;P, Rd
		com @1
		out @0, @1
		com @1
.ENDMACRO

.macro conv10to8bit ;ADL , ADH
;making 10-bit 8-bit by losing a 2-bit accuracy

ror @1 
lsr @0 

ror @1
lsr @0 
.endmacro


jmp reset

;TOV position
.org 0x00C
rjmp time1AOC_handler	;pointer of OCI at pos 0x00C for 7s delay 
.org 0x00E
rjmp timer1BOC_handler	;pointer of OCI at pos 0x00E for 1s delay

.org 0x100 	
reset: 
	LDI	temp, low(RAMEND)
	OUT	SPL, temp
	LDI	temp, high(RAMEND)
	OUT	SPH, temp   

	;clear the counter
	clr temp
	out TCNT1H , temp
	out TCNT1L , temp

	;load the value 0x6ACE = 27342 = 7s on the compare register
	ldi temp,0x6A
	out OCR1AH,temp
	ldi temp,0xCE
	out OCR1AL,temp

	;load the value 0x0F42 = 3905 = 1s on the compare register
	ldi temp,0x0F
	out OCR1BH,temp
	ldi temp,0x42
	out OCR1BL,temp

	clr temp	;this is for CTC mode
	out TCCR1A,temp
	ldi temp,0b0001000	;this is for CTC mode and prescaling 1024
	out TCCR1B,temp
	
	
	ldi temp,0xFF	; load portB as an output
	out DDRB,temp


		
	clr r16
   	ldi  r16, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
   	out  ADCSR, r16
		
   	ldi  r16, (1<<REFS0) //reference = AVCC (=VCC)
   	out  ADMUX, r16
	sei
	rjmp main

main:
 start_pr:  
 	;wait in an endless loop for start to be pressed,
        sbic PIND, 0
	rjmp start_pr 
	         
	         

trans_silo_1: 
	;wait in an endless loop for transportation to silo 1 to be pressed
        sbic PIND,1
        rjmp trans_silo_1
        ldi leds,0b00100000
	OUTI PORTB,leds
			  

	;wait in an endless loop for main deposit to be full of material
main_deposit:
	ldi  temp, (0<<REFS0) | PA0// set channel
        out  ADMUX, temp
    	ldi temp,0b10000101	;enable adc, prescaling 32, conversion hasn't started
	out ADCSRA,temp
	
	ldi temp,0b11000101	;start conv [6]bit
	out ADCSRA,temp

wait_for_conv0_finished:

        sbic ADCSRA, 6  //bit ADSC goes low after conversion done         
        rjmp wait_for_conv0_finished 

        in   adl, ADCL
        in   adh, ADCH
	ldi temp1,0x84
	ldi temp2,0x03 

	;conv10to8bit adl,adh
	;conv10to8bit temp1,temp2
	;OUTI PORTB,adh
	;rcall wait1sec
	;OUTI PORTB,adl
	;rcall wait1sec
	cp adh,temp2
	brlo main_deposit
	cp adl,temp1
	brlo main_deposit

silo1_deposit: 
        ldi  r16, (0<<REFS0) | PA1// set channel
	out  ADMUX, r16
	sbi  ADCSRA, ADSC              // start conversion

wait_for_conv1_finished:
        sbic ADCSRA, ADSC  //bit ADSC goes low after conversion done         
        rjmp wait_for_conv1_finished 

        in   r1, ADCL
        in   r2, ADCH
	ldi temp1,0xc8
	ldi temp2,0x00
        ;compare
	cp temp2,R2	
	brlo silo1_deposit
	cp temp1,r1
	brlo silo1_deposit
		
silo2_deposit:
        ldi  r16, (0<<REFS0) | PA2// set channel
   	    out  ADMUX, r16
   	    sbi  ADCSRA, ADSC              // start conversion

wait_for_conv3_finished:
        sbic ADCSRA, ADSC  //bit ADSC goes low after conversion done         
        rjmp wait_for_conv3_finished 

        in   r1, ADCL
        in   r2, ADCH
	ldi temp1,0xc8
	ldi temp2,0x00
        ;compare
	cp temp2,R2	
	brlo silo2_deposit
	cp temp1,r1
	brlo silo2_deposit
		
B5:     
        
	ldi temp,0b10010000 ;turn on led 4 and 7 
	OR leds,temp
	OUTI PORTB,leds ;leave this open while it runs
	rcall wait7sec	
	
	;turn on m1
	ldi temp,0b01000100 ;turn on led 6 for motor m1
	OR leds,temp
	OUTI PORTB,leds
	
	;rcall wait7sec
	rjmp startsilo1  go to startsilo1_prep when done with silo2

startsilo1_prep:
	clr temp
	ldi temp,(1<<5)|(1<<3)
	eor leds,temp
	OUTI PORTB,leds
startsilo1:
	rcall check_main_silo
	sbis PIND,4
	rcall siren
	sbis PIND,5
	rcall siren
	sbis PIND,2
	rjmp startsilo2_prep
	sbis PIND,7
        rjmp stop_handler
silo1filled:
	// read_adc
	ldi  r16, (0<<REFS0) | PA3// set channel
	out  ADMUX, r16
	sbi  ADCSRA, ADSC              // start conversion

wait_for_conv4_finished:
	sbic ADCSRA, ADSC  //bit ADSC goes low after conversion done         
	rjmp wait_for_conv4_finished
	in   r1, ADCL
	in   r2, ADCH
	ldi temp1,0x03 
	ldi temp2,0x84
        ;compare
	cp r2,temp1
	brlo startsilo1
		
	cp r1,temp2
	brlo startsilo1

startsilo2_prep:
	clr temp
	ldi temp,(1<<5)|(1<<3)
	eor leds,temp
	OUTI PORTB,leds 
startsilo2:
	rcall check_main_silo
	sbis PIND,4
	rcall siren
	sbis PIND,5
	rcall siren
	sbis PIND,1
	rjmp startsilo1_prep
	sbis PIND,7
	rjmp stop_handler
silo2filled:
    	// read_adc
   	ldi  r16, (0<<REFS0) | PA4	// set channel
   	out  ADMUX, r16
   	sbi  ADCSRA, ADSC              // start conversion

wait_for_conv5_finished:
	sbic ADCSRA, ADSC  		//bit ADSC goes low after conversion done         
	rjmp wait_for_conv5_finished
	in   r1, ADCL
	in   r2, ADCH
   	ldi temp1,0x03 
	ldi temp2,0x84
        ;compare
	cp r2,temp1	
	brlo startsilo2
		
   	cp r1,temp2
   	brlo startsilo2
	rcall siren


stop_handler: 
	;turn all leds on
	ldi temp,0xff
	OUTI PORTB,temp
start_pr2: 
	//perimenw na ksanapatithei start kai arxizw apo tin arxi
	sbic PIND, 0
	rjmp start_pr2
	rjmp trans_silo_1 //sinexizw apo kei pou tha sinexize kata ti diarkeia tis ekkinisis 

time1AOC_handler:	;7sec delay for engine 2
	inc time7secFlag
	reti

timer1BOC_handler:	;1sec delay blink
	inc time1secFlag
	reti

wait7sec:
	push temp
	push time7secFlag
	clr temp 
	out TCNT1H,temp
	out TCNT1L,temp
	;enable interrupt fron timer1
	ldi temp, 0b00010000
	out TIMSK,temp
	
	ldi temp,0b00001101
	out TCCR1B,temp
	clr time7secFlag	;wait for 7 seconds with timer
	loopFor7sec:
	sbrs time7secFlag,0
	rjmp loopFor7sec
	
	ldi temp,0b0001000	;close the source of the timer
	out TCCR1B,temp
	pop time7secFlag
	pop temp
	ret

siren:
        ldi leds,0b00000001
	OUTI PORTB,leds
 wait_for_ack:
   	sbic PIND,6
   	rjmp wait_for_ack
on_and_off1:
   	ldi leds,0x00
   	OUTI PORTB,leds
    	rcall wait1sec
	ldi leds,0x01
  	OUTI PORTB,leds
   	rcall wait1sec
   	rjmp on_and_off1
	ret

wait1sec:
	push temp
	push time1secFlag
	clr temp 
	out TCNT1H,temp
	out TCNT1L,temp
	;enable interrupt fron timer1
	ldi temp, 0b00001000
	out TIMSK,temp
	
	ldi temp,0b00001101
	out TCCR1B,temp
	clr time1secFlag	;wait for 7 seconds with timer
	loopFor1sec:
	sbrs time1secFlag,0
	rjmp loopFor1sec
	ldi temp,0b0001000	;close the source of the timer
	out TCCR1B,temp
	pop time1secFlag
	pop temp
	ret

blink:
	push led
	on_and_off:
	ldi led,0x00 
	OUTI PORTB,led
	rcall wait1sec
	ldi led,0xFF
	OUTI PORTB,led
	rcall wait1sec
	rjmp on_and_off
   	pop led
	ret

check_main_silo:
	push temp
	push adl
	push adh
	push temp1
	push temp2

        ldi  temp, (0<<REFS0) | PA0// set channel
	out  ADMUX, temp
    	ldi temp,0b10000101	;enable adc;not conv started ; put prescaling 32
	out ADCSRA,temp
	
	ldi temp,0b11000101	; start conv [6]bit
	out ADCSRA,temp

wait_for_conv10_finished:
        sbic ADCSRA, 6  //bit ADSC goes low after conversion done         
        rjmp wait_for_conv10_finished 

        in   adl, ADCL
        in   adh, ADCH
	ldi temp1,0xc8		; check for under 200/1024
	ldi temp2,0x00 

	;conv10to8bit adl,adh
	;conv10to8bit temp1,temp2
	;OUTI PORTB,adh
	;rcall wait1sec
	;OUTI PORTB,adl
	;rcall wait1sec
	lsr adh
	ror adl

	lsr adh
	ror adl

	lsr temp2
	ror temp1

	lsr temp2
	ror temp1

	cp temp1,adl
	brlo continue

	rcall siren
continue:
	
	pop temp2
	pop temp1
	pop adh
	pop adl
	pop temp

ret		
