/*************************************************************************
*
* rForth is developed by Roland Koluvek.
* Start date January 27, 2012
* ARM forth system
* Define the Forth engine
* ARM registers defined here.
* 20130115 Project restarted on a Raspberry Pi  
* 20130309 moved return stack and parameter stack per memory map .sp0;.rp0
* 20130310 __CODE instead of __COLON for the word CHAR.
**************************************************************************/
.global rForthCore
        .code   32

@ r0 to r9 are general work registers
w       .req    r10     @ Forth work register
rsp     .req    r11     @ Return Stack Pointer
@ IP    .req    r12     @ Interpreter Pointer   @ predefined
@ SP    .req    r13     @ @ SP predefined
@ LR    .req    r14     @ Link Register
@ PC    .req    r15     @ Program Counter

/*  Basic types   */
        .equ    normal,         0x00
        .equ    compile_only,   0x40
        .equ    immediate,      0x80

/* ---- Basic Macros Defined here  ----  */

@   pushr -- push a register data (reg1) on to a stack ptr to by reg2.
            .macro pushr,reg1,reg2 
                str \reg1,[\reg2,#-4]!
            .endm

@   popr -- pop a register data (reg1) from a stack ptr to by reg2.
            .macro  popr,reg1,reg2
                ldr \reg1,[\reg2],#4
            .endm

@   pickr n words down from reg2 stack and reg1
@   holds ncells which becomes the poped item,
            .macro pickr reg1,reg2
                ldr \reg1,[\reg2,\reg1,lsl #2]
            .endm


@   LABEL set up a global label
            .macro label lblName
                .global \lblName
\lblName:
            .endm

@   HEADER for code Builds a head for Forth defintions
            .macro __CORE fncName,lenx,assmName,type=0
                .align 2
                .word link
                .set link,  .-4            
                .hword view
                .set view, view + 1
                .byte \lenx + \type          
                .ascii "\fncName"
                .align 2, 0x20 
                .global \assmName
\assmName:
            .endm

@   CODE HEADER Builds a header for code definition
            .macro __CODE fncName,lenx,assmName,type=0
                .align 2
                .word   link
                .set link, .-4
                .hword view
                .set view, view + 1
                .byte \lenx + \type
                .ascii "\fncName"
                .align 2, 0x20
                .global \assmName
\assmName:
                .word   . + 4
            .endm

@   COLON HEADER Builds a header for colon definition
            .macro __COLON fncName,lenx,assmName,type=0
                .align 2
                .word   link
                .set link, .-4
                .hword view
                .set view, view + 1
                .byte \lenx + \type
                .ascii "\fncName"
                .align 2, 0x20
                .global \assmName
\assmName:
                .word   _nest
            .endm

@   CREATE HEADER Builds a header for create function
            .macro __CREATE fncName,lenx,assmName,type
                __CORE "\fncName",\lenx,\assmName,\type
                .word _docreate
            .endm

@   VARIABLE HEADER Builds a header for a variable (user for 2VARIBLE)                    
            .macro __VARIABLE fncName,lenx,assmName,type
                __CORE "\fncName",\lenx,\assmName,\type
                .word _dovar
            .endm


@   VOCABULARY HEADER Builds a header for vocabularies
            .macro  __VOCABULARY fncName,lenx,assmName,type=0
                __CORE "\fncName",\lenx,\assmName,\type
                .word   _dovoc
            .endm

@   CONSTANT HEADER Builds a header for constants
            .macro  __CONSTANT fncName,lenx,assmName,type
                __CORE "\fncName",\lenx,\assmName,\type
                .word _doconstant
            .endm

@   USER HEADER Builds a header for user variables 
            .macro  __USER fncName,lenx,assmName,type
                __CORE "\fncName",\lenx,\assmName,\type
                .word   _douser
            .endm

@   USER-DEFER HEADER Builds a header for user defered words
            .macro  __USER_DEFER fncName,lenx,assmName,type
                __CORE "\fncName",\lenx,\assmName,\type
                .word   _douser_defer
            .endm

@   DEFER HEADER Builds a header for defered words
            .macro  __DEFER fncName,lenx,assmName,type
                __CORE "\fncName",\lenx,\assmName,\type
                .word _dodefer
            .endm
/* vocabulary switching while assembly */
            .macro  startroot
            .set    link,rootlink
            .endm

            .macro  exitroot
            .set    rootlink,link
            .endm

            .macro  startforth
            .set    link,forthlink
            .endm

            .macro  exitforth
            .set    forthlink,link
            .endm

            .macro  startfiles
            .set    link,fileslink
            .endm

            .macro  exitfiles
            .set    fileslink,link
            .endm

            .macro  starteditor
            .set    link,editorlink
            .endm

            .macro  exiteditor
            .set    editorlink,link
            .endm

            .macro  startassembler
            .set    link,assemblerlink
            .endm

            .macro  exitassmbler
            .set    assemberlink,link
            .endm


/******************memory map****************************/
                .equ    .bytesperbuffer,  1024
                .equ    .hashbuffers,   8
                .equ    .size_bcb,      12   /* bufferControlBlock*/
                .equ    user_sz,        0x0002000
                .equ    sp_sz,          0x0000100    @data stack area
                .equ    rp_sz,          0x0000100    @return stack area
                .equ    fp_sz,          0x0000080    @frame stack area
                .equ    bufx_sz,        0x0000010
                .equ    tib_sz,         0x0000100
                .equ    tickword_sz,    0x0000100
                .equ    squote_sz,      0x0000080
                .equ    ttymem_sz,      0x0000100
                .equ    keyin_sz,       0x0000010
                .equ    mem_sz,         0x0010000    @this can be increased

                .equ    em,             .toram + mem_sz/2
                .equ    .tofirst,       em - (.hashbuffers*.bytesperbuffer)
                .equ    .tobcbs,        .tofirst -(.hashbuffers*.size_bcb)
                .equ    .tobuf,         .tobcbs - .hashbuffers
                .equ    .todisk,        .tobuf - 8
                .equ    .totib,         .todisk - tib_sz
                .equ    .rp0,           .totib - bufx_sz
                .equ    .sp0,           .rp0 - rp_sz
                .equ    fp_mem,         .sp0 - sp_sz
                .equ    user_mem,       fp_mem - fp_sz - user_sz
                .equ    tickword_mem,   user_mem - tickword_sz
                .equ    squote_mem,     tickword_mem - squote_sz
                .equ    tty_mem,        squote_mem - ttymem_sz
                .equ    keyin_mem,      tty_mem - keyin_sz
                .equ    diskbuffer_size, em - .todisk
                .equ    $word,          tickword_mem


.section   .data
.align  2

/**********************************************************************/
/* inter interpreter plus defining words execution words
/**********************************************************************/
.section    .text
label   _unnest
            popr    ip,rsp
label   _next
            popr    w,ip
            popr    pc,w

label   _pushr1
            push    {r1}
label   _pushr0
            push    {r0}
            popr    w,ip
            popr    pc,w

            .macro exit
                b   _unnest
            .endm

            .macro next
                b   _next
            .endm

            .macro pushr0
                b   _pushr0
            .endm

            .macro pushr1
                b   _pushr1
            .endm

label   _nest
            pushr   ip,rsp        @ put the present ip on the return stack
            mov     ip,w
            popr    w,ip
            popr    pc,w

label   _dodoes
            pushr   ip,rsp
            mov     ip,lr
            pushr   w,sp
            next

label   _dovar
            ldr     r0,[w]
            pushr0
 
label   _doconstant
            popr    r0,w
            pushr0

label   _do2constant
            popr    r1,w
            popr    r0,w
            pushr1

label   _docreate
            mov     r0,w
            pushr0

label   _dovoc
            mov     r0,w
            ldr     r1,_cntxt
            ldr     r1,[r1,#4]
            str     r0,[r1]
            next

_cntxt:     .word   _context
        
label   _dodefer
            ldr     w,[w]
            ldr     w,[w]
            popr    pc,w

label   _douser_defer
            ldr     r0,.up
            ldr     r0,[r0]
            ldr     r1,[w]
            add     r0,r0,r1,lsl #2
            ldr     w,[r0]
            popr    pc,w

label   _douser
            ldr     r0,.up
            ldr     r0,[r0]
            ldr     r1,[w]
            add     r0,r0,r1,lsl #2
            pushr0

.up:        .word   $up
/**********************************************************************/
/*** set up vocabulary links ***********/
            .set    view,       0
            .set    userNumber, 0
            .set    link,       0
            .set    rootlink,   0
            .set    forthlink,  0
            .set    fileslink,  0
            .set    editorlink, 0
            .set    assemblerlink,0
/**********************************************************************/
/**********************************************************************/

.section    .data
label   $word                           @$
            .rept   0x0100   @ 256 chars
            .byte   0x00
            .endr

            .set    MAXOUT,  127
            .set    MAXLINE, 48 

/* defered vectors */
.align 2
.dotprompt: .word   _dotok
.status:    .word   _noop
.beep:      .word   _noop
.del_in:    .word   _bs_in
.receive:   .word   _key
.cr:        .word   _pcrp
.source:    .word   _psourcep

.continued:
.undefined: .word   _pundefinedp
.number:    .word   _dnumber
.where:     .word   _dot
.error:     .word   _perrorp
.interactive:
            .word   _noop
.create:    .word   _pcreatep
.boot:      .word   _noop
.default:   .word   _command
.keypt:     .word   0
/* user data section */
.section    .data
.align 2

$0link:     .word   0
$1sp0:      .word   .sp0
$2rp0:      .word   .rp0
$3dp:       .word   _rompt
$rompt:     .word   .torom
$rampt:     .word   .toram

/******Variables**********/
$up:        .word   $0link
$nout:      .word   0
$nline:     .word   0
$base:      .word   10
$hld:       .word   0
$state:     .word   0
$toin:      .word   0
$csp:       .word   0
$runvoc:    .word   0
$current:   .word   0
$context:   .word   0,0,0,0,0,0,0,0,0,0
$voclink:   .word   linkassembler
$blk:       .word   0x856
$dpl:       .word   0
$last:      .word   0
$toexit:    .word   0
$caps:      .word   0
$lasttoin:  .word   0
$endq:      .word   0
$warning:   .word   -1
$sqbuf:     .word   0
$view:      .word   0
$hashtib:   .word   0
$fileslink: .word   0
$span:      .word   0
$ticktib:   .word   .totib                  @$


/*
.load:      .word   _ploadp
            .word   _pcontinuedp
.create0:   .word   _pcreate0p
.update:    .word   _pupdatep
.read_block:
            .word   _pread_blockp
.write_block:
            .word   _pwrite_blockp
*/

/*************************************************************************/

/*************************************************************************/
            startforth
/*************************************************************************/
.section    .text
.align  2

            __USER "LINK",4,"_link"
            .word   0
            __USER "SP0",3,"_sp0"
            .word   1
            __USER "RP0",3,"_rp0"
            .word   2
            __USER_DEFER "DP",2,"_dp"
            .word   3
            __USER "ROMPT",5,"_rompt"
            .word   4 
            __USER "RAMPT",5,"_rampt"
            .word   5 



.section    .text
            __VARIABLE "UP",2,_up
            .word   $up 
            __VARIABLE "#OUT",4,"_nout"
            .word   $nout
            __VARIABLE "#LINE",5,"_nline"
            .word   $nline
            __VARIABLE "BASE",4,"_base"
            .word   $base
            __VARIABLE "HLD",3,"_hld"
            .word   $hld
            __VARIABLE "STATE",5,"_state"
            .word   $state
            __VARIABLE ">IN",3,"_toin"
            .word   $toin
            __VARIABLE "CSP",3,"_csp"
            .word   $csp
            __VARIABLE "RUN-VOC",7,"_run_voc"
            .word   $runvoc
            __VARIABLE "CURRENT",7,"_current"
            .word   $current
            __VARIABLE "CONTEXT",7,"_context"
            .word   $context
            __VARIABLE "VOC-LINK",8,"_voc_link"
            .word   $voclink
            __VARIABLE "BLK",3,"_blk"
            .word   $blk
            __VARIABLE "DPL",3,"_dpl"
            .word   $dpl
            __VARIABLE "LAST",4,"_last"
            .word   $last
            __VARIABLE ">EXIT",4,"_toexit"
            .word   $toexit
            __VARIABLE "CAPS",4,"_caps"
            .word   $caps
            __VARIABLE "LAST>IN",7,"_lasttoin"
            .word   $lasttoin
            __VARIABLE "END?",4,"_endq"
            .word   $endq
            __VARIABLE "WARNING",7,"_warning"
            .word   $warning
            __VARIABLE "S\"BUF",5,"_squotebuf"
            .word   $sqbuf
            __VARIABLE "VIEW",4,"_view"
            .word   $view
            __VARIABLE "#TIB",4,"_hashtib"
            .word   $hashtib
            __VARIABLE "FILE-LINK",9,"_file_link"
            .word   $fileslink
            __VARIABLE "SPAN",4,"_span"
            .word   $span
            __VARIABLE "'TIB",4,"_ticktib"
            .word   $ticktib            @.totib




/*
            __USER "FILE",4,"_file"
            .word   $FILE
            __USER "IN-FILE",7,"_in_file"
            .word   $INFILE
            __USER "'BCB",4,"_tickbcb"
            .word   $'BCB
*/



/* DEFER */            
            __DEFER ".PROMPT",7,"_dotprompt"
            .word   .dotprompt
            __DEFER "STATUS",6,"_status"
            .word   .status
            __DEFER "BEEP",4,"_beep"
            .word   .beep
            __DEFER "DEL-IN",6,"_del_in"
            .word   .del_in
            __DEFER "RECEIVE",7,"_receive"
            .word   .receive
            __DEFER "CR",2,"_cr"
            .word   .cr
            __DEFER "SOURCE",6,"_source"
            .word   .source
@            __DEFER "USERDEFER",9,"_userdefer"
@            .word   .userdefer
            __DEFER "UNDEFINED",9,"_undefined"
            .word   .undefined
            __DEFER "NUMBER",6,"_number"
            .word   .number
            __DEFER "WHERE",5,"_where"
            .word   .where
            __DEFER "ERROR",5,"_error"
            .word   .error
            __DEFER "INTERACTIVE",11,"_interactive"
            .word   .interactive
            __DEFER "CREATE",6,"_create"
            .word   .create
            __DEFER "BOOT",4,"_boot"
            .word   .boot
            __DEFER "DEFAULT",7,"_default"
            .word   .default
@           __DEFER "EMIT",4,"_emit",0




/*            __DEFER "UPDATE",6,"_update"
            .word   .update
            __DEFER "READ-BLOCK",10,"_read_block"
            .word   .read_block
            __DEFER "WRITE-BLOCK",11,"_write_block"
            .word   .write_block
            __DEFER "LOAD",4,"_load"
            .word   .load
            __DEFER "CONTINUED",9,"_continued"
            .word   .continued  */
/*            __DEFER "CREATE0",7,"_create0"
            .word   .create0  */

/******************************************************************
            __CONSTANT "scr-limit",9,"_scr_limit"
            .word   512
            __CONSTANT "#buffers",8,"_hashbuffers"
            .word   .hashbuffers
            __CONSTANT "b/buf",5,"_bperbuf"
            .word   .bytesperbuffer
            __CONSTANT "size-bcb",8,"_size_bcb"
            .word   .size_bcb
            __CONSTANT "blk/file",8,"_blkperfile"
            .word   1000
            __CONSTANT "first",5,"_first"
            .word   .tofirst
            __CONSTANT ">bcbs",5,"_tobcbs"
            .word   .tobcbs
            __CONSTANT ">buf",4,"_tobuf"
            .word   .tobuf
******************************************************************/
            __CONSTANT ">TIB",4,"_totib"
            .word   .totib
            __CONSTANT "#VOCS",5,"_hashvocs"
            .word   8
            __CONSTANT "MAXOUT",6,"_maxout"
            .word   MAXOUT
/******************************************************************

******************************************************************/
.section    .text

/* ROOT */
            __VOCABULARY "ROOT",4,"_root"
            .word   .root
linkroot:   .word   0
/* FORTH */
            __VOCABULARY "FORTH",5,"_forth"
            .word   .forth
linkforth:  .word   linkroot
/* FILES */
            __VOCABULARY "FILES",5,"_files"
            .word   .files
linkfiles:   .word   linkforth
/* EDITOR */
            __VOCABULARY "EDITOR",6,"_editor"
            .word   .editor
linkeditor: .word   linkfiles
/* ASSEMBLER */
            __VOCABULARY "ASSEMBLER",9,"_assembler"
            .word   .assembler
linkassembler:
            .word   linkeditor


/*&EXECUTE (i*x xt -- j*x) "execute" &*/
            __CODE "EXECUTE",7,"_execute"
            pop     {w}
            popr    pc,w
/* 16 ( -- 16 ) */
            __CODE "16",2,"_16"
            mov     r0,#16
            pushr0


/* (REG)  ( n -- n )   DEBUGGING WORDS  */
/*            __CODE "(REG)",5,"_pregp"             */
/**********************************************************
            ldr     r0,[sp]  @ top item on stack
            mov     r1,#32
            bl      shownow
/**********************************************************
            next

/******REG** ( n -- n ) ****
            __COLON "REG",3,"_reg"
            .word   _pregp
            .word   _key
            .word   _drop
            .word   _exit
/*********************************************************/


/* DUMP ( addr len -- ) */
/*: DUMP BASE @ -ROT HEX .HEAD
    BOUNDS DO  I DLN  KEY? ?LEAVE 16 +LOOP BASE ! ; */
            __COLON "DUMP",4,"_dump"
            .word   _base
            .word   _fetch
            .word   _mrot
            .word   _hex
            .word   _dothead
            .word   _bounds
            .word   _pdop
1:          .word   _i
            .word   _dln
            .word   _keyq
            .word   _pqleavep
            .word   2f
            .word   _16
            .word   _pplusloopp
            .word   1b
2:          .word   _unloop
            .word   _base
            .word   _store
            .word   _exit

/*: .HEAD ( addr len -- addr len )
    CR  9 SPACES  OVER 16 0
    DO  I 8 = NEAGATE SPACES  DUP 15 AND  3 U.R  1+ LOOP
    2 SPACES  16 0
    DO  DUP 15 AND  1 U.R  1+ LOOP DROP ; */
            __COLON ".HEAD",5,"_dothead"
            .word   _cr
            .word   _plitp
            .word   9
            .word   _spaces
            .word   _over
            .word   _16
            .word   _0
            .word   _pdop
1:          .word   _i
            .word   _8
            .word   _equ
            .word   _negate
            .word   _spaces
            .word   _dup
            .word   _15
            .word   _and
            .word   _3
            .word   _udotr
            .word   _1plus
            .word   _ploopp
            .word   1b
            .word   _unloop
            .word   _2
            .word   _spaces
            .word   _16
            .word   _0
            .word   _pdop
2:          .word   _dup
            .word   _15
            .word   _and
            .word   _1
            .word   _udotr
            .word   _1plus
            .word   _ploopp
            .word   2b
            .word   _unloop
            .word   _drop
            .word   _exit

/*: .LINE ( addr -- ) 16 0
     DO I 8 = NEGATE SPACES DUP I + C@ SPACE 2 U.L LOOP ; */
            __COLON ".LINE",5,"_dotline"
            .word   _16
            .word   _0
            .word   _pdop
1:          .word   _i
            .word   _8
            .word   _equ
            .word   _negate
            .word   _spaces  
            .word   _dup
            .word   _i
            .word   _plus
            .word   _cfetch
            .word   _space
            .word   _2
            .word   _udotl
            .word   _ploopp
            .word   1b
            .word   _unloop
            .word   _exit

/*: .CHRS ( addr -- ) 16 0
     DO DUP I + C@ EMIT. LOOP ; */
            __COLON ".CHRS",5,"_dotchrs"
            .word   _plitp 
            .word   16
            .word   _0
            .word   _pdop
1:          .word   _dup
            .word   _i
            .word   _plus
            .word   _cfetch
            .word   _emitdot
            .word   _ploopp
            .word   1b
            .word   _unloop
            .word   _exit

/*: DLN ( addr -- ) CR DUP 8 U.R SPACE 
     .LINE 2 SPACES .CHARS DROP ; */
            __COLON "DLN",3,"_dln"
            .word   _cr
            .word   _dup
            .word   _8
            .word   _udotr
            .word   _space
            .word   _dotline
            .word   _2
            .word   _spaces
            .word   _dotchrs
            .word   _drop
            .word   _exit
/* DUMPW ( addr len -- )  DUMP WORDS 32 BITS*/
/*: DUMPW SWAP ALIGNED SWAP BASE @ -ROT HEX .HEADW   
    BOUNDS DO  I DLNW  KEY? ?LEAVE 32 +LOOP BASE ! ; */
            __COLON "DUMPW",5,"_dumpw"
            .word   _swap
            .word   _plum
            .word   _swap
            .word   _base
            .word   _fetch
            .word   _mrot
            .word   _hex
            .word   _dotheadw
            .word   _bounds
            .word   _pdop
1:          .word   _i
            .word   _dlnw
            .word   _keyq
            .word   _pqleavep
            .word   2f
            .word   _plitp
            .word   32
            .word   _pplusloopp
            .word   1b
2:          .word   _unloop
            .word   _base
            .word   _store
            .word   _exit

/*: .HEADW ( addr len -- addr len )
    CR  10 SPACES  OVER 8 0
    DO DUP 15 AND 9 U.R SPACE 4+ LOOP
        2 SPACES  32 0
    DO DUP 15 AND 1 U.R  1+ LOOP DROP ; */
        __COLON ".HEADW",6,"_dotheadw"
            .word   _cr
            .word   _plitp
            .word   10
            .word   _spaces
            .word   _over
            .word   _plitp
            .word   8
            .word   _0
            .word   _pdop
1:          .word   _dup
            .word   _plitp
            .word   15
            .word   _and
            .word   _plitp
            .word   8
            .word   _udotr
            .word   _space
            .word   _4plus
            .word   _ploopp
            .word   1b
            .word   _unloop
            .word   _space
            .word   _plitp
            .word   32
            .word   _0
            .word   _pdop
2:          .word   _dup
            .word   _15
            .word   _and
            .word   _1
            .word   _udotr
            .word   _1plus
            .word   _ploopp
            .word   2b
            .word   _unloop
            .word   _drop
            .word   _exit

/*: .LINEW ( addr -- ) 32 0
     DO DUP I + @ SPACE 8 U.L 4 +LOOP ; */
            __COLON ".LINEW",6,"_dotlinew"
            .word   _plitp
            .word   32
            .word   _0
            .word   _pdop
1:          .word   _dup
            .word   _i
            .word   _plus
            .word   _fetch
            .word   _space
            .word   _8
            .word   _udotl
            .word   _4
            .word   _pplusloopp
            .word   1b
            .word   _unloop
            .word   _exit
/*: .CHRSW ( addr -- ) 32 0
     DO DUP I + C@ EMIT. LOOP ; */
            __COLON ".CHRSW",6,"_dotchrsw"
            .word   _plitp 
            .word   32
            .word   _0
            .word   _pdop
1:          .word   _dup
            .word   _i
            .word   _plus
            .word   _cfetch
            .word   _emitdot
            .word   _ploopp
            .word   1b
            .word   _unloop
            .word   _exit

/*: DLNW ( addr -- ) CR DUP 8 U.R SPACE 
     .LINEW 2 SPACES .CHRSW DROP ; */
            __COLON "DLNW",4,"_dlnw"
            .word   _cr
            .word   _dup
            .word   _8
            .word   _udotr
            .word   _space
            .word   _dotlinew
            .word   _2
            .word   _spaces
            .word   _dotchrsw
            .word   _drop
            .word   _exit

/*: EMIT. ( c -- ) 127 AND  DUP 127 BL WITHIN
     IF  DROP [ CHAR . ] LITERAL THEN EMIT ; */
            __COLON "EMIT.",5,"_emitdot"
            .word   _plitp
            .word   127
            .word   _and
            .word   _dup
            .word   _plitp
            .word   127
            .word   _bl
            .word   _within
            .word   _0branch
            .word   1f
            .word   _drop
            .word   _plitp
            .word   0x02E
1:          .word   _emit
            .word   _exit

/*: U.L ( u len -- ) >R 0 <# R> 0 ?DO # LOOP #> TYPE ; */
            __COLON "U.L",3,"_udotl"
            .word   _tor
            .word   _0
            .word   _lthash
            .word   _rfrom
            .word   _0
            .word   _pqdop
            .word   1f
2:          .word   _hash
            .word   _ploopp
            .word   2b
1:          .word   _unloop
            .word   _hashgt
            .word   _type
            .word   _exit

/*: BOUNDS ( addr len -- addr+len addr )  OVER + SWAP ;*/
            __COLON "BOUNDS",6,"_bounds"
            .word   _over
            .word   _plus
            .word   _swap
            .word   _exit

/* ' ( "<spaces>name" -- xt) "tick" */
/* : ' DEFINED 0= ?MISSING ; */
            __COLON "'",1,"_tick"
            .word   _defined
            .word   _0equ
            .word   _qmissing
            .word   _exit
/* : COMPOSE   ( -- )
    BEGIN
      BEGIN
        BEGIN ?STACK   STATE ON
          BEGIN DEFINED DUP 0<
          WHILE DROP ,
          REPEAT
        WHILE EXECUTE
        REPEAT DUP C@
      WHILE NUMBER  DPL @ 0<
        IF DROP
        ELSE SWAP POSTPONE LITERAL
        THEN POSTPONE LITERAL
      REPEAT DROP BLK @ ABORT" Unfinished compilation."
      CR   DEPTH SPACES   QUERY
    REPEAT ; */
            __COLON "COMPOSE",7,"_compose"
1:          .word   _qstack
            .word   _state
            .word   _on
2:          .word   _defined
            .word   _dup
            .word   _0lt
            .word   _0branch
            .word   3f
            .word   _drop
            .word   _comma
            .word   _branch
            .word   2b
3:          .word   _0branch
            .word   4f
            .word   _execute
            .word   _branch
            .word   1b
4:          .word   _dup
            .word   _cfetch
            .word   _0branch
            .word   5f
            .word   _number
            .word   _dpl
            .word   _fetch
            .word   _0lt
            .word   _0branch
            .word   6f
            .word   _drop
            .word   _branch
            .word   7f
6:          .word   _swap
            .word   _literal
7:          .word   _literal
            .word   _branch
            .word   1b
5:          .word   _drop
            .word   _blk
            .word   _fetch
            .word   _pabortqp
            .byte   23
            .ascii  "Unfinished compilation."
            .align  2
            .word   _cr
            .word   _depth
            .word   _spaces
            .word   _query
            .word   _branch
            .word   1b

/* : (C: "<spaces>name" -- colon-sys ) "colon" */
/* :  :   ( -- )   CREATE HIDE   !CSP   CURRENT @ CONTEXT !
   COMPOSE  ;USES   NEST , */
            __COLON ":",1,"_colon"
            .word   _create
            .word   _hide
            .word   _storecsp
            .word   _current
            .word   _fetch
            .word   _context
            .word   _store
            .word   _compose
            .word   _qcsp
            .word   _pscusesp
            .word   _nest
            .word   _exit

/* : ;   ( -- )  ?COMP ?CSP   POSTPONE UNNEST   REVEAL
   R> DROP   ; IMMEDIATE */
            __COLON ";",1,"_semicolon",immediate
            .word   _qcomp
            .word   _qcsp
            .word   _plitp
            .word   _exit
            .word   _comma
            .word   _reveal
            .word   _rfrom
            .word   _drop
            .word   _exit

/* >NUMBER ( ud1 c-addr1 u1 -- ud2 c-addr2 u2) "to-number" */
/* : >NUMBER BEGIN >R COUNT SWAP >R BASE @ DIGIT 
             WHILE -ROT BASE @ UN*U ROT 0 D+ R> R> 1- DUP 0= 
             UNTIL 
             ELSE DROP R> 1- R> 
             THEN ;  */
            __COLON ">NUMBER",7,"_tonumber"
1:          .word   _tor
            .word   _count
            .word   _swap
            .word   _tor
            .word   _base
            .word   _fetch
            .word   _digit
            .word   _0branch
            .word   2f
            .word   _mrot
            .word   _base
            .word   _fetch
            .word   _rot
            .word   _0
            .word   _dplus
            .word   _rfrom
            .word   _rfrom
            .word   _1minus
            .word   _dup
            .word   _0equ
            .word   _0branch
            .word   1b
            .word   _branch
            .word   3f
2:          .word   _drop
            .word   _rfrom
            .word   _1minus
            .word   _rfrom
3:          .word   _exit

/* ABORT ( i*x -- ) (R: j*x -- ) "abort" */
/* : ABORT SP0 @ SP! QUIT ;  */
            __COLON "ABORT",5,"_abort"
            .word   _sp0
            .word   _fetch
            .word   _spstore
            .word   _quit

/* ABORT"  ("ccc<quote>" -- )*/
/*  RT: (i*x x1 -- |i*x)(R:j*x--|j*x)*/
/*: ABORT" POSTPONE (ABORT") ," ; IMMEDIATE */
            __COLON "ABORT\"",6,"_abortq",immediate
            .word   _plitp
            .word   _pabortqp
            .word   _commaquote
            .word   _exit

/* ACCEPT ( c-addr +n1 -- +n2 )*/
/* : ACCEPT >R 0
      BEGIN 0 MAX DUP R@ <
      WHILE KEY LITERAL 127 AND DUP >R BL < 0=
        IF 2DUP + R@ SWAP C! R@ EMIT 1+ THEN
        DUP 0= INVERT R@ BS = AND
        IF BS EMIT BL EMIT BS EMIT 
        THEN R> DUP BS =
        IF DROP BL THEN BL < 
      UNTIL -ROT R> 2DROP SPACE ; */ 
            __COLON "ACCEPT",6,"_accept"
            .word   _tor
            .word   _0
1:          .word   _0
            .word   _max
            .word   _dup 
            .word   _rfetch
            .word   _lt 
            .word   _0branch
            .word   2f
            .word   _key
            .word   _plitp
            .word   127
            .word   _and
            .word   _dup 
            .word   _tor 
            .word   _bl 
            .word   _lt 
            .word   _0equ
            .word   _0branch
            .word   2f
            .word   _2dup
            .word   _plus
            .word   _rfetch
            .word   _swap
            .word   _cstore
            .word   _rfetch
            .word   _emit 
            .word   _1plus
2:          .word   _dup
            .word   _0equ
            .word   _invert
            .word   _rfetch
            .word   _bs
            .word   _equ
            .word   _and
            .word   _0branch
            .word   3f
            .word   _bs
            .word   _emit
            .word   _bl 
            .word   _emit
            .word   _bs
            .word   _emit
3:          .word   _rfrom
            .word   _dup
            .word   _bs
            .word   _equ
            .word   _0branch
            .word   4f
            .word   _drop
            .word   _bl 
4:          .word   _bl 
            .word   _0branch
            .word   1b
            .word   _swap
            .word   _rfrom
            .word   _2drop
            .word   _space
            .word   _exit

/* CONSTANT (x"<spaces>name" --)
   Execution ( -- x ) */
/* : CONSTANT   ( n -- )
   CREATE ;USES DOCONSTANT ,   */
            __COLON "CONSTANT",8,"_constant"
            .word   _create
            .word   _pscusesp
            .word   _doconstant
            .word   _comma
            .word   _exit

/*: HEAD, ( 'word -- )
   DUP COUNT DUP 0= ABORT" No Word"                    ('word addr count)
   DUP 63 > ABORT" Word length exceeded 63 characters" ('word addr count)
   (put down link) ALIGN HERE CURRENT @ @ DUP @ , !    ('word addr count)
   (put down view) VIEW @ DUP H, 1+ VIEW !           ('word addr count)
   (put down new word) TUCK HERE DUP LAST ! PLACE 1+ ALLOT ALIGN ('word) 
   (check if previously defined in this voc) WARNING @ ('word flag)
   IF DUP CURRENT @ @ @ @ (FIND)                         ('word flag n)
      IF OVER COUNT CR TYPE ." redefined. " THEN DROP    ( 'word )
   THEN DROP ; */
            __COLON "HEAD,",5,"_headcomma"
            .word   _dup
            .word   _count
            .word   _dup
            .word   _0equ
            .word   _pabortqp
            .byte   7
            .ascii "No Word"
            .align 2
            .word   _dup
            .word   _plitp
            .word   63
            .word   _gt 
            .word   _pabortqp 
            .byte   33
            .ascii "Word length exceeded 63 characters"
            .align 2
            .word   _align
            .word   _here
            .word   _current
            .word   _fetch
            .word   _fetch
            .word   _dup
            .word   _fetch
            .word   _comma
            .word   _store
            .word   _view
            .word   _fetch
            .word   _dup
            .word   _hcomma
            .word   _1plus
            .word   _view
            .word   _store
            .word   _tuck
            .word   _here
            .word   _dup
            .word   _last
            .word   _store
            .word   _place
            .word   _1plus
            .word   _allot
            .word   _align
            .word   _warning
            .word   _fetch
            .word   _0branch
            .word   1f
            .word   _dup
            .word   _current
            .word   _fetch
            .word   _fetch
            .word   _fetch
            .word   _fetch
            .word   _pfindp
            .word   _0branch
            .word   2f
            .word   _over
            .word   _count
            .word   _cr
            .word   _type 
            .word   _pdotqp
            .byte   12;.ascii " redefined. ";.align 2
2:          .word   _drop
1:          .word   _drop
            .word   _exit

/* (CREATE) ("<spaces>name"--) "peren-create" */
/*: (CREATE) BL WORD ('word) HEAD,
     [ DOCREATE ]  LITERAL , ; */
            __COLON "(CREATE)",8,"_pcreatep"
            .word   _bl 
            .word   _word 
            .word   _headcomma
            .word   _plitp
            .word   _docreate
            .word   _comma
            .word   _exit

/*: (CR) 10 EMIT #OUT OFF 1 #LINE +! ;  */
            __COLON "(CR)",4,"_pcrp"
            .word   _plitp 
            .word   10
            .word   _emit
            .word   _nout
            .word   _off
            .word   _1
            .word   _nline
            .word   _plusstore
            .word   _exit

/*& : EMIT ( char -- ) DUP 10 <> 
    IF DUP (EMIT) BS = IF -2 #OUT +! THEN #OUT @ 1+ DUP MAXOUT 1- > 
        IF DROP 0 THEN
    ELSE DROP 0 THEN DUP #OUT ! 0=
    IF 10 (EMIT)  1 #LINE +! THEN ; */
            __COLON "EMIT",4,"_emit"
            .word   _dup
            .word   _plitp
            .word   10
            .word   _notequ
            .word   _0branch
            .word   1f          @if
            .word   _dup
            .word   _pemitp
            .word   _bs
            .word   _equ
            .word   _0branch
            .word   4f
            .word   _minus2
            .word   _nout
            .word   _plusstore
4:          .word   _nout
            .word   _fetch
            .word   _1plus
            .word   _dup
            .word   _maxout
            .word   _1minus
            .word   _gt         
            .word   _0branch
            .word   2f          @  if
            .word   _drop
            .word   _0          
2:          .word   _branch     @  then    
            .word   3f          @else
1:          .word   _drop
            .word   _0
3:          .word   _dup        @then
            .word   _nout
            .word   _store
            .word   _0equ
            .word   _0branch
            .word   4f          @if
            .word   _plitp
            .word   10
            .word   _pemitp
            .word   _1
            .word   _nline
            .word   _plusstore
4:          .word   _exit       @then

/*(EMIT)&*/
            __CODE "(EMIT)",6,"_pemitp"
            pop     {r1}
            ldr     r0,bufxp
            strb    r1,[r0]
            mov     r1,#1
            ldr     r2,regx
            stmea   r2,{r10-r13}
            bl      Print
            bl      TerminalDisplay
            ldr     r2,regx
            ldmfd   r2,{r10-r13}
            next
bufxp:      .word   bufx
.data
bufx:       .string "testing"
.text

/*EVALUATE  (i*x c-addr u -- j*x) */

/********************TEST***********************************/
/*&: .S DEPTH DUP 0> 
     IF 0 DO DEPTH I - 1- PICK . LOOP ELSE SP0 @ SP! THEN ; */
            __COLON ".S",2,"_dots"
            .word   _depth
            .word   _dup
            .word   _0gt
            .word   _0branch
            .word   2f
            .word   _0
            .word   _pdop
1:          .word   _depth
            .word   _i
            .word   _minus
            .word   _1minus
            .word   _pick
            .word   _dot
            .word   _ploopp
            .word   1b
            .word   _unloop
            .word   _branch
            .word   3f
2:          .word   _sp0
            .word   _fetch
            .word   _spstore
3:          .word   _exit

/***********************************************************/

/*: .S.R ( -- ) DEPTH ?DUP
    IF 0 DO DEPTH I - 1- PICK 10 .R SPACE LOOP
    THEN ;  */
            __COLON ".S.R",4,"_dotsdotr"
            .word   _depth
            .word   _qdup
            .word   _0branch
            .word   1f
            .word   _0
            .word   _pdop
2:          .word   _depth
            .word   _i
            .word   _minus
            .word   _1minus
            .word   _pick
            .word   _plitp
            .word   10
            .word   _dotr
            .word   _space
            .word   _ploopp
            .word   2b
            .word   _unloop
1:          .word   _exit
 


/*FIND (c-addr -- c-addr 0 | xt 1 | xt -1) */
/*: FIND   0 FALSE   #VOCS 0
   DO   DROP CONTEXT I 4* + @ DUP
      IF TUCK =
         IF FALSE
         ELSE >R R@  @ @ (FIND) R> SWAP DUP ?LEAVE
         THEN
      THEN
   LOOP  NIP ; */
            __COLON "FIND",4,"_find"
            .word   _0
            .word   _false
            .word   _hashvocs
            .word   _0
            .word   _pdop
3:          .word   _drop
            .word   _context
            .word   _i
            .word   _4star
            .word   _plus
            .word   _fetch
            .word   _dup
            .word   _0branch
            .word   1f
            .word   _tuck
            .word   _equ      
            .word   _0branch
            .word   2f
            .word   _false
            .word   _branch
            .word   1f
2:          .word   _tor
            .word   _rfetch
            .word   _fetch
            .word   _fetch
            .word   _pfindp
            .word   _rfrom
            .word   _swap
            .word   _dup
            .word   _pqleavep
            .word   4f
1:          .word   _ploopp
            .word   3b
4:          .word   _unloop
            .word   _nip
            .word   _exit

/* CODE (FIND) ( here link -- cfa flag | here false) */
            __CODE "(FIND)",6,"_pfindp"
            pop     {r2}        @ r2 is link
1:          ldr     r0,[sp]     @ r0 is here
            mov     r1,r2
            teq     r1,#0       @ test for end
            beq     2f
            ldr     r2,[r1]     @ get next link
            add     r1,#6       @ mov pointer to word
            mov     r5,r1       @ save pointer
            ldrb    r3,[r1]     @ get count
            ldrb    r4,[r0]     @ get count
            eor     r3,r4       @ compare
            ands    r3,#0x3f    @ filter off the precedent bits
            bne     1b          @ count not equal
            ldr     r6,[r1]
            and     r6,#0x3f    @ get count
3:          ldrb    r3,[r1,#1]! @ get next char
            ldrb    r4,[r0,#1]! 
            eors    r3,r4 
            bne     1b          @ get next word if not equal
            subs    r6,#1
            bgt     3b
            add     r1,#1
            ands    r3,r1,#0x03 @ r1 is pointing to cfa or before.
            subne   r1,r3
            addne   r1,#0x04    @ rounded to cfa
            str     r1,[sp]     @ put on the stack
            ldrb    r3,[r5]     @ get count with precedent bits
            tst     r3,#0x80     @ check for immediate
            movne   r0,#01      @ set flag to 1
            mvneq   r0,#0       @ other wise set to -1
            pushr0              @ exit and push on stack
2:          mov     r0,#0
            pushr0

/* : DEFINED   ( -- here 0 | cfa [ -1 | 1 ] )
   BL WORD  ?UPPERCASE  FIND   ; */
            __COLON "DEFINED",7,"_defined"
            .word   _bl
            .word   _word
            .word   _quppercase
            .word   _find
            .word   _exit

/*&HERE  ( -- addr ) "here" */
/*: HERE DP @ ;*/
            __COLON "HERE",4,"_here"
            .word   _dp
            .word   _fetch
            .word   _exit

/* : IMMEDIATE ( -- ) LAST @  DUP C@ 128 ( Prec. bit) OR SWAP C! ; */
            __COLON "IMMEDIATE",9,"_immediate"
            .word   _last
            .word   _fetch
            .word   _dup
            .word   _cfetch
            .word   _plitp
            .word   0x80
            .word   _or
            .word   _swap
            .word   _cstore
            .word   _exit

regx:       .word regs

/*&KEY  ( -- char ) */
            __CODE "KEY",3,"_key"
            ldr     r1,regx
            stmea   r1,{r10-r13}
1:          bl KeyboardUpdate
            bl KeyboardGetChar
            teq     r0,#0
            beq     1b
            ldr     r1,regx
            ldmfd   r1,{r10-r13}
            pushr0

/*KEY?  ( -- 0|\n) */
            __CODE "KEY?",4,"_keyq"
            ldr     r1,regx
            stmea   r1,{r10-r13}
1:          bl KeyboardUpdate
            bl KeyboardGetChar
            ldr     r1,regx
            ldmfd   r1,{r10-r13}
            pushr0



/* : LITERAL   ( n -- )    POSTPONE (LIT)   ,   ;   IMMEDIATE */
            __COLON "LITERAL",7,"_literal",immediate
            .word   _plitp
            .word   _plitp
            .word   _comma
            .word   _comma
            .word   _exit 

/*POSTPONE ("name", -- ) "postpone" */
/* : POSTPONE ' , ;     */
            __COLON "POSTPONE",8,"_postpone",immediate
            .word   _tick
            .word   _comma
            .word   _exit

/*QUIT  (--) (R: i*x -- ) */
/*: QUIT   ( -- ) >TIB   'TIB ! INTERACTIVE
   BEGIN  RP0 @ RP!   STATUS QUERY INTERPRET .PROMPT  REPEAT ; */
            __COLON "QUIT",4,"_quit"
            .word   _totib
            .word   _ticktib
            .word   _store
            .word   _interactive
1:          .word   _rp0
            .word   _fetch
            .word   _rpstore
            .word   _status
            .word   _query
            .word   _interpret
            .word   _dotprompt
            .word   _branch
            .word   1b
            .word   _exit

/*RECURSE ( -- )*/
/* : RECURSE   LAST @ NAME> ,  ;  IMMEDIATE */
            __COLON "RECURSE",7,"_recurse",immediate
            .word   _last
            .word   _fetch
            .word   _namefrom
            .word   _comma
            .word   _exit

/* : S" <name> "( -- addr u ) compile leave addr u, interactive addr u 
   STATE @
   IF POSTPONE (") [CHAR] " PARSE-CHAR  TUCK HERE PLACE  
             1+ ALLOT ALIGN  
   ELSE [CHAR] " PARSE-CHAR    S"BUF PLACE S"BUF COUNT THEN ; IMMEDIATE */   
            __COLON "S\"",2,"_squote", immediate
            .word   _state
            .word   _fetch
            .word   _0branch
            .word   1f
            .word   _plitp
            .word   _pqp
            .word   _comma
            .word   _plitp
            .word   34
            .word   _parsechar
            .word   _tuck
            .word   _here
            .word   _place
            .word   _1plus
            .word   _allot
            .word   _align
            .word   _branch
            .word   2f
1:          .word   _plitp
            .word   34
            .word   _parsechar
            .word   _squotebuf
            .word   _place
            .word   _squotebuf
            .word   _count 
2:          .word   _exit

/* : C" <name> "( -- addr ) compile leave addr, interactive addr  
   STATE @
   IF POSTPONE (C") [CHAR] " PARSE-CHAR    TUCK HERE PLACE 1+ ALLOT ALIGN   
   ELSE [CHAR] " PARSE-CHAR S"BUF PLACE S"BUF THEN ; IMMEDIATE */   
            __COLON "C\"",2,"_cquote"  immediate
            .word   _state
            .word   _fetch
            .word   _0branch
            .word   1f
            .word   _plitp
            .word   _pcqp
            .word   _comma
            .word   _plitp
            .word   34
            .word   _parsechar
            .word   _tuck
            .word   _here
            .word   _place
            .word   _1plus
            .word   _allot
            .word   _align
            .word   _branch
            .word   2f
1:          .word   _plitp
            .word   34
            .word   _parsechar
            .word   _squotebuf
            .word   _place
            .word   _squotebuf 
2:          .word   _exit

/* : VARIABLE  ("<spaces>name" -- )
   CREATE 0 ,   ;USES DOCREATE ,  */
            __COLON "VARIABLE",8,"_variable"
            .word   _create
            .word   _pscusesp
            .word   _dovar
            .word   _ram
            .word   _here
            .word   _0
            .word   _comma
            .word   _rom
            .word   _comma
            .word   _exit

/* : WORD    ( char -- addr )
   PARSE  'WORD PLACE 'WORD ;
   DUP COUNT + BL SWAP C!   ( Stick Blank at end ); SEE $NUMBER   $*/
            __COLON "WORD",4,"_word"
            .word   _parse
            .word   _tickword
            .word   _place
            .word   _tickword
/*            .word   _exit */
            .word   _dup
            .word   _count
            .word   _plus
            .word   _bl
            .word   _swap
            .word   _cstore
            .word   _exit  


/* 'WORD ( -- addr) "tick-word" location that WORD stores parsed words*/
            __CODE "'WORD",5,"_tickword"
            ldr     r0,$wd
            pushr0
$wd:        .word   $word

/*[ ( -- ) "left-bracket"   $*/
/* : [  INTERPRET  ; IMMEDIATE */
            __COLON "[",1,"_ltbracket",immediate
            .word   _interpret
            .word   _exit

/* : INTERPRET   ( -- )
   BEGIN
      BEGIN ?STACK   STATE OFF   DEFINED
      WHILE EXECUTE   END? @
         IF END? OFF EXIT THEN
      REPEAT
      DUP C@
   WHILE NUMBER   DPL @ 0<
      IF DROP THEN
   REPEAT DROP ; */
            __COLON "INTERPRET",9,"_interpret"
1:          .word   _qstack
            .word   _state
            .word   _off
            .word   _defined
            .word   _0branch
            .word   2f
            .word   _execute
            .word   _endq
            .word   _fetch
            .word   _0branch
            .word   3f
            .word   _endq
            .word   _off
            .word   _exit
3:          .word   _branch
            .word   1b
2:          .word   _dup
            .word   _cfetch
            .word   _0branch
            .word   4f
            .word   _number
            .word   _dpl
            .word   _fetch
            .word   _0lt
            .word   _0branch
            .word   5f
            .word   _drop
5:          .word   _branch
            .word   1b
4:          .word   _drop
            .word   _exit

/*['] ("<spaces>name" -- )*/
/* : [']    ' POSTPONE (LIT) ,   ; IMMEDIATE */
            __COLON "[']",3,"_btickb",immediate
            .word   _tick
            .word   _plitp
            .word   _plitp
            .word   _comma
            .word   _comma
            .word   _exit

/*[CHAR] ("<spaces>name" -- ) "bracket-char" */
/*: [CHAR] CHAR LITERAL ;*/
            __COLON "[CHAR]",6,"_brktchar",immediate
            .word   _char
            .word   _literal
            .word   _exit

/*] ( -- ) "right-bracket" */
/*: ] R> DROP ;*/
            __COLON "]",1,"_rtbracket"
            .word   _rfrom
            .word   _drop
            .word   _exit


/*:NONAME ( -- xt ) "colon-noname" */

/*CASE */
/*: CASE 0 ; IMMEDIATE*/
            __COLON "CASE",4,"_case",immediate
            .word   _0 
            .word   _exit 

/*OF ( n1 n2 -- n1 )*/
/*: OF COMPILE OVER COMPILE = POSTPONE IF COMPILE DROP ; IMMEDIATE */
            __COLON "OF",2,"_of",immediate
            .word   _plitp
            .word   _over
            .word   _comma
            .word   _plitp
            .word   _equ
            .word   _comma 
            .word   _plitp
            .word   _if
            .word   _comma 
            .word   _plitp
            .word   _drop
            .word   _comma
            .word   _exit

/*: ENDOF POSTPONE ELSE ; IMMEDIATE */
            __COLON "ENDOF",5,"_endof",immediate
            .word   _plitp
            .word   _else
            .word   _comma 
            .word   _exit

/*: ENDCASE COMPILE DROP
     BEGIN ?DUP WHILE POSTPONE THEN REPEAT ; IMMEDIATE */
            __COLON "ENDCASE",7,"_endcase",immediate
1:          .word   _qdup
            .word   _0branch
            .word   2f
            .word   _plitp
            .word   _then
            .word   _comma 
            .word   _branch
            .word   1b
2:          .word   _exit

/*: COMPILE, ( xt -- ) "compile-comma" , ; */
            __COLON "COMPILE,",8,"_compilecomma"
            .word   _comma 
            .word   _exit

/* : EXPECT   ( c-addr len -- )
   SWAP 0   ( len adr 0 ) SPAN OFF
   BEGIN   2 PICK OVER > ( len adr #so-far more?)
   WHILE   RECEIVE DUP BL <
      IF   4* CC-FORTH + @ EXECUTE
      ELSE DUP 127 ( DEL) =
         IF DROP DEL-IN ELSE CHR THEN
      THEN
   REPEAT  SPAN !  2DROP ; */
            __COLON "EXPECT",6,"_expect"
            .word   _swap
            .word   _0
            .word   _span
            .word   _off
8:          .word   _2
            .word   _pick
            .word   _over
            .word   _gt
            .word   _0branch
            .word   1f
            .word   _receive
            .word   _dup
            .word   _bl
            .word   _lt
            .word   _0branch
            .word   2f
            .word   _4star
            .word   _plitp
            .word   _ccforth
            .word   _plus
            .word   _fetch
            .word   _execute
            .word   _branch
            .word   3f
2:          .word   _dup
            .word   _plitp
            .word   127
            .word   _equ      
            .word   _0branch
            .word   6f
            .word   _drop
            .word   _del_in
            .word   _branch
            .word   3f
6:          .word   _chr
3:          .word   _branch
            .word   8b
1:          .word   _span
            .word   _store
            .word   _2drop
            .word   _exit

/* : CHR  ( a n char -- a n+1 )
   3DUP EMIT + C!   1+   ; */
            __COLON "CHR",3,"_chr"
            .word   _3dup
            .word   _emit
            .word   _plus
            .word   _cstore
            .word   _1plus
            .word   _exit

/****  ccforth  **/
/* CONSTANT CC-FORTH ( -- addr ) */
            __CONSTANT "CC-FORTH",8,"_cc_forth"
            .word   _ccforth

.section    .data
            .align 2
_ccforth:   .word   _beep,      _beep,      _beep,      _beep
            .word   _beep,      _beep,      _beep,      _beep
            .word   _bs_in,     _beep,      _cr_in,     _beep
            .word   _beep,      _cr_in,     _beep,      _beep
            .word   _beep,      _beep,      _beep,      _beep
            .word   _beep,      _beep,      _beep,      _beep
            .word   _beep,      _beep,      _beep,      _beep
            .word   _beep,      _beep,      _beep,      _beep

.section    .text
/* : BS-IN   ( n -- 0 | n-1 )
   DUP IF  1-  BACKSPACE SPACE BACKSPACE
   ELSE  BEEP  THEN  ; */
            __COLON "BS-IN",5,"_bs_in"
            .word   _dup
            .word   _0branch
            .word   1f
            .word   _1minus
            .word   _backspace
            .word   _space
            .word   _backspace
            .word   _branch
            .word   2f
1:          .word   _beep
2:          .word   _exit

/* : BACK-UP ( n -- 0 )
   DUP BACKSPACES   DUP SPACES   BACKSPACES   0   ; */
            __COLON "BACK-UP",7,"_backup"
            .word   _dup
            .word   _backspaces
            .word   _dup
            .word   _spaces
            .word   _backspaces
            .word   _0
            .word   _exit

/* : CR-IN ( m a n -- n a n )
   ROT DROP   TUCK SPACE ; */
            __COLON "CR-IN",5,"_cr_in"
            .word   _rot
            .word   _drop
            .word   _tuck
            .word   _space
            .word   _cr
            .word   _exit

/* : ZERO-IN ( -- )  KEY DROP ; */
            __COLON "ZERO-IN",7,"_zero_in"
            .word   _key
            .word   _drop
            .word   _exit

/* : BACKSPACE  ( -- ) 8 ( BS) EMIT  -2 #OUT +! ; */
            __COLON "BACKSPACE",9,"_backspace"
            .word   _8
            .word   _emit
            .word   _exit

/* : BACKSPACES   ( n -- )     0 ?DO BACKSPACE LOOP   ; */
            __COLON "BACKSPACES",10,"_backspaces"
            .word   _0
            .word   _pqdop
            .word   1f
2:          .word   _backspace
            .word   _ploopp
            .word   2b
            .word   _unloop
1:          .word   _exit


/* : MARKER ( ,name -- ) ( when name is executed after name will be
                          deleted including name )
     CREATE ONLY FORTH ALSO DEFINITIONS
     ROMPT @ , RAMPT @ , ((( FILES-LINK  @ , ))) HIDE VOC-LINK @ DUP ,
     BEGIN DUP WHILE DUP 4- @ @ , @ REPEAT REVEAL
     DOES> LENGTH ROMPT ! LENGTH RAMPT ! ((( LENGTH FILES-LINK ! )))
     LENGTH SWAP >R  DUP VOC-LINK !
     BEGIN DUP WHILE DUP 4- @  R> LENGTH SWAP >R SWAP ! @ REPEAT
     R> 2DROP ['] NOOP IS STATUS  ; */
            __COLON "MARKER",6,"_marker"
            .word   _create
            .word   _rompt
            .word   _fetch
            .word   _comma
            .word   _rampt
            .word   _fetch
            .word   _comma
/*          .word   _file_link
            .word   _fetch
            .word   _comma   */
            .word   _hide
            .word   _voc_link
            .word   _fetch
            .word   _dup
            .word   _comma
1:          .word   _dup
            .word   _0branch
            .word   2f
            .word   _dup
            .word   _4minus
            .word   _fetch
            .word   _fetch
            .word   _comma
            .word   _fetch
            .word   _branch
            .word   1b
2:          .word   _drop
            .word   _reveal
            .word   _doesgt
            .word   _length
            .word   _rompt
            .word   _store
            .word   _length
            .word   _rampt
            .word   _store
/*          .word   _length
            .word   _file_link
            .word   _store   */
            .word   _length
            .word   _swap
            .word   _tor
            .word   _dup
            .word   _voc_link
            .word   _store
3:          .word   _dup
            .word   _0branch
            .word   4f
            .word   _dup
            .word   _4minus
            .word   _fetch
            .word   _rfrom
            .word   _length
            .word   _swap
            .word   _tor
            .word   _swap
            .word   _store
            .word   _fetch
            .word   _branch
            .word   3b
4:          .word   _rfrom
            .word   _2drop
            .word   _exit

/* PAD  ( -- addr ) "pad"  */
/* : PAD HERE 128 + ;  */
            __COLON "PAD",3,"_pad"  
            .word   _here
            .word   _plitp
            .word   128
            .word   _plus
            .word   _exit

/* : PARSE-CHAR   ( char -- addr len )
   >R   SOURCE >IN @  DUP LAST>IN !  /STRING   OVER SWAP R>
   SCAN >R OVER -  DUP R>  0<> -  >IN +!  ; */
            __COLON "PARSE-CHAR",10,"_parsechar"
            .word   _tor
            .word   _source
            .word   _toin
            .word   _fetch
            .word   _dup
            .word   _lasttoin
            .word   _store
            .word   _slashstring
            .word   _over
            .word   _swap
            .word   _rfrom
            .word   _scan
            .word   _tor
            .word   _over
            .word   _minus
            .word   _dup
            .word   _rfrom
            .word   _0notequ
            .word   _minus
            .word   _toin
            .word   _plusstore
            .word   _exit

/* : PARSE ( char -- addr len )
    >R SOURCE TUCK >IN @ DUP LAST>IN ! /STRING R@ SKIP
    OVER SWAP R> SCAN >R OVER - ROT R> DUP 0<> + - >IN ! ;  */    
            __COLON "PARSE",5,"_parse"
            .word   _tor
            .word   _source
            .word   _tuck
            .word   _toin
            .word   _fetch
            .word   _dup
            .word   _lasttoin
            .word   _store
            .word   _slashstring
            .word   _rfetch
            .word   _skip
            .word   _over
            .word   _swap
            .word   _rfrom
            .word   _scan
            .word   _tor
            .word   _over
            .word   _minus
            .word   _rot
            .word   _rfrom
            .word   _dup
            .word   _0notequ
            .word   _plus
            .word   _minus
            .word   _toin
            .word   _store
            .word   _exit


/*QUERY*/
/* : QUERY   ( -- )
   TIB 80 EXPECT  SPAN @ #TIB !   BLK OFF  >IN OFF  ; */
            __COLON "QUERY",5,"_query"
            .word   _tib
            .word   _plitp
            .word   80
            .word   _expect
            .word   _span
            .word   _fetch
            .word   _hashtib
            .word   _store
            .word   _blk
            .word   _off
            .word   _toin
            .word   _off
            .word   _exit

/*REFILL*/

/*RESTORE-INPUT*/

/*SAVE-INPUT*/

/*SOURCE-ID  ( -- 0|-1) 0 User Input device | -1 string  */

/*SPAN ( -- a-addr )

/* : TIB     ( -- adr )   'TIB @  ; */
            __COLON "TIB",3,"_tib"
            .word   _ticktib
            .word   _fetch  
            .word   _exit

/*VALUE*/

/*[COMPILE] ("<spaces>name -- ")  "bracket-compile" */
/*: [COMPILE] ' . ; IMMEDIATE */
            __COLON "[compile]",9,"_brktcompile"
            .word   _tick 
            .word   _comma 
            .word   _exit
 
/* /STRING ( a-addr len n -- a-addr' len' ) "slash_string" */
/*: /STRING DUP NEGATE UNDER+ UNDER+ ;  */
            __COLON "/STRING",7,"_slashstring"  
            .word   _dup
            .word   _negate
            .word   _underplus
            .word   _underplus
            .word   _exit

/* : GETGPU ( -- addr ) ;  */
/*            __CODE "getgpu"6,"_getgpu"
            ldr     r0,=graphicsAddress
            ldr     r0,[r0]            
            ldr     r0,[r0,#32]
            pushr   r0,sp
            mov     pc,lr
*/

/* : SKIP  ( addr len char -- addr' len' )  */   
            __CODE "SKIP",4,"_skip"
            pop     {r2}
            pop     {r0}
            pop     {r1}
1:          teq     r0,#0
            beq     2f
            ldrb    r3,[r1]
            teq     r2,r3
            subeq   r0,#1
            addeq   r1,#1
            beq     1b
2:          pushr1

/* : SCAN  ( addr len char -- addr' len' )  */   
            __CODE "SCAN",4,"_scan"
            pop     {r2}
            pop     {r0}
            pop     {r1}
1:          teq     r0,#0
            beq     2f
            ldrb    r3,[r1]
            teq     r2,r3
            subne   r0,#1
            addne   r1,#1
            bne     1b
2:          pushr1

/* DEFER SOURCE IS : (SOURCE) ( -- addr len ) BLK @ ?DUP 
    IF BLOCK B/BUF ELSE TIB #TIB @ THEN ; */
            __COLON "(SOURCE)",8,"_psourcep"
/*            .word   _blk
            .word   _fetch
            .word   _qdup
            .word   _0branch
            .word   1f
            .word   _block
            .word   _bperbuf
            .word   _branch
            .word   2f  */
1:          .word   _tib
            .word   _hashtib
            .word   _fetch
2:          .word   _exit


/* : COMMAND SP0 @ SP! BLK OFF >IN OFF ['] ?REDEFINE IS UNDEFINED
    FILE-LINK @ MARK-FILE ! DTA COUNT #TIB ! 'TIB !
    INTERPRET  ['] (UNDEFINED) IS UNDEFINED ; */
            __COLON "COMMAND",7,"_command"
            .word   _sp0
            .word   _fetch
            .word   _spstore
            .word   _blk
            .word   _off
            .word   _toin
            .word   _off
            .word   _plitp
            .word   _qredefine
            .word   _plitp
            .word   _pisp
            .word   _undefined
            .word   _exit

/* : (CREATE)   ( -- ) BL WORD   HEAD,  ; */
/*            __COLON "(CREATE)",8,"_pcreatep"
            .word   _bl
            .word   _word
            .word   _headcomma
            .word   _exit  */

/* : (CREATE0)   ( -- ) BL WORD  ?UPPERCASE  HEAD0,  ; */
/*            __COLON "_pcreate0p",9,"(CREATE0)"
            .word   _bl
            .word   _word
            .word   _quppercase
            .word   _head0comma
            .word   _exit */

/* : (ERROR)  ( -- )
      BLK @ IF  BEEP  >IN @ 1- BLK @ WHERE  THEN ; */
            __COLON "(ERROR)",7,"_perrorp"
            .word   _blk
            .word   _fetch
            .word   _0branch
            .word   1f
            .word   _beep
            .word   _toin
            .word   _fetch
            .word   _1minus
            .word   _blk
            .word   _fetch
            .word   _where
1:          .word   _exit

/* __CODE DIGIT ( char base - n f ) */
            __CODE "DIGIT",5,"_digit"
            pop     {r0}
            ldr     r1,[sp]
            subs    r1,#0x30
            blt     1f
            cmp     r1,#9
            ble     2f
            cmp     r1,#17
            blt     1f
            sub     r1,#7
2:          cmp     r1,r0
            bge     1f
            str     r1,[sp]
            mvn     r0,#0
            pushr0
1:          mov     r0,#0
            pushr0

/* : CONVERT   ( +d1 adr1 -- +d2 adr2 )
   BEGIN  1+  DUP >R  C@  BASE @  DIGIT
   WHILE  SWAP  BASE @ UM*  DROP  ROT  BASE @ UM*  D+
      1 DPL +! R>
   REPEAT  DROP  R> ; */
            __COLON "CONVERT",7,"_convert"
1:          .word   _1plus
            .word   _dup
            .word   _tor
            .word   _cfetch
            .word   _base
            .word   _fetch
            .word   _digit
            .word   _0branch
            .word   2f
            .word   _swap
            .word   _base
            .word   _fetch
            .word   _umstar
            .word   _drop
            .word   _rot
            .word   _base
            .word   _fetch
            .word   _umstar
            .word   _dplus
            .word   _1
            .word   _dpl
            .word   _plusstore
            .word   _rfrom
            .word   _branch
            .word   1b
2:          .word   _drop
            .word   _rfrom
            .word   _exit

/*&: NUMBER?   ( adr -- d flag )
   0 0  ROT DUP 1+  C@ DUP [CHAR] + = IF OVER [CHAR] 0 SWAP 1+ C! THEN
   [CHAR] -  =  DUP  >R  -  DPL OFF CONVERT DUP >R
   BEGIN  DUP C@  ASCII , - 4 U< ( , - . / )
   WHILE R> DROP DUP >R CONVERT REPEAT
   DPL @ 0> OVER R> 1+ - DPL ! SWAP C@ BL = AND
   -ROT  R> ?DNEGATE  ROT ; */
            __COLON "NUMBER?",7,"_numberq"
            .word   _0
            .word   _0
            .word   _rot
            .word   _dup
            .word   _1plus
            .word   _cfetch
            .word   _dup
            .word   _plitp
            .word   0x2B
            .word   _equ      
            .word   _0branch
            .word   3f
            .word   _over
            .word   _plitp
            .word   0x30
            .word   _swap
            .word   _1plus
            .word   _cstore
3:          .word   _plitp
            .word   45
            .word   _equ      
            .word   _dup
            .word   _tor
            .word   _minus
            .word   _dpl
            .word   _off
            .word   _convert
            .word   _dup
            .word   _tor
1:          .word   _dup
            .word   _cfetch
            .word   _plitp
            .word   44
            .word   _minus
            .word   _4
            .word   _ult
            .word   _0branch
            .word   2f
            .word   _rfrom
            .word   _drop
            .word   _dup
            .word   _tor
            .word   _convert
            .word   _branch
            .word   1b
2:          .word   _dpl
            .word   _fetch
            .word   _0gt
            .word   _over
            .word   _rfrom
            .word   _1plus
            .word   _minus
            .word   _dpl
            .word   _store
            .word   _swap
            .word   _cfetch
            .word   _bl
            .word   _equ      
            .word   _and
            .word   _mrot
            .word   _rfrom
            .word   _qdnegate
            .word   _rot
            .word   _exit


/* : (NUMBER)   ( adr -- d# )  NUMBER? UNDEFINED ; */
            __COLON "(NUMBER)",8,"_pnumberp"
            .word   _numberq
            .word   _undefined
            .word   _exit

/* : $NUMBER  ( addr -- dn )  
   >> BL OVER COUNT + C! (stick a blank on end) <<
    BASE @ >R DUP 1+ C@ [ CHAR $ ] LITERAL =
    IF 1+ HEX
    ELSE DUP 1+ C@ [ CHAR o ] LITERAL =
        IF 1+ OCTAL THEN
    THEN NUMBER? R> BASE ! UNDEFINDED ; */
            __COLON "$NUMBER",7,"_dnumber"         /* $ */
  /*        .word   _bl
            .word   _over
            .word   _count
            .word   _plus
            .word   _cstore  */
            .word   _base
            .word   _fetch
            .word   _tor
            .word   _dup
            .word   _1plus
            .word   _cfetch
            .word   _plitp
            .word   36
            .word   _equ      
            .word   _0branch
            .word   1f
            .word   _1plus
            .word   _hex
            .word   _branch
            .word   2f
1:          .word   _dup
            .word   _1plus
            .word   _cfetch
            .word   _plitp
            .word   111
            .word   _equ      
            .word   _0branch
            .word   2f
            .word   _1plus
            .word   _octal
2:          .word   _numberq
            .word   _rfrom
            .word   _base
            .word   _store
            .word   _undefined
            .word   _exit

/* : (UNDEFINED) 0= ?MISSING ; */
            __COLON "(UNDEFINED)",11,"_pundefinedp"
            .word   _0equ
            .word   _qmissing
            .word   _exit

/* : .OK  ( -- )  ."  ok" DEPTH 0 ?DO ." ." LOOP SPACE ; */
            __COLON ".OK",3,"_dotok"
            .word   _pdotqp;.byte 3;.ascii " ok";.align 2
            .word   _depth
            .word   _0
            .word   _pqdop
            .word   1f
2:          .word   _pdotqp;.byte 1;.ascii ".";.align 2
            .word   _ploopp
            .word   2b
1:          .word   _unloop
            .word   _space
            .word   _exit


/* : !FILES   ( fcb -- )   DUP FILE !  IN-FILE !  ; 
            __COLON "!files",6,"_storefiles"
            .word   _dup
            .word   _file
            .word   _store
            .word   _in_file
            .word   _store
            .word   _exit
*/
/* : HIDE   ( -- ) LAST @  N>LINK @ CURRENT @  @ ! ; */
            __COLON "HIDE",4,"_hide"
            .word   _last
            .word   _fetch
            .word   _ntolink
            .word   _fetch
            .word   _current
            .word   _fetch
            .word   _fetch
            .word   _store
            .word   _exit

/* : REVEAL ( -- ) LAST @ N>LINK CURRENT @  ! ; */
            __COLON "REVEAL",6,"_reveal"
            .word   _last
            .word   _fetch
            .word   _ntolink
            .word   _current
            .word   _fetch
            .word   _fetch
            .word   _store
            .word   _exit

/* : !CSP   ( -- )  CONTEXT @ RUN-VOC !  DEPTH CSP !  >EXIT OFF ; */
            __COLON "!CSP",4,"_storecsp"
            .word   _context
            .word   _fetch
            .word   _run_voc
            .word   _store
            .word   _depth
            .word   _csp
            .word   _store
            .word   _toexit
            .word   _off
            .word   _exit

/* : ?CSP   ( -- )  RUN-VOC @ CONTEXT !
                  DEPTH CSP @ <> ABORT" Invalid definition." ; */
            __COLON "?CSP",4,"_qcsp"
            .word   _run_voc
            .word   _fetch
            .word   _context
            .word   _store
            .word   _depth
            .word   _csp
            .word   _fetch
            .word   _notequ
            .word   _pabortqp;.byte 20;.ascii "Invalid definitions."
            .align  2
            .word   _exit

/* : +CSP ( -- ) CSP @ 1- CSP ! ;  */
            __COLON "+CSP",4,"_pluscsp",immediate
            .word   _csp
            .word   _fetch
            .word   _1minus
            .word   _csp
            .word   _store
            .word   _exit

/* : -CSP ( -- ) CSP @  1+ CSP ! ;  */
            __COLON "-CSP",4,"_minuscsp",immediate
            .word   _csp
            .word   _fetch
            .word   _1plus
            .word   _csp
            .word   _store
            .word   _exit

/* : N>LINK     6 - ; (nfa -- lfa) */
            __COLON "N>LINK",6,"_ntolink"
            .word   _plitp
            .word   6
            .word   _minus
            .word   _exit

/* : L>NAME     6 + ; */
            __COLON "L>NAME",6,"_ltoname"
            .word   _plitp
            .word   6
            .word   _plus
            .word   _exit

/* : L>VIEW     4 + ;  
            __COLON "L>VIEW",6,"_ltoview"
            .word   _4plus.word   _exit  */

/* : BODY>      2-   ; */
            __COLON "BODY>",5,"_bodyfrom"
            .word   _4minus
            .word   _exit

/* : NAME>  DUP C@ 0x3F AND + DUP C@ 0= IF 1+ THEN ALIGNED (nfa -- cfa); */
            __COLON "NAME>",5,"_namefrom"
            .word   _count
            .word   _plitp
            .word   0x3F
            .word   _and
            .word   _plus
            .word   _dup
            .word   _cfetch
            .word   _0equ
            .word   _0branch
            .word   1f
            .word   _1plus
1:          .word   _aligned
            .word   _exit

/* : LINK>  L>NAME NAME> ; */
            __COLON "LINK>",5,"_linkfrom"
            .word   _ltoname
            .word   _namefrom
            .word   _exit

/* >BODY ( xt -- a-addr ) "to-body" */
            __CODE ">BODY",5,"_tobody"
            pop     {r0}
            add     r0,#4
            pushr0

/* __CODE (>NAME?) ( cfa alf -- nfa true | cfa false ) */
            __CODE "(>NAME?)",8,"_ptonameqp"
            pop     {r0}
2:          mov     r2,r0
            ldr     r0,[r0]
            teq     r2,#0
            beq     1f
            add     r2,#6
            mov     r3,r2           @ save nfa
            ldrb    r4,[r2],#1
            and     r4,#0x3F
            add     r2,r4
            ands    r5,r2,#0x3
            subne   r2,r5
            addne   r2,#0x04
            ldr     r1,[sp]
            teq     r2,r1           @ test cfa's
            bne     2b              @ get next word
            str     r3,[sp]         @ push nfa
            mvn     r0,#0
            pushr0
1:          mov     r0,#0
            pushr0

/* : >NAME?   ( cfa -- nfa true|xxx false )
   0 FALSE   #VOCS 0
   DO   DROP CONTEXT I 4* + @ DUP
      IF TUCK =
         IF FALSE
         ELSE >R R@ @ @ (>NAME?) R> SWAP DUP ?LEAVE
         THEN
      THEN
   LOOP  NIP ; */ 
            __COLON ">NAME?",6,"_tonameq"
            .word   _0
            .word   _false
            .word   _hashvocs
            .word   _0
            .word   _pdop
3:          .word   _drop
            .word   _context
            .word   _i
            .word   _4star
            .word   _plus
            .word   _fetch
            .word   _dup
            .word   _0branch
            .word   1f
            .word   _tuck
            .word   _equ
            .word   _0branch
            .word   2f
            .word   _false
            .word   _branch
            .word   1f
2:          .word   _tor
            .word   _rfetch
            .word   _fetch
            .word   _fetch
            .word   _ptonameqp
            .word   _rfrom
            .word   _swap
            .word   _dup
            .word   _pqleavep
            .word   4f
1:          .word   _ploopp
            .word   3b
4:          .word   _unloop
            .word   _nip
            .word   _exit

/* : >NAME ( cfa -- nfa ) >NAME?  0= ABORT" Name not found" ; */           
            __COLON ">NAME",5,"_toname"
            .word   _tonameq
            .word   _0equ
            .word   _pabortqp;.byte 14;.ascii  "Name not found"
            .align  2
            .word   _exit  
         
/* : >LINK      >NAME   N>LINK   ; */
            __COLON ">LINK",5,"_tolink"
            .word   _toname
            .word   _ntolink
            .word   _exit

/* : >VIEW      >NAME   2-   ; */
            __COLON ">VIEW",5,"_toview"
            .word   _toname
            .word   _2minus
            .word   _exit

/* : VIEW>      2+   NAME>   ; */
            __COLON "VIEW>",5,"_viewfrom"
            .word   _2plus
            .word   _namefrom
            .word   _exit

/* : (ABORT")   ( f -- )
   IF SP0 @ SP!   INTERACTIVE ERROR
      R> COUNT SPACE TYPE SPACE QUIT THEN
   R> COUNT + ALIGNED >R   ; */
            __COLON "(ABORT\")",8,"_pabortqp"
            .word   _0branch
            .word   1f
            .word   _sp0
            .word   _fetch
            .word   _spstore
            .word   _interactive
            .word   _error
            .word   _rfrom
            .word   _count
            .word   _space
            .word   _type
            .word   _space
            .word   _quit
1:          .word   _rfrom
            .word   _count
            .word   _plus
            .word   _aligned
            .word   _tor
            .word   _exit

/* : ?PAIRS    - ABORT" Control Structure error." ; */
            __COLON "?PAIRS",6,"_qpairs"
            .word   _minus
            .word   _pabortqp;.byte 24
            .ascii "Control Structure error.";.align 2
            .word   _exit

/* : ?COMP  ( -- ) STATE @ 0= ABORT" Compilation only." ; */
            __COLON "?COMP",5,"_qcomp"
            .word   _state
            .word   _fetch
            .word   _0equ
            .word   _pabortqp;.byte 17;.ascii "Compilation only."
            .align  2
            .word   _exit

/* : >MARKS      ( addr1 -- addr2 )    HERE SWAP ,   ; */
            __COLON ">MARKS",6,"_tomarks"
            .word   _here
            .word   _swap
            .word   _comma
            .word   _exit

/* : >RESOLVES  ( addr -- )
   BEGIN ?DUP WHILE DUP @ HERE ROT ! REPEAT ; */
            __COLON ">RESOLVES",9,"_toresolves"
1:          .word   _qdup
            .word   _0branch
            .word   2f
            .word   _dup
            .word   _fetch
            .word   _here
            .word   _rot
            .word   _store
            .word   _branch
            .word   1b
2:          .word   _exit

/* : <MARKS      ( -- addr1 addr2 )    >EXIT @ HERE >EXIT OFF ; */
            __COLON "<MARKS",6,"_ltmarks"
            .word   _toexit
            .word   _fetch
            .word   _here
            .word   _toexit
            .word   _off
            .word   _exit

/* : <RESOLVES  ( addr1 addr2 -- ) , >EXIT @ >RESOLVES >EXIT ! ; */
            __COLON "<RESOLVES",9,"_ltresolves"
            .word   _comma
            .word   _toexit
            .word   _fetch
            .word   _toresolves
            .word   _toexit
            .word   _store
            .word   _exit

/* : (;USES)     ( -- )   R> DUP 4 + >R @  LAST @ NAME>  !  ; */
            __COLON "(;USES)",7,"_pscusesp"
            .word   _rfrom
            .word   _dup
            .word   _4plus
            .word   _tor
            .word   _fetch
            .word   _last
            .word   _fetch
            .word   _namefrom
            .word   _store
            .word   _exit

/* : ;USES       ( -- )   ?CSP   POSTPONE  (;USES)
    REVEAL   R> DROP   ASSEMBLER   ; IMMEDIATE */
            __COLON ";USES",5,"_scuses",immediate
            .word   _qcsp
            .word   _plitp
            .word   _pscusesp
            .word   _comma
            .word   _reveal
            .word   _rfrom
            .word   _drop
            .word   _assembler
            .word   _exit

/* : >TYPE   ( adr len -- )
   TUCK PAD SWAP CMOVE   PAD SWAP TYPE  ; */
            __COLON ">TYPE",5,"_totype"
            .word   _tuck
            .word   _pad
            .word   _swap
            .word   _cmove
            .word   _pad
            .word   _swap
            .word   _type
            .word   _exit

/* : ?REDEFINE  0= IF 2DROP 0 DPL ! REDEFINE THEN ; */
            __COLON "?REDEFINE",9,"_qredefine"
            .word   _0equ
            .word   _0branch
            .word   1f
            .word   _2drop
            .word   _0
            .word   _dpl
            .word   _store
            .word   _redefine
1:          .word   _exit

/* : REDEFINE ( -- ) >RE DEFINE ; */
            __COLON "REDEFINE",8,"_redefine"
            .word   _tore
            .word   _define
            .word   _exit

/* : DEFINE ( -- ) ?DEFINE DROP ; */
            __COLON "DEFINE",6,"_define"
            .word   _qdefine
            .word   _drop
            .word   _exit


/* : ?DEFINE ( ,file-- fcb )  DEFINED
   IF >BODY ELSE DROP >RE BLOCK-FILE: THEN ; */
            __COLON "?DEFINE",7,"_qdefine"
            .word   _defined
            .word   _0branch
            .word   1f
            .word   _tobody
            .word   _branch
            .word   2f
1:          .word   _drop
            .word   _tore
2:          .word   _exit

/* : >RE ( -- )   LAST>IN @ >IN ! ; */
            __COLON ">RE",3,"_tore"
            .word   _lasttoin
            .word   _fetch
            .word   _toin
            .word   _store
            .word   _exit

/* : ?STACK  ( -- )   ( System dependent )
   SP@ SP0 @ SWAP U<   ABORT" Stack underflow"
   SP0 @ SP@ - 0x100 U>   ABORT" Stack overflow"   ; */
            __COLON "?STACK",6,"_qstack"
            .word   _spfetch
            .word   _sp0
            .word   _fetch
            .word   _swap
            .word   _ult
            .word   _pabortqp;.byte 15;.ascii "Stack Underflow"
            .align  2
            .word   _sp0
            .word   _fetch
            .word   _spfetch
            .word   _minus
            .word   _plitp
            .word   0x0100
            .word   _ugt
            .word   _pabortqp;.byte 14;.ascii "Stack Overflow"
            .align  2
            .word   _exit

/* : ?MISSING   ( f -- )
   IF  'WORD COUNT TYPE   TRUE ABORT"  ?"   THEN   ; */
            __COLON "?MISSING",8,"_qmissing"
            .word   _0branch
            .word   1f
            .word   _tickword
            .word   _count
            .word   _type
            .word   _true
            .word   _pabortqp;.byte 2;.ascii " ?";.align 2
1:          .word   _exit

/* : ?UPPERCASE   ( adr -- adr )
   CAPS @ IF  DUP COUNT UPPER   THEN  ; */
            __COLON "?UPPERCASE",10,"_quppercase"
            .word   _caps
            .word   _fetch
            .word   _0branch
            .word   5f
            .word   _dup
            .word   _count
            .word   _upper
5:          .word   _exit

_UPPER:     cmp     r0,#97        @ 97 = 'a'
            bmi     1f
            cmp     r0,#123       @ 123 = 'z'
            bpl     1f
            sub     r0,#32        @  make upper case
1:          mov     pc,lr
/* UPC ( char -- char' )  make upper case */
            __CODE "UPC",3,"_upc"
            pop     {r0}
            bl    _UPPER
            pushr0
/* UPPER (addr len -- ) */
            __CODE "UPPER",5,"_upper"
            pop     {r2}
            pop     {r1}
            teq     r2,#0
            beq     2f
3:          ldrb    r0,[r1]
            bl      _UPPER
            strb    r0,[r1],#1  
            sub     r2,#1
            bne     3b
2:          next

/* : ROM ( -- ) ' ROMPT IS DP ; */
            __COLON "ROM",3,"_rom"
            .word   _plitp
            .word   _rompt
            .word   _pisp
            .word   _dp
            .word   _exit

/* : RAM ( -- ) ' RAMPT IS DP ; */
            __COLON "RAM",3,"_ram"
            .word   _plitp
            .word   _rampt
            .word   _pisp
            .word   _dp
            .word   _exit

/* : >DATA   ( cfa -- data-address )
   DUP @
   DUP [  [ASSEMBLER] DOUSER-VARIABLE META ] LITERAL = SWAP
   DUP [  [ASSEMBLER] DOUSER-DEFER    META ] LITERAL = SWAP
   DROP   OR IF >BODY @ 4* UP @ +   ELSE    >BODY @ THEN   ; */
            __COLON ">DATA",5,"_todata"
            .word   _dup
            .word   _fetch
            .word   _dup
            .word   _plitp
            .word   _douser
            .word   _equ
            .word   _swap
            .word   _dup
            .word   _plitp
            .word   _douser_defer
            .word   _equ
            .word   _swap
            .word   _drop
            .word   _or
            .word   _0branch
            .word   1f
            .word   _tobody
            .word   _fetch
            .word   _4star
            .word   _up
            .word   _fetch
            .word   _plus
            .word   _branch
            .word   2f
1:          .word   _tobody
            .word   _fetch
2:          .word   _exit  

/*            __COLON "_todata",5,">DATA"
            .word   _4plus,_fetch,_4star,_up,_fetch,_plus,_exit
*/

/* : (IS)      ( cfa --- )
   R@ @  >DATA !   R> 4+ >R   ; R> LENGTH >DATA ! >R */
            __COLON "(IS)",4,"_pisp"
            .word   _rfetch
            .word   _fetch
            .word   _todata
            .word   _store
            .word   _rfrom
            .word   _4plus
            .word   _tor
            .word   _exit

/* : IS   ( cfa --- )
   STATE @ IF  POSTPONE (IS)  ELSE  ' >DATA !  THEN ; IMMEDIATE */
            __COLON "IS",2,"_is",immediate
            .word   _state
            .word   _fetch
            .word   _0branch
            .word   1f
            .word   _plitp
            .word   _pisp
            .word   _comma
            .word   _exit
1:          .word   _tick
            .word   _todata
            .word   _store
            .word   _exit

/* : <RESOLVE> 0<
   IF , >EXIT @ SWAP >EXIT ! 0 SWAP 2
   ELSE <RESOLVES THEN ; */
            __COLON "<RESOLVE>",9,"_ltresolvegt"
            .word   _0lt
            .word   _0branch
            .word   1f
            .word   _comma
            .word   _toexit
            .word   _fetch
            .word   _swap
            .word   _toexit
            .word   _store
            .word   _0
            .word   _swap
            .word   _2
            .word   _branch
            .word   2f
1:          .word   _ltresolves
2:          .word   _exit

/* : .ID     ( nfa -- )
   COUNT 0x3f AND TYPE SPACE ; */
            __COLON ".ID",3,"_dotid"
            .word   _count
            .word   _plitp
            .word   0x03F
            .word   _and
            .word   _type
            .word   _space
            .word   _exit

/* : DEFINITIONS   ( -- )
   CONTEXT @ CURRENT !   ; */
            __COLON "DEFINITIONS",11,"_definitions"
            .word   _context
            .word   _fetch
            .word   _current
            .word   _store
            .word    _exit

/* : ALSO   ( -- ) CONTEXT #VOCS 1- 4* + @
   ABORT" Search order exceeded."
   CONTEXT DUP 4+ #VOCS 1- 4* CMOVE>  ; */
            __COLON "ALSO",4,"_also"
            .word   _context
            .word   _hashvocs
            .word   _1minus
            .word   _4star
            .word   _plus
            .word   _fetch
            .word   _pabortqp
            .byte   22
            .ascii "Search order exceeded."
            .align  2
            .word   _context
            .word   _dup
            .word   _4plus
            .word   _hashvocs
            .word   _1minus
            .word   _4star
            .word   _cmoveup
            .word   _exit

/* : KNOWN   ( -- )
   CONTEXT 4+ #VOCS 1- 4* ERASE   ALSO  ; */
            __COLON "KNOWN",5,"_known"
            .word   _context
            .word   _4plus
            .word   _hashvocs
            .word   _1minus
            .word   _4star
            .word   _erase
            .word   _also
            .word   _exit

/* : SEAL   ( -- ) 1 IS #VOCS  ; */
            __COLON "SEAL",4,"_seal"
            .word   _1
            .word   _pisp
            .word   _hashvocs
            .word   _exit

/* : UNSEAL  ( -- ) [ #VOCS ] LITERAL IS #VOCS  ; */
            __COLON "UNSEAL",6,"_unseal"
            .word   _plitp
            .word   8
            .word   _pisp
            .word   _hashvocs
            .word   _exit

/* VOCABULARY ROOT */
/* : ONLY ( -- ) ROOT KNOWN  ; */
            __COLON "ONLY",4,"_only"
            .word   _root
            .word   _known
            .word   _exit

            exitforth
/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
/* ROOT DEFINITIONS           ( For backward capatibility.) */
/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
            startroot
/* : DEFINITIONS ( -- ) DEFINITIONS  ; */
            __COLON "DEFINITIONS",11,"_rdefinitions"
            .word   _definitions
            .word   _exit

/* : FORTH       ( -- ) FORTH  ; */
            __COLON "FORTH",5,"_rforth"
            .word   _forth
            .word   _exit

/* : ALSO        ( -- ) ALSO  ; */
            __COLON "ALSO",4,"_ralso"
            .word   _also
            .word   _exit

            exitroot
/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
/* FORTH DEFINITIONS */
/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
            startforth


/* : PREVIOUS   ( -- )
   CONTEXT DUP 4+ SWAP [ #VOCS 1- 4* ] LITERAL CMOVE
   CONTEXT [ #VOCS 1- 4* ] LITERAL + OFF    ; */
            __COLON "PREVIOUS",8,"_previous"
            .word   _context
            .word   _dup
            .word   _4plus
            .word   _swap
            .word   _hashvocs
            .word   _1minus
            .word   _4star
            .word   _cmove
            .word   _context
            .word   _hashvocs
            .word   _1minus
            .word   _4star
            .word   _plus
            .word   _off
            .word   _exit

/* : ORDER   (S -- )
   CR ." Search order: " CONTEXT   #VOCS 0
   DO   DUP @ ?DUP IF
        BODY> >NAME .ID THEN 4+
   LOOP DROP  CR ."  Definitions:  " CURRENT @ BODY> >NAME .ID     ; */
            __COLON "ORDER",5,"_order"
            .word   _cr
            .word   _pdotqp
            .byte   14
            .ascii "Search order: "
            .align  2
            .word   _context
            .word   _hashvocs
            .word   _0
            .word   _pdop
1:          .word   _dup
            .word   _fetch
            .word   _qdup
            .word   _0branch
            .word   2f
            .word   _bodyfrom
            .word   _toname
            .word   _dotid
2:          .word   _4plus
            .word   _ploopp
            .word   1b
            .word   _unloop
            .word   _drop
            .word   _cr
            .word   _pdotqp
            .byte   14
            .ascii " Definitions: "
            .align 2
            .word   _current
            .word   _fetch
            .word   _bodyfrom
            .word   _toname
            .word   _dotid
            .word   _exit

/* : VOCS   (S -- ) SPACE   VOC-LINK @
   BEGIN DUP 4- BODY> >NAME .ID   @ ?DUP 0= UNTIL  ; */
            __COLON "VOCS",4,"_vocs"
            .word   _space
            .word   _voc_link
            .word   _fetch
1:          .word   _dup
            .word   _4minus
            .word   _bodyfrom
            .word   _toname
            .word   _dotid
            .word   _fetch
            .word   _qdup
            .word   _0equ
            .word   _0branch
            .word   1b
            .word   _exit



.section .text
/* SET-STACKS ( STACKS ) */
/*            __CODE "set-stacks",10,"_setstacks"
            ldr     sp,=.sp0
            ldr     rsp,=.rp0
            next */
/*& : SP@ ( -- addr ) ; */
            __CODE "SP\@",3,"_spfetch"
            mov     r0,sp
            push    {r0} 
            next
/*& : SP! ( addr -- ) ; */
            __CODE "SP!",3,"_spstore"
            pop     {r0}
            mov     sp,r0
            next
/*& : RP!  ( addr -- )  ; */
            __CODE "RP!",3,"_rpstore"
            pop     {r0}
            mov     rsp,r0
            next
/*& : RP@  ( -- addr )  ; */
            __CODE "RP\@",3,"_rpfetch"
            push    {rsp}
            next

/* (LIT)  ( -- x ) get next token and put it on the stack */
            __CODE "(LIT)",5,"_plitp"
            popr    r0,ip
            pushr0

/*& ABS ( n -- u ) "abs" */
            __CODE "ABS",3,"_abs"
            pop     {r0}
            cmp     r0,#0
            rsblt   r0,#0
            pushr0


/*& + ( n1|u1 n2|u2 -- n2|u3)  "plus" */
            __CODE "+",1,"_plus"
            pop     {r0}
            pop     {r1}
            add     r0,r1
            pushr0

/*& +! ( n|u a-addr -- ) "plus-store*/
            __CODE "+!",2,"_plusstore"
            pop     {r0}
            pop     {r1}
            ldr     r2,[r0]
            add     r2,r1
            str     r2,[r0]
            next

/*& - ( n1|u1 n2|u2 -- n2|u3) "minus" */
            __CODE "-",1,"_minus"
            pop     {r0}
            pop     {r1}
            sub     r1,r0
            push    {r1}
            next

/*&  / ( n1 n2 -- n3 ) "slash" */
/* : /  /MOD  NIP ;  */
            __COLON "/",1,"_slash"
            .word   _slashmod
            .word   _nip
            .word   _exit

/*& 1+ ( n -- n+1 ) "one-plus" */
            __CODE "1+",2,"_1plus"
            pop     {r0}
            add     r0,#1
            pushr0
            

/*& 1- ( n -- n-1 ) " one-minus" */
            __CODE "1-",2,"_1minus"
            pop     {r0}
            sub     r0,#1
            pushr0

/*& 2+ ( n -- n+2 ) "two-plus" */
            __CODE "2+",2,"_2plus"
            pop     {r0}
            add     r0,#2
            pushr0
            

/*& 2- ( n -- n-2 ) " two-minus" */
            __CODE "2-",2,"_2minus"
            pop     {r0}
            sub     r0,#2
            pushr0

/*& 4+ ( n -- n+4 ) "four-plus" */
            __CODE "4+",2,"_4plus"
            pop     {r0}
            add     r0,#4
            pushr0

/*& 8+ ( n -- n+8 ) "eight-plus" */
            __CODE "8+",2,"_8plus"
            pop     {r0}
            add     r0,#8
            pushr0

/*& 4- ( n -- n-4 ) " four-minus" */
            __CODE "4-",2,"_4minus"
            pop     {r0}
            sub     r0,#4
            pushr0

/*& 2* ( x1 -- x1*2 ) "two-star" */
            __CODE "2*",2,"_2star"
            pop     {r0}
            mov     r0,r0,lsl #1
            pushr0

/*& 2/ ( x1 -- x1/2 ) "two-slash" */
            __CODE "2/",2,"_2slash"
            pop     {r0}
            mov     r0,r0,asr #1
            pushr0

/*& 4* ( x1 -- x1*4 ) "four-star" */
            __CODE "4*",2,"_4star"
            pop     {r0}
            mov     r0,r0,lsl #2
            pushr0

/*& 4/ ( x1 -- x1/4 ) "four-slash" */
            __CODE "4/",2,"_4slash"
            pop     {r0}
            mov     r0,r0,asr #2
            pushr0

/*& 2DROP ( n1 n2 -- )  "two-drop" */
            __CODE "2DROP",5,"_2drop"  
            add     sp,#8
            next

/*& 2DUP  ( n1 n2 -- n1 n2 n1 n2 ) "two-dupe" */
            __CODE "2DUP",4,"_2dup"  
            ldr     r1,[sp,#4]
            ldr     r0,[sp]
            pushr1

/*& 2OVER ( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 ) "two-over" */
            __CODE "2OVER",5,"_2over"
            ldr     r1,[sp,#12]
            ldr     r0,[sp,#8]
            pushr1

/*& 2SWAP ( x1 x2 x3 x4 -- x3 x4 x1 x2 ) "two-swap" */
            __CODE "2SWAP",5,"_2swap"
            ldr     r1,[sp,#12]
            ldr     r2,[sp,#8]
            ldr     r3,[sp,#4]
            ldr     r4,[sp]
            str     r3,[sp,#12]
            str     r4,[sp,#8]
            str     r1,[sp,#4]
            str     r2,[sp]
            next
/*& SWAP ( u1 u2 -- u2 u1 ) "swap" */
            __CODE "SWAP",4,"_swap"
            pop     {r1}
            pop     {r0}
            pushr1

/*& >R ( u -- ) (R: -- u ) "tor"  */
            __CODE ">R",2,"_tor"
            pop     {r0}
            pushr   r0,rsp
            next

/*& R> ( -- u ) (R: u --  ) "rfrom" */
            __CODE "R>",2,"_rfrom"
            popr    r0,rsp
            pushr0

/*& R@   ( -- u ) (R: u -- )  "r-fetch" */
            __CODE "R@",2,"_rfetch"
            ldr     r0,[rsp]
            pushr0

/*2>R (x1 x2 -- )(R: -- x1 x2) "two-to-r"*
            __CODE "2>R",3,"_2tor" */
            pop     {r0}
            pop     {r1}
            pushr   r1,rsp
            pushr   r0,rsp
            next

/*2R> ( -- x1 x2 )(R: x1 x2 -- ) "two-r-from"*/
            __CODE "2R>",3,"_2rfrom"
            popr    r0,rsp
            popr    r1,rsp
            pushr1

/*2R@ ( -- x1 x2)(R: x1 x2 -- x1 x2 ) "2-r-fetch"*/
            __CODE "2R@",3,"_2rfetch"
            ldr     r0,[rsp]
            ldr     r1,[rsp,#4]
            pushr1

/*& 3DUP  ( x1 x2 x3 -- x1 x2 x3 x1 x2 x3)  "three-dupe" */
            __CODE "3DUP",4,"_3dup"
            ldr     r2,[sp,#8]
            ldr     r1,[sp,#4]
            ldr     r0,[sp]
            push    {r2}
            pushr1

/*& ?DUP ( x -- 0|x x ) "question-dupe" */
            __CODE "?DUP",4,"_qdup"
            ldr     r0,[sp]
            teq     r0,#0
            pushne  {r0}
            next

/*& C, ( char -- ) "c-comma"*/
/*: C, HERE C! 1 ALLOT ;  */
            __COLON "C,",2,"_ccomma"
            .word   _here
            .word   _cstore
            .word   _1
            .word   _allot
            .word   _exit


/*& C@ ( addr -- char ) "c-fetch"*/
            __CODE "C@",2,"_cfetch"
            pop     {r0}
            ldrb    r0,[r0]
            pushr0

/*& C! ( char a-addr -- )  "c-store"  */
            __CODE "C!",2,"_cstore"
            pop     {r0}
            pop     {r1}
            strb    r1,[r0]
            next


/*& H, ( x -- ) "h-comma" */
/*: H, HERE H! 2 ALLOT ;*/
            __COLON "H,",2,"_hcomma"
            .word   _here
            .word   _hstore
            .word   _2
            .word   _allot
            .word   _exit

/*& H@ ( a-addr -- hw ) */
            __CODE "H@",2,_hfetch
            pop     {r0}
            ldrh    r0,[r0]
            pushr0

/*& H! ( hw hw-addr -- ) */
            __CODE "H!",2,"_hstore"
            pop     {r0}
            pop     {r1}
            strh    r1,[r0]
            next

/*& , ( x -- ) "comma" */
/*: , HERE ! 4 ALLOT ;*/
            __COLON ",",1,"_comma"
            .word   _here
            .word   _store
            .word   _4
            .word   _allot
            .word   _exit

/*& @  ( a-addr - x ) "fetch" */
            __CODE "@",1,"_fetch"
            pop     {r0}
            ldr     r0,[r0]
            pushr0

/*& ! ( x a-addr -- ) "store" ; */
            __CODE "!",1,"_store"
            pop     {r0}
            pop     {r1}
            str     r1,[r0]
            next

/* 2@ ( a-addr -- x1 x2 ) "two-fetch" */
            __CODE "2@",2,"_2fetch"
            pop     {r3}
            ldr     r1,[r3]
            ldr     r0,[r3,#4]
            pushr1


/* 2! ( x1 x2 a-addr -- ) "two-store" */
            __CODE "2!",2,"_2store"
            pop     {r0}
            pop     {r2}
            pop     {r1}
            str     r1,[r0]
            str     r2,[r0,#4]
            next

/*& AND ( n1 n2 -- n3 ) "and" */
            __CODE "AND",3,"_and"  
            pop     {r0}
            pop     {r1}
            and     r0,r1
            pushr0

/*&INVERT  ( n -- !n)  */
            __CODE "INVERT",6,"_invert"
            pop     {r0}
            mvn     r0,r0
            pushr0

/*&DEPTH ( -- n) "depth" */
/*: DEPTH SP@ SP0 @ SWAP - 4/ */
            __COLON "DEPTH",5,"_depth"
            .word   _spfetch
            .word   _sp0
            .word   _fetch
            .word   _swap
            .word   _minus
            .word   _4slash
            .word   _exit
/*& DROP ( n -- ) "drop" */
            __CODE "DROP",4,"_drop"
            pop     {r0}
            next

/*& DUP ( u -- u u ) "dup" */
            __CODE "DUP",3,"_dup"
            ldr     r0,[sp]
            pushr0

/*& ROT ( x1 x2 x3 -- x2 x3 x1 ) "rot" */
            __CODE "ROT",3,"_rot"
            pop     {r1}
            pop     {r2}
            pop     {r0}
            push    {r2}
            pushr1

/*& -ROT ( x1 x0 x2 -- x2 x1 x0 ) "minus-rot" */
            __CODE "-ROT",4,"_mrot"
            pop     {r2}
            pop     {r0}
            pop     {r1}
            push    {r2}
            pushr1

/*&NEGATE ( n -- -n ) "negate" */
            __CODE "NEGATE",6,"_negate"
            pop     {r0}
            rsb     r0,#0
            pushr0

/*&XOR ( x1 x2 -- x3 ) "xor" */
            __CODE "XOR",3,"_xor"
            pop     {r0}
            pop     {r1}
            eor     r0,r1
            pushr0

/*&OR (n1 n2 -- n3) "or"*/
            __CODE "OR",2,"_or"
            pop     {r0}
            pop     {r1}
            orr     r0,r1
            pushr0

/*& OVER ( u1 u2 -- u1 u2 u1 ) "over" */
            __CODE "OVER",4,"_over"
            ldr     r0,[sp,#4]
            pushr0

/*&NIP ( x1 x2 -- x2 ) "nip" */
            __CODE "NIP",3,"_nip"
            pop     {r0}
            str     r0,[sp]
            next

/*PICK  ( xn..x2 x1 n -- xn..x2 x1 xn )*/
            __CODE "PICK",4,"_pick"
            pop     {r1}
            ldr     r0,[sp,r1,lsl #2]
            pushr0

/*&ROLL(xu xu-1...x0 u -- xu-1...x0 xu)*/
            __CODE "ROLL",4,"_roll"
            pop     {r0}
            ldr     r1,[sp,r0,lsl #2]
1:          mov     r3,r0
            subs    r0,#1
            blt     2f
            ldr     r2,[sp,r0,lsl #2]
            str     r2,[sp,r3,lsl #2]
            b       1b
2:          str     r1,[sp]
            next

/*&UNDER+ ( n1 n2 n3 -- n1+n3 n2 ) "under-plus" */
            __CODE "UNDER+",6,"_underplus"
            pop     {r0}
            ldr     r1,[sp,#4]
            add     r0,r1 
            str     r0,[sp,#4]
            next

/*&RSHIFT  (x1 u - x2)"r-shift"*/
            __CODE "RSHIFT",6,"_rshift"
            pop     {r1}
            pop     {r0}
            mov     r0,r0,lsr r1
            pushr0

/*&LSHIFT  (x1 u - x2)"l-shift"*/
            __CODE "LSHIFT",6,"_lshift"
            pop     {r1}
            pop     {r0}
            mov     r0,r0,lsl r1
            pushr0

/*&MAX  (n1 n2 -- n3 ) "max" */
            __CODE "MAX",3,"_max"
            pop     {r0}
            pop     {r1}
            cmp     r0,r1
            movlt   r0,r1
            pushr0

/*&MIN (n1 n2 -- n3)  "min" */
            __CODE "MIN",3,"_min"
            pop     {r0}
            pop     {r1}
            cmp     r0,r1
            movgt   r0,r1
            pushr0

/*&TUCK ( u1 u2 -- u2 u1 u2 )  "tuck" */
            __CODE "TUCK",4,"_tuck"  
            pop     {r0}
            pop     {r1}
            push    {r0}
            pushr1

/*&ON (addr -- )*/
            __CODE "ON",2,"_on"
            pop     {r1}
            mvn     r0,#0
            str     r0,[r1]
            next

/*&OFF (addr -- )*/
            __CODE "OFF",3,"_off"
            pop     {r1}
            mov     r0,#0
            str     r0,[r1]
            next

/*&TRUE ( -- -1 )*/
            __CODE "TRUE",4,"_true"
            mvn     r0,#0
            pushr0

/*&FALSE ( -- 0 )*/
            __CODE "FALSE",5,"_false"
            mov     r0,#0
            pushr0

/*&BL  ( -- char )  "bl" */
            __CODE "BL",2,"_bl"
            mov     r0,#0x20
            pushr0


/*& 0 ( -- 0 )  "zero" */
            __CODE "0",1,"_0"
            mov     r0,#0
            pushr0

/*& 1 ( -- 1 )  "one" */
            __CODE "1",1,"_1"
            mov     r0,#1
            pushr0

/*& 2 ( -- 2 )  "two" */
            __CODE "2",1,"_2"
            mov     r0,#2
            pushr0

/*& 3 ( -- 3 )  "three" */
            __CODE "3",1,"_3"
            mov     r0,#3
            pushr0

/*& 4 ( -- 4 )  "four" */
            __CODE "4",1,"_4"
            mov     r0,#4
            pushr0

/*& 5 ( -- 5 )  "five" */
            __CODE "5",1,"_5"
            mov     r0,#5
            pushr0

/*& 15 ( -- 15 )  "fifteen" */
            __CODE "15",2,"_15"
            mov     r0,#15
            pushr0

/*& 127 ( -- 127 )  "127" */
            __CODE "127",3,"_127"
            mov     r0,#127
            pushr0

/*& 8 ( -- 8 )  "eight" */
            __CODE "8",1,"_8"
            mov     r0,#8
            pushr0

/*& -1 ( -- -1 )  "minus-one" */
            __CODE "-1",2,"_minus1"
            mov     r0,#-1
            pushr0

/* -2 ( -- -2 )  "minus-two" */
            __CODE "-2",2,"_minus2"
            mov     r0,#-2
            pushr0

/*& -3 ( -- -3 )  "minus-three" */
            __CODE "-3",2,"_minus3"
            mov     r0,#-3
            pushr0

/*& -4 ( -- -4 )  "minus-four" */
            __CODE "-4",2,"_minus4"
            mov     r0,#-4
            pushr0

/*& BS ( -- bs ) */
            __CODE "BS",2,"_bs"
            mov     r0,#8
            pushr0

/*& * ( n1|u1 n2|u2 -- n3|u3)  "star" */
/*: *  UM* DROP ; */
            __COLON "*",1,"_star"
            .word   _umstar
            .word   _drop
            .word   _exit

/*& */ /* ( n1 n2 n3 -- n4 ) "star-slash" */
/*: *./ * /MOD NIP */
            __COLON "*/",2,"_starslash"
            .word   _starslashmod
            .word   _nip
            .word   _exit


/*& */ /* ( n1 n2 n3 -- n4 n5)  "star-slash-mod"  */     
/*: * MOD >R m* R> M/MOD */
            __COLON "*/MOD",5,"_starslashmod"
            .word   _tor
            .word   _mstar
            .word   _rfrom
            .word   _mslashmod
            .word   _exit

/*& UN*U (ud n -- ud ) "U N star U" */
/* : UN*U TUCK UM* DROP -ROT UM* ROT 0 SWAP D+ ; */
            __COLON "UN*U",4,"_unstaru"
            .word   _tuck
            .word   _umstar
            .word   _drop
            .word   _mrot
            .word   _umstar
            .word   _rot
            .word   _0
            .word   _swap
            .word   _dplus
            .word   _exit

/*&M* ( n1 n2 -- d ) "m-star"*/
            __CODE "M*",2,"_mstar"
            pop     {r2}
            pop     {r3}
            smull   r1,r0,r3,r2
            pushr1

/*& /MOD ( n1 n2 -- rem quot ) "slashmod"  */
/*: /MOD  >R S>D R> M/MOD */
            __COLON "/MOD",4,"_slashmod"
            .word    _tor
            .word    _stod
            .word    _rfrom
            .word    _mslashmod
            .word    _exit

/*& : M/MOD   ( d# n1 -- rem quot )
   ?DUP
   IF >R   R@ ?DNEGATE S>D   R@ ABS AND +   R@ ABS UM/MOD
      SWAP R> ?NEGATE   SWAP
   THEN ; */
            __COLON "M/MOD",5,"_mslashmod"
            .word   _qdup
            .word   _0branch
            .word   1f
            .word   _tor
            .word   _rfetch
            .word   _qdnegate
            .word   _stod
            .word   _rfetch
            .word   _abs
            .word   _and
            .word   _plus
            .word   _rfetch
            .word   _abs
            .word   _umslashmod
            .word   _swap
            .word   _rfrom
            .word   _qnegate
            .word   _swap
1:          .word   _exit

/*&FM/MOD  (d1 n1 -- n2 n3)  "f-m-slash-mod" */
/*: FM/MOD DUP >R OVER >R ABS >R DABS R@ UM/MOD
      OVER R> - ABS R> R@ XOR 0< 
      IF ROT DROP SWAP 1+ NEGATE 
      ELSE DROP THEN
      SWAP R> ?NEGATE SWAP ;*/
            __COLON "FM/MOD",6,"_fmslashmod"
            .word   _dup
            .word   _tor
            .word   _over
            .word   _tor
            .word   _abs
            .word   _tor
            .word   _dabs
            .word   _rfetch
            .word   _umslashmod
            .word   _over
            .word   _rfrom
            .word   _minus
            .word   _abs
            .word   _rfrom
            .word   _rfetch
            .word   _xor
            .word   _0less
            .word   _0branch
            .word   1f
            .word   _rot
            .word   _drop
            .word   _swap
            .word   _1plus
            .word   _negate
            .word   _branch
            .word   2f
1:          .word   _drop
2:          .word   _swap
            .word   _rfrom
            .word   _qnegate
            .word   _swap
            .word   _exit

/*& SM/REM ( d1 n1 -- n2 n3 ) "s-m-slash-rem" */
/*: SM/REM OVER >R >R DABS R@ ABS UM/MOD SWAP R> SWAP R@ ?NEGATE 
      -ROT R> XOR ?NEGATE ; */
            __COLON "SM/REM",6,"_smslashrem"
            .word   _over
            .word   _tor 
            .word   _tor 
            .word   _dabs
            .word   _rfetch
            .word   _abs
            .word   _umslashmod
            .word   _swap
            .word   _rfrom
            .word   _swap
            .word   _rfetch
            .word   _qnegate
            .word   _mrot
            .word   _rfrom
            .word   _xor
            .word   _qnegate
            .word   _exit

/*MOD (n1 n2 -- n3)  "mod" */
/*: MOD >R S>D R> FM/MOD DROP ; */
            __COLON "MOD",3,"_mod"
            .word   _tor
            .word   _stod
            .word   _rfrom
            .word   _fmslashmod
            .word   _drop
            .word   _exit

/*UM* ( u1 u2 -- ud ) "um-star"*/
            __CODE "UM*",3,"_umstar"
            pop     {r2}
            pop     {r3}
            umull   r1,r0,r3,r2
            pushr1

/* UM/MOD ( d n -- rem quot ) "u-m-slash-mod" */
            __CODE "UM/MOD",6,"_umslashmod"
            pop     {r5}
            mov     r0,#0
            pop     {r1}
            pop     {r2}
            mov     r3,#33
            cmp     r1,r5
            bhi     uerr
            cmp     r5,#0
            beq     uerr
ums1:       cmp     r1,r5
            subhss  r1,r5
            adc     r0,r0
            subs    r3,#1
            beq     uexit
            adds    r2,r2
            adc     r1,r1
            b       ums1
uerr:       mvn     r0,#0
            mov     r1,r0
uexit:      pushr1


/* DUM/MOD ( d n -- rem d#quot ) "D U M slash MOD */
/* : DUM/MOD >R 0 R@ UM/MOD R> SWAP >R UM/MOD R> ; */
            __COLON "DUM/MOD",7,"_dumslashmod"
            .word   _tor
            .word   _0
            .word   _rfetch
            .word   _umslashmod
            .word   _rfrom
            .word   _swap
            .word   _tor
            .word   _umslashmod
            .word   _rfrom
            .word   _exit

/*: BLANK    ( addr len -- )  BL FILL ; */
            __COLON "BLANK",5,"_blank"
            .word   _bl
            .word   _fill
            .word   _exit

/*: ERASE    ( addr len -- )  0 FILL ; */
            __COLON "ERASE",5,"_erase"
            .word   _0
            .word   _fill
            .word   _exit

/*: D=    ( d1 d2 -- f )    D-  D0=  ;  */
            __COLON "D=",2,"_dequ"
            .word   _dminus
            .word   _d0equ
            .word   _exit

/* DABS  ( d -- |d|)  */
            __CODE "DABS",4,"_dabs"
            pop     {r0}
            pop     {r1}
            tst     r0,#0x8000
            beq     1f
            rsbs    r1,#0
            rsc     r0,#0
1:          pushr1

/* D2* ( d -- d*2 ) */
            __CODE "D2*",3,"_d2star"
            pop     {r0}
            pop     {r1}
            adds    r1,r1
            adc     r0,r0
            pushr1


/* D2/ ( d -- d/2 )   */
            __CODE "D2/",3,"_d2slash"
            pop     {r0}
            pop     {r1}
            movs    r0,r0,asr #1
            mov     r1,r1,rrx     
            pushr1

/* : D-    ( d1 d2 -- d3 )   DNEGATE D+   ; */
            __COLON "D-",2,"_dminus"
            .word   _dnegate
            .word   _dplus
            .word   _exit

/* : ?DNEGATE  ( d1 n -- d2 )     0< IF   DNEGATE   THEN   ; */
            __COLON "?DNEGATE",8,"_qdnegate"
            .word   _0lt
            .word   _0branch
            .word   1f
            .word   _dnegate
1:          .word   _exit

/*: D0=   ( d -- f )        OR 0= ; */
            __COLON "D0=",3,"_d0equ"
            .word   _or
            .word   _0equ
            .word   _exit

/* DNEGATE ( d -- -d ) */
            __CODE "DNEGATE",7,"_dnegate"
            pop     {r0}
            pop     {r1}
            rsbs    r1,#0
            rsc     r0,#0
            pushr1

/* D+  ( d1 d2 -- d3 )*/
            __CODE "D+",2,"_dplus"
            pop     {r0}
            pop     {r1}
            pop     {r2}
            pop     {r3}
            adds    r1,r3
            adc     r0,r2
            pushr1


/*& ?NEGATE ( n1 n2 -- n3) */
            __COLON "?NEGATE",7,"_qnegate"
            .word   _0lt
            .word   _0branch
            .word   1f
            .word   _negate
1:          .word   _exit

/* : .(   ( -- )   ASCII ) PARSE-CHAR    >TYPE  ; IMMEDIATE */
            __COLON ".(",2,"_dotpren",immediate
            .word   _plitp
            .word   41
            .word   _parsechar
            .word   _totype
            .word   _exit

/* 0<> ( n -- f )*/
            __CODE "0<>",3,"_0notequ"
            pop     {r0}
            teq     r0,#0
            mvnne   r0,#0
            moveq   r0,#0
            pushr0


/* 0> ( n -- f )*/
            __CODE "0>",2,"_0gt"
            pop     {r0}
            cmp     r0,#0
            mvngt   r0,#0
            movle   r0,#0
            pushr0

/* 0< ( n -- f )*/
            __CODE "0<",2,"_0lt"
            pop     {r0}
            cmp     r0,#0
            mvnlt   r0,#0
            movge   r0,#0
            pushr0


/*<> ( x1 x2 -- flag ) "not-equal" */
            __CODE "<>",2,"_notequ"
            pop     {r0}
            pop     {r1}
            teq     r0,r1 
            mvnne   r0,#0
            moveq   r0,#0
            pushr0


/*& LENGTH ( addr -- addr+4 n) */
            __CODE "LENGTH",6,"_length"
            pop     {r1}
            ldr     r0,[r1],#4
            pushr1

/*&: PLACE     ( str-addr len to -- )
   3DUP  1+ SWAP MOVE  C! DROP  ; */
            __COLON "PLACE",5,"_place"
            .word   _3dup
            .word   _1plus
            .word   _swap
            .word   _move
            .word   _cstore
            .word   _drop
            .word   _exit

/* COUNT ( c-addr1 -- c-addr2 u) "count"*/
/*&: COUNT DUP C@ 1 UNDER+ ; */
            __COLON "COUNT",5,"_count"
            .word   _dup
            .word   _cfetch
            .word   _1
            .word   _underplus
            .word   _exit

/* CELL+ (a-addr1 -- a-addr2) "cell-plus" */
            __CODE "CELL+",5,"_cellplus"
            pop     {r0}
            add     r0,#4
            pushr0

/* CELLS ( n1 -- n2 ) "cells"  */
            __CODE "CELLS",5,"_cells"
            pop     {r0}
            mov     r0,r0,lsl #2
            pushr0

/*FILL (c-addr u char -- )  "fill" */
            __CODE "FILL",4,"_fill"
            pop     {r0}
            pop     {r1}
            pop     {r2}
1:          subs    r1,#1
            strgeb  r0,[r2]
            addge   r2,#1
            bge     1b
            next

/*EARSE ( addr u -- ) */
            __CODE "EARSE",5,"_earse"
            pop     {r0}
            pop     {r1}
            mov     r2,#0
1:          subs    r0,#1
            blt     2f
            strb    r2,[r1],#1
            b       1b
2:          next

/*S>D  ( n -- d ) "s-to-d"*/
            __CODE "S>D",3,"_stod"
            pop     {r1}
            tst     r1,#0x80000000
            mvnne   r0,#0
            moveq   r0,#0
            pushr1

/*&CMOVE (addr1 addr2 u -- ) "c-move"*/
            __CODE "CMOVE",5,"_cmove"
            pop     {r0}
            pop     {r1}
            pop     {r2}
1:          subs    r0,#1
            blt     2f
            ldrb    r3,[r2],#1
            strb    r3,[r1],#1
            b       1b
2:          next


/*&CMOVE> (addr1 addr2 u -- ) "c-move-up"*/
            __CODE "CMOVE>",6,"_cmoveup"
            pop     {r0}
            pop     {r1}
            pop     {r2}
            teq     r0,#0
            beq     2f
            sub     r0,#1
            add     r1,r0
            add     r2,r0
            add     r0,#1
1:          ldrb    r3,[r2],#-1
            strb    r3,[r1],#-1
            subs    r0,#1
            bne     1b
2:          next


/*&MOVE (addr1 addr2 u -- ) "move"  */
/*: MOVE >R 2DUP U< R> SWAP IF CMOVE> ELSE CMOVE THEN ; */
            __COLON "MOVE",4,"_move"
            .word   _tor
            .word   _2dup
            .word   _ult
            .word   _rfrom
            .word   _swap
            .word   _0branch
            .word   1f
            .word   _cmoveup
            .word   _exit
1:          .word   _cmove
            .word   _exit


/* < ( n1 n2 -- flag ) "less-than*/
            __CODE "<",1,"_lt"
            pop     {r0}
            pop     {r1}
            cmp     r1,r0
            mvnlt   r0,#0
            movge   r0,#0
            pushr0

/* = ( n1 n2 -- flag ) "equal" */
            __CODE "=",1,"_equ"
            pop     {r0}
            pop     {r1}
            cmp     r1,r0
            mvneq   r0,#0
            movne   r0,#0
            pushr0

/* > ( n1 n2 -- flag ) "greater-than" */
            __CODE ">",1,"_gt"
            pop     {r0}
            pop     {r1}
            cmp     r1,r0
            mvngt   r0,#0
            movle   r0,#0
            pushr0

/* 0< ( n -- flag )  "zero-less" */
            __CODE "0<",2,"_0less"
            pop     {r0}
            cmp     r0,#0
            mvnlt   r0,#0
            movge   r0,#0
            pushr0 

/* 0= ( n -- flag ) "zero-less" */
            __CODE "0=",2,"_0equ" 
            pop     {r0}
            cmp     r0,#0
            mvneq   r0,#0
            movne   r0,#0
            pushr0

/* U<  (u1 u2 -- flag ) "u-less-than" */
            __CODE "U<",2,"_ult"
            pop     {r0}
            pop     {r1}
            cmp     r1,r0
            mvnlo   r0,#0
            movhs   r0,#0
            pushr0

/* U>  (u1 u2 -- flag ) "u-greater" */
            __CODE "U>",2,"_ugt"
            pop     {r0}
            pop     {r1}
            cmp     r1,r0
            mvnhi   r0,#0
            movls   r0,#0
            pushr0

/*&DECIMAL ( -- )  "decimal" */
            __COLON "DECIMAL",7,"_decimal"
            .word   _plitp
            .word   10
            .word   _base
            .word   _store
            .word   _exit

/*&HEX ( -- ) "hex" */ 
            __COLON "HEX",3,"_hex"
            .word   _plitp
            .word   16
            .word   _base
            .word   _store
            .word   _exit

/*&OCTAL ( -- ) "octal" */ 
            __COLON "OCTAL",5,"_octal"
            .word   _plitp
            .word   8
            .word   _base
            .word   _store
            .word   _exit

/*WITHIN ( n1 min max -- f ) */
/*: WITHIN  OVER - >R - R> U< ; */
            __COLON "WITHIN",6,"_within"
            .word   _over
            .word   _minus
            .word   _tor
            .word   _minus
            .word   _rfrom
            .word   _ult
            .word   _exit

/*: BETWEEN   ( n1 min max -- f )  1+ WITHIN ; */
            __COLON "BETWEEN",7,"_between"
            .word   _1plus
            .word   _within
            .word   _exit

/*& ALIGN ( -- )   "align" */
/*: ALIGN HERE ALIGNED DP ! ;*/
            __COLON "ALIGN",5,"_align"
            .word   _here
            .word   _aligned
            .word   _dp
            .word   _store
            .word   _exit

/*&ALIGNED ( addr -- a-addr) "aligned" */
/* : ALIGNED DUP 3 AND IF 3 INVERT AND 4+ THEN ; */
            __COLON "ALIGNED",7,"_aligned"
            .word   _dup
            .word   _3
            .word   _and
            .word   _0branch
            .word   1f
            .word   _3
            .word   _invert
            .word   _and
            .word   _4plus
1:          .word   _exit

/* HALIGN ( -- )   "halfword-align" */
/*: HALIGN HERE HALIGNED DP ! ;*/
            __COLON "HALIGN",6,"_halign"
            .word   _here
            .word   _haligned
            .word   _dp
            .word   _store
            .word   _exit

/* HALIGNED ( addr -- ah-addr) "halfwod-aligned" */
/* : HALIGNED DUP 1 AND IF 1 INVERT AND 2+ THEN ; */
            __COLON "HALIGNED",8,"_haligned"
            .word   _dup
            .word   _1
            .word   _and
            .word   _0branch
            .word   1f
            .word   _1
            .word   _invert
            .word   _and
            .word   _2plus
1:          .word   _exit

/*&ALLOT ( n -- )  "allot" */
            __COLON "ALLOT",5,"_allot"
            .word   _dp 
            .word   _plusstore
            .word   _exit
/*PLUM ( addr -- a-addr )  align to upper boundry */
/*: PLUM  DUP 3 AND IF 4- THEN ALIGNED ; */
            __COLON "PLUM",4,"_plum"
            .word   _dup
            .word   _3
            .word   _and
            .word   _0branch
            .word   1f
            .word   _4minus
1:          .word   _aligned
            .word   _exit            

/* CHAR ( -- char )  "char" */ 
/*: CHAR BL WORD COUNT 1- ?MISSING C@ ; */
            __COLON "CHAR",4,"_char"
            .word   _bl 
            .word   _word 
            .word   _count
            .word   _1minus
            .word   _qmissing
            .word   _cfetch
            .word   _exit

/* CHAR+ ( c-addr -- c-addr ) "char-plus" */
            __CODE "CHAR+",5,"_charplus"
            pop     {r0}
            add     r0,#1
            pushr0

/* CHARS (n1 -- n2) "chars"*/
            __CODE "CHARS",5,"_chars"
            next

/*& # ( ud1 -- ud2)  "hash" "number sign" */
/* : #  BASE @ DUM/MOD ROT 9 OVER < 7 AND + [CHAR] 0 + HOLD ; */    
            __COLON "#",1,"_hash"
            .word   _base
            .word   _fetch
            .word   _dumslashmod
            .word   _rot
            .word   _plitp
            .word   9
            .word   _over
            .word   _lt
            .word   _plitp
            .word   7
            .word   _and
            .word   _plus
            .word   _plitp
            .word   '0'
            .word   _plus
            .word   _hold
            .word   _exit

/*& <# ( -- ) "less-than-hash"  */
/* : <# PAD HLD ! ;  */
            __COLON "<#",2,"_lthash"
            .word   _pad
            .word   _hld
            .word   _store
            .word   _exit


/*& #> ( xd -- c-addr u ) "number-sign-greater" */
/* : #> 2DROP HLD @ PAD OVER - ;  */
            __COLON "#>",2,"_hashgt"
            .word   _2drop
            .word   _hld
            .word   _fetch
            .word   _pad
            .word   _over
            .word   _minus
            .word   _exit

/*& #S ( ud1 -- ud2 ) "number-sign-s"  */
/* : #S  BEGIN # 2DUP OR 0= UNTIL ;  */
            __COLON "#S",2,"_hashs"
1:          .word   _hash
            .word   _2dup
            .word   _or
            .word   _0equ
            .word   _0branch
            .word   1b
            .word   _exit

/*& HOLD ( char -- )  "hold" */
/* : HOLD -1 HLD +!  HLD @ C! ;  */
            __COLON "HOLD",4,"_hold"
            .word   _minus1
            .word   _hld
            .word   _plusstore
            .word   _hld
            .word   _fetch
            .word   _cstore
            .word   _exit

/*& SIGN  ( n -- ) "sign"  */
/* : SIGN 0< IF [CHAR] - HOLD THEN ;  */
            __COLON "SIGN",4,"_sign"
            .word   _0lt
            .word   _0branch
            .word   1f
            .word   _plitp
            .word   '-'
            .word   _hold
1:          .word   _exit

/*&SPACE (--)*/
/*: SPACE BL EMIT ; */
            __COLON "SPACE",5,"_space"
            .word   _bl
            .word   _emit
            .word   _exit

/*&SPACES ( u -- ) */
/*: SPACES 0 ?DO BL EMIT LOOP THEN ; */
            __COLON "SPACES",6,"_spaces"
            .word   _0
            .word   _pqdop
            .word   2f
1:          .word   _bl
            .word   _emit
            .word   _ploopp
            .word   1b
2:          .word   _unloop
            .word   _exit

/*&TYPE ( c-addr u -- )*/
/*: TYPE 0 ?DO COUNT EMIT LOOP DROP ; */
            __COLON "TYPE",4,"_type"
            .word   _0 
            .word   _pqdop
            .word   1f
2:          .word   _count 
            .word   _emit
            .word   _ploopp
            .word   2b
1:          .word   _unloop
            .word   _drop
            .word   _exit

/*& : (U.)  ( u -- a l )   0    <# #S #>   ; */
            __COLON "(U.)",4,"_pudotp"
            .word   _0
            .word   _lthash
            .word   _hashs
            .word   _hashgt
            .word   _exit

/*U. ( u -- ) "u-dot" */
/*& : U.    ( u -- )       (U.)   TYPE SPACE   ; */
            __COLON "U.",2,"_udot"
            .word   _pudotp
            .word   _type
            .word   _space
            .word   _exit

/*: SPACETYPE ( addr cnt l -- ) */
            __COLON "SPACETYPE",9,"_spacetype"
            .word   _over
            .word   _minus
            .word   _dup
            .word   _0gt
            .word   _0branch
            .word   1f
            .word   _spaces
            .word   _branch
            .word   2f
1:          .word   _drop
2:          .word   _type
            .word   _exit

/* : U.R   ( u l -- )   >R  (U.)  R> SPACETYPE ( OVER - DUP 0> 
            IF SPACES ELSE DROP THEN TYPE ) ; */
            __COLON "U.R",3,"_udotr"
            .word   _tor
            .word   _pudotp
            .word   _rfrom
            .word   _spacetype
            .word   _exit

/*Test U.R */
            __COLON "UU.R",4,"_uudotr"
            .word   _4
            .word   _1
            .word   _udotr
            .word   _4
            .word   _1
            .word   _udotr
            .word   _4
            .word   _1
            .word   _udotr
            .word   _4
            .word   _1
            .word   _udotr
            .word   _exit



/*: .R    ( n l -- )  >R  (.)  R> SPACETYPE ( OVER - DUP 0>
        IF SPACES ELSE DROP THEN  TYPE ) ; */
            __COLON ".R",2,"_dotr"
            .word   _tor
            .word   _pdotp
            .word   _rfrom
            .word   _spacetype
            .word   _exit

/*: (DU.) ( ud -- a l ) <# #S #> ; */
            __COLON "(DU.)",5,"_pdudotp"
            .word   _lthash
            .word   _hashs
            .word   _hashgt
            .word   _exit

/*: DU. ( ud -- ) (DU.) TYPE SPACE ; */
            __COLON "DU.",3,"_dudot"
            .word   _pdudotp
            .word   _type
            .word   _space
            .word   _exit

/*: DU.R ( ud l -- ) >R (DU.) R>  SPACETYPE ( OVER - DUP 0>  
        IF SPACES ELSE DROP THEN TYPE ) ;  */
            __COLON "DU.R",4,"_dudotr"
            .word   _tor
            .word   _pdudotp
            .word   _rfrom
            .word   _spacetype
            .word   _exit

/*&: (D.) ( d -- a l ) TUCK DABS <# #S ROT SIGN #> ;  */
            __COLON "(D.)",4,"_pddotp"
            .word   _tuck
            .word   _dabs
            .word   _lthash
            .word   _hashs
            .word   _rot
            .word   _sign
            .word   _hashgt
            .word   _exit

/*&: D. ( d -- ) (D.) TYPE SPACE ;  */
            __COLON "D.",2,"_ddot"
            .word   _pddotp
            .word   _type
            .word   _space
            .word   _exit

/*: D.R ( d l -- ) >R (D.) R> SPACETYPE ( OVER - DUP 0>
        IF SPACES ELSE DROP THEN TYPE ) ;*/
            __COLON "D.R",3,"_ddotr"
            .word   _tor
            .word   _pddotp
            .word   _rfrom
            .word   _spacetype
            .word   _exit

/* ( ("ccc,<paren>" -- )  "paren"  */
/*: ( [CHAR] ) PARSE-CHAR    2DROP ; IMMEDIATE */
            __COLON "(",1,"_paren",immediate
            .word   _plitp
            .word   ')'
            .word   _parsechar
            .word   _2drop
            .word   _exit

/*& . ( n -- )  "dot"  */
/* : . (.)  TYPE SPACE  ;  */
            __COLON ".",1,"_dot"
            .word   _pdotp
            .word   _type
            .word   _space
            .word   _exit

/* ." (C:"ccc<quote>" -- )  RT: ( -- ) */
/* : ." POSTPONE (.") ," ; IMMEDIATE */
            __CODE ".\"",2,"_dotquote",immediate
            .word   _plitp
            .word   _pdotqp
            .word   _comma
            .word   _commaquote
            .word   _exit

/* : (.)   ( n -- a l )   DUP ABS 0   <# #S   ROT SIGN   #>   ; */
            __COLON "(.)",3,"_pdotp"
            .word   _dup
            .word   _abs
            .word   _0
            .word   _lthash
            .word   _hashs
            .word   _rot
            .word   _sign
            .word   _hashgt
            .word   _exit

/* : (.")   ( -- )   R> COUNT 2DUP + ALIGNED >R   TYPE   ; */
            __COLON "(.\")",4,"_pdotqp"
            .word   _rfrom
            .word   _count
            .word   _2dup
            .word   _plus
            .word   _aligned
            .word   _tor
            .word   _type
            .word   _exit

/* : ,"   ( -- )
      [CHAR] " PARSE  TUCK HERE PLACE  1+ ALLOT ALIGN  ; */
            __COLON ",\"",2,"_commaquote"
            .word   _plitp
            .word   34
            .word   _parse
            .word   _tuck
            .word   _here
            .word   _place
            .word   _1plus
            .word   _allot
            .word   _align
            .word   _exit

/* : ."   ( -- )   POSTPONE (.")   ,"   ;   IMMEDIATE */
            __COLON ".\"",2,"_dotq",immediate
            .word   _plitp
            .word   _pdotqp
            .word   _comma
            .word   _commaquote
            .word   _exit

/* : "    ( -- )    STATE @
   IF            POSTPONE (")    ,"
   ELSE ASCII " PARSE PAD PLACE PAD COUNT THEN ; IMMEDIATE */
            __COLON "\"",1,"_q",immediate
            .word   _state
            .word   _fetch
            .word   _0branch
            .word   1f
            .word   _plitp
            .word   _pqp
            .word   _comma
            .word   _commaquote
            .word   _branch
            .word   2f
1:          .word   _plitp
            .word   34
            .word   _parse
            .word   _pad
            .word   _place
            .word   _pad
            .word   _count
2:          .word   _exit

/* : (")    ( -- addr len )   R> COUNT 2DUP + ALIGNED >R  ; */
            __COLON "(\")",3,"_pqp"
            .word   _rfrom
            .word   _count
            .word   _2dup
            .word   _plus
            .word   _aligned
            .word   _tor
            .word   _exit

/* : (C")    ( -- addr )   R> DUP COUNT + ALIGNED >R  ; */
            __COLON "(C\")",4,"_pcqp"
            .word   _rfrom
            .word   _dup
            .word   _count
            .word   _plus
            .word   _aligned
            .word   _tor
            .word   _exit

/* : ,"   ( -- )
      [CHAR] " PARSE  TUCK HERE PLACE  1+ ALLOT ALIGN  ; */
            __COLON ",\"",2,"_commaq"
            .word   _plitp
            .word   34
            .word   _parse
            .word   _tuck
            .word   _here
            .word   _place
            .word   _1plus
            .word   _allot
            .word   _align
            .word   _exit

/* : THENIF  ABS 2 ?PAIRS POSTPONE ?BRANCH >MARKS 2 ; IMMEDIATE */
            __COLON "THENIF",6,"_thenif",immediate
            .word   _abs
            .word   _2
            .word   _qpairs
            .word   _plitp
            .word   _0branch
            .word   _comma
            .word   _tomarks
            .word   _2
            .word   _exit


/* : IF      0 0 2 POSTPONE THENIF ; IMMEDIATE */
            __COLON "IF",2,"_if",immediate
            .word   _0
            .word   _0
            .word   _2
            .word   _thenif
            .word   _exit

/*ELSE (C:org1 -- org2) "else" */
/* : ELSE   ABS 2 ?PAIRS SWAP POSTPONE BRANCH >MARKS
       SWAP >RESOLVES 0 -2 ; IMMEDIATE */
            __COLON "ELSE",4,"_else",immediate
            .word   _abs
            .word   _2
            .word   _qpairs
            .word   _swap
            .word   _plitp
            .word   _branch
            .word   _comma
            .word   _tomarks
            .word   _swap
            .word   _toresolves
            .word   _0
            .word   _minus2
            .word   _exit

/*THEN ( -- )*/
/* : THEN    ABS 2 ?PAIRS >RESOLVES >RESOLVES  ;  IMMEDIATE */
            __COLON "THEN",4,"_then",immediate
            .word   _abs
            .word   _2
            .word   _qpairs
            .word   _toresolves
            .word   _toresolves
            .word   _exit

/* BEGIN     "begin" */
/* : BEGIN    <MARKS  1  ;  IMMEDIATE */
            __COLON "BEGIN",5,"_begin",immediate
            .word   _ltmarks
            .word   _1
            .word   _exit


/* : WHILE   ABS DUP 2- ABS 1 ?PAIRS POSTPONE ?BRANCH >EXIT @
          >MARKS  >EXIT !   NEGATE ; IMMEDIATE */
            __COLON "WHILE",5,"_while",immediate
            .word   _abs
            .word   _dup
            .word   _2minus
            .word   _abs
            .word   _1
            .word   _qpairs
            .word   _plitp
            .word   _0branch
            .word   _comma
            .word   _toexit
            .word   _fetch
            .word   _tomarks
            .word   _toexit
            .word   _store
            .word   _negate
            .word   _exit
/*UNTIL ( flag -- ) "until" */
/* : UNTIL   DUP ABS 1 ?PAIRS POSTPONE ?BRANCH <RESOLVE> ; IMMEDIATE */
            __COLON "UNTIL",5,"_until",immediate
            .word   _dup
            .word   _abs
            .word   _1
            .word   _qpairs
            .word   _plitp
            .word   _0branch
            .word   _comma
            .word   _ltresolvegt
            .word   _exit

/* : REPEAT  ABS 1 ?PAIRS POSTPONE BRANCH <RESOLVES ; IMMEDIATE */
            __COLON "REPEAT",6,"_repeat",immediate
            .word   _abs
            .word   _1
            .word   _qpairs
            .word   _plitp
            .word   _branch
            .word   _comma
            .word   _ltresolves
            .word   _exit

/*AGAIN ( -- ) */
/* : AGAIN   POSTPONE   REPEAT  ;  IMMEDIATE */
            __COLON "AGAIN",5,"_again",immediate
            .word   _repeat
            .word   _exit

/* +LOOP (C: do-sys -- )  "plus-loop" */
/*: +LOOP DUP ABS 3 ?PAIRS POSTPONE (+LOOP) 
    <RESOLVE> POSTPONE UNLOOP ; IMMEDIATE */
            __COLON "+LOOP",5,"_ploop",immediate
            .word   _dup
            .word   _abs 
            .word   _3
            .word   _qpairs
            .word   _plitp
            .word   _pplusloopp
            .word   _comma
            .word   _ltresolvegt
            .word   _plitp
            .word   _unloop
            .word   _comma
            .word   _exit

/*DO  (index limit -- )  "do" */
/*: DO      POSTPONE (DO)  <MARKS   3    ;  IMMEDIATE */
            __COLON "DO",2,"_do",immediate
            .word   _plitp
            .word   _pdop
            .word   _comma
            .word   _ltmarks
            .word   _3
            .word   _exit

/* : LOOP    DUP ABS 3 ?PAIRS POSTPONE (LOOP)
          <RESOLVE>  POSTPONE UNLOOP ; IMMEDIATE */
            __COLON "LOOP",4,"_loop",immediate
            .word   _dup
            .word   _abs
            .word   _3
            .word   _qpairs
            .word   _plitp
            .word   _ploopp
            .word   _comma
            .word   _ltresolvegt
            .word   _plitp
            .word   _unloop
            .word   _comma
            .word   _exit

/*?DO RT:( n1|u1 n2|u2 --  )(R: -- l1 l2) "question-do" */
/*: ?DO     POSTPONE (?DO) >EXIT @ 0 >MARKS
          >EXIT ! HERE  3 ;  IMMEDIATE */
            __COLON "?DO",3,"_qdo",immediate
            .word   _plitp
            .word   _pqdop
            .word   _comma
            .word   _toexit
            .word   _fetch
            .word   _0
            .word   _tomarks
            .word   _toexit
            .word   _store
            .word   _here
            .word   _3
            .word   _exit

/*&(LOOP) ( -- ) */
            __CODE "(LOOP)",6,"_ploopp",compile_only
            mov     r1,#1
_ploop1:    ldr     r0,[rsp]
            adds    r0,r1
            str     r0,[rsp]
            ldrvc   ip,[ip]
            addvs   ip,#4
            b       _next


/*(+LOOP) (n -- ) */
            __CODE "(+LOOP)",7,"_pplusloopp",compile_only
            pop     {r1}
            b       _ploop1

/*&UNLOOP*/
            __CODE "UNLOOP",6,"_unloop"
            add     rsp,#8
            next

/*(?LEAVE)*/
            __CODE "(?LEAVE)",8,"_pqleavep",compile_only
            pop     {r0}
            teq     r0,#0
            ldrne   ip,[ip]
            addeq   ip,#4
            b       _next

/* : ?LEAVE   POSTPONE (?LEAVE) >EXIT @ >MARKS >EXIT !   ;  IMMEDIATE */
            __COLON "?LEAVE",6,"_qleave",immediate
            .word   _plitp
            .word   _pqleavep
            .word   _comma
            .word   _toexit
            .word   _fetch
            .word   _tomarks
            .word   _toexit
            .word   _store
            .word   _exit

/* : LEAVE   POSTPONE BRANCH >EXIT @ >MARKS >EXIT !   ;  IMMEDIATE */
            __COLON "LEAVE",5,"_leave",immediate
            .word   _plitp
            .word   _branch
            .word   _comma
            .word   _toexit
            .word   _fetch
            .word   _tomarks
            .word   _toexit
            .word   _store
            .word   _exit


/*& (DO) (l i -- ) */
            __CODE "(DO)",4,"_pdop",compile_only
            pop     {r0}
            pop     {r1}
_pdo1:      add     r1,#0x80000000
            pushr   r1,rsp
            sub     r0,r1
            pushr   r0,rsp
            next

/* (?DO) (l i -- ) */
            __CODE "(?DO)",5,"_pqdop",compile_only
            pop     {r0}
            pop     {r1}
            cmp     r0,r1
            beq     1f
            add     ip,#4
            b       _pdo1
1:          ldr     ip,[ip]
            add     ip,#4
            next

/*&0BRANCH  branch if 0 ( flag -- ) */
            __CODE "0BRANCH",7,"_0branch",compile_only
            pop     {r0}
            teq     r0,#0
            addne   ip,#4  
            ldreq   ip,[ip]
            next

/*&BRANCH  branch ( -- ) */
            __CODE "BRANCH",6,"_branch",compile_only
$_branch:   ldr     ip,[ip]  @ $
            next

/*&I ( -- n|u ) */
            __CODE "I",1,"_i"
            ldr     r0,[rsp]
            ldr     r1,[rsp,#4]
            add     r0,r1
            pushr0

/*J ( -- n)*/
            __CODE "J",1,"_j"
            ldr     r0,[rsp,#8]
            ldr     r1,[rsp,#12]
            add     r0,r1
            pushr0

/*K ( -- n)*/
            __CODE "K",1,"_k"
            ldr     r0,[rsp,#16]
            ldr     r1,[rsp,#20]
            add     r0,r1
            pushr0


/* DOES>  ( )  "does"  */
/* : DOES>   ( -- )   POSTPONE (;CODE)   0xEB000000 (BL) 
  [ DODOES ] LITERAL   HERE 4+ - DUP ABS 0xFE000000  AND
ABORT" Out of range of dodoes"  + ,   ; IMMEDIATE */
            __COLON "DOES>",5,"_doesgt",immediate
            .word   _plitp
            .word   _psccodep
            .word   _comma
            .word   _plitp
            .word   _dodoes
            .word   _here
            .word   _4plus
            .word   _minus
            .word   _dup
            .word   _abs
            .word   _plitp
            .word   0xFE000000
            .word   _and
            .word   _pabortqp;.byte 22;.ascii "Out of range of dodoes";.align 2
2:          .word   _plitp
            .word   _4slash
            .word   0xEB000000
            .word   _plus
            .word   _comma
            .word   _exit

/*EXIT  ( -- )  "exit"  _exit */
/*: EXIT R> DROP ; */
            __CODE "EXIT",4,"_exit"
            b  _unnest

/* : (;CODE)     ( -- )   R>    LAST @ NAME>  !  ; */
            __COLON "(;CODE)",7,"_psccodep"
            .word   _rfrom
            .word   _last
            .word   _fetch
            .word   _namefrom
            .word   _store
            .word   _exit

/* : ;CODE       ( -- )   ?CSP   POSTPONE  (;CODE)
    R> DROP   ASSEMBLER   ; IMMEDIATE 
            __COLON ";CODE",5,"_sccode",immediate
            .word   _qcsp
            .word   _plitp
            .word   _psccodep
            .word   _comma
            .word   _rfrom
            .word   _drop
            .word   _assembler
            .word   _exit
*/

/*NOOP*/
            __CODE "NOOP",4,"_noop"
            next

/* : WORDS ( -- )
  CONTEXT @ @
    BEGIN @ DUP WHILE DUP
       LINK> 8 .R SPACE DUP L>NAME .ID 23 TAB #OUT @ 94 >
       IF CR THEN KEY? ?LEAVE
    REPEAT DROP ;  */
            __COLON "WORDS",5,"_words"
            .word   _base
            .word   _fetch
            .word   _tor
            .word   _hex
            .word   _context
            .word   _fetch
            .word   _fetch
3:          .word   _fetch
            .word   _dup
            .word   _0branch
            .word   2f
            .word   _dup
            .word   _linkfrom
            .word   _plitp
            .word   6
            .word   _dotr
            .word   _space
            .word   _dup
            .word   _ltoname
            .word   _dotid
            .word   _plitp
            .word   23
            .word   _tab
            .word   _nout
            .word   _fetch
            .word   _plitp
            .word   94
            .word   _gt
            .word   _0branch
            .word   5f
            .word   _cr
5:          .word   _keyq
            .word   _pqleavep
            .word   2f
            .word   _branch
            .word   3b
2:          .word   _drop
            .word   _rfrom
            .word   _base
            .word   _store
            .word   _exit

/* TAB ( n -- ) #OUT @ OVER MOD - SPACES ; */
            __COLON "TAB",3,"_tab"
            .word   _nout
            .word   _fetch
            .word   _over
            .word   _mod
            .word   _minus
            .word   _spaces
            .word   _exit

/****************************************************************************
*       GPIO  executing Alex Chadwick programs interactively 
****************************************************************************/
/****** GetGpioAddress  ( -- addr ) ***/
            __CODE "GETGPIOADDRESS",14,"_getgpioaddress"
            bl      GetGpioAddress
            pushr0
/****** SetGpioFunction  ( gpioRegister function -- )  */
            __CODE  "SETGPIOFUNCTION",15,"_setgpiofunction"
            pop     {r1}
            pop     {r0}
            bl      SetGpioFunction
            next
/****** SetGpio   ( gpioreg value -- )  ***/ 
            __CODE "SETGPIO",7,"_setgpio"
            pop     {r1}
            pop     {r0}
            bl      SetGpio
            next
/****** SetPin  ( 1|0 pin -- )   ***/
            __CODE "SETPIN",6,"_setpin"
            ldr     r0,[sp]
            mov     r1,#1
            bl      SetGpioFunction
            pop     {r0}
            pop     {r1}
            bl      SetGpio
            next
/**********************************************************************/
@ .include    "sdmmc.s1"

/**********************************************************************/


/***************************************************************************/

.section .data

label numberString
    .rept 32
    .byte 0x20
    .endr

.align 2
label buf
    .rept 80
    .byte 0x20
    .endr


label kbleds
            .byte 0x80
.align 2
.section .text


/* test section preset and execute */
            __CODE "end",3,"_end"
            b       onward

label _testx
            .word   _0
            .word   _nout
            .word   _store
            .word   _execute
            .word   _space
            .word   _plitp
            .word   0x5B
            .word   _emit
            .word   _dots
            .word   _plitp
            .word   0x5D
            .word   _emit
            .word   _end


/*  BUFFER ( -- addr )*/
            __CODE "BUFFER",6,"_buffer"
            ldr     r0,$buf
            pushr0
$buf:       .word   buf

label _bufferx
            .word   _buffer
            .word   _numberq
            .word   _0equ
            .word   _0branch
            .word   1f
            .word   _2drop
1:          .word   _end
        

            __COLON "START",5,"_startt"
label coldstart
            .word   _sp0
            .word   _fetch
            .word   _spstore
            .word   _rp0
            .word   _fetch
            .word   _rpstore
            .word   _forth
            .word   _definitions
            .word   _message          
            .word   _quit
            .word   _end

/*** start up message ***/
            __COLON "MESSAGE",7,"_message"
            .word   _pdotqp
            .byte   26
            .ascii  "Welcome to my Forth system"
            .align  2
            .word   _cr            
            .word   _pdotqp
            .byte   51
            .ascii  "See link at www.forth.com/starting-forth/index.html"
            .align  2
            .word   _cr
            .word   _pdotqp
            .byte   40
            .ascii  "See also lars.nocrew.org/dpans/dpans.htm"
            .align  2
            .word   _cr
            .word   _pdotqp
            .byte   13
            .ascii  "Type in WORDS"
            .align  2
            .word   _cr
            .word   _pdotqp
            .byte   28
            .ascii  "Type : HW .\" HELLO WORLD\" ; "
            .align  2
            .word   _cr
            .word   _pdotqp
            .byte   14
            .ascii  "Now type in HW"
            .align  2
            .word   _cr
            .word   _pdotqp
            .byte   39
            .ascii  "Check this out type> HEX 10000 200 DUMP"
            .align  2
            .word   _cr
            .word   _exit
            exitforth

.section    .data

.root:      .word   rootlink
.forth:     .word   forthlink
.editor:    .word   editorlink
.files:     .word   fileslink
.assembler: .word   assemblerlink


label   LINK
            .word  link

.align  2


.torom:     .skip mem_sz/2,0xFF
@            .bss
@            .lcomm  .torom,mem_sz/2
.toram:     .skip mem_sz/2,0xFF
@            .bss
@            .lcomm  .toram,mem_sz/2
_memend:

.end

