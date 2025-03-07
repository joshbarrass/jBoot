BITS 16

FAT:
    jmp short start
    nop
    OEM_LABEL db 'MSWIN4.1'
    BYTES_PER_SECTOR dw 512
    SECTORS_PER_CLUSTER db 1
    RESERVED_SECTORS dw 1
    N_FATS db 2
    N_ROOTS dw 224
    N_SECTORS dw 2880
    MDT db 240
    SECTORS_PER_FAT dw 9
    SECTORS_PER_TRACK dw 18
    N_HEADS dw 2
    N_HIDDEN_SECTORS dd 0
    LARGE_SECTOR_COUNT dd 0
    DRIVE_NUMBER db 0
    NT_FLAGS db 0
    SIGNATURE db 41
    VOLUME_ID dd 816439811
    VOLUME_LABEL db 'NO NAME    '
    SYSTEM_ID db 'FAT12   '

start:
    ; Need to set up some stack space somewhere safe
    ; ----------------------------------------------
    ; https://wiki.osdev.org/Memory_Map_(x86)#Overview
    ; 0x0500 ­to 0x7BFF is should be free
    ; ----------------------------------------------
    ; SS:SP defines the position of the stack.
    ; SP points to the top of the stack.
    ; (SS << 4) + SP is the physical location of the
    ; end top of the stack.
    ; ----------------------------------------------
    ; When something is placed on the stack, SP is
    ; decreased. In that way, the initial choice of
    ; SP decides how large the stack is (though SP
    ; can underflow from 0 to 0xfffe, so a stack
    ; overflow will launch SP somewhere else), while
    ; the choice of SS defines which section of RAM
    ; the stack uses.
    ; ----------------------------------------------
    ; If we set SS to 0x0050, this will put the
    ; lowest possible stack position (SP = 0) at
    ; 0x0500. When the stack is empty, we want the
    ; the stack pointer to be at 0x7C00 (since adding
    ; something to the stack pushes SP back, then
    ; adds it). So we initially want SP to be 0x7700.
    ; This gives a little under 30KiB of stack space.
    ; ----------------------------------------------
    ; Setting SS guarantees you one instruction with
    ; no interrupts. Use this to safely set up the
    ; stack without the risk of an interrupt
    ; clobbering something.
    mov ax, 50h
    mov ss, ax
    mov sp, 7700h
    mov bp, sp

    ; Set DS to where the bootloader is loaded.
    ; This allows us to access data in the bootloader
    ; "directly", via the offset from the start of
    ; the bootloader known at assemble-time, rather
    ; than having to calculate where to find some
    ; data.
    mov ax, 7C0h
    mov ds, ax

    ; Jump here indefinitely
    ; Will hang the system.
    jmp $

footer:
    times 510-($-$$) db 0   ; Pad remainder of boot sector with 0s
    dw 0xAA55       ; The standard PC boot signature
