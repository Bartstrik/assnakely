	.file	"add.c"
	.text
	.section	.rodata
.LC0:
	.string	"%d\n"
	.text
	.globl	main
	.type	main, @function
main:
.LFB6:
	.cfi_startproc

	# the stack starts of containing only the return address. at one word higher than rsp.
	# then rbp is pushed to the stack, meaning rsp is decremented by the size of rbp (8-bytes), and the memory at [rsp] is set to equal the rbp pointer
	# then the value of rsp is copied to rbp so that rbp stores the old rbp value of the parent caller. 
	# then 32 is subtracted from the stack pointer to make place for the local variables, in this case the input arguments argc = 4bytes, argv* = 8bytes and ret value = 4bytes
	# I dont really understand why but the compiler decided to add 32 bytes to ensure stack size allignment, which should be doable aswell with 16 bytes...
	
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	subq	$32, %rsp
	movl	%edi, -20(%rbp) #argc 32bit int so rbp - 20 to rbp -24
	movq	%rsi, -32(%rbp) #argv* 64bit p so rbp - 32 

	# memory layout after previous part 
	# 
	#		 		+------------------------------+
	#		 		| return address			   |
	# rbp 	    ->	| old rbp 					   |
	# -4(%rbp)  -> 	| ret   4bytes upto -1(%rbp)   |
	# -16(%rbp) ->  | padding					   |
	# -20(%rbp) ->  | argc  4bytes upto -17(%rbp)  |
	# -32(%rbp) ->  | argv** 8bytes upto -25(%rbp)  |
	# rsp = -32(%rbp) (row above)				   |
	#		 		+------------------------------+

	cmpl	$3, -20(%rbp)
	je	.L2
	movl	$1, %eax
	jmp	.L3
.L2:
	movq	-32(%rbp), %rax # copy argv** to rax register 
	addq	$8, %rax		# add 8 to the argv**, to move to index 1 of argv which should contain the first argument
	movq	(%rax), %rax    # dereference the pointer, to get the pointer to the first input argument string 
	movq	%rax, %rdi		# move into rdi, which is the first argument register for the function
	call	atoi@PLT
	movl	%eax, -4(%rbp)	# move the result to the stack at ret (see above
	movq	-32(%rbp), %rax	# same as before but now with the second input variable
	addq	$16, %rax
	movq	(%rax), %rax
	movq	%rax, %rdi
	call	atoi@PLT
	addl	%eax, -4(%rbp)	# add to ret
	movl	-4(%rbp), %eax	# move ret to eax register (useless)
	leaq	.LC0(%rip), %rdx# move the address of the string into rdx (useless)
	movl	%eax, %esi		# move ret into esi (second argument)
	movq	%rdx, %rdi		# move the address of the string int rdi (first argument)
	movl	$0, %eax		# set eax to 0 (necessary)
	call	printf@PLT		# call printf
	movl	$0, %eax		# (useless)
.L3:
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE6:
	.size	main, .-main
	.ident	"GCC: (GNU) 16.2.1 20260810"
	.section	.note.GNU-stack,"",@progbits
