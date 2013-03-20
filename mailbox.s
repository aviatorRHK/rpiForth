/******************************************************************************
*	mailbox.s
*	 by Alex Chadwick
*
*	A sample assembly code implementation of the input02 operating system.
*	See main.s for details.
*
*	mailbox.s contains code that interacts with the mailbox for communication
*	with various devices.
******************************************************************************/

/*
* GetMailboxBase returns the base address of the mailbox region as a physical
* address in register r0.
* C++ Signature: void* GetMailboxBase()
*/
.globl GetMailboxBase
GetMailboxBase: 
	ldr r0,=0x2000B880
	mov pc,lr

/*
* MailboxRead returns the current value in the mailbox addressed to a channel
* given in the low 4 bits of r0, as the top 28 bits of r0.
* C++ Signature: u32 MailboxRead(u8 channel)
*/
.globl MailboxRead
MailboxRead: 
	and r3,r0,#0xf
	mov r2,lr
	bl GetMailboxBase
	mov lr,r2
	
	rightmail$:
		wait1$: 
			ldr r2,[r0,#24]
			tst r2,#0x40000000
			bne wait1$
			
		ldr r1,[r0,#0]
		and r2,r1,#0xf
		teq r2,r3
		bne rightmail$

	and r0,r1,#0xfffffff0
	mov pc,lr

/*
* MailboxWrite writes the value given in the top 28 bits of r0 to the channel
* given in the low 4 bits of r1.
* C++ Signature: void MailboxWrite(u32 value, u8 channel)
*/
.globl MailboxWrite
MailboxWrite: 
	and r2,r1,#0xf
	and r1,r0,#0xfffffff0
	orr r1,r2
	mov r2,lr
	bl GetMailboxBase
	mov lr,r2

	wait2$: 
		ldr r2,[r0,#24]
		tst r2,#0x80000000
		bne wait2$

	str r1,[r0,#32]
	mov pc,lr
