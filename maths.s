/******************************************************************************
*	maths.s
*	 by Alex Chadwick
*
*	A sample assembly code implementation of the input02 operating system.
*	See main.s for details.
*
*	maths.s contains the rountines for mathematics.
******************************************************************************/

/* 
* DivideU32 Divides one unsigned 32 bit number in r0 by another in r1 and 
* returns the result in r0 and the remainder in r1.
* C++ Signature: u32x2 DivideU32(u32 dividend, u32 divisor);
* This is implemented as binary long division.
*/
.globl DivideU32
DivideU32:
	result .req r0
	remainder .req r1
	shift .req r2
	current .req r3

	clz shift,r1
	clz r3,r0
	subs shift,r3
	lsl current,r1,shift
	mov remainder,r0
	mov result,#0
	blt divideU32Return$
	
	divideU32Loop$:
		cmp remainder,current
		blt divideU32LoopContinue$

		add result,result,#1
		subs remainder,current
		lsleq result,shift 
		beq divideU32Return$

	divideU32LoopContinue$:
		subs shift,#1
		lsrge current,#1
		lslge result,#1
		bge divideU32Loop$
	
divideU32Return$:
	.unreq current
	mov pc,lr
	
	.unreq result
	.unreq remainder
	.unreq shift
