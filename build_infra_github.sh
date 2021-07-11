#!/bin/bash
# build the rg , AS and 2 VMs for NFS share and one VM for iscsi target

logfile="./build_infra_log"


cat << EOF
Usage :
-------

This script is used to create a test 2 node cluster following the documentation:

https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-pacemaker
and
https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-nfs

by default it uses SLES 15 SP1 for SAP, you can use any other image by adding the option -i or --image and image Urn

--------------------
EOF

rgname="sles-ha-rg"
loc="eastus"
asname="slesha"
vmname1="nfs-0"
vmname2="nfs-1"
vmname3="sbd-storage"
lbname="sles-ha-lb"
vnetname="havnet"
subnetname="hasubnet"
sku_size="Standard_D2s_v3"
if [[ $# -gt 0 ]]
then
	if [[ $1=='-i' || $1 == '--image' ]]
	then
	offer=$2
	fi
else
offer="SUSE:sles-sap-15-sp1:gen1:latest"
fi

frontendip="nw01"
backendpoolname="nfs-cls"
probename="nw1-probe"
sshpubkeyfile="/home/$USER/.ssh/id_rsa.pub"


if [ -f "./username.txt" ] 
then 
    username=`cat username.txt`
else
    read -p "Please enter the username: " username
fi

if [ -f "./password.txt" ]
then
    password=`cat password.txt`
else
    read -s -p "Please enter the password: " password
fi

echo""
date >> $logfile
echo "Creating RG .."
az group create --name $rgname --location $loc >> $logfile

echo "Creating VNET .."
az network vnet create --name $vnetname -g $rgname --address-prefixes 10.0.0.0/24 --subnet-name $subnetname --subnet-prefixes 10.0.0.0/24  >> $logfile

echo "Creating availability set .."
az vm availability-set create -n $asname -g $rgname --platform-fault-domain-count 3 --platform-update-domain-count 20  >> $logfile

echo "Creating load balancer .."
az network lb create --resource-group $rgname --name $lbname --location $loc --backend-pool-name $backendpoolname --frontend-ip-name $frontendip --private-ip-address "10.0.0.4" --sku "Standard" --vnet-name $vnetname --subnet $subnetname  >> $logfile

echo "Creating First node, with both ssh key and password authentication methods .."
az vm create -g $rgname -n $vmname1 --admin-username $username --admin-password $password --authentication-type "all"  --ssh-key-values $sshpubkeyfile --availability-set $asname --image $offer --data-disk-sizes-gb 6 --vnet-name $vnetname --subnet $subnetname --public-ip-sku Standard  >> $logfile

echo "Creating Second node, with both ssh key and password authentication methods .."
az vm create -g $rgname -n $vmname2 --admin-username $username --admin-password $password --authentication-type "all" --ssh-key-values $sshpubkeyfile --availability-set $asname --image $offer --data-disk-sizes-gb 6 --vnet-name $vnetname --subnet $subnetname --public-ip-sku Standard  >> $logfile

echo "Creating iscsi target machine, with both ssh key and password authentication methods .."
az vm create -g $rgname -n $vmname3 --admin-username $username --admin-password $password --authentication-type  "all" --ssh-key-values $sshpubkeyfile --image $offer --vnet-name $vnetname --subnet $subnetname  >> $logfile

echo "Connecting the machines to the load balancer .."
az network lb probe create --lb-name $lbname --resource-group $rgname --name $probename --port 61000 --protocol Tcp  >> $logfile

nic1name1=`az vm show -g $rgname -n $vmname1  --query networkProfile.networkInterfaces[].id -o tsv | cut -d / -f 9`
az network nic ip-config address-pool add --address-pool $backendpoolname --ip-config-name ipconfig$vmname1 --nic-name $nic1name1 --resource-group $rgname --lb-name $lbname  >> $logfile

nic1name2=`az vm show -g $rgname -n $vmname2  --query networkProfile.networkInterfaces[].id -o tsv | cut -d / -f 9` 
az network nic ip-config address-pool add --address-pool $backendpoolname --ip-config-name ipconfig$vmname2 --nic-name $nic1name2 --resource-group $rgname --lb-name $lbname  >> $logfile

echo "Creating load balancing rule .."
az network lb rule create --resource-group $rgname --lb-name $lbname --name "nw1-rule" --backend-port 0 --frontend-port 0 \
 --frontend-ip-name $frontendip --backend-pool-name $backendpoolname --protocol All --floating-ip true \
 --idle-timeout 30 --probe-name $probename  >> $logfile

echo "Please wait while we prepare the iscsi target .."
 az vm extension set \
  --resource-group $rgname \
  --vm-name $vmname3 \
  --name customScript \
  --publisher Microsoft.Azure.Extensions \
  --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/imabedalghafer/sles_ha_scripts/master/config_iscsi_target.sh"],"commandToExecute": "./config_iscsi_target.sh"}' >> $logfile

echo "Start configuring the nodes .."
echo "We will start by configuring the iscsi initiator and preparing the disks the local disks by preparing the LVM .."
az vm extension set \
  --resource-group $rgname \
  --vm-name $vmname1 \
  --name customScript \
  --publisher Microsoft.Azure.Extensions \
  --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/imabedalghafer/sles_ha_scripts/master/config_iscsi_initiator.sh"],"commandToExecute": "./config_iscsi_initiator.sh"}'   >> $logfile & 

az vm extension set \
  --resource-group $rgname \
  --vm-name $vmname2 \
  --name customScript \
  --publisher Microsoft.Azure.Extensions \
  --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/imabedalghafer/sles_ha_scripts/master/config_iscsi_initiator.sh"],"commandToExecute": "./config_iscsi_initiator.sh"}' >> $logfile

echo 'Configuring the sbd device on both nodes ..'
az vm extension set \
  --resource-group $rgname \
  --vm-name $vmname1 \
  --name customScript \
  --publisher Microsoft.Azure.Extensions \
  --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/imabedalghafer/sles_ha_scripts/master/sbd_setup.sh"],"commandToExecute": "./sbd_setup.sh"}' >> $logfile

az vm extension set \
  --resource-group $rgname \
  --vm-name $vmname2 \
  --name customScript \
  --publisher Microsoft.Azure.Extensions \
  --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/imabedalghafer/sles_ha_scripts/master/sbd_setup.sh"],"commandToExecute": "./sbd_setup.sh"}'  >> $logfile

echo 'Configuring the drbd devices, starting from second node then first node'
az vm extension set \
  --resource-group $rgname \
  --vm-name $vmname2 \
  --name customScript \
  --publisher Microsoft.Azure.Extensions \
  --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/imabedalghafer/sles_ha_scripts/master/drbd_setup.sh"],"commandToExecute": "./drbd_setup.sh"}' >> $logfile

az vm extension set \
  --resource-group $rgname \
  --vm-name $vmname1 \
  --name customScript \
  --publisher Microsoft.Azure.Extensions \
  --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/imabedalghafer/sles_ha_scripts/master/drbd_setup.sh"],"commandToExecute": "./drbd_setup.sh"}'  >> $logfile

echo 'Updating NSGs with public IP and allowing ssh access from that IP'
my_pip=`curl ifconfig.io`
nsg_list=`az network nsg list -g $rgname  --query [].name -o tsv`
for i in $nsg_list
do
    az network nsg rule create -g $rgname --nsg-name $i -n buildInfraRule --priority 100 --source-address-prefixes $my_pip  --destination-port-ranges 22 --access Allow --protocol Tcp >> $logfile
done

#adding a sleep for 30 seconds to allow for NSG rules to get updated
sleep 30

echo 'As we are using this machine to deploy and we can authenticate without password, we will update the authenctication between the 2 cluster nodes ..'
echo 'Generating and getting RSA public key of root user on first node ..'
vm_1_pip=`az vm list-ip-addresses -g $rgname -n $vmname1 --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`
vm_2_pip=`az vm list-ip-addresses -g $rgname -n $vmname2 --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`

# getting VM 1 public key
ssh -o "StrictHostKeyChecking=no" $username@$vm_1_pip 'sudo cat /dev/zero | sudo ssh-keygen -t rsa -q -N ""' >> $logfile
vm_1_public_key=`ssh -o "StrictHostKeyChecking=no" $username@$vm_1_pip 'sudo cat /root/.ssh/id_rsa.pub'`

#getting VM 2 public key
ssh -o "StrictHostKeyChecking=no" $username@$vm_2_pip 'sudo cat /dev/zero | sudo ssh-keygen -t rsa -q -N ""' >> $logfile
vm_2_public_key=`ssh -o "StrictHostKeyChecking=no" $username@$vm_2_pip 'sudo cat /root/.ssh/id_rsa.pub'`

echo 'Done getting the ssh keys, updating both nodes to have passwordless root access between them'
az vm run-command invoke -g $rgname -n $vmname1 --command-id RunShellScript --scripts "echo $vm_2_public_key > /root/.ssh/authorized_keys" >> $logfile
az vm run-command invoke -g $rgname -n $vmname2 --command-id RunShellScript --scripts "echo $vm_1_public_key > /root/.ssh/authorized_keys" >> $logfile

echo 'Entering the final phase of configuring the cluster, we will start with node 2 then node 1'
az vm extension set \
  --resource-group $rgname \
  --vm-name $vmname2 \
  --name customScript \
  --publisher Microsoft.Azure.Extensions \
  --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/imabedalghafer/sles_ha_scripts/master/cluster_setup.sh"],"commandToExecute": "./cluster_setup.sh"}' >> $logfile

az vm extension set \
  --resource-group $rgname \
  --vm-name $vmname1 \
  --name customScript \
  --publisher Microsoft.Azure.Extensions \
  --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/imabedalghafer/sles_ha_scripts/master/cluster_setup.sh"],"commandToExecute": "./cluster_setup.sh"}' >> $logfile

echo "Woah !! , that was a really hard task, thanks for waiting, enjoy your day ^_^"
