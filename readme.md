### My way of learning a bit of GAS AT&T asm
The goal of this project is to learn assembly by creating a simple snake type game written in asm using only linux syscalls (no glibc).
Since I barely knew anything about assembly I started writing C code and simply compiling it to asm and trying to understand how it worked.
I thought lets start easy and just write a program that adds the 2 arguments together and prints them to stdout, easy right?
Well I thought so too, until I realized that the numbers are parsed in as characters, which meant I needed to write functions to convert strings to integers and integers to strings.
Afterwards I wanted to use malloc for my integer to string function, but of course that is a libc function too, so I tried to implement my own version of malloc using sys_brk

TODO:
 - heap allocation using sys_brk
 - integer overflow/underflow detection batoi (if possible using cpu flags?) 
 - Totally get rid of libc by switching to _start somehow
 - get started on snake
 - continually draw an arena
 - get keyboard input to work
 - move character dependend on input

