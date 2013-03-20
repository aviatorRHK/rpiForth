/******************************************************************************
*	keyboard.s
*	 by Alex Chadwick
*
*	A sample assembly code implementation of the input02 operating system.
*	See main.s for details.
*
*	keyboard.s contains code to do with the keyboard.
******************************************************************************/

.section .data
/*
* The address of the keyboard we're reading from.
* C++ Signautre: u32 KeyboardAddress;
*/
.align 2
.global KeyboardAddress
KeyboardAddress:
	.int 0
	
Caps: .word   2
/*
* The scan codes that were down before the current set on the keyboard.
* C++ Signautre: u16* KeyboardOldDown;
*/
KeyboardOldDown:
	.rept 6
	.hword 0
	.endr
	
/*
* KeysNoShift contains the ascii representations of the first 104 scan codes
* when the shift key is up. Special keys are ignored.
* C++ Signature: char* KeysNoShift;
*/
.align 3
KeysNormal:
	.byte 0x0, 0x0, 0x0, 0x0, 'a', 'b', 'c', 'd'
	.byte 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l'
	.byte 'm', 'n', 'o', 'p', 'q', 'r', 's', 't'
	.byte 'u', 'v', 'w', 'x', 'y', 'z', '1', '2'
	.byte '3', '4', '5', '6', '7', '8', '9', '0'
	.byte '\n', 0x0, '\b', '\t', ' ', '-', '=', '['
	.byte ']', '\\', '#', ';', '\'', '`', ',', '.'
	.byte '/', 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	.byte 0x0, 0x0, 0x0, 0x0, '/', '*', '-', '+'
	.byte '\n', '1', '2', '3', '4', '5', '6', '7'
	.byte '8', '9', '0', '.', '\\', 0x0, 0x0, '='
	
/*
* KeysShift contains the ascii representations of the first 104 scan codes
* when the shift key is held. Special keys are ignored.
* C++ Signature: char* KeysShift;£
*/
.align 3
KeysShift:
	.byte 0x0, 0x0, 0x0, 0x0, 'A', 'B', 'C', 'D'
	.byte 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'
	.byte 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T'
	.byte 'U', 'V', 'W', 'X', 'Y', 'Z', '!', '@'
	.byte '#', '$', '%', '^', '&', '*', '(', ')'
	.byte '\n', 0x0, '\b', '\t', ' ', '_', '+', '{'
	.byte '}', '|', '~', ':', '"', '¬', '<', '>'
	.byte '?', 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	.byte 0x0, 0x0, 0x0, 0x0, '/', '*', '-', '+'
	.byte '\n', '1', '2', '3', '4', '5', '6', '7'
	.byte '8', '9', '0', '.', '|', 0x0, 0x0, '='
.align 3

KeysControl:
	.byte 0x0, 0x0, 0x0, 0x0, 0x1, 0x2, 0x3, 0x4
	.byte 0x5, 0x6, 0x7, 0x8, 0x9, 0xA, 0xB, 0xC
	.byte 0xD, 0xE, 0xF, 0x10,0x11,0x12,0x13,0x14
	.byte 0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C
	.byte 0x1D,0x1E,0x1F,'^','&','*','(',')'
	.byte '\n', 0x0, '\b', '\t', ' ', '_', '+', '{'
	.byte '}', '|', '~', ':', '@', '¬', '<', '>'
	.byte '?', 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	.byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	.byte 0x0, 0x0, 0x0, 0x0, '/', '*', '-', '+'
	.byte '\n', '1', '2', '3', '4', '5', '6', '7'
	.byte '8', '9', '0', '.', '|', 0x0, 0x0, '='

.section .text
/*
* Updates the keyboard pressed and released data.
* C++ Signature: void KeyboardUpdate();
*/
.globl KeyboardUpdate
KeyboardUpdate:
	push {r4,r5,lr}

	kbd .req r4
	ldr r0,=KeyboardAddress
	ldr kbd,[r0]
	
	teq kbd,#0
	bne haveKeyboard$

getKeyboard$:
	bl UsbCheckForChange
	bl KeyboardCount
	teq r0,#0	
	ldreq r1,=KeyboardAddress
	streq r0,[r1]
	beq return$

	mov r0,#0
	bl KeyboardGetAddress
	ldr r1,=KeyboardAddress
	str r0,[r1]
	teq r0,#0
	beq return$
	mov kbd,r0

