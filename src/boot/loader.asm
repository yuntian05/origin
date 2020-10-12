org 0x100
    jmp START

BaseOfStack equ 0x100   ;调试状态下堆栈基地址(栈底)
;============================================================================
;头文件
;----------------------------------------------------------------------------
;挂载点相关的信息
%include    "load.inc"  
; 下面是 FAT12 磁盘的头, 之所以包含它是因为下面用到了磁盘的一些信息
%include	"fat12hdr.inc"
;=============================================================================

START:
    ;寄存器复位
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, BaseOfStack

    ;显示字符串 "Hello Loader!"
	mov	dh, 0			; "Hello Loader!  "
	call	DispStr		; 显示字符串

    ;检查并得到内存信息
    mov ebx, 0          ;放置“得到后续的内存信息的值”，第一次调用必须为0
    mov di,_MemChkBuf   ; es:di ->指向准备写入ADRS的缓冲区地址
._MemChkLoop:
    mov eax, 0x0000e820
    mov ecx,20          ;ecx=ADRS的大小
    mov edx, 0x0534d4150;字符串"SMAP"
    int 0x15			;得到ADRS
    jc  .MemChkFail     ; 产生了一个进位，CF=1，检查得到ADRS错误！
	;CF=0,检查并获取成功
    add di,20           ; di += 20, es:di 指向缓冲区准备放入下一个ADRS的
    inc dword [_ddMCRCount] ;ADRS数量++
    cmp ebx,0
    je  .MemChkFinish   ; ebx == 0, 表示已经拿到最后一个ADRS，完成检查并且跳出循环
    ;ebx != 0,表示还没拿到最后一个，继续
    jmp ._MemChkLoop

.MemChkFail:
    mov dword  [_ddMCRCount], 0 ;检查失败 ADRS数量设置位0

    mov dh, 1
    call DispStr
    jmp $

.MemChkFinish:
    xor	ah, ah	; ┓
	xor	dl, dl	; ┣ 软驱复位
	int	13h		; ┛


; 下面在 A 盘的根目录寻找 KERNEL.BIN
	mov	word [wSectorNo], SectorNoOfRootDirectory
LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
	cmp	word [wRootDirSizeForLoop], 0	; ┓
	jz	LABEL_NO_KERNELBIN				; ┣ 判断根目录区是不是已经读完
	dec	word [wRootDirSizeForLoop]		; ┛ 如果读完表示没有找到 KERNEL.BIN
	mov	ax, KERNEL_SEG
	mov	es, ax				; es <- KERNEL_SEG
	mov	bx, KERNEL_OFFSET	; bx <- KERNEL_OFFSET	于是, es:bx = KERNEL_SEG:KERNEL_OFFSET
	mov	ax, [wSectorNo]		; ax <- Root Directory 中的某 Sector 号
	mov	cl, 1
	call	ReadSector

	mov	si, KernelFileName	; ds:si -> "KERNEL  BIN"
	mov	di, KERNEL_OFFSET	; es:di -> KERNEL_SEG:0100 = KERNEL_SEG*10h+100
	cld
	mov	dx, 10h
LABEL_SEARCH_FOR_KERNELBIN:
	cmp	dx, 0										; ┓循环次数控制,
	jz	LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR			; ┣如果已经读完了一个 Sector,
	dec	dx											; ┛就跳到下一个 Sector
	mov	cx, 11
LABEL_CMP_FILENAME:
	cmp	cx, 0
	jz	LABEL_FILENAME_FOUND	; 如果比较了 11 个字符都相等, 表示找到
    dec	cx
	lodsb				; ds:si -> al
	cmp	al, byte [es:di]
	jz	LABEL_GO_ON
	jmp	LABEL_DIFFERENT		; 只要发现不一样的字符就表明本 DirectoryEntry 不是
							; 我们要找的 LOADER.BIN
LABEL_GO_ON:
	inc	di
	jmp	LABEL_CMP_FILENAME	;	继续循环

LABEL_DIFFERENT:
	and	di, 0FFE0h						; else ┓	di &= E0 为了让它指向本条目开头
	add	di, 20h							;      ┃
	mov	si, KernelFileName				;      ┣ di += 20h  下一个目录条目
	jmp	LABEL_SEARCH_FOR_KERNELBIN		;      ┛

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
	add	word [wSectorNo], 1
	jmp	LABEL_SEARCH_IN_ROOT_DIR_BEGIN

LABEL_NO_KERNELBIN:
	mov	dh, 2			; "No KERNEL."
	call	DispStr		; 显示字符串
%ifdef	_BOOT_DEBUG_
	mov	ax, 4c00h		; ┓
	int	21h				; ┛没有找到 LOADER.BIN, 回到 DOS
