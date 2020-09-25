#!Makefile

all: MBR LOADER

.PHONY:MBR
MBR:
	nasm -f bin ./boot/MBR.s -o ./boot/MBR.bin
	dd if=./boot/MBR.bin of=Origin.img seek=0
.PHONY:LOADER
LOADER:
	nasm -f bin ./boot/LOADER.s -o ./boot/LOADER.bin
	dd if=./boot/LOADER.bin of=Origin.img seek=1
.PHONY:run
run:
	qemu -S Origin.img -monitor stdio
.PHONY:qemu
qemu:
	qemu -S Origin.img -monitor stdio