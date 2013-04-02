/******************************************************************************
*	kernel.ld
*	 by Alex Chadwick
*
*	A linker script for generation of raspberry pi kernel images.
******************************************************************************/

SECTIONS {
	/*
	* First and formost we need the .init section, containing the IVT.
	*/
	.init 0x0000 : {
		*(.init)
	} = 0x3F3F3F3F
		
	/* 
	* We allow room for the ATAGs and the stack and then start our code at
	* 0x8000.
	*/
	.text 0x8000 : {
		*.c.o(.text)
		*(.text)
	} = 0x3F3F3F3F


    /* 
	* Next we put the data.
	*/  /*
	.task 0x4000 : {
		*(.task)
		*.c.o(*)
	} = 0x3F3F3F3F  */


	
	/* 
	* Next we put the data.
	*/
	.data  : {
		*(.data)
		*.c.o(*)
	} = 0x3F3F3F3F

	/*
	* Finally comes everything else. A fun trick here is to put all other 
	* sections into this section, which will be discarded by default.
	*/
	/DISCARD/ : {
		*(*)
	}
}
