#!/bin/bash 
echo "check........"
if [ ! -e  $BXSHARE/keymaps/x11-pc-us.map ];then
    echo $BXSHARE"/keymaps/x11-pc-us.map does not exist..."
    exit 1
else
    file $BXSHARE/keymaps/x11-pc-us.map
fi

if [ ! -e  $BXSHARE/BIOS-bochs-latest ];then
    echo $BXSHARE"/BIOS-bochs-latest does not exist..."
    exit 1
else 
    file $BXSHARE/BIOS-bochs-latest
fi


echo "check over ...."
sleep 1
echo "run........"
bochs -f bochsrc