# Automated script to build a 2 node NFS cluster
## Usage:
-------

This script is used to create a test 2 node cluster following the documentation:

https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-pacemaker
https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-nfs

by default it uses SLES 15 SP1 for SAP, you can use any other image by adding the option -i or --image and image Urn

--------------------

## The script will do the below:
* Ask user for input for username and password, to be used for accessing the VM

NOTE: Another option is to create a file username.txt contains the username and password.txt contains the password in the same location as script so that it will automatically read them for username and password
* Create a resouce group, load balancer and availabilty set
* Crete 3 VMs, 2 for cluster and one as iscsi target for sbd device
* Attach the machines to the load balancer, and update the NSG created to allow SSH from users public IP only
* Starting a custom script extension to configure:
  * iscsi initiators and connect them to iscsi target
  * format the local disks and create the LVM to prepare them for drbd
  * SBD device setup
  * DRBD setup 
  * Cluster installtion and creation of the nodes
  * make sure pacakges version and other cluster configuration matching MS documentation mentioned in the usage section 

---------------------

## Tools required to run it:
* WSL (windows subsystem for linux) or any Linux system
* Azure CLI installed on the machine and already logged in

---------------------
## limitations:
* Currently the script takes 40 min to finish the deploying the whole cluster, most of the time is spent waiting for the drbd disks to ready.
* Unfortunately, the names of the VMs cannot be changed as there is a dependancy on the scripts that configures the cluster on the hostname. Although the resouce group name can be changed by editing rgname variable directly on the script.

---------------------
## To do list:
* Enchance the deployment time by working on having parallel deployments happening together
* Asks for input from user for prefix to be added for the machines name, to remove the dependancy on current names
* Enhance logging mechanism and log file content.



