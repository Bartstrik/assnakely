.section .data
table_ptr: .quad 0
table_usage: .zero 32 # 32 bytes or 256 bits where each bit indicates whether the pair is in use or not, should be null-initialized
brk_ptr: .quad 0


.text
.globl _start
.type _start, @function

# trying to allocate 512 Bytes on the heap using bmalloc and freeing afterwards using bfree.
_start:
pushq %rbp
movq %rsp, %rbp

movq $512, %rdi
call bmalloc

movq $512, %rdi
call bmalloc

L_start_exit:
# sys_exit 
movq $60, %rax
movq $0, %rdi
syscall






# I can use sys_brk to first get the pointer to the heap and then offset it for smaller heap increments (will try this first)
# Or if it needs to have good performance it would allocate larger chunks using mmap and keep track itself of which parts are used

# Anyways I would need to keep track of each pointer thats stored on the heap with its size to be able to free them afterwards.
# I will store this information at the very start of the heap, since I dont know where else to put it, any other place such as stack or .bcc can not grow "indefinitely"
# Lets start with just having the first 512 bytes of the heap be used as 256 pairs of void* ptr and uint64_t size variables, so [void*, uint64_t, void*, uint64_t, ..... ]
bmalloc:
# rdi should hold the size of the to be allocated space

# first time bmalloc is called we need to initialize the heap table and store its pointer
cmpq $0, table_ptr(%rip)
je .L_bmalloc_init

.L_bmalloc_main0:
# storing the size in r10 for later use (adding to table)
movq %rdi, %r10

# sys_brk with nullptr to get the current break point
movq $12, %rax
movq $0, %rdi
syscall

# sys_brk with incremented brk pointer
movq %rax, %rdi
addq %r10, %rdi

movq $12, %rax
syscall

# storing incremented brk pointer
movq %rax, brk_ptr(%rip)

# loading table_usage and offset
leaq table_usage(%rip), %r9
movq $0, %r11

# TODO start at right most bit instead of left
# setting the first bit to 1 in r8
.L_bmalloc_table_comp1:
movq $0x1, %r8
shl $63, %r8

# looping over the table_usage and checking if open spots have a large enough space (freed heap space will be reused when possible)
.L_bmalloc_table_comp2:
andq %r8, (%r9, %r11, 8) # 0b0100 & 0b1011 = 0b0000
cmpq $0, (%r9, %r11, 8)
je .L_bmalloc_table_comp_finish # if equal, it means the place is empty and we can assign it

# bitshifting right and if r8 == 0, we need to start checking the next 64 bits of table_usage 
shr $1, %r8
cmp $0, %r8
jne .L_bmalloc_table_comp2	# so if not equal, we simple do the next iteration of the loop

# else we increment the offset and reinitialize the bitmask
addq $1, %r11
jmp .L_bmalloc_table_comp1

# when we found an empty spot
.L_bmalloc_table_comp_finish:
# we set the bit
orq %r8, (%r9, %r11, 8)

# we want to store the pointer and the size in the table, but first we need to compute the pointer to the right spot

# load the table_ptr and offset it using the offset * 64
movq table_ptr(%rip), %rcx
movq $0, %rdx
movq $64, %rax
mulq %r11
#now rax contains offset * 64
addq %rax, %rcx

# + bitlength
#we loop through the bitmask shifting left and incrementing the pointer for ever shift
.L_bmalloc_bitlength_loop:
shl $1, %r8
cmpq $0, %r8
je .L_bmalloc_bitlength_loop_finish
addq $8, %rcx
jmp .L_bmalloc_bitlength_loop

.L_bmalloc_bitlength_loop_finish:
# now we can actually store the size
movq %r10, 8(%rcx)
# and the pointer which is equal to the new brk_ptr - size
movq brk_ptr(%rip), %r8
subq %r10, %r8
movq %r8, (%rcx)

ret







.L_bmalloc_init:
# storing rdi in r12 to make sure its preserved during syscall  TODO might need to store somewhere else, this violates function callee rules
movq %rdi, %r12

# sys_brk with nullptr to get the current break point
movq $12, %rax
movq $0, %rdi
syscall

# storing the location of the heap table in the .data section of the process
movq %rax, table_ptr(%rip)

# incrementing the break pointer by 512
movq %rax, %rdi
addq $512, %rdi

# storing the break pointer 
movq %rdi, brk_ptr(%rip)

# sys_brk to create the heap table
movq $12, %rax
syscall

# restoring rdi
movq %r12, %rdi
jmp .L_bmalloc_main0
