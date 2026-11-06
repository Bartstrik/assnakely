# TODO syscalls can fail (for example when out of memory), we should check for this
.section .data
table_ptr: .quad 0
table_offset: .quad 0
table_size: .quad 0 
brk_ptr: .quad 0


.text
.globl _start
.type _start, @function

# testing by calling bmalloc and free 256 times in a row until the 8 bit value unsigned integer overflows and starts again
# then maybe I can check and count how many times the overflow bit has been set as a debug variable

_start:
pushq %rbp
movq %rsp, %rbp
subq $16, %rsp

.L_start1:
movb $1, %r11b

.L_start2:
movq $0, %rdi
movb %r11b, %dil

call bmalloc

movq %rax, %rdi
call bfree

addb $1, %r11b
jo .L_start1	# overflow check
jmp .L_start2

.L_start_exit:
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
jle .Lbmalloc_err

# initliaze stack
pushq %rbp
movq %rsp, %rbp
subq $16, %rsp
# -8(%rbp) = size
# -16(%rbp) = brk_ptr

# if table_ptr != NULL 
#	check if table has spot available
cmpq $0, table_ptr(%rip)
jne .Lbmalloc_table_find_spot0

# if brk_ptr == NULL:
#	call sys_brk with rdi=0 to retreive brk_ptr
cmpq $0, brk_ptr(%rip)
je	.Lbmalloc_brk_ptr_init


.Lbmalloc_main0:
# storing size at -8(%rbp), 
# then incrementing rdi by the brk_ptr, 
# then incrementing by 8 to make space for the size variable aswell 
# then storing the new brk_ptr at -16(%rbp), and calling sys_brk
movq %rdi, -8(%rbp)
addq brk_ptr(%rip), %rdi
addq $8, %rdi
movq %rdi, -16(%rbp)

movq $12, %rax
syscall

# On failure, the system call returns the current break. 
# On success, the system call returns the new program break
# if unsuccesful, err
cmpq -16(%rbp), %rax 
jne .Lbmalloc_err

# if succesful, update brk_ptr and 
movq -16(%rbp), %rax
movq %rax, brk_ptr(%rip)

# store the size into the first 64-bits of the allocated memory, by decrementing size + 8
subq -8(%rbp), %rax
subq $8, %rax
movq -8(%rbp), %rcx
movq %rcx, (%rax)

# and setting rax to the memory address by incrementing again
addq $8, %rax
jmp .Lbmalloc_exit

.Lbmalloc_brk_ptr_init:
# store rdi temporarily on the stack
movq %rdi, -8(%rbp)

# sys_brk with NULL
movq $0, %rdi
movq $12, %rax
syscall

# storing current brk_ptr and restoring original rdi val
movq %rax, brk_ptr(%rip)
movq -8(%rbp), %rdi
jmp .Lbmalloc_main0


.Lbmalloc_table_find_spot0:
movq table_ptr(%rip), %rcx
movq table_offset(%rip), %rdx
addq %rcx, %rdx

.Lbmalloc_table_find_spot1:
#if the tables end is reached, we simply run malloc normally
cmpq %rcx, %rdx
je .Lbmalloc_main0

# if size is less then requested,
# try next entry in table
cmpq (%rcx), %rdi
jae .Lbmalloc_table_find_spot2

# else simply return the pointer in the table
movq 8(%rdi), %rax
jmp .Lbmalloc_exit

.Lbmalloc_table_find_spot2:
addq $2, %rcx
jmp .Lbmalloc_table_find_spot1


.Lbmalloc_exit:
leave
ret

.Lbmalloc_err:
movq $-1, %rax
leave
ret

bfree:
# rdi holds the pointer

# initliaze stack
pushq %rbp
movq %rsp, %rbp
subq $16, %rsp
# -8(%rbp) = size
# -16(%rbp) = ptr

# store the size in -8(%rbp) and the pointer at -16(%rbp)
movq %rdi, -16(%rbp)
subq $8, %rdi
movq (%rdi), %rcx
movq %rcx, -8(%rbp)

# if table_ptr == NULL
#	call malloc with initial size (512)
cmpq $0, table_ptr(%rip)
je .Lbfree_table_init


.Lbfree_table_size_check:
# first we check if the table is full

# if table_offset * 8 >= table_size
# increase table_size
movq table_offset(%rip), %rsi
imulq $8, %rsi
cmp %rsi, table_size(%rip)
jl .Lbfree_increase_table_size0

.Lbfree_main:
# storing size in table_ptr + table_offset * 8
# and freed pointer in table_ptr + table_offset * 8 + 8

# calculating table_ptr + table_offset * 8
movq table_ptr(%rip), %rcx
movq table_offset(%rip), %rsi
imul $8, %rsi
addq %rsi, %rcx

# store size
movq (%rcx), %rsi
movq -8(%rbp), %rsi

# incrementing the pointer by 8
addq $8, %rcx

# and storing freed pointer
movq (%rcx), %rsi
movq -16(%rbp), %rsi

# incrementing offset by 2
addq $2, table_offset(%rip)

jmp .Lbfree_exit

.Lbfree_table_init:
movq $128, %rdi
call bmalloc

# error check
cmpq $-1, %rax
je .Lbfree_err

# storing table pointer
movq %rax, table_ptr(%rip)
movq $128, table_size(%rip)
jmp .Lbfree_table_size_check

.Lbfree_increase_table_size0:
# call malloc with 2 * table size 
movq table_size(%rip), %rdi
shl $1, %rdi
call bmalloc

# move table to new memory

# store table_prt and table_ptr + table_offset
movq table_ptr(%rip), %rdi
movq table_offset(%rip), %rcx
imulq $8, %rcx
addq %rdi, %rcx

# temporary storage of old table_ptr
movq %rdi, %r8
# store new table_ptr
movq %rax, table_ptr(%rip)

.Lbfree_increase_table_size1:
# if the pointers match, we reached the end
cmp %rdi, %rcx
je .Lbfree_increase_table_size2 

# copy values
movq (%rdi), %rdx
movq %rdx, (%rax)

addq $8, %rdi
addq $8, %rax

jmp .Lbfree_increase_table_size1

.Lbfree_increase_table_size2:

# store old table size+ptr in table aswell 
movq table_size(%rip), %rcx
movq %rcx, (%rax)
addq $8, %rax

movq %r8, %rcx
movq %rcx, (%rax)

# update table_offset and table_size (table_ptr was updated earlier)
addq $2, table_offset(%rip)
movq table_size(%rip), %rcx
shl $1, %rcx

jmp .Lbfree_main

.Lbfree_exit:
leave
ret

.Lbfree_err:
movq $-1, %rax
leave
ret