haveKeyboard$:
	mov r5,#0

	saveKeys$:
		mov r0,kbd
		mov r1,r5
		bl KeyboardGetKeyDown

		ldr r1,=KeyboardOldDown
		add r1,r5,lsl #1
		strh r0,[r1]
		add r5,#1
		cmp r5,#6
		blt saveKeys$

	mov r0,kbd
	bl KeyboardPoll
	teq r0,#0
	bne getKeyboard$

return$:
	pop {r4,r5,pc} 
	.unreq kbd
	
/*
* Returns r0=0 if a in r1 key was not pressed before the current scan, and r0
* not 0 otherwise.
* C++ Signature bool KeyWasDown(u16 scanCode)
*/
.globl KeyWasDown
KeyWasDown:
	ldr r1,=KeyboardOldDown
	mov r2,#0

	keySearch$:
		ldrh r3,[r1]
		teq r3,r0
		moveq r0,#1
		moveq pc,lr

		add r1,#2
		add r2,#1
		cmp r2,#6
		blt keySearch$

	mov r0,#0
	mov pc,lr
	
/*
* Returns the ascii character last typed on the keyboard, with r0=0 if no 
* character was typed.
* C++ Signature char KeyboardGetChar()
*/
.globl KeyboardGetChar
KeyboardGetChar:	
	ldr r0,=KeyboardAddress
	ldr r1,[r0]
	teq r1,#0
	moveq r0,#0
	moveq pc,lr

	push {r4,r5,r6,r7,lr}
	
	kbd .req r4
	key .req r6

	mov r4,r1	
	mov r5,#0
    ldr     r2,=Caps
    ldr     r0,[r2]
    mov     r7,r0
    bl      SetLeds
	keyLoop$:
		mov r0,kbd
		mov r1,r5
		bl KeyboardGetKeyDown

		teq r0,#0
		beq keyLoopBreak$
		
		mov key,r0
		bl KeyWasDown
		teq r0,#0
		bne keyLoopContinue$

		cmp key,#104
		bge keyLoopContinue$

        cmp key,#57             @ Caps Lock Key
        eoreq r7,#0x002
        moveq r0,r7
        beq  6f
        
		mov r0,kbd
		bl KeyboardGetModifiers
        ands r7,#0x02
        bne     1f
/* no cap-lock */
        tst r0,#0b00010001
        bne 2f
        tst r0,#0b00100010
		ldreq r0,=KeysNormal
		ldrne r0,=KeysShift
        b   3f
/* do cap-lock here */
1:      tst r0,#0b00010001
        bne 2f
        cmp     key,#4
        blt     4f
        cmp     key,#29
        bgt     4f
/*  alpha keys */
        tst r0,#0b00100010
		ldrne r0,=KeysNormal
		ldreq r0,=KeysShift
        b   3f
/* not alpha keys */
4:      tst r0,#0b00100010
		ldreq r0,=KeysNormal
		ldrne r0,=KeysShift
        b   3f

2:      ldrne   r0,=KeysControl
3:      ldrb    r0,[r0,key]
        mov     r4,r0
        b       5f
6:      bl      SetLeds
        mov     r4,#0
5:      teq     r4,#0
		bne keyboardGetCharReturn$

	keyLoopContinue$:
		add r5,#1
		cmp r5,#6
		blt keyLoop$

	keyLoopBreak$:
	mov r0,#0		
keyboardGetCharReturn$:
	pop {r4,r5,r6,r7,pc}
	.unreq kbd
	.unreq key

/* Set Caps on  r0 0b00111 */
.global SetLeds
SetLeds:
    mov     r2,r0
	ldr r0,=KeyboardAddress
	ldr r1,[r0]
	teq r1,#0
	moveq r0,#0
	moveq pc,lr

	kbd .req r4
	led .req r6
	mov kbd,r1	
	mov led,r2
    push    {r4,r5,r6,lr}
    ldr     r2,=Caps
    str     led,[r2]
    mov     r1,led
    mov     r0,kbd
    bl      KeyboardSetLeds
    pop     {r0,r1,r7,pc}
    .unreq  kbd
    .unreq  led



	
