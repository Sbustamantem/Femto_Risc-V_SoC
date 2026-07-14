/* Target architecture specification */
OUTPUT_ARCH("riscv")

/* Define the physical 1KB BRAM boundaries */
MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 1024
}

/* Map the code sections into the RAM layout */
SECTIONS
{
    .text :
    {
        /* Force the boot assembly code to occupy the very first bytes */
        *(.text._start)
        *(.text)
        *(.text.*)
    } > RAM

    .rodata :
    {
        *(.rodata)
        *(.rodata.*)
    } > RAM

    .data :
    {
        *(.data)
        *(.data.*)
    } > RAM

    .bss :
    {
        *(.bss)
        *(.bss.*)
    } > RAM
}