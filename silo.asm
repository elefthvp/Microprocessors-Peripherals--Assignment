/*
 * AVRAssembler1.asm
 *
 *  Created: 28/5/2018 10:21:10 ??
 *   Authors: Eleftheria Papaioannou
              George Vafiadis
 */ 
 
 .include "m16def.inc"
 .device ATMega16

/* Registers Definitions */
.def temp = r16
.def temp1= r19
.def temp2= r20
.def time7secFlag = r17
.def led0 = r18
.def leds=r19


.CSEG ;code segment of the programme 
/* A macro that toggles the current value of the port given as an argument */
.MACRO OUTI ;P, Rd
		com @1
		out @0, @1
.ENDMACRO


jmp reset

;TOV position
.org 0x100 	
reset: 
		LDI	temp, low(RAMEND)
		OUT	SPL, temp
		LDI	temp, high(RAMEND)
		OUT	SPH, temp   

	/*TIMER INITIALIZATIONS*/
  ;clear the counter
	clr temp
	out TCNT1H , temp
	out TCNT1L , temp

	;load the value 0x6ACE = 27342 = 7s on the timer compare register
	ldi temp,0x6A
	out OCR1AH,temp
	ldi temp,0xCE
	out OCR1AL,temp

	;load the value 0x0F42 = 3905 = 1s on the timer compare register
	ldi temp,0x0F
	out OCR1BH,temp
	ldi temp,0x42
	out OCR1BL,temp

	clr temp; this is for CTC mode
	out TCCR1A,temp
	ldi temp,0b0001000; //this binary value is for CTC mode and prescaling 1024 according to the datasheet
	out TCCR1B,temp
	
	/*enable the interrupt fron timer1 so that it interrupts the process when the desired time passes */
	ldi temp, 1<<OCIE1A
	out TIMSK,temp
	
	ldi temp,0xFF; /*portB is initializes as an output port by writing 0xFF to it
	out DDRB,temp


	/* Analog to Digital Converter Initialization */
	clr r16
  ldi  r16, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
  out  ADCSR, r16
		
  ldi  r16, (1<<REFS0) //choose reference AVCC (=VCC)
  out  ADMUX, r16
	rjmp main

/* Main programme definition */
main:
 start_pr:  ;wait in an endless loop for start to be pressed,
             sbic PIND, 0 ;skip the next command if D is zero, which means pressed
			       rjmp start_pr 
	         
	         

trans_silo_1: ;wait in an endless loop for transportation to silo 1 to be pressed
              sbic PIND,1
			        rjmp trans_silo_1
              ldi leds,0b00100000
			        OUTI PORTB,leds
			  

			  ;wait in an endless loop for main deposit to be full of material
main_deposit:
        ldi  r16, (1<<REFS0) | PA0// set channel
   	    out  ADMUX, r16
   	    sbi  ADCSRA, ADSC              // start conversion

wait_for_conv0_finished:
        sbic ADCSRA, ADSC  //bit ADSC goes low after conversion done         
        rjmp wait_for_conv0_finished 

        in   r1, ADCL
        in   r2, ADCH
		ldi temp1,0x03 
		ldi temp2,0x84
        ;compare
		cp r2,temp1	;compare	//einai ok me ton arithmo twn bits? ti rolo varaei to R1?
		brge wait_for_conv0_finished
		
		cp r1,temp1
		brge wait_for_conv0_finished 
ldi temp,0b00000010
OR leds,temp
OUTI PORTB,leds		
silo1_deposit: 
        ldi  r16, (1<<REFS0) | PA1// set channel
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
		cp temp2,R2	;compare	//einai ok me ton arithmo twn bits? ti rolo varaei to R1?
		brlo wait_for_conv1_finished
		cp temp1,r1
		brlo wait_for_conv1_finished
		
silo2_deposit:
        ldi  r16, (1<<REFS0) | PA2// set channel
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
		cp temp2,R2	;compare	//einai ok me ton arithmo twn bits? ti rolo varaei to R1?
		brlo wait_for_conv3_finished
		cp temp1,r1
		brlo wait_for_conv3_finished
		
B5:     
        
		ldi temp,0b10010000 //anoigw 7 gia run kai 4 gia kinitira m2 simfwna me thn ekfwnhsh
		OR leds,temp
		OUTI PORTB,leds //den to kleinw, to afinw anoixto oso douleyei
		rcall wait7sec//TIMER GIORGOU //delay7s //STIMULATES B5 ACTIVATION
		;edw anabei h mhxanh1
		ldi temp,0b01000100 //anavw led 6 gia m1 kai led 2 gia B5
		OR leds,temp
		OUTI PORTB,leds
		rjmp startsilo1  //sto startsilo1prep tha paei mono an epistrefei apo to silo2

