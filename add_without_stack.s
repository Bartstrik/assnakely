.file "add.s"
.section	.rodata
.LC0:
	.string "%d\n"

.text
.globl main
.type main, @function

main:
	# check if argc == 3
	cmpl 	$3, %edi
	je .L1
	movl	$1, %eax #return code 1
	jmp	.Lexit

.L1:
	# this 16bit allignment is needed to ensure the stack is handled appropriately when exiting the main function.
	pushq %rbp
    movq %rsp, %rbp
    subq $8, %rsp

	# moving argv** into rbx which is safe from caller
	movq 	%rsi, %rbx

	# algo
	movq 	8(%rbx), %rdi	# dereference first argument into rdi
	call 	atoi@PLT		# using atoi for now
	movl	%eax, %r12d		# moving return integer into r12w

	# atoi is allowed to do whatever it wants with any of the registers rdi, rsi, rdx and rcx, rax, r8 and r9 according to the SYSTEM V AMD64 ABI	
	movq 	16(%rbx), %rdi	# dereference second argument into rdi
	call 	atoi@PLT		# using atoi for now
	addl	%eax, %r12d		# adding ret to edx

	# itoa is not a libc function -_-
	# movl	%edx, %edi		# first argument of itoa, integer
	# leaq	-56(%rbp), %rsi # second argument of itoa, char* buffer
	# call	itoa@PLT


	leaq	.LC0(%rip), %rdi # first argument of printf, "%d\n"
	movl	%r12d, %esi # second argument of printf, ret integer
    xorl %eax, %eax		# AL = 0 for printf ABI requirement
	call printf@PLT
	
	# sys_write
	#movq 	$1, %rax
	# movq	$1, %rdi
	# leaq	-48(%rbp), %rsi
	# syscall
	
	# return value
	movq	$0,  %rdi
.Lexit:
	ret
