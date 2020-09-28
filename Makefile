#!Makefile

all: MBR LOADER

.PHONY:MBR
MBR:
	nasm -f bin -i ./src/boot/include/ ./src/boot/boot.asm -o ./boot.bin
	dd if=./boot.bin of=Origin.img  bs=512 count=1 conv=notrunc
.PHONY:LOADER
#LOADER:
#	nasm -f bin ./boot/LOADER.s -o ./boot/LOADER.bin
#	dd if=./boot/LOADER.bin of=Origin.img seek=1
.PHONY:run
run:
	qemu   Origin.img -monitor stdio
.PHONY:qemu
qemu:
	qemu  Origin.img -monitor stdio
qemu-gdb:
	qemu -s -S Origin.img -monitor stdio
bochs:
	bochs
