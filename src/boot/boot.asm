;%deine _BOOT_DEBUG_ ;做 Boot Sector 时一定将此行注释掉!将此行打开后用 nasm Boot.asm -o Boot.com 做成一个.COM文件易于调试

%ifdef _BOOT_DEBUG_ 
    org 0x0100
%else
    org 0x7c00
%endif

;================================================================================================
%ifdef	_BOOT_DEBUG_
    BaseOfStack		equ	0100h	; 调试状态下堆栈基地址(栈底, 从这个位置向低地址生长)
%else
    BaseOfStack		equ	07c00h	; Boot状态下堆栈基地址(栈底, 从这个位置向低地址生长)
%endif

    jmp START
    nop
    ;下面是FAT12磁盘的头
    BS_OEMName      DB 'Origin--'    ; OEM String, 必须是8个字节
    BPP_BytsPerSec  DW 51            ;  每扇区字节数
    BPB_SecPerClus  DB 1             ; 每簇多少扇区
    BPB_RsvdSecCnt  DW 1             ; Boot记录占用多少扇区
    BPB_NumFATs     DB 2             ;共有多少FAT表
    BPB_RootEntCnt  DW 224           ; 根目录文件数最大值
    BPB_TotSec16    DW 2880          ; 逻辑扇区总数
    BPB_Media       DB 0xF0          ; 媒体描述符
    BPB_FATSz16     DW 9             ; 每FAT扇区数
    BPB_SecPerTrk   DW 18            ; 每磁道扇区数
    BPB_NumHeads    DW 2             ; 磁头数（面数）
    BPB_HiddSec     DD 0             ; 隐藏扇区数
    BPB_TotSec32    DD 0             ; 如果wTotalSectorCount是0，由这个值记录扇区数
    BS_DrvNum       DB 0             ; 中断13的驱动器号
    BS_Reserved1    DB 0             ; 未使用
    BS_BootSig      DB 0X29          ; 扩展引导标记
    BS_VolID        DB 0             ; 卷序列号
    BS_VolLab       DB 'Origin 0.01' ; 卷标，必须是11字节
    BS_FileSysType  DB 'FAT12   '    ; 文件系统类型，必须是8字节

BootMsg: db "Booting.............."

START:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov sp, StackBase
    
    ; 清屏，清理BIOS的输出
    mov	ax, 0600h		; AH = 6,  AL = 0h
	mov	bx, 0700h		; 黑底白字(BL = 07h)
	mov	cx, 0			; 左上角: (0, 0)
	mov	dx, 0184fh		; 右下角: (80, 50)
	int	10h				; int 10h	

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
