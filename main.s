/******************************************************************************
*	main.s
*	 by Alex Chadwick
*
*	A sample assembly code implementation of the input02 operating system, that 
*	demonstrates a commnad line interface.
*
*	main.s contains the main operating system, and IVT code.
******************************************************************************/

/*
* .globl is a directive to our assembler, that tells it to export this symbol
* to the elf file. Convention dictates that the symbol _start is used for the 
* entry point, so this all has the net effect of setting the entry point here.
* Ultimately, this is useless as the elf itself is not used in the final 
* result, and so the entry point really doesn't matter, but it aids clarity,
* allows simulators to run the elf, and also stops us getting a linker warning
* about having no entry point. 
*/
.globl  scrwidth
.set    scrwidth,   1024
.globl  scrheight
.set    scrheight,  768


.section .init
.globl _start
_start:

/*
* According to the design of the RaspberryPi, addresses 0x00 through 0x20 
* actually have a special meaning. This is the location of the interrupt 
* vector table. Thus, we shouldn't make the code for our operating systems in 
* this area, as we will need it in the future. In fact the first address we are
* really safe to use is 0x8000.
*/
b main

/*
* This command tells the assembler to put this code at 0x8000.
*/
.section .text

/*
* main is what we shall call our main operating system method. It never 
* returns, and takes no parameters.
* C++ Signature: void main()
*/
main:

/*
* Set the stack point to 0x8000.
*/
	mov sp,#0x8000

/**************************************************************************
* for testing pulsesz>>> data tobe displayed in r0, number of bit in r1
*********************8*******8*******8*******8*****************************
    ldr r0,=0b10111001011110110011110010100010
    mov r1,#16    
    bl  showword
hold1$:
    b   hold1$ 
/**************************************************************************
* for testing pulses
***************************************************************************/

/* 
* Setup the screen.
*/
    ldr r0,=scrwidth
	ldr r1,=scrheight
	mov r2,#16
	bl InitialiseFrameBuffer

/* 
* Check for a failed frame buffer.
*/
	teq r0,#0
	bne noError$
		
	mov r0,#16
	mov r1,#1
	bl SetGpioFunction

	mov r0,#16
	mov r1,#0
	bl SetGpio

	error$:
		b error$

	noError$:

	fbInfoAddr .req r4
	mov fbInfoAddr,r0
/*
* Let our drawing method know where we are drawing to.
*/
	bl SetGraphicsAddress

	bl UsbInitialise

reset$:
	mov sp,#0x8000
	bl TerminalClear


welcome$:
	ldr r0,=welcome
	mov r1,#welcomeEnd-welcome
	bl Print
	ldr r0,=command
	mov r1,#commandEnd-command
	bl ReadLine
    bl TerminalDisplay
        ldr     r0,=registers
        stmea   r0,{r1-r12}     @ save registers at base
        ldr     r10,=vault      @ load sp0 and rp0
        ldmfd   r10,{r11,r13}
        ldr     ip,=coldstart      @ load ip to first word in testx
        b       _next
	ldr r0,=command
	mov r1,#commandEnd-command
	bl ReadLine
    

