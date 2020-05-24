#!/bin/bash

apt-get update -y
apt-get install mdadm jq lsscsi -y --no-install-recommends

cp /etc/fstab /etc/fstab.original
# udev rules for Azure storage devices https://github.com/Azure/WALinuxAgent/blob/develop/config/66-azure-storage.rules

luns=`basename -a $(curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/storageProfile/dataDisks?api-version=2019-06-01" | jq '.[] | select(.name | ascii_upcase | test("[a-zA-Z]*[0-9]*RAID";"i")) | .lun') | sed 's/"//' | sed 's/"//'`
locals=`basename -a $(lsscsi -t | grep "disk" | sed 's/\/dev\// /' | sed 's/[/([0-9]*:[0-9]*:[0-9]*://' | sed 's/]//' | awk '{print $1$3}')`
reserved=`basename -a $(readlink -f /dev/disk/azure/root /dev/disk/azure/resource)`

unset toRaid
c=0
for i in $luns
do
	val=`basename -a $(grep -i $i <<< "$locals" | sed 's/[0-9]*//' | tr " " "\n" )`
    for x in $val
    do
        exist="0"
        for i in $reserved
        do
            if [[ "$i" == "$x" ]]
            then
                exist="1"
            fi
        done
            if [[ "$exist" == "0" ]]
            then
                toRaid[c]=$x
                c=$((c+1))
            fi
    done
done
toRaid="${toRaid[@]}"

function enoughDisks() {
  
length=${#toRaid[@]}
if (( $length < 2 ))
then
    exit
fi

}
enoughDisks
md=9
i=0
RAID_CMD="mdadm --create /dev/md${md} --level 0 --raid-devices "
RAID_DISKS=""
for d in $toRaid
do
    disk="/dev/${d}"
    (echo n; echo p; echo 1; echo ; echo ; echo p; echo w;) | fdisk ${disk}
    RAID_DISKS+=" ${disk}1"
done
RAID_CMD+=$length
RAID_CMD+=$RAID_DISKS
for d in $toRaid 
do
    disk="/dev/${d}"
    (echo n; echo p; echo 1; echo ; echo ; echo p; echo t; echo fd; echo p; echo w;) | fdisk ${disk} 
done
eval "$RAID_CMD"
mkfs.ext4 /dev/md${md}
sudo mkdir -p /mnt/raid1
mount -a
