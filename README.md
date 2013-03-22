rpiForth
========

A Forth Operating System for Raspberry Pi

20130322 -- I am not able to make sdmmc.s1 work so I a starting anew with sdmmc.S. 

'sdmmc.S' will not assemble with 'make'. 'make' requires a small 's'. To assemble 'sdmmc.S', at the end of 'rFothCore.s' is a '.include "sdmmc.S"' which will assemble it that location.  If I were to use *.s, it would assemble it somewhere other than where I would wamt it and the Forth words would not thread properly.  One negative feature is, after you make a change to the .include file, 'make' would not find it.  You need to make a change to the .s file that includes it. --that is-- add a space and take it out and re-save it. --this will inform 'make' something has changed and it will assemble that file with the .include file.

I am using .S for include files and have set Eclipse to recognize both .s and .S files. This way, Eclipse will function the same way on both files.
Roland


