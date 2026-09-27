.file "add_without_atoi.s"
.section	.rodata
.LC0:
	.string "%ld\n"

.text
.globl main
.type main, @function

main:
	# check if argc == 3
	cmpl 	$3, %edi
	je .L1
	movl	$1, %eax #return code 1
	ret


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
	call 	batoi
	movq	%rax, -16(%rbp)  # moving return integer into r12w

	# atoi is allowed to do whatever it wants with any of the registers rdi, rsi, rdx and rcx, rax, r8 and r9 according to the SYSTEM V AMD64 ABI	
	movq 	-8(%rbp), %rdi	# dereference second argument into rdi
	movq 	(%rdi), %rdi

	#call 	atoi@PLT		# using atoi for now
	call 	batoi
	addq	%rax, -16(%rbp) # adding ret to edx

	leaq	.LC0(%rip), %rdi # first argument of printf, "%d\n"
	movq	-16(%rbp), %rsi # second argument of printf, ret integer
    xorl 	%eax, %eax		# AL = 0 for printf ABI requirement
	call 	printf@PLT
	
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

	.size main, .-main
	.globl batoi
	.type batoi, @function
batoi:
	# %rdi = char*

	# will store local variables in the callee-owned registers: rax, rcx, rdx, rsi, rdi, r8, r9, r10, r11 registers



	movq $0, %rax		# int64_t ret = 0;
	movq $1, %r8 		# int8_t sign = 1;
	movb $0, %ch 		# uint8_t count = 0;
	movb $0, %dl 		# uint8_t str_len = 0;
	
	# // set sign multiplier to -1 if str starts with '-'
	cmpb $45, (%rdi)	# if (*str == 45) {
	jne .LB0
	movq $-1, %r8   	# 	sign = -1;
	addq $1, %rdi   	# 	str += sizeof(char);
.LB0: # }

	# // finding str_len
.LB1:
	cmpb $0, (%rdi) 	# while (*str != '\0') {
	je .LB2
	addb $1, %dl    	# 	str_len++;
	addq $1, %rdi   	# 	str += sizeof(char);
	jmp .LB1

.LB2: # }

	subq $1, %rdi  	# str -= sizeof(char);

	# // int64 max is 9223372036854775807 = 19 chars, beware that if '9' * 19 is inserted it will not return -1 but overflow ret.

	cmpb $19, %dl		# if (str_len > 19) return 0;
	ja .LBERR
	
.LB3:
	cmpb %dl, %ch		# while (count < str_len) {
	jae .LBE
	
	cmpb $48, (%rdi)	# 	if (*str < 48 || *str > 57) return 0; // incorrect string check (48 = '0', 45 = '9')
	jb .LBERR
	cmpb $57, (%rdi)
	ja .LBERR

	movb (%rdi), %cl	# 	int64_t add = sign * (*str - 48);
	subb $48, %cl
	movq $0, %rsi
	movb %cl, %sil
	imulq %r8, %rsi		# LIKELY WILL FAIL HERE, TRY SWITCHING

	movb $0, %dh		# 	for (uint8_t i = 0; i < count; i++) { add *= 10; } //Simple 10**count

.LB4:
	cmp %ch, %dh
	jae .LB5
	imulq $10, %rsi
	addb $1, %dh
	jmp .LB4
	

.LB5:
	addq %rsi, %rax		# 	ret += add;
	addb $1, %ch		# 	count++;
	subq $1, %rdi		# 	str -= sizeof(char);
	jmp .LB3			# }

.LBE:
	ret

.LBERR: # error, return 0
	movq $0, %rax
	ret




