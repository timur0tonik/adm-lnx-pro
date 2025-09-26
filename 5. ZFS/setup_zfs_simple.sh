#!/bin/bash

echo "Настройка сервера для ZFS (домашнее задание)..."
echo "=============================================="

apt update && apt install -y zfsutils-linux

zpool create otus1 mirror /dev/sdb /dev/sdc
zpool create otus2 mirror /dev/sdd /dev/sde
zpool create otus3 mirror /dev/sdf /dev/sdg
zpool create otus4 mirror /dev/sdh /dev/sdi

zfs set compression=lzjb otus1
zfs set compression=lz4 otus2
zfs set compression=gzip-9 otus3
zfs set compression=zle otus4

for pool in otus1 otus2 otus3 otus4; do
    wget -O "/$pool/pg2600.converter.log" https://gutenberg.org/cache/epub/2600/pg2600.converter.log >/dev/null
done

wget -O /root/archive.tar.gz --no-check-certificate 'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download' >/dev/null
mkdir -p /root/zpoolexport
tar -xzvf /root/archive.tar.gz -C /root/zpoolexport >/dev/null

zpool import -d /root/zpoolexport/zpoolexport/ otus

wget -O /root/otus_task2.file --no-check-certificate 'https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download' >/dev/null

zfs create otus/test
zfs destroy -r otus/test@today 2>/dev/null || true
zfs receive -F otus/test@today < /root/otus_task2.file

echo "=============================================="
echo "Сервер настроен."
echo "=============================================="