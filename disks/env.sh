#!/bin/bash
group="cs"
vms=10
vmname="cs-test"
vmsize="Standard_F4s"
location="westeurope"
username="apk8jpgdfm1rh9n6"
password="T@i6c6slm3db44ka3"
echo "=============== DEPLOYMENT ==============="
az group create -l $location -n $group --output none

for ((n=1;n<=$vms;n++))
do 	    
	r=$(( $RANDOM % 5 ));
	o=$(( $RANDOM % 4));
	disksraid=""
	disksother=""
	disks=""
	echo "DISKS VM: "${vmname}${n}" | "${r}" RAID | "${o}" Others"

	name=`basename -a $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-5} | head -n 1)`
	for ((x=0;x<$r;x++))
	do
		disksraid+=${vmname}${n}-RAID-$x-$name" "
		az disk create -g $group -n ${vmname}${n}-RAID-$x-$name --sku Standard_LRS --size-gb 5 --output none &
	done
	for ((x=0;x<$o;x++))
	do
		disksother+=${vmname}${n}-Other-$x-$name" "
		az disk create -g $group -n ${vmname}${n}-Other-$x-$name --sku Standard_LRS --size-gb 5 --output none &
	done
	wait
	disks=$disksraid$disksother
	az vm create --resource-group $group --name "${vmname}${n}" --image "UbuntuLTS" --size $vmsize --admin-username $username --admin-password $password --location $location --attach-data-disks $disks --output none &
done
wait
for ((n=1;n<=$vms;n++))
do 	
	ip=`basename -a $(az vm show -g $group -n ${vmname}${n} -d | awk '/publicIps/{match($0,/[0-9]+.[0-9]+.[0-9]+.[0-9]+/); ip = substr($0,RSTART,RLENGTH); print ip}')`
	echo "IP VM: "${vmname}${n}" | "$ip
done
for ((n=1;n<=$vms;n++))
do 	
echo "Extension VM: "${vmname}${n}
	az vm extension set --resource-group $group --vm-name ${vmname}${n} --name "CustomScriptForLinux" --publisher Microsoft.OSTCExtensions --settings '{"fileUris": ["https://raw.githubusercontent.com/akaddour/az/master/raid-disks.sh"],"commandToExecute": "./raid-disks.sh"}' --output none &
done
wait
echo "=============== TEST ===============" 
for ((n=1;n<=$vms;n++))
do 	
	echo "TEST RAID VM: "${vmname}${n}
	ip=`basename -a $(az vm show -g $group -n ${vmname}${n} -d | awk '/publicIps/{match($0,/[0-9]+.[0-9]+.[0-9]+.[0-9]+/); ip = substr($0,RSTART,RLENGTH); print ip}')`
	status=`basename -a $(sshpass -p $password ssh -q -t $username@$ip 'sudo mdadm -D /dev/md0 | grep "State :"')`
	devices=`basename -a $(sshpass -p $password ssh -q -t $username@$ip 'sudo mdadm -D /dev/md0 | grep "Active Devices :"')`	
	echo $status
	echo $devices
done
echo "=============== END ==============="
