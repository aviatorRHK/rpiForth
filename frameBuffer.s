/******************************************************************************
*	frameBuffer.s
*	 by Alex Chadwick
*
*	A sample assembly code implementation of the input02 operating system.
*	See main.s for details.
*
*	frameBuffer.s contains code that creates and manipulates the frame buffer.
******************************************************************************/

/* 
* When communicating with the graphics card about frame buffers, a message 
* consists of a pointer to the structure below. The comments explain what each
* member of the structure is.
* The .align 4 is necessary to ensure the low 4 bits of the address are 0, 
* as these cannot be communicated and so are assumed 0.
* C++ Signature: 
* struct FrameBuferDescription {
*  u32 width; u32 height; u32 vWidth; u32 vHeight; u32 pitch; u32 bitDepth;
*  u32 x; u32 y; void* pointer; u32 size;
* };
* FrameBuferDescription FrameBufferInfo =
*		{ 1024, 768, 1024, 768, 0, 24, 0, 0, 0, 0 };
*/
.section .data
/* Align 12 is a little excessive, but linux does use page alignment here.. */

.align 12 
.globl FrameBufferInfo 
FrameBufferInfo:
	.int scrwidth	/* #0 Width Variables definied on main.s*/
	.int scrheight	/* #4 Height */
	.int scrwidth	/* #8 vWidth */
	.int scrheight	/* #12 vHeight */
	.int 0		/* #16 GPU - Pitch */
	.int 24		/* #20 Bit Dpeth */
	.int 0		/* #24 X */
	.int 0		/* #28 Y */
	.int 0		/* #32 GPU - Pointer */
	.int 0		/* #36 GPU - Size */

/* 
* InitialiseFrameBuffer creates a frame buffer of width and height specified in
* r0 and r1, and bit depth specified in r2, and returns a FrameBuferDescription
* which contains information about the frame buffer returned. This procedure 
* blocks until a frame buffer can be created, and so is inapropriate on real 
* time systems. While blocking, this procedure causes the OK LED to flash.
* If the frame buffer cannot be created, this procedure treturns 0.
* C++ Signature: FrameBuferDescription* InitialiseFrameBuffer(u32 width,
*		u32 height, u32 bitDepth)
*/
.section .text
.globl InitialiseFrameBuffer
InitialiseFrameBuffer:
	width .req r0
	height .req r1
	bitDepth .req r2
	cmp width,#4096
	cmpls height,#4096
	cmpls bitDepth,#32
	result .req r0
	movhi result,#0
	movhi pc,lr

	push {r4,lr}			
	fbInfoAddr .req r4
	ldr fbInfoAddr,=FrameBufferInfo+0x40000000
	str width,[r4,#0]
	str height,[r4,#4]
	str width,[r4,#8]
	str height,[r4,#12]
	str bitDepth,[r4,#20]
	.unreq width
	.unreq height
	.unreq bitDepth

	mov r0,fbInfoAddr
	mov r1,#1
	bl MailboxWrite
	
	mov r0,#1
	bl MailboxRead
		
	teq result,#0
	movne result,#0
	popne {r4,pc}

	pointerWait$:
		ldr result,[fbInfoAddr,#32]
		
		teq result,#0
		beq pointerWait$
				
	mov result,fbInfoAddr
	pop {r4,pc}
	.unreq result
	.unreq fbInfoAddr
