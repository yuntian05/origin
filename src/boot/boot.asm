org 0x7c00

    jmp START
    nop

StackBase: equ 0x7c00

BootMsg: db "Booting.............."

START:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov sp, StackBase

    ;打印字符串"Booting.............."
    mov al, 1
    mov bh, 0
    mov bl, 0x07 ;黑底白字
    mov cx,13
    mov dl, 0
    mov dh, 0

    ;es = ds
    push ds
    pop es

    mov bp, BootMsg
    mov ah, 0x13
    int 0X10

    jmp $

times 510 - ($ - $$) db 0
dw 0xaa55