startsilo1_prep:
ldi leds,(1<<5)|(0<<4)
OUTI PORTB,leds
startsilo1:
		sbic ,4
		rjmp siren
		sbic PIND,5
	  	rjmp siren
		sbic PIND,2
		rjmp startsilo2_prep
		sbic PIND,7
	    rjmp stop_handler
silo1filled:


	// read_adc
   	ldi  r16, (1<<REFS0) | PA3// set channel
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
	cp temp1,r2	;compare	//einai ok me ton arithmo twn bits? ti rolo varaei to R1?
	brge startsilo1
		
   cp temp2,r1
   brge startsilo1
		 //gyrnaw stin arxi gia na elegxw kai tis alles sinthikes

startsilo2_prep:
ldi leds,(0<<5)|(1<<4) //vale sti thesi 5 to miden, sti thesi 4 to 1, einai swsto?
OUTI PORTB,leds 
startsilo2:
	sbic PIND,4
	rjmp siren
	sbic PIND,5
	rjmp siren
	sbic PIND,1
	rjmp startsilo1_prep
	sbic PIND,7
	rjmp stop_handler
silo2filled:
    // read_adc
   	ldi  r16, (1<<REFS0) | PA5// set channel
   	out  ADMUX, r16
   	sbi  ADCSRA, ADSC              // start conversion

wait_for_conv5_finished:
   sbic ADCSRA, ADSC  //bit ADSC goes low after conversion done         
   rjmp wait_for_conv5_finished

   in   r1, ADCL
   in   r2, ADCH
   ldi temp1,0x03 
	ldi temp2,0x84
        ;compare
	cp temp1,r2	;compare	//einai ok me ton arithmo twn bits? ti rolo varaei to R1?
	brge startsilo2
		
   cp temp2,r1
   brge startsilo2
		 //gyrnaw stin arxi gia na elegxw kai tis alles sinthikes


siren:
   ldi leds,0b00000001
   OUTI PORTB,leds
 wait_for_ack:
   sbic PIND,6
   rjmp wait_for_ack
on_and_off:
   ldi temp,0x00 //swstos simvolismos?
   OUTI PORTB,temp
   rcall //TIMER GIORGOU 1 SEC
   OUTI PORTB,leds
   rcall //TIMER GIORGOU
   rjmp on_and_off
 
stop_handler: ;;turn all leds on
   ldi temp,0xff
   OUTI PORTB,temp
start_pr2 //perimenw na ksanapatithei start kai arxizw apo tin arxi
   sbic PIND, 0
   rjmp start_pr2
   rjmp trans_silo_1 //sinexizw apo kei pou tha sinexize kata ti diarkeia tis ekkinisis 








time1AOC_handler:;7sec delay for engine 2
	inc time7secFlag
	reti

timer1BOC_handler:;1sec delay blink
	ldi temp ,0b00000001; i want to swap only the 0 led
	com led0
	add led0,temp
	reti

wait7sec:
	ldi temp,0b0001101;this is for CTC mode and prescaling 1024
	out TCCR1B,temp
	clr time7secFlag;wait for 7 seconds with timer
	loopFor7sec:
		sbrs time7secFlag,0
		rjmp loopFor7sec
	
	ldi temp,0b0001000;close the source of the timer
	out TCCR1B,temp
	ret

wait1secblick:
	clr led0
	ldi temp,0b00001000;enable the interrupt OCIE1B
	out TIMSK, temp

	clr temp;clear the counter
	out TCNT1H , temp
	out TCNT1L , temp

	ldi temp,0b0001101;enalbe the prescaling 1024 
	out TCCR1B,temp
	
	loopFor1sec:
		out PORTB,led0;here happens the blinking from the timer until reset
		rjmp loopFor1sec
	ret


        






















		; A routine that delays program execution by 1 sec.
delay1sec:
		push R18
		push R19
		push R20
		
		ldi  r18, 21
    	ldi  r19, 75
    	ldi  r20, 184
d1ss: 	dec  r20
    	;brne d1ss
    	;dec  r19
    	;brne d1ss
    	;dec  r18
    	;brne d1ss
    	rjmp PC+1
		nop		

		pop R20
		pop R19
		pop R18
		ret


