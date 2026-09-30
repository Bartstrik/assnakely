.text
.globl main
.type main, @function

main:
	# check if argc == 3
	cmpl 	$3, %edi
	jne .Lmain_err

	# allocate memory [8 bytes for int64_t val, 8 bytes for the pointer argv*[1]]
	pushq %rbp	
	movq %rsp, %rbp
	subq $32, %rsp

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

	# using bitoa:
	movq -16(%rbp), %rdi
	leaq -32(%rbp), %rsi		# reusing allocated stack as the string buffer
	call bitoa

	# sys_write 
	movq %rax, %rsi			# put char* into second arg

	# finding str_len 
	movq $0, %rdx

.Lmain0:
	cmpb $0, (%rax)
	je .Lmain1
	addq $1, %rax
	addq $1, %rdx
	jmp .Lmain0

.Lmain1:
	addq $1, %rdx			# reuse the nullterminator as newline
	movb $10, (%rax)		# 13 = carriage return '\n'

 	movq 	$1, %rax		# sys_write
	movq	$1, %rdi		# 1 into first arg (stdout)
	syscall
	
.Lmain_ret:
	# sys_exit
	movq	$0,  %rdi		# return value
	movq	$60, %rax
	syscall

.Lmain_err:
	# sys_exit
	movq	$1,  %rdi		# return value
	movq	$60, %rax
	syscall

batoi:
	# %rdi = char*

	# will store local variables in the callee-owned registers: rax, rcx, rdx, rsi, rdi, r8, r9, r10, r11 registers

	movq $0, %rax		# int64_t ret = 0;
	movq $1, %r8 		# int8_t sign = 1;
	movb $0, %ch 		# uint8_t count = 0;
	movb $0, %dl 		# uint8_t str_len = 0;
	
	# // set sign multiplier to -1 if str starts with '-'
	cmpb $45, (%rdi)	# if (*str == 45) {
	jne .Lbatoi0
	movq $-1, %r8   	# 	sign = -1;
	addq $1, %rdi   	# 	str += sizeof(char);
.Lbatoi0: # }

	# // finding str_len
.Lbatoi1:
	cmpb $0, (%rdi) 	# while (*str != '\0') {
	je .Lbatoi2
	addb $1, %dl    	# 	str_len++;
	addq $1, %rdi   	# 	str += sizeof(char);
	jmp .Lbatoi1

.Lbatoi2: # }

	subq $1, %rdi  	# str -= sizeof(char);

	# // int64 max is 9223372036854775807 = 19 chars, beware that if '9' * 19 is inserted it will not return -1 but overflow ret.

	cmpb $19, %dl		# if (str_len > 19) return 0;
	ja .Lbatoi_err
	
.Lbatoi3:
	cmpb %dl, %ch		# while (count < str_len) {
	jae .Lbatoi_ret
	
	cmpb $48, (%rdi)	# 	if (*str < 48 || *str > 57) return 0; // incorrect string check (48 = '0', 45 = '9')
	jb .Lbatoi_err
	cmpb $57, (%rdi)
	ja .Lbatoi_err

	movb (%rdi), %cl	# 	int64_t add = sign * (*str - 48);
	subb $48, %cl
	movq $0, %rsi
	movb %cl, %sil
	imulq %r8, %rsi

	movb $0, %dh		# 	for (uint8_t i = 0; i < count; i++) { add *= 10; } //Simple 10**count

.Lbatoi4:
	cmp %ch, %dh
	jae .Lbatoi5
	imulq $10, %rsi
	addb $1, %dh
	jmp .Lbatoi4
	

.Lbatoi5:
	addq %rsi, %rax		# 	ret += add;
	addb $1, %ch		# 	count++;
	subq $1, %rdi		# 	str -= sizeof(char);
	jmp .Lbatoi3			# }

.Lbatoi_ret:
	ret

.Lbatoi_err: # error, return 0
	movq $0, %rax
	ret

bitoa:
	# will fail if the integer >= 19 digits
	# rdi = int64_t	
	# rsi = char* to address with min size of 21 bytes to store the string in
	movq %rsi, %r11		# make sure we return the pointer to the string

	# int64_t longest possible value = -9223372036854775808 so 20 chars are required + 1 for '\0', will be done on the stack (32 bytes total to ensure 16-byte allignment)
	
	# will attempt a method where we find the highest value of a * 10 ^ b and substitute that from the int
	
	# add a '-' and multiplies the int with -1 if negative
	cmpq $0, %rdi
	jge .Lbitoa1
	movb $45, (%rsi)
	addq $1, %rsi
	imulq $-1, %rdi

.Lbitoa1:
	# c = a * 10 ^ b
	# r9 = a 
	# rax = b
	# r8 = c
	
	# set b = 1, and finding the highest order of rdi by multiplying by 10 and comparing until b is bigger than rdi
	movq $1, %rax
	movq $0, %rdx	# set rdx to 0 for later divisions
	movq $10, %r10	# used for devide by 10, not allowed to use $10 with divq -_-

.Lbitoa2:
	cmpq %rax, %rdi		
	jl .Lbitoa3
	imulq $10, %rax		# multiply b by 10 if b <= rdi
	jmp .Lbitoa2

.Lbitoa3:
	cmpq $0, %rdi
	je .Lbitoa5

	divq %r10
	# found the highest order of the int, time to subtract the highest number
	movq $0, %r9		# a = 0	

.Lbitoa4:
	addq $1, %r9		# keep incrementing a by 1, then compute c each iteration and compare
	movq %rax, %r8
	imulq %r9, %r8
	cmpq %r8, %rdi		# if rdi >= c {retry}
	jae	.Lbitoa4					
						# else {
	subq $1, %r9		# 	a--;
	addb $48, %r9b
	movb %r9b, (%rsi)	# 	*rsi = a;
	addq $1, %rsi		# 	rsi++;

	subq %rax, %r8		# 	decrease c by b (9000 -> 8000)
	subq %r8, %rdi
	jmp .Lbitoa3		# }
	
.Lbitoa5:
	movq %r8, %rax # move c into rax, needed for devisions in .Lbitoa6

.Lbitoa6:
	# special case to ensure trailing zeros are added to the string aswell
	# we just subtracted by c, so if c has trailing zeros we add that many to the string


	cmpq $10, %rax		# if c < 10, exit
	jl .Lbitoa_ret
	
	# else add '0' 
	movb $48, (%rsi)
	addq $1, %rsi

	# devide c by 10 
	divq %r10
	
	# and retry
	jmp .Lbitoa6


.Lbitoa_ret:
	movb $0, (%rsi)		# *rsi = '\0'
	# return rax = char*
	movq %r11, %rax
	ret
