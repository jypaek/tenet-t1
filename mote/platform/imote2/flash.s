@@@@@@@@@@@@@@@@@@@@@@@@@
@ Author:		Josh Herbach
@ Revision:	1.0
@ Date:		09/02/2005
@
@ Modified by: Robbie Adler and Junaith Ahemed
@ Modified Date: Feb 13, 2007
@ Modification Overview:
@	1. Cleaned up the code and reduced redundant flash read instructions.
@	2. To clear the status register the command can be written to any valid flash address,
@	but since the first 1MB is cached in the current tree, writing to an address in that
@	area causes data cache issues which leads to data aborts. The clear status is issued
@	to the address that is passed in to the commands, which will fall in the non cached
@	area of flash.
@@@@@@@@@@@@@@@@@@@@@@@@@@

.macro CPWAIT  Rd
        MRC     P15, 0, \Rd, C2, C0, 0       @ arbitrary read of CP15 into register Rd
        MOV     \Rd, \Rd                     @ wait for it (foward dependency)
        SUB     PC, PC, #4                   @ branch to next instruction
.endm	

	.equ FLASH_READARRAY,(0x00FF)
	.equ FLASH_CFIQUERY,(0x0098)
	.equ FLASH_READSTATUS,(0x0070)
	.equ FLASH_CLEARSTATUS,(0x0050)
	.equ FLASH_PROGRAMWORD,(0x0040)
	.equ FLASH_PROGRAMBUFFER,(0x00E8)
	.equ FLASH_ERASEBLOCK,(0x0020)
	.equ FLASH_DLOCKBLOCK,(0x0060)
	.equ FLASH_PROGRAMBUFFERCONF,(0x00D0)
	.equ FLASH_LOCKCONF,(0x0001)
	.equ FLASH_UNLOCKCONF,(0x00D0)
	.equ FLASH_ERASECONF,(0x00D0)
	.equ FLASH_SUSPEND,(0x00B0)
	.equ FLASH_SUS_RESUME,(0x00D0)
	.equ FLASH_OP_NOT_SUPPORTED,(0x10)


	.global __Flash_Erase
	.global __GetEraseStatus
	.global __EraseFlashSpin
	.global __Flash_Program_Word
	.global __Flash_Program_Buffer
	.global __Flash_Erase_true_end
	.global __Flash_Program_Word_true_end
	.global __Flash_Program_Buffer_true_end

	.global __Flash_Suspend
	.global __Flash_Suspend_Resume

@@@@@@@@@@@@@@@@@@@@
@ The function sets up a particular block for erasing and returns,
@ the status check could be done using GetEraseStatus or EraseFlashSpin.
@@@@@@@@@@@@@@@@@@@@
__Flash_Erase:
.func __Flash_Erase @r0 (return) = status
		    @r0 = addr (move to r1)
					
	STMFD R13!, {R1, R5, LR} @I'm being conservative and saving registers R1-R3 which might not be necessary with function calls
	mov r1,r0
	ldr r5,=FLASH_CLEARSTATUS
	strh r5,[r1]				@Clear Status register
	ldr r5,=FLASH_ERASEBLOCK
	strh r5,[r1]				@Send EraseBlock command
	ldr r5,=FLASH_ERASECONF
	strh r5,[r1]				@Confirm Erase Block
    ldrh r0,[r1]
	LDMFD R13!, {R1, R5, PC}
.endfunc

@@@@@@@@@@@@@
@ Returns the current status of the Erase function and could be
@ used to get status for other commands.
@@@@@@@@@@@@@
__GetEraseStatus:
.func __GetEraseStatus @r0 (return) = status
			@r0 = addr (move to r1)
    
	STMFD R13!, {R1, LR}
	mov r1,r0
	ldrh r0,[r1]			@Read / return status
	LDMFD R13!, {R1, PC}
.endfunc
 
@@@@@@@@@@@@@@@@@@@@
@ The function loops around till the erase is completes.
@@@@@@@@@@@@@@@@@@@@
__EraseFlashSpin:
.func __EraseFlashSpin @r0 (return) = status
			@r0 = addr (move to r1)
					
	STMFD R13!, {R1, R5, LR}
	mov r1,r0
	__EraseSpin:
	ldrh r5,[r1]			@Read Block Status
	mov r0, r5				@save the status so that we don't have to reread (slow)
	and r5,r5,#0x80
	cmp r5,#0x0			@Check if Erase is complete
	beq __EraseSpin			@Spin if not complete
	ldr r5,=FLASH_READARRAY
	strh r5,[r1]			@Set Block back to normal read mode
	ldrh r5,[r1]
	LDMFD R13!, {R1, R5, PC}
	__Flash_Erase_true_end:
	nop;
.endfunc

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Writes a word to the flash and takes the address and word
@ to be written as parameter. The function blocks until the
@ word write is completed. 
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

