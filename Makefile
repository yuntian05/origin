#!Makefile

all: MBR LOADER

.PHONY:MBR
MBR:
	nasm -f bin ./boot/MBR.s -o ./boot/MBR.bin
	dd if=./boot/MBR.bin of=BHOS.vhd seek=0
.PHONY:LOADER
LOADER:
	nasm -f bin ./boot/LOADER.s -o ./boot/LOADER.bin
	dd if=./boot/LOADER.bin of=BHOS.vhd seek=1
.PHONY:run
run:
	qemu BHOS.vhd
.PHONY:qemu
qemu:
	qemu BHOS.vhd