loop$:		
	ldr r0,=prompt
	mov r1,#promptEnd-prompt
	bl Print

	ldr r0,=command
	mov r1,#commandEnd-command
	bl ReadLine
    
	teq r0,#0
	beq loopContinue$

	mov r4,r0               @ length is stored in r4
	
	ldr r5,=command
	ldr r6,=LINK
	commandLoop$:
        ldr     r6,[r6]         @ one word at a time 
        teq     r6,#0
        beq     notfound$
        ldrb    r7,[r6,#6]      @ count
        and     r7,#0x1f      
        mov     r10,r7
        teq     r7,r4
        bne     commandLoop$    @ not equal, get next word
        mov     r2,#0        
        add     r8,r6,#7   @ set pointer to beginning of word in word list
1:
        subs    r7,#1
        blt     process
        ldrb    r3,[r8,r2]
        ldrb    r9,[r5,r2]
        add     r2,#1
        teq     r3,r9       @ compare letters
        beq     1b
        b       commandLoop$
process:
        ldr     r0,=messageOK
        mov     r1,#messageOKEnd-messageOK
        push    {r10}
        bl      Print
/************************Forth Registers********************************
****    w   .req    r10
****    rsp .req    r11
****    ip  .req    r12
****    sp  .req    r13
****    lr  .req    r14
****    pc  .req    r15
/* now execute it */
        pop     {r10}
        add     r7,r8,r10          @ r10 count, r8 start of word
        tst     r7,#3
        andne   r7,#0xFFFFFFFC
        addne   r7,#4           @ r7 is execution token
        ldr     r0,=registers
        stmea   r0,{r1-r12}     @ save registers at base
        ldr     r10,=vault      @ load sp0 and rp0
        ldmfd   r10,{r11,r13}
        push    {r7}            @ push execution token onto the stack
        ldr     ip,=_testx      @ load ip to first word in testx
        b       _next
.global onward
onward:                         @ return here 
        ldr     r10,=vault 
        stmea   r10,{r11,r13}
        ldr     r0,=registers
        ldmfd   r0,{r1-r12}
/**********************************************************
        ldr     r0,[sp]  @ top item on stack
        mov     r1,#32   @ 32 bits to be displayed 
        bl      shownow
/**********************************************************/
loopContinue$:
        bl TerminalDisplay
        b loop$
notfound$:
            /*r5 points to start of text r4 is length */
            /*mov to buf as counted string */
        ldr     r0,=buf
        strb    r4,[r0],#1
1:      ldrb    r1,[r5],#1
        strb    r1,[r0],#1
        subs    r4,#1
        bne     1b

/* convert unfounded string to number if possible */
        ldr     r0,=registers
        stmea   r0,{r1-r12}     @ save registers at base
        ldr     r10,=vault      @ load sp0 and rp0
        ldmfd   r10,{r11,r13}
        ldr     ip,=_bufferx    @ load ip to first word in testx
        b       _next
/* will return by the way of onward: */


       b       loopContinue$

        ldr     r0,=messageBad
        mov     r1,#messageBadEnd-messageBad
        bl      Print

        ldr     r0,=command
        mov     r1,#commandEnd-command
        bl      Print

 
echo:
    cmp r1,#5
    movle pc,lr

	add r0,#5
	sub r1,#5 
	b Print

ok:
	teq r1,#5
	beq okOn$
	teq r1,#6
	beq okOff$
	mov pc,lr

	okOn$:
		ldrb r2,[r0,#3]
		teq r2,#'o'
		ldreqb r2,[r0,#4]
		teqeq r2,#'n'
		movne pc,lr
		mov r1,#0
		b okAct$

	okOff$:
		ldrb r2,[r0,#3]
		teq r2,#'o'
		ldreqb r2,[r0,#4]
		teqeq r2,#'f'
		ldreqb r2,[r0,#5]
		teqeq r2,#'f'
		movne pc,lr
		mov r1,#1

	okAct$:
		mov r0,#16
		b SetGpio
	
.section .data
.align 2
welcome:
	.ascii "FORTH OS based on Forth f83xt by Roland Koluvek. Started with Alex's OS - Everyone's favourite OS \n"
welcomeEnd:

.align 2
prompt:
	.ascii "> "
promptEnd:

.align 2
messageBad:
    .ascii "Not Found "
messageBadEnd:

.align 2
messageOK:
    .ascii "OK "
messageOKEnd:

.align 2
command:
	.rept 128
		.byte 0
	.endr
commandEnd:
.byte 0
.align 2
commandUnknown:
	.ascii "Command `%s' was not recognised.\n"
commandUnknownEnd:

.align 2
formatBuffer:
	.rept 256
	.byte 0
	.endr
formatEnd:

.align 2
vault:
    .long  0x007E00     @ r11 tempoary pointers
    .long  0x007F00     @ r13 
vaultEnd:

.align 2
registers:
    .rept 15
    .long 0
    .endr
registersend:

.align 2
.global regs
regs:
    .rept 14
    .word 0
    .endr
regsend:



.align 2
commandStringEcho:  .ascii "echo"
commandStringReset: .ascii "reset"
commandStringOk:    .ascii "ok"
commandStringCls:   .ascii "cls"
commandStringEnd:

.align 2
commandTable:
.int commandStringEcho, echo
.int commandStringReset, reset$
.int commandStringOk, ok
.int commandStringCls, TerminalClear
.int commandStringEnd, 0


