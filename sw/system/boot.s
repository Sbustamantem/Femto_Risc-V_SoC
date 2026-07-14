.section .text
.global _start

_start:
    # Initialize the stack pointer to the very top of the 1KB RAM (0x00000000 + 1024)
    # The stack grows downward, keeping it safely away from your program code.
    li sp, 0x00000400

    # Jump to the C main function. 
    # If main ever accidentally returns, loop forever to prevent a CPU runaway.
    jal main
1:  j 1b