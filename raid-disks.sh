#!/bin/bash
apt-get update -y
apt-get install mdadm -y --no-install-recommends
cp /etc/fstab /etc/fstab.original
# udev rules for Azure storage devices https://github.com/Azure/WALinuxAgent/blob/develop/config/66-azure-storage.rules
attached=`basename -a $(find /sys/class/block -name 'sd[a-z]')`
reserved=`basename -a $(readlink -f /dev/disk/azure/root /dev/disk/azure/resource)`
for i in $reserved
do
	attached="${attached/$i/}"
done
i=0
RAID_CMD="mdadm --create /dev/md1 --level 0 --raid-devices "
RAID_DISKS=""
for d in $attached
do
	i=$((i+1))
	disk="/dev/${d}"
	(echo n; echo p; echo 1; echo ; echo ; echo p; echo w;) | fdisk ${disk}
	RAID_DISKS+=" ${disk}1"
done
RAID_CMD+=$i
RAID_CMD+=$RAID_DISKS
for d in $attached 
do
	disk="/dev/${d}"
	(echo n; echo p; echo 1; echo ; echo ; echo p; echo t; echo fd; echo p; echo w;) | fdisk ${disk} 
done
eval "$RAID_CMD"
mkfs.ext4 /dev/md1 
sudo mkdir /mnt/raid1
mount -a