%else
	jmp	$				; 没有找到 LOADER.BIN, 死循环在这里
%endif

LABEL_FILENAME_FOUND:			; 找到 LOADER.BIN 后便来到这里继续
	mov	ax, RootDirSectors
	and	di, 0FFE0h				; di -> 当前条目的开始
	add	di, 01Ah				; di -> 首 Sector
	mov	cx, word [es:di]
	push	cx					; 保存此 Sector 在 FAT 中的序号
	add	cx, ax
	add	cx, DeltaSectorNo		; 这句完成时 cl 里面变成 LOADER.BIN 的起始扇区号 (从 0 开始数的序号)
	mov	ax, KERNEL_SEG
	mov	es, ax					; es <- KERNEL_SEG
	mov	bx, KERNEL_OFFSET		; bx <- KERNEL_OFFSET	于是, es:bx = KERNEL_SEG:KERNEL_OFFSET = KERNEL_SEG * 10h + KERNEL_OFFSET
	mov	ax, cx					; ax <- Sector 号

LABEL_GOON_LOADING_FILE:
	push	ax			; ┓
	push	bx			; ┃
	mov ah, 0Eh		; # 每读一个扇区就在　"Loading   "加符号 '.'
	mov al, '.'		; #
	mov bl, 0Fh		; # 效果：Loading ......
	int	10h			    ; ┃
	pop	bx			    ; ┃
	pop	ax			    ; ┛

	mov	cl, 1
	call	ReadSector
	pop	ax				; 取出此 Sector 在 FAT 中的序号
	call	GetFATEntry
	cmp	ax, 0FFFh
	jz	LABEL_FILE_LOADED
	push	ax			; 保存 Sector 在 FAT 中的序号
	mov	dx, RootDirSectors
	add	ax, dx
	add	ax, DeltaSectorNo
	add	bx, [BPB_BytsPerSec]
	jmp	LABEL_GOON_LOADING_FILE
LABEL_FILE_LOADED:
	mov	dh, 3			    ; "Hello Kernel!"
	call	DispStr			; 显示字符串
    jmp $
    
;============================================================================
;变量
;----------------------------------------------------------------------------
wRootDirSizeForLoop	dw	RootDirSectors	; Root Directory 占用的扇区数, 在循环中会递减至零.
wSectorNo		dw	0		; 要读取的扇区号
bOdd			db	0		; 奇数还是偶数

;============================================================================
;字符串
;----------------------------------------------------------------------------
KernelFileName		db	"KERNEL  BIN", 0	; LOADER.BIN 之文件名
; 为简化代码, 下面每个字符串的长度均为 MessageLength
MessageLength		equ	13
Message:		db	"Loading......"  ; 13字节, 不够则用空格补齐. 序号 0
                db  "Mem Chk Fail!"  ;
                db  "No kernel...."  ;
                db  "Hello Kernel!"  ;
;============================================================================

;----------------------------------------------------------------------------
; 函数名: DispStr
;----------------------------------------------------------------------------
; 作用:
;	显示一个字符串, 函数开始时 dh 中应该是字符串序号(0-based)
DispStr:
	mov	ax, MessageLength
	mul	dh
	add	ax, Message
	mov	bp, ax			; ┓
	mov	ax, ds			; ┣ ES:BP = 串地址
	mov	es, ax			; ┛
	mov	cx, MessageLength	; CX = 串长度
	mov	ax, 01301h		; AH = 13,  AL = 01h
	mov	bx, 0007h		; 页号为0(BH = 0) 黑底白字(BL = 07h)
	mov	dl, 0
	int	10h			; int 10h
	ret
;----------------------------------------------------------------------------
; 函数名: ReadSector
;----------------------------------------------------------------------------
; 作用:
;	从第 ax 个 Sector 开始, 将 cl 个 Sector 读入 es:bx 中
ReadSector:
	; -----------------------------------------------------------------------
	; 怎样由扇区号求扇区在磁盘中的位置 (扇区号 -> 柱面号, 起始扇区, 磁头号)
	; -----------------------------------------------------------------------
	; 设扇区号为 x
	;                           ┌ 柱面号 = y >> 1
	;       x           ┌ 商 y ┤
	; -------------- => ┤      └ 磁头号 = y & 1
	;  每磁道扇区数     │
	;                   └ 余 z => 起始扇区号 = z + 1
	
	push	bp
	mov	bp, sp
	sub	esp, 2			; 辟出两个字节的堆栈区域保存要读的扇区数: byte [bp-2]

	mov	byte [bp-2], cl
	push	bx			; 保存 bx
	mov	bl, [BPB_SecPerTrk]	; bl: 除数
	div	bl			; y 在 al 中, z 在 ah 中
	inc	ah			; z ++
	mov	cl, ah			; cl <- 起始扇区号
	mov	dh, al			; dh <- y
	shr	al, 1			; y >> 1 (其实是 y/BPB_NumHeads, 这里BPB_NumHeads=2)
	mov	ch, al			; ch <- 柱面号
	and	dh, 1			; dh & 1 = 磁头号
	pop	bx			; 恢复 bx
	; 至此, "柱面号, 起始扇区, 磁头号" 全部得到 ^^^^^^^^^^^^^^^^^^^^^^^^
	mov	dl, [BS_DrvNum]		; 驱动器号 (0 表示 A 盘)
