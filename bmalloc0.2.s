.section .data
table_ptr: .quad 0
table_offset: .quad 0
table_size: .quad 0 
brk_ptr: .quad 0


.text
.globl _start
.type _start, @function

# testing by calling bmalloc 1024 times in a row
_start:
pushq %rbp
movq %rsp, %rbp
subq $16, %rsp

movl $0, -8(%rbp)

L_start1:
cmpw $1024, -8(%rbp)
ja L_start_exit

movq $512, %rdi
call bmalloc

addw $1, -8(%rbp)
jmp L_start1

L_start_exit:
ret

# sys_exit 
movq $60, %rax
movq $0, %rdi
syscall


# bmalloc works by storing the size of the allocated data in the 8 bytes before the void pointer returned by bmalloc

# when bfree is called it simply copies the size and pointer into a table which can then be used by bmalloc to allocate new datasections

# this table is also allocated on the heap using bmalloc and works as a dynamic array. 
# When it is full, it doubles its size, calls bmalloc, copies itself to the newly allocated memory, 
# and adds the previous ptable and tablesize to the table, and finally updates the table pointer




bmalloc:
# rdi should hold the size of the to be allocated space

# making sure size is > 0
cmpq $0, %rdi
jle Lbmalloc_err

# initliaze stack
pushq %rbp
movq %rsp, %rbp
subq $16, %rsp
# -8(%rbp) = temp_size

# if table_ptr != NULL 
#	check if table has spot available
cmpq $0, table_ptr(%rip)
je Lbmalloc_table_find_spot

# if brk_ptr == NULL:
#	call sys_brk with rdi=0 to retreive brk_ptr
cmpq $0, brk_ptr(%rip)
jne	Lbmalloc_skip_brk_init

# store rdi temporarily on the stack
movq %rdi, -8(%rbp)

# sys_brk with NULL
movq $0, %rdi
movq $12, %rax
syscall

# storing current brk_ptr and restoring original rdi val
movq %rax, brk_ptr(%rip)
movq -8(%rbp), %rdi

.Lbmalloc_skip_brk_init:
# storing size at -16(%rbp), 
# then incrementing rdi by the brk_ptr, 
# then incrementing by 8 to make space for the size variable aswell 
# then storing the new brk_ptr at -8(%rbp), and calling sys_brk
movq %rdi, -16(%rbp)
addq brk_ptr(%rip), %rdi
addq $8, %rdi
movq %rdi, -8(%rbp)
movq $12, %rax
syscall

# if unsuccesful, err
cmpq $0, %rax 
jne Lbmalloc_err

# if succesful, update brk_ptr and 
movq -8(%rbp), %rax
movq %rax, brk_ptr(%rip)

# store the size into the first byte of the allocated memory, by decrementing size + 8
subq -16(%rbp), %rax
subq 8, %rax
movq -16(%rbp), %rcx
movq %rcx, (%rax)

# and setting rax to the memory address by incrementing again
addq 8, %rax

.Lbmalloc_exit:
leave
ret

.Lbmalloc_err:
movq $-1, %rax
leave
ret

bfree:
# rdi holds the pointer

# store the pointer in -8(%rbp) and the size at -16(%rbp)
movq %rdi, -8(%rbp)
subq -8, %rdi
movq %rdi, -16(%rbp)

# if table_ptr == NULL
#	call malloc with initial size (512)
cmpq $0, table_ptr(%rip)
jne Lbfree_skip_table_init

movq $512, %rdi
call malloc

# error check
cmpq $-1, %rax
je Lbfree_err

# storing table pointer
movq %rax, table_ptr(%rip)
movq $512, table_size(%rip)

Lbfree_skip_table_init:
# storing size in table_ptr + table_offset * 8
# and freed pointer in table_ptr + table_offset * 8 + 8

# calculating table_ptr + table_offset * 8
movq table_ptr(%rip), %rcx
movq table_offset(%rip), %rsi
imul $8, %rsi
addq %rsi, %rcx

# store size
movq (%rcx), %rsi
movq -16(%rbp), %rsi

# incrementing the pointer by 8
addq $8, %rcx

# and storing freed pointer
movq (%rcx), %rsi
movq -8(%rbp), %rsi

# incrementing offset by 2
addq $2, table_offset(%rip)

# TODO add check for table_offset == table_size
# if True, call malloc with 2 * table size move table to new local and store old table size+ptr in table and update table_ptr finally.



.Lbfree_exit:
leave
ret

.Lbfree_err:
movq $-1, %rax
leave
ret
