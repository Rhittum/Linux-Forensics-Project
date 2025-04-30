#!/bin/bash

echo "Hello World" > /mnt/test_ext4/file1.txt
echo "Important Data" > /mnt/test_ext4/file2.txt
echo "This is a very unique line to be recovered later 123ABCxyz!" > /mnt/test_ext4/file3.txt

dd if=/dev/urandom of=/mnt/test_ext4/file4.txt bs=1M count=1
dd if=/dev/urandom of=/mnt/test_ext4/file5.txt bs=1M count=1

cp /bin/ls /mnt/test_ext4/ls_copy
cp /home/rhittum/wp1817964-interstellar-wallpapers.jpg /mnt/test_ext4

mkdir /mnt/test_ext4/folder1
echo "Hidden message" > /mnt/test_ext4/folder1/secret.txt

