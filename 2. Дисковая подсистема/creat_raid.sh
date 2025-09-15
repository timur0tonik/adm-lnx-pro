#!/bin/bash

raid="/dev/md22"
disks=("/dev/sdb" "/dev/sdc" "/dev/sdd")
mount="/raid"

for d in "${disks[@]}"; do
    mdadm --zero-superblock --force $d
done

mdadm --create --verbose $raid --level=5 --raid-devices=${#disks[@]} ${disks[@]}

sleep 5

mkfs.ext4 -F $raid

mkdir -p $mount

mount $raid $mount

echo "RAID5 создан и смонтирован в $mount"
