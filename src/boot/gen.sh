
#!/bin/bash
file_path=$(cd `dirname $0`; pwd)
project_path=$file_path/../..
target_path=$project_path/target
echo $file_path
echo $target_path
if [ ! -d $target_path ]; then
    mkdir $target_path
    mkdir $target_path/boot
fi
#if [ -e "Origin.img" ]; then
 #    rm -rf hd3M.img  
#fi

nasm -I include/ -o $target_path/boot/mbr.bin mbr.S && dd if=$target_path/boot/mbr.bin of=$project_path/Origin.img bs=512 count=1  conv=notrunc
nasm -I include/ -o $target_path/boot/loader.bin loader.S && dd if=$target_path/boot/loader.bin of=$project_path/Origin.img bs=512 count=1 seek=2 conv=notrunc