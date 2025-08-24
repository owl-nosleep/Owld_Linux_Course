#!/bin/bash
# setup_lab_a.sh

# 建立複雜目錄結構
mkdir -p /tmp/lab_a/{level1,level2,level3}/{alpha,beta,gamma}
mkdir -p /tmp/lab_a/.hidden/{secret1,secret2}
mkdir -p /tmp/lab_a/maze/{room1,room2,room3}/{door1,door2}

# 建立各種flag檔案
echo "flag{welcome_to_linux}" > /tmp/lab_a/level1/flag1.txt
echo "flag{hidden_in_plain_sight}" > /tmp/lab_a/level2/beta/.flag2.txt
echo "This is not a flag" > /tmp/lab_a/level1/alpha/notflag.txt
echo "The flag{directory_master} is here" > /tmp/lab_a/level3/gamma/readme.md
echo "flag{permission_denied}" > /tmp/lab_a/.hidden/secret1/flag3.dat
chmod 000 /tmp/lab_a/.hidden/secret1/flag3.dat
echo "flag{size_matters}" > /tmp/lab_a/maze/room2/door1/bigflag.bin
dd if=/dev/zero bs=1M count=5 >> /tmp/lab_a/maze/room2/door1/bigflag.bin 2>/dev/null
echo "ZmxhZ3tiYXNlNjRfZGVjb2RlZH0K" | base64 -d > /tmp/lab_a/level2/alpha/encoded.txt
ln -s /tmp/lab_a/level1/flag1.txt /tmp/lab_a/level3/alpha/flag_link.txt