.GoOnReading:
	mov	ah, 2				; 读
	mov	al, byte [bp-2]		; 读 al 个扇区
	int	13h
	jc	.GoOnReading		; 如果读取错误 CF 会被置为 1, 这时就不停地读, 直到正确为止

	add	esp, 2
	pop	bp

	ret

;----------------------------------------------------------------------------
; 函数名: GetFATEntry
;----------------------------------------------------------------------------
; 作用:
;	找到序号为 ax 的 Sector 在 FAT 中的条目, 结果放在 ax 中
;	需要注意的是, 中间需要读 FAT 的扇区到 es:bx 处, 所以函数一开始保存了 es 和 bx
GetFATEntry:
	push	es
	push	bx
	push	ax
	mov	ax, KERNEL_SEG	; ┓
	sub	ax, 0100h		; ┣ 在 KERNEL_SEG 后面留出 4K 空间用于存放 FAT
	mov	es, ax			; ┛
	pop	ax
	mov	byte [bOdd], 0
	mov	bx, 3
	mul	bx			; dx:ax = ax * 3
	mov	bx, 2
	div	bx			; dx:ax / 2  ==>  ax <- 商, dx <- 余数
	cmp	dx, 0
	jz	LABEL_EVEN
	mov	byte [bOdd], 1
LABEL_EVEN:;偶数
	xor	dx, dx			; 现在 ax 中是 FATEntry 在 FAT 中的偏移量. 下面来计算 FATEntry 在哪个扇区中(FAT占用不止一个扇区)
	mov	bx, [BPB_BytsPerSec]
	div	bx			; dx:ax / BPB_BytsPerSec  ==>	ax <- 商   (FATEntry 所在的扇区相对于 FAT 来说的扇区号)
					;				dx <- 余数 (FATEntry 在扇区内的偏移)。
	push	dx
	mov	bx, 0			; bx <- 0	于是, es:bx = (KERNEL_SEG - 100):00 = (KERNEL_SEG - 100) * 10h
	add	ax, SectorNoOfFAT1	; 此句执行之后的 ax 就是 FATEntry 所在的扇区号
	mov	cl, 2
	call	ReadSector		; 读取 FATEntry 所在的扇区, 一次读两个, 避免在边界发生错误, 因为一个 FATEntry 可能跨越两个扇区
	pop	dx
	add	bx, dx
	mov	ax, [es:bx]
	cmp	byte [bOdd], 1
	jnz	LABEL_EVEN_2
	shr	ax, 4
LABEL_EVEN_2:
	and	ax, 0FFFh

LABEL_GET_FAT_ENRY_OK:

	pop	bx
	pop	es
	ret
;============================================================================
; 32 位数据段
;----------------------------------------------------------------------------
[section .data32]
align 32
DATA32:

;----------------------------------------------------------------------------
; 16位实模式下的数据地址符号
;----------------------------------------------------------------------------
_ddMCRCount:        dd 0    ; 检查完成的ADRS的数量， 为0则代表检查失败 memory check result
_ddMemSize:         dd 0    ; 内存大小
;地址范围描述符结构(Address Range Descriptor Structure)
_ADRS:
    _ddBaseAddrLow:  dd 0    ;基地址低32位
    _ddBaseAddrHigh: dd 0    ;基地址高32位
    _ddLengthLow:    dd 0    ;内存长度（字节）低32位
    _ddLengthHigh:   dd 0    ;内存长度（字节）高32位
    _ddType:         dd 0    ;ADRS的类型，用于判断是否可以被OS使用
;内存检查结果缓冲区，用于存放内存检查的ADRS结构，256个字节是为了对齐32位，256/20=12.8
;所以这个缓冲区可以存放12个ADRS
_MemChkBuf:          times 256 db 0 
;----------------------------------------------------------------------------
; 32位实模式下的数据地址符号
;----------------------------------------------------------------------------

;============================================================================