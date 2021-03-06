%include "include/boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
;jmp loader_start

;=================================================
;=================================================
GDT_BASE: dd 0x00000000
            dd 0x00000000

CODE_DESC: dd 0x0000FFFF
            dd DESC_CODE_HIGH4

DATA_STACK_DESC: dd 0x0000FFFF
                    dd DESC_DATA_HIGH4

VIDEO_DESC: dd 0x80000007;limit=(0xbffff-0xb8000)/0x1000=0x7
                dd DESC_VIDEO_HIGH4

GDT_SIZE equ $ - GDT_BASE
GDT_LIMIT equ GDT_SIZE - 1
times 60 dq 0
SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0
SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0

;==================================================
;total_mem_bytes address is 0x200 = 4 * 8 + 60 * 8
;==================================================
total_mem_bytes dd 0

;==================================================
;gdt pointer
;==================================================
gdt_ptr dw GDT_LIMIT
        dd GDT_BASE
;loadermsg db '2 loader in real.'

;==================================================
;total_mem_bytes 4 + gdt_ptr 6 + ards_buf 244 + ards_nr 2 = 256
;==================================================
ards_buf times 244 db 0
ards_nr dw 0

;==================================================
; 输出背景色绿色，前景色红色，并且跳动的字符串"1 MBR"
;==================================================
loader_start:
;==================================================
;int 0x15 eax=0x0000e820 edx=0x534d4150('SMAP') 
;==================================================
    xor ebx,ebx
    mov edx, 0x534d4150
    mov di, ards_buf
.e820_mem_get_loop:
    mov eax, 0x0000e820
    mov ecx, 20
    int 0x15
    jmp .e820_failed_and_try_e801
    add di, cx
    inc word [ards_nr]
    cmp ebx, 0
    jnz .e820_mem_get_loop

; mem=base_add_low+length_low 
    mov cx, [ards_nr]
    mov ebx, ards_buf
    xor edx, edx
.find_max_mem_area:
    mov eax, [ebx]      ;base_add_low
    add eax, [ebx + 8]  ;length_low
    add ebx, 20
    cmp edx, eax
    jge .next_ards
    mov edx, eax
.next_ards:
    loop .find_max_mem_area
    jmp .mem_get_ok

;==================================================
;int 0x15 ax=0x0000e801 max mem 4G
;==================================================
.e820_failed_and_try_e801:
    mov ax,0x0000e801
    int 0x15
    jc .e801_failed_and_try_88
; 1.low 15M
    mov cx, 0x400
    mul cx,
    shl edx, 16
    and eax, 0x0000FFFF
    or edx, eax
    add edx, 0x100000
    mov esi, edx

; 2. high 16M-4G
    xor eax, eax
    mov ax, bx
    mov ecx, 0x10000
    mul ecx
    add esi, eax
    mov edx, esi
    jmp .mem_get_ok

;==================================================
;int 0x15 ah=0x88 max mem 64M
;==================================================
.e801_failed_and_try_88:
    mov ah, 0x88
    int 0x15
    jc .error_hlt
.mem_get_ok:
    mov [total_mem_bytes], edx
;==================================================
    ;mov byte [gs:160],'2'
    ;mov byte [gs:161],0xA4     ; A表示绿色背景闪烁，4表示前景色为红色

    ;mov byte [gs:162],' '
    ;mov byte [gs:163],0xA4

    ;mov byte [gs:164],'L'
    ;mov byte [gs:165],0xA4   

    ;mov byte [gs:166],'O'
    ;mov byte [gs:167],0xA4

    ;mov byte [gs:168],'A'
    ;mov byte [gs:169],0xA4

    ;mov byte [gs:170],'D'
    ;mov byte [gs:171],0xA4

    ;mov byte [gs:172],'E'
    ;mov byte [gs:173],0xA4

    ;mov byte [gs:174],'R'
    ;mov byte [gs:175],0xA4
;==================================================

;==================================================
    ;mov sp,LOADER_BASE_ADDR
    ;mov bp, loadermsg
    ;mov cx, 17
    ;mov ax, 0x1301
    ;mov bx, 0x001f
    ;mov dx, 0x1800
    ;int 0x10
;==================================================

;==================================================
    ;first open A20

    in al,0x92
    or al,0000_0010b
    out 0x92,al

    ;second load GDT
    lgdt [gdt_ptr]

    ;set cr0 0 as 1
    mov eax, cr0
    or eax, 0x00000001
    mov cr0, eax

    ;refresh
    jmp SELECTOR_CODE:p_mode_start

.error_hlt:
    hlt
;==================================================
[bits 32]
p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax

    call setup_page
    
    ;
    sgdt [gdt_ptr]
    mov ebx, [gdt_ptr + 2]
    or dword [ebx+0x18+4], 0xc0000000

    add dword [gdt_ptr + 2], 0xc0000000

    add esp, 0xc0000000

    mov eax, PAGE_DIR_TABLE_POS
    mov cr3, eax

    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    lgdt [gdt_ptr]

    mov byte [gs:320], 'V'

    jmp $		       ; 通过死循环使程序悬停在此
;==================================================
;create page directory entry(PDE) and page table entry(PTE)
;==================================================
setup_page:
    mov ecx, 4096
    mov esi, 0
.clear_page_dir:
    mov byte [PAGE_DIR_TABLE_POS + esi], 0
    inc esi
    loop .clear_page_dir

.create_pde:
    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x1000
    mov ebx, eax

    or eax, PG_US_U | PG_RW_W | PG_P
    mov [PAGE_DIR_TABLE_POS + 0x0], eax
    mov [PAGE_DIR_TABLE_POS + 0xc00], eax

    sub eax, 0x1000
    mov [PAGE_DIR_TABLE_POS + 4092], eax

    mov ecx, 256
    mov esi, 0
    mov edx, PG_US_U | PG_RW_W | PG_P
.create_pte:
    mov [ebx + esi * 4], edx
    add edx, 4096
    inc esi
    loop .create_pte

    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x2000
    or eax, PG_US_U | PG_RW_W | PG_P
    mov ebx, PAGE_DIR_TABLE_POS
    mov ecx, 254
    mov esi, 769
.create_kernel_pde:
    mov [ebx+esi*4],eax
    inc esi
    add eax, 0x1000
    loop .create_kernel_pde
    ret