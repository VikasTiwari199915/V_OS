org  0x7C00
bits 16

%define ENDL 0x0D, 0x0A ; define new line and carriage return chars(\n\r)

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

    hlt

.halt:
    jmp .halt

os_name: db '========= Welcome to NV OS! ========= ', ENDL, 0 ; db diective declares string
made_by: db '       Made By Vikas Tiwari', ENDL, 0

empty_line: db ENDL, ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
