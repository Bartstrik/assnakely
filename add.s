.file "add_with_stack.s"
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
	ret

.Latoi:
# expects the char* to be in rdi


.L1:
	# allocate memory [8 bytes for ret, 8 bytes for the pointer argv*[1] and 8 for 16-bit allignment]
	pushq %rbp	
	movq %rsp, %rbp
	subq $16, %rsp

	leaq 8(%rsi), %rdi 
	movq %rdi, -8(%rbp) #-8(%rsp) contains argv*[1]
	addq $8, %rdi

	# algo
	movq 	(%rdi), %rdi	# dereference second argument
	
# call 	atoi@PLT		# using atoi for now
	movl	%eax, -16(%rbp)  # moving return integer into r12w

	# atoi is allowed to do whatever it wants with any of the registers rdi, rsi, rdx and rcx, rax, r8 and r9 according to the SYSTEM V AMD64 ABI	
	movq 	-8(%rbp), %rdi	# dereference second argument into rdi
	movq 	(%rdi), %rdi
	call 	atoi@PLT		# using atoi for now
	addl	%eax, -16(%rbp) # adding ret to edx

	leaq	.LC0(%rip), %rdi # first argument of printf, "%d\n"
	movl	-16(%rbp), %esi # second argument of printf, ret integer
    xorl %eax, %eax		# AL = 0 for printf ABI requirement
	call printf@PLT
	
	# sys_write (not possible until I convert to string
# 	movq 	$1, %rax
#	movq	$1, %rdi
#	leaq	-48(%rbp), %rsi
#	syscall
	
	# return value
	movq	$0,  %rdi
.Lexit:
	# return 0
	movl    $0, %eax
	leave
	ret
