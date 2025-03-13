        BITS 16

FAT_header:
        jmp short start
        nop
        OEM_LABEL db 'MSWIN4.1'
        BYTES_PER_SECTOR dw 512
        SECTORS_PER_CLUSTER db 1
        RESERVED_SECTORS dw 1
        N_FATS db 2
        N_ROOT_DIR_ENTRIES dw 224
        N_SECTORS dw 2880
        MDT db 0f0h
        SECTORS_PER_FAT dw 9
        SECTORS_PER_TRACK dw 18
        N_HEADS dw 2
        N_HIDDEN_SECTORS dd 0
        LARGE_SECTOR_COUNT dd 0
        DRIVE_NUMBER db 0
        NT_FLAGS db 0
        SIGNATURE db 41
        VOLUME_ID dd 816439811
        VOLUME_LABEL db 'jBoot Disk '
        SYSTEM_ID db 'FAT12   '

start:
        ;; Need to set up some stack space somewhere safe
        ;; -----------------------------------------------------------
        ;; https://wiki.osdev.org/Memory_Map_(x86)#Overview
        ;; 0x0500 ­to 0x7BFF is should be free
        ;; -----------------------------------------------------------
        ;; SS:SP defines the position of the stack. SP points to the
        ;; top of the stack. (SS << 4) + SP is the physical location
        ;; of the end top of the stack.
        ;; -----------------------------------------------------------
        ;; When something is placed on the stack, SP is decreased. In
        ;; that way, the initial choice of SP decides how large the
        ;; stack is (though SP can underflow from 0 to 0xfffe, so a
        ;; stack overflow will launch SP somewhere else), while the
        ;; choice of SS defines which section of RAM the stack uses.
        ;; -----------------------------------------------------------
        ;; If we set SS to 0x0050, this will put the lowest possible
        ;; stack position (SP = 0) at 0x0500. When the stack is empty,
        ;; we want the the stack pointer to be at 0x7C00 (since adding
        ;; something to the stack pushes SP back, then adds it). So we
        ;; initially want SP to be 0x7700. This gives a little under
        ;; 30KiB of stack space.
        ;; -----------------------------------------------------------
        ;; Setting SS guarantees you one instruction with no
        ;; interrupts. Use this to safely set up the stack without the
        ;; risk of an interrupt clobbering something.
        mov ax, 50h
        mov ss, ax
        mov sp, 7700h
        mov bp, sp

        mov [boot_drive], dl    ; Store the boot drive number. The
                                ; BIOS initially stores this in DL,
                                ; but we might overwrite this.

        ;; Set DS to where the bootloader is loaded. This allows us
        ;; to access data in the bootloader "directly", via the offset
        ;; from the start of the bootloader known at assemble-time,
        ;; rather than having to calculate where to find some data.
        mov ax, 7C0h
        mov ds, ax

        ;; Print floppy info
        mov cx, 8
        mov si, OEM_LABEL
        call print_N_string
        call new_line
        mov cx, 11
        mov si, VOLUME_LABEL
        call print_N_string

        ;; Load all FATs and the start of the root directory into the
        ;; memory immediately after this bootloader
        xor dx, dx                    ; Zero DX and AX
        xor ax, ax                    ;
        mov al, [N_FATS]              ; Set the least significant byte of AX
        mul word [SECTORS_PER_FAT]    ; Calculate how many sectors we need for all the FATs
        mov cl, al                    ; Store the result

        ;; root directory sectors = 32*(# root entries)/(bytes per sector)
        xor dx, dx                    ; Zero DX and AX
        xor ax, ax                    ;
        mov al, 32                    ; Calculate number of sectors for the root directory
        mul word [N_ROOT_DIR_ENTRIES] ;
        div word [BYTES_PER_SECTOR]   ; Result is now in AX
        add cl, al                    ; Add to how many sectors are needed by the FATs

        ;; We now know how many sectors are used by the FATs and the
        ;; root directory entries. If we add 1 to this, this is the
        ;; offset (in sectors) to the first data cluser (cluster 2).
        ;;
        ;; Simplified example: if the FATs and root dir use 3 sectors,
        ;; then there are a total of 4 sectors in use before the first
        ;; data cluster: the MBR (sector 0) + sectors 1, 2, and
        ;; 3. Therefore, cluster 2 lies at sector 4.
        ;;
        ;; If we save this value now, we can reuse it when we come to
        ;; load data from the filesystem.
        ;; The variable is a word, but since it's little-endian we can
        ;; do this for conciseness.
        mov [cluster_2_sector], cl
        inc word [cluster_2_sector]

        mov ax, 1                     ; Read from LBA 1
        mov dl, [boot_drive]
        mov bx, 7c0h                  ; Store at the end of the boot sector
        mov es, bx                    ;
        mov bx, FAT                   ;
        call load_sectors

        ;; load a file somewhere random
        mov bx, 0CC0h
        mov es, bx
        mov bx, 0
        mov ax, 2
        call load_file

        mov bx, es
        mov ds, bx
        mov cx, 10
        mov si, 0
        call print_N_string
        mov bx, 0CE0h
        mov ds, bx
        mov cx, 13
        mov si, 0
        call print_N_string

        jmp $                   ; Jump here indefinitely. Will hang the system.

;;; Subroutine to print an N-byte string. Put a number of bytes to
;;; print in CX, and put a pointer to the string in SI. Expect bad
;;; things to happen if you set CX = 0
print_N_string:
        mov ah, 0Eh             ; set to "print char" mode

        .loop:
        lodsb
        int 10h
        loop .loop

        .done:
        ret

;;; subroutine to go to the next line and carriage return
new_line:
        mov ax, 0e0dh           ; carriage return
        int 10h
        mov al, 0ah             ; new line
        int 10h
        ret

;;; Subroutine to load a number of sectors into memory. This is
;;; a wrapper around int 13h to take the sector number as an
;;; LBA value.
;;; Args:
;;;   - AX: sector number to read (LBA)
;;;   - CL: number of sectors to read
;;;   - DL: drive number
;;;   - ES:BX: location to read data to
;;; Clobbered registers:
;;;   - CH
;;;   - DH
load_sectors:
        ;; https://wiki.osdev.org/Disk_access_using_the_BIOS_(INT_13h)#The_Algorithm

        ;; Because the sector number (LBA value) is already in ax, we
        ;; can divide it directly.
        ;; We want to use the DIV r/m16 instruction.
        ;; This divides DX:AX by the operand, then stores the quotient
        ;; in AX and the remainder in DX.
        ;; Therefore we will clobber DL

        ;; We'll store those args to some static variables to avoid
        ;; losing them
        mov [sector_count_storage], cl
        mov [drive_number_storage], dl

        xor dx, dx
        div word [SECTORS_PER_TRACK]
                                ; ax now contains Temp
                                ; dx now contains LBA % (Sectors per Track)
        ;; Now store the sector value in CL (and add 1, since sectors
        ;; are addressed from 1).
        mov cl, dl
        inc cl

        ;; now calculate head and cylinder
        xor dx, dx
        ;; ax already contains Temp
        div word [N_HEADS]
                                ; ax now contains the cylinder
                                ; dx now contains the head
        ;; store the head
        mov dh, dl
        ;; store the lower byte of the cylinder
        mov ch, al
        ;; extract the upper two bits of the cylinder
        shr ax, 2
        and al, 0C0h
        ;; store the upper two bits of the cylinder
        or cl, al

        ;; all arithmetic is done; restore the drive number
        mov dl, [drive_number_storage]

        ;; set the necessary registers for int 13h
        mov al, [sector_count_storage]    ; # sectors to read
        mov ah, 02h

        int 13h
        ret
        sector_count_storage db 0
        drive_number_storage db 0

;;; Subroutine to load a file into memory by following the FAT chain.
;;; Args:
;;;   - AX: index of the first cluster (first cluster is cluster 2)
;;;   - DL: drive number
;;;   - ES:BX: location to read data to
load_file:
        push ax ; we need to keep track of which (logical) sector we're reading
        ;; store how many sectors we need to read in the right
        ;; register
        xor cx, cx
        mov cl, byte [SECTORS_PER_CLUSTER]

                                ; AX currently contains the cluster number
        sub ax, 2               ; subtract 2...
        mul cl                  ; multiply by the number of sectors per cluster...
        add ax, word [cluster_2_sector]    ; and add the sector offset to cluster 2
        ;; AX now contains the starting sector of the target cluster
        ;; CL contains the numbers of sectors to read
        ;; DL still contains the drive number
        ;; ES:BX still contains the location to read to
        ;; Now we can load this sector.        
        call load_sectors

        ;; increment BX by one cluster's worth of bytes
        push dx                  ; the 16-bit multiplication will clobber dx
        mov ax, word [BYTES_PER_SECTOR]
        mov cx, [SECTORS_PER_CLUSTER]
        mul cx
        pop dx                   ; restore dx
        add bx, ax
        jnc .bx_ok               ; if carry flag is not set, all good
        ;; if we made it here, bx overflowed, so we need to increase
        ;; es by 1000h to avoid overwriting what's already been loaded
        mov ax, es
        add ah, 10h
        mov es, ax

        ;; Now figure out where the next sector is by reading the FAT
        .bx_ok:
        pop ax
        call read_FAT_for_cluster

        ;; If it's not an EOF marker, read the next chunk
        ;; AX contains the next cluster index
        ;; DL is unchanged
        ;; EX:BX has been incremented
        cmp ax, 0FFFh
        jne load_file
        
        .done:
        ret

;;; Subroutine to read the entry in the FAT corresponding to a cluster.
;;; Args:
;;;   - AX: index of the cluster, starting from 2
;;; Return values:
;;;   - AX: value in the FAT
read_FAT_for_cluster:
        push bx
        
        mov bx, ax              ; get bx = floor(AX * 1.5) so we can read the correct word
        shr bx, 1               ;
        add bx, ax              ; doing everything on bx avoids clobbering ax

        mov bx, [bx+FAT]

        ;; BX now contains the word corresponding to the FAT
        ;; entry. For FAT12, this will contain the FAT entry we want +
        ;; one nibble of the entry we don't want. Dependent on whether
        ;; the current cluster is odd or even, we need to filter it in
        ;; a different way. Since we haven't clobbered AX, if we just
        ;; AND with 1, the zero flag will be set if the current
        ;; cluster is even.
        and ax, 1
        jnz .is_odd
        .is_even:
        and bx, 0FFFh
        jmp .done
        .is_odd:
        shr bx, 4
        
        .done:
        mov ax, bx
        pop bx
        ret

footer:
        boot_drive db 0
        cluster_2_sector dw 0
        
        times 510-($-$$) db 0   ; Pad remainder of boot sector with 0s
        dw 0xAA55               ; The standard PC boot signature

FAT:
