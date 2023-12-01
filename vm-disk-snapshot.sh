#!/bin/bash
echo -n "Enter VM rg:"
read rg
echo -n "Enter VM name:"
read vm
echo -n "Enter TAG value:"
read value
az vm show -g $rg -n $vm --query "[storageProfile.osDisk.name, storageProfile.dataDisks[].name]" -o tsv | sed 's/\s\+/\n/g' | awk 'NF' > diskname.log
az vm show -g $rg -n $vm --query "[storageProfile.osDisk.managedDisk.resourceGroup, storageProfile.dataDisks[].managedDisk.resourceGroup]" -o tsv | sed 's/\s\+/\n/g' | awk 'NF' > diskrg.log
az vm show -g $rg -n $vm --query "[location]" -o tsv > location.log
location=`cat location.log`
paste diskrg.log diskname.log > disklist.log
echo
cat disklist.log
disk_count=`cat disklist.log | wc -l`
echo
echo "About to create '$disk_count' snapshot for '$vm' with the above listed disks in respective resource group in '$location' location."
    read -p "Continue [Y/N]? " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
	  exit 1
    fi
if [ ! -d snapshot_log ]; then
	mkdir snapshot_log
	echo "snapshot_log directory created"
fi
while read disk;do
	diskname=`echo $disk | awk '{print $2}'`
	mod_diskname=`echo $disk | awk '{print $2}' | cut -c1-64`
	diskrg=`echo $disk | awk '{print $1}'`
	longdate=`date -d "+5 hours 30 minutes" +%d%m%Y`
	longdatetime=`date -d "+5 hours 30 minutes" +%H%M%S_%d%m%Y`
	snapshotname=$mod_diskname-$longdatetime
	vm_gen=`az disk show --name $diskname -g $diskrg --query "[hyperVGeneration]" -o tsv | sed 's/None/V1/'`
	echo
	echo "started creating snapshot $snapshotname in $diskrg"
	az snapshot create -g $diskrg -n $snapshotname --source $diskname -l $location --hyper-v-generation $vm_gen --tag "Description"="$value" >> snapshot_log/$longdate-$vm.log
if [ $? -eq 0 ]; then
echo "SNAPSHOT $snapshotname in $diskrg SUCCESSFUL"
else
echo "SNAPSHOT $snapshotname in $diskrg FAILED"
fi
done < disklist.log
