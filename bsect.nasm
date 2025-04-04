        BITS 16

;;; We'll use the space from 0x7600 to 0x7BFF as working space for the
;;; FAT and root directory listing.
;;; https://wiki.osdev.org/Memory_Map_(x86)#Overview
;;; 0x0500 to 0x7BFF should be free
        FAT_SEGMENT equ 760h
        FAT_OFFSET equ 0
        ROOT_DIR_OFFSET equ 400h

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
        ;; Need to set up some stack space somewhere safe.
        ;; SS:SP defines the position of the stack. SP points to the
        ;; top of the stack.
        ;;
        ;; If we set SS = 0x0050, this will put the lowest possible
        ;; stack position at 0x0500, which is safe. When the stack is
        ;; empty, we want the the stack pointer to be at 0x7600 (since
        ;; adding something to the stack pushes SP back, then sets the
        ;; value). So want SP = 0x7100
        ;; -----------------------------------------------------------
        ;; Setting SS guarantees you one instruction with no
        ;; interrupts. Use this to safely set up the stack without the
        ;; risk of an interrupt breaking something.
        mov ax, 50h
        mov ss, ax
        mov sp, 7100h
        mov bp, sp

        mov [boot_drive], dl    ; Store the boot drive number. The
                                ; BIOS initially stores this in DL,
                                ; but we might overwrite this.

        ;; Set DS to where the bootloader is loaded. This allows us
        ;; to access data in the bootloader "directly", via the offset
        ;; from the start of the bootloader.
        push word 7C0h
        pop ds

        ;; Print floppy info
        ;; call new_line
        ;; mov cx, 11
        ;; mov si, TARGET_FILE
        ;; call print_N_string
        ;; call new_line

        ;; Calculate how many sectors are used by the FATs so we know
        ;; which sector the root directory entry starts on
        xor dx, dx                    ; Zero DX and AX
        xor ax, ax                    ;
        mov al, [N_FATS]              ; Set the least significant byte of AX
        mul word [SECTORS_PER_FAT]    ; Calculate how many sectors we need for all the FATs
        mov cl, al                    ; Store the result

        ;; Cache this value to quickly find the root directory entry
        ;; The variable is a word, but since it's little-endian we can
        ;; do this for conciseness.
        mov [root_dir_sector], cl
        inc word [root_dir_sector]

        ;; Calculate which sector the first data sector starts on
        ;; root directory sectors = 32*(# root entries)/(bytes per sector)
        xor dx, dx                    ; Zero DX
        mov ax, 32                    ; Calculate number of sectors for the root directory
        mul word [N_ROOT_DIR_ENTRIES] ;
        div word [BYTES_PER_SECTOR]   ; Result is now in AX
        add cl, al                    ; Add to how many sectors are needed by the FATs

        ;; Save this to aid loading data later
        mov [cluster_2_sector], cl
        inc word [cluster_2_sector]

        ;; No longer need to pre-load the FAT/root dir
        ;; These will be loaded automatically

        ;; Find the first cluster of the file
        mov si, TARGET_FILE
        call get_cluster_of_file
        ;; AX now contains the cluster number
        ;; if it's zero, then the file doesn't exist
        or ax, ax
        jz .err

        ;; set up the other args to load the file just after the boot
        ;; sector
        ;; mov bx, 07E0h
        ;; mov es, bx
        push word 07E0h
        pop es
        xor bx, bx
        call load_file

        push es
        pop ds
        mov cx, 13
        xor si, si
        call print_N_string
        push word 0800h
        pop ds
        mov cx, 13
        xor si, si
        call print_N_string
        jmp .hang

        .err:
        mov si, ERR_FNF
        mov cx, 7
        call print_N_string

        .hang:
        cli
        hlt
        jmp .hang               ; Jump here indefinitely. Will hang the system.

;;; Subroutine to print an N-byte string. Put a number of bytes to
;;; print in CX, and put a pointer to the string in SI. CX = 0 is
;;; equivalent to N = 256.
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

;;; subroutine to load a single 512-byte chunk of the root directory
;;; entry (14 entries) into the root directory workspace.
;;; Args:
;;; - AX: which sector of the entry to load (0 = first sector)
;;; Clobbers:
;;; - AX
;;; - BX
;;; - CX
;;; - DX
;;; - ES
load_root_dir_chunk:
        add ax, word [root_dir_sector]; Get the root directory sector
        mov bx, ROOT_DIR_OFFSET       ;
        mov cl, 1                     ; Read one sector
        jmp load_FAT_chunk.all_loads

;;; subroutine to load a single 1024-byte chunk of the FAT into the
;;; FAT workspace.
;;; Args:
;;; - AX: which sector of the FAT to load (0 = first sector of the
;;;       FAT)
;;; Clobbers:
;;; - AX
;;; - BX
;;; - CX
;;; - DX
;;; - ES
load_FAT_chunk:
        ;; set up for load_sector
        .FAT_specific_loads:
        mov [loaded_FAT_chunk], ax
        inc ax                        ; FAT starts at index 1, so add 1
        mov bx, FAT_OFFSET            ;
        mov cl, 2                     ; Read two sectors

        ;; configure parameters that stay the same for both the FAT
        ;; and root directory entry loads
        .all_loads:
        push word FAT_SEGMENT         ; Store just before the boot sector
        pop es                        ;
        mov dl, [boot_drive]

        ;; Because of where we've placed the routine, the call is
        ;; implicit. We can save a few bytes here.
        ;; call load_sectors

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
        push ax                 ; we will restore this later to test the parity
        
        mov bx, ax              ; get ax = floor(AX * 1.5) so we can read the correct word
        shr bx, 1               ;
        add ax, bx              ;
        ;; ax now contains the offset into the FAT for the cluster we care about

        ;; now need to get the sector number and relative offset
        ;; just divide by the sector size
        ;; quotient is the sector number
        ;; remainder is the offset into that sector
        push dx                 ; clear DX so we can divide just AX
        xor dx, dx
        div word [BYTES_PER_SECTOR]
        ;; AX now contains sector number
        ;; DX now contains offset

        ;; don't reload the FAT chunk if the sector number hasn't
        ;; changed since last time
        cmp ax, [loaded_FAT_chunk]
        je .read_FAT

        .reload_chunk:
        ;; load the necessary FAT chunk (it's already in AX)
        pusha
        push es
        call load_FAT_chunk
        pop es
        popa

        .read_FAT:
        mov bx, dx              ; store offset in BX so we can access the data directly
        pop dx
        pop ax                  ; restore AX from earlier for the comparison we need

        push ds                 ; We need to set the data segment to do (ds:)bx properly
        push word FAT_SEGMENT   ;
        pop ds                  ;
        mov bx, [bx]
        pop ds                  ; Restore the old DS

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

;;; Put an 11-byte filename string at SI. This function will return in
;;; AX the number of the first cluster of this file by searching the
;;; root directory entry.
;;; Args:
;;;  - SI: location of the filename string to compare against
;;; Returns:
;;;  - AX: index of the first cluster of the file
;;; Clobbers:
;;;  - CX
;;;  - BX
get_cluster_of_file:
        push es

        ;; Set the segment.
        ;; ES needs to point us to the right segment for the root
        ;; directory entry.
        ;; DS stays as it is as we're comparing DS:SI against ES:DI
        push word FAT_SEGMENT
        pop es

        ;; now we need to loop through the 32-byte entries until we
        ;; find the one with the right filename

        ;; calculate how many sectors are used by the root directory
        ;; entries.

        ;; since we already know the first sector of the root
        ;; directory entry and the first sector of the data clusters,
        ;; we can subtract one from the other to find the root
        ;; directory length without recalculating anything in full
        mov cx, [cluster_2_sector]    ; use this as a loop counter
        sub cx, [root_dir_sector]

        .chunk_load_loop:
        ;; load the directory chunk
        pusha
        mov ax, cx
        dec ax
        call load_root_dir_chunk
        popa

        ;; point to the root directory entry in the working space
        mov ax, ROOT_DIR_OFFSET
        ;; AX now contains the start of the root directory listing

        ;; we'll backup the location of the string we're comparing
        ;; with, and then store AX to DI. Then we can use CMPS to
        ;; compare DS:SI against ES:DI
        ;; test at most 16 entries before we load the next root dir
        ;; chunk
        push cx
        mov cx, 16
        .loop:
        push si
        mov di, ax
        ;; compare at most 11 characters
        push cx
        mov cx, 11
        ;; then we can use REPZ CMPS to compare the strings, which
        ;; will either compare CX characters or short-circuit the
        ;; first time it encounters a non-matching character
        ;; REPE is an alias for this (repeat while equal)
        repe cmpsb
        pop cx
        pop si
        je .done
        ;; if we got here, the strings don't match
        ;; move to the next entry and repeat
        add ax, 32
        loop .loop

        ;; didn't find it in this batch of 14
        ;; go to the start of the outer loop and load the next chunk
        pop cx
        loop .chunk_load_loop

        ;; If we made it here, it means we didn't use the jump to
        ;; .done before we ran out of tries. This means the file does
        ;; not exist!
        ;; We can just return 0 if that's the case, since 0 is not a
        ;; valid chunk number.
        xor ax, ax
        jmp .return

        .done:
        ;; get the chunk number
        pop cx                  ; this is the extra loop counter
                                ; if we don't remove this, the ret will
                                ; fail!
        mov bx, ax
        mov ax, [es:bx+1Ah]     ; Override the segment.
                                ; 0x1A is the offset to the cluster number.
                                ; Our offset is to a location in the
                                ; root directory listing segment,
                                ; which we've been using ES for.

        .return:
        pop es
        ret

footer:
        boot_drive db 0
        root_dir_sector dw 0
        cluster_2_sector dw 0
        loaded_FAT_chunk dw 0xFFFF
        TARGET_FILE db 'TEST2'
        times (TARGET_FILE+8)-$ db ' '
        db 'TXT'

        ERR_FNF db 'MISSING'

        times 510-($-$$) db 0   ; Pad remainder of boot sector with 0s
        dw 0xAA55               ; The standard PC boot signature
