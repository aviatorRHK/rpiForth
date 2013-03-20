/******************************************************************************
*   count.s
*    by Roland Koluvek
*
*   A function that will toggle n times at t1 time and exit 1.
*   r0 is n and r1 is pin gpio pin. 
******************************************************************************/


.global CountShort     
CountShort:
push  {r2-r8,lr}

pulses  .req    r4
pin     .req    r5

mov     pulses,r0
mov     pin,r1

/*
* Use our new SetGpioFunction function to set the function of GPIO port 16 (OK 
* LED) to 001 (binary)
*/


mov     r0,pin
mov     r1,#1
bl      SetGpioFunction

loopx$:       
subs    pulses,#1
blt     exit10$
bl      onpulse

/* test for end */
b       loopx$

exit10$:

pop     {r2-r8,pc}

.unreq  pulses

/* turn on */
turnon:
push    {lr}
mov     r0,pin 
mov     r1,#1
bl      SetGpio
pop     {pc}
/* turn off */
turnoff:
push    {lr}
mov     r0,pin 
mov     r1,#0
bl      SetGpio
pop     {pc}
/* on pulse */
onpulse:
push    {lr}
bl      turnon
bl      turnoff
pop     {pc}
/* off pulse */
offpulse:
push    {lr}
bl      turnoff
bl      turnoff
pop     {pc}
.unreq  pin



/* show word part in r0 length in r1  */
.global     showword
showword:       
push    {lr}

push    {r0,r1}
mov     r0,#1    @ synch pulse
mov     r1,#0    @ gpio 0  
bl      CountShort
pop     {r0,r1}

bl      shownow

mov     r0,#1    @ synch pulse
mov     r1,#0    @ gpio 0  
bl      CountShort

pop     {pc}

/* show without synch */
.globl  shownow
shownow:
pin     .req    r5
byte    .req    r6
counter .req    r7
       
        push    {r2-r9,lr}
        push    {r0,r1}
        mov     pin,#1        
        mov     r0,pin 
        mov     r1,#1
        bl      SetGpioFunction
        pop     {r0,r1}
        mov     byte,r0
        mov     counter,r1
        mov     r8,counter
        sub     r8,#1
        mov     r9,#1
        lsl     r9,r8  
loopit$:
        subs    counter,#1
        blt     doneit$
        mov     pin,#1 
        tst     byte,r9
        bleq    turnoff
        blne    turnon
        lsl     byte,#1
        b       loopit$
doneit$:
        mov     r0,#1    @ end pulse
        mov     r1,#0    @ gpio 0  
        bl      CountShort

        pop     {r2-r9,pc}
        .unreq  counter
        .unreq  byte
        .unreq  pin
        