__Flash_Program_Word:
.func __Flash_Program_Word	@r0 (return) = status
							@r0 (move to r1) = addr
							@r1 (move to r2) = dataword
							
	STMFD R13!, {R1 - R2, R5, LR} @I'm being conservative and saving registers R1-R3 which might not be necessary with function calls
	mov r2,r1
	mov r1,r0	
	ldr r5,=FLASH_CLEARSTATUS
	strh r5,[r1]				@Clear Status register
	ldr r5,=FLASH_PROGRAMWORD
	strh r5,[r1]				@Send Program Word Command
	strh r2,[r1]				@Write Word
	_goProgramWordSpin:
	ldrh r5,[r1]				@Read Block Status
	mov  r0, r5					@keep a copy of the status register so that we don't have to reread (slow)
	and r5,r5,#0x80
	cmp r5,#0x0					@Check if Write is complete
	beq _goProgramWordSpin		@Spin if not complete
	ldr r5,=FLASH_READARRAY
	strh r5,[r1]				@Set Block back to normal read mode
	ldrh r5,[r1]
	LDMFD R13!, {R1 - R2, R5, PC}
	__Flash_Program_Word_true_end:
	nop;
.endfunc

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ The function writes a 32 word buffer to the flash, the length of the buffer
@ together with the buffer and the physical address is taken in to account.
@ The user is responsible for the data in the buffer and should follow the
@ flash memory spec particularly if data buffer contains less than 32 words. 
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
__Flash_Program_Buffer:
.func __Flash_Program_Buffer	@r0 (return) = status
								@r0 (move to r1) = addr
								@r1 (move to r2) = datadata
								@r2 (move to r3) = datalen
					 
	STMFD R13!, {R1 - R5, LR} @I'm being conservative and saving registers R1-R3 which might not be necessary with function calls
	mov r3,r2
	mov r2,r1
	mov r1,r0
	ldr r4,=0x0						@r4 is our loop counter
	ldr r5,=FLASH_CLEARSTATUS
	strh r5,[r1]					@Clear Status register
	ldr r5,=FLASH_PROGRAMBUFFER
	strh r5,[r1]					@Send Program Buffer Command
	ldrh r5,[r1]					@Read Block Status
	and r5,r5,#0x80
	cmp r5,#0x0						@Check if Program Buffer works with this flash
	beq _goProgramBufferNS			@Program Buffer Not Supported, Jump

	strh r3, [r1]					@Send number of words to write
	_goProgramBufferLoop:
	ldrh r5, [r2,r4]				@Temporarily Store Word
	strh r5, [r1,r4]				@Write Word
	add r4,r4,#2					@Increment Counter
	cmp r4, r3, LSL #1				@Check if all words written
	ble _goProgramBufferLoop		@If all words written, continue
	ldr r5,=FLASH_PROGRAMBUFFERCONF	@Confirm Program Buffer
	strh r5,[r1]
	_goProgramBufferSpin:
	ldrh r5,[r1]					@Read Block Status
	mov r0, r5						@store the status so that we don't have to reread (slow)
	and r5,r5,#0x80
	cmp r5,#0x0				@Check if Write is complete
	beq _goProgramBufferSpin		@Spin if not complete
	b _goProgramBufferEnd
	_goProgramBufferNS:
	ldrh r0,=FLASH_OP_NOT_SUPPORTED		@Program Buffer is not supported
	mov r0,r0,LSL #1			@Return operation not supported
	_goProgramBufferEnd:
	ldr r5,=FLASH_READARRAY
	strh r5,[r1]				@Set Block back to normal read mode
	ldrh r5,[r1]
	LDMFD R13!, {R1 - R5, PC}
	__Flash_Program_Buffer_true_end:
	nop;
.endfunc

__Flash_Suspend:
.func __Flash_Suspend @r0 (return) = status
					@r0 = addr (move to r1) 
  STMFD R13!, {R1 - R2, LR}
  mov r1,r0
  ldr r2,=FLASH_SUSPEND
  strh r2,[r1]
_suspend_loop:
  ldrh r2,[r1]
  mov r0, r2			@store the status so that we don't have to reread(slow)
  and r2,r2,#0x80
  cmp r2,#0x0			@Check if Write is complete
  beq _suspend_loop		@Spin if not complete
  __Suspend_End:
  ldr r2,=FLASH_READARRAY
  strh r2,[r1]			@Set Block back to normal read mode
  ldrh r2,[r1]
  LDMFD R13!, {R1 - R2, PC}
  __Flash_Suspend_true_end:
  nop;
.endfunc
  

__Flash_Suspend_Resume:
.func __Flash_Suspend_Resume @r0 (return) = status
					@r0 = addr (move to r1) 
  STMFD R13!, {R1, R3, LR}
  mov r1,r0
  ldr r3,=FLASH_SUS_RESUME
  strh r3,[r1]
  ldr r3,=FLASH_READSTATUS
  strh r3,[r1]
  _resume_loop:
  ldrh r3,[r1]
  mov r0, r1			@save a copy so that we don't have to reread(slow)
  and r3,r3,#0x80
  cmp r3,#0x0			@Check if Write is complete
  beq _resume_loop		@Spin if not complete
  ldr r3,=FLASH_READARRAY
  strh r3,[r1]			@Set Block back to normal read mode
  ldrh r3,[r1]
  LDMFD R13!, {R1, R3, PC}
  __Flash_Suspend_Resumetrue_end:
  nop;
.endfunc

