org  0x7C00
bits 16

%define ENDL 0x0D, 0x0A ; define new line and carriage return chars(\n\r)

;
; FAT 12 Headers
; These headers are required in a FAT 12 Disc
;
jmp short start
NOP

bdb_oem:                     db 'MSWIN4.1'      ; 8 Bytes
bdb_bytes_per_sector:        dw 512
bdb_sectors_per_clustor:     db 1
bdb_reserved_sector:         dw 1
bdb_fat_count:               db 2
bdb_dir_entries_count:       dw 0E0h
bdb_total_sectors:           dw 2880
dbd_media_descriptor_type:   db 0F0h
bdb_sectors_per_fat:         dw 9
bdb_sectors_per_track:       dw 18
bdb_heads:                   dw 2
bdb_hidden_sectors:          dd 0
bdb_large_sector_count:      dd 0

; extended Boot Record
ebr_drive_number:           db 0
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value does not matter
ebr_volume_label:           db 'NV OS BOOT '        ; 11 Byte label, shoulf be 11 byte even if padded with space
ebr_system_id:              db 'FAT12   '           ; 8 Byte String



;
; Code goes here
;


start:
    jmp main

;
;   Prints a srting to screen
;   Params
;       - ds:si points to string
;
puts:
    ; save the registers we will modify
    push si
    push ax

.loop:
    lodsb       ; loads next char in al
    or al, al   ; check if or gives null, ex. (0 or 0)=0, (1 or 1)=1, if result is 0, then zero flag is set
    jz puts.done    ; jumps to label if zero flag is set

    mov ah, 0x0e ; calls BIOS interrupt
    int 0x10    ; set interupt to video/teletext

    jmp puts.loop   ; jumps back to loop if not zero

.done:
    ; restore saved registers
    pop ax
    pop si
    ret

draw_line:
    mov dx, 0
    mov al, 0xB0 ;ascii chart char to AL
.loop:
    cmp dx, 20 ; 20 times comparison
    je draw_line.done
    mov ah, 0x0e ; calls BIOS interrupt
    int 0x10    ; set interupt to video/teletext
    inc dx
    jmp draw_line.loop
.done:
    ret


main:
    ; set 0 to all registers
    mov ax, 0
    ; since ds/es can not write values directly, we will copy the value of ax
    mov dx, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00  ; point the stack to 0x7C00 address, our OS starts from the, 
                    ; and stack uses memomry in backwords diection, so our OS will not get overwritten by the stack
    

    ; read something from floppy disk
    ; BIOS should set DL to drive number
    mov [ebr_drive_number], dl

    mov ax, 1                   ; LBA=1, second sector from disk
    mov cl, 1                   ; 1 sector to read
    mov bx, 0x7E00              ; data should be after the bootloader
    call disk_read

    ;call draw_line

    ;   print a new line
    mov si, empty_line
    call puts

    ;   print OS Welcome Message
    mov si, os_name
    call puts

    ;print made by
    mov si, made_by
    call puts

    cli
    hlt



;
; Error handlers
;

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                     ; wait for keypress
    jmp 0FFFFh:0                ; jump to beginning of BIOS, should reboot

.halt:
    cli                         ; disable interrupts, this way CPU can't get out of "halt" state
    hlt


;
; Disk routines
;

;
; Converts an LBA address to a CHS address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
;

lba_to_chs:

    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack

    inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                        ; dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                           ; put upper 2 bits of cylinder in CL

    pop ax
    mov dl, al                          ; restore DL
    pop ax
    ret


;
; Reads sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
;
disk_read:

    push ax                             ; save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx                             ; temporarily save CL (number of sectors to read)
    call lba_to_chs                     ; compute CHS
    pop ax                              ; AL = number of sectors to read
    
    mov ah, 02h
    mov di, 3                           ; retry count

.retry:
    pusha                               ; save all registers, we don't know what bios modifies
    stc                                 ; set carry flag, some BIOS'es don't set it
    int 13h                             ; carry flag cleared = success
    jnc .done                           ; jump if carry not set

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax                             ; restore registers modified
    ret


;
; Resets disk controller
; Parameters:
;   dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret



os_name:                 db '========= Welcome to NV OS! ========= ', ENDL, 0 ; db diective declares string
made_by:                 db '        Made By Vikas Tiwari', ENDL, 0
msg_read_failed:         db 'Read from disk failed!', ENDL, 0

empty_line: db ENDL, ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
