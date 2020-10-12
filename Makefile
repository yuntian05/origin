#!Makefile
#==============================================================================
# 变量
#------------------------------------------------------------------------------
#编译链接的中间目录
t = target
tb = target/boot
tk = target/kernel

#所需软盘镜像。可以指定已存在的软盘镜像，系统内核将被写入这里
FD = Origin.img
# 硬盘镜像 

# 镜像挂载点，自指定，必须存在于自己的计算机上
ImgMountPoint = /media/disk

# 所需的编译器已经编译参数
ASM = nasm
ASMFlagsOfBoot = -I src/boot/include/
CC	= gcc
#==============================================================================
# 目标程序以及编译的中间文件
#------------------------------------------------------------------------------
OrginBoot = $(tb)/boot.bin $(tb)/loader.bin
#==============================================================================
# 所有的功能伪命令
#------------------------------------------------------------------------------
.PHONY: nop all image debug run clean realclean
#默认选项(make 没有参数，自动执行)，提示一下用户我们的makefile有哪些功能
nop:
	@echo "all 			编译所有文件，生成目标文件(二进制文件，boot.bin)"
	@echo "image 		生成系统镜像文件"
	@echo "debug 		打开bochs进行系统的运行和调试"
	@echo "run 			提示用于如何将系统安装到虚拟机上运行"
	@echo "clean 		清理所有的中间编译文件"
	@echo "realclean 	完全清理：清理所有的中间编译文件以及生成的目标文件（二进制文件）"

#编译所有文件
all: $(OrginBoot)

#生成系统镜像文件
image: $(FD) $(OrginBoot)
	dd if=$(tb)/boot.bin of=$(FD) bs=512 count=1 conv=notrunc
	sudo mount -o loop $(FD) $(ImgMountPoint)
	sudo cp -fv $(tb)/loader.bin $(ImgMountPoint)
	sudo umount $(ImgMountPoint)

#使用bochs进行系统的运行与调试
debug:$(FD)
	bochs -q

#运行系统：打印提示信息
run:
	@echo "使用vbox等虚拟机挂载Origin.img软盘，即可开始运行！"

#清理所有的中间编译文件
clean:
	@echo ""

#完全清理：清理所有的中间编译文件以及生成的目标文件（二进制文件）
realclean:
	rm -f $(OrginBoot)

#==============================================================================
# 目标程序以及编译的中间文件
#------------------------------------------------------------------------------
#软盘镜像文件不存在，应该怎么生成
$(FD):
	dd if=/dev/zero of=$(FD) bs=512 count=2880

#引导程序的生成规则
$(tb)/boot.bin: src/boot/include/fat12hdr.inc
$(tb)/boot.bin: src/boot/boot.asm 
	$(ASM) $(ASMFlagsOfBoot) -o $@ $<

#加载程序loader
$(tb)/loader.bin: src/boot/loader.asm 
	$(ASM) $(ASMFlagsOfBoot) -o $@ $<
#==============================================================================

