# Automated script to build a 2 node NFS cluster
## Usage:
-------

This script is used to create a test 2 node cluster following the documentation:

https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-pacemaker
https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-nfs
https://www.suse.com/c/azure-shared-disks-excercise-w-sles-for-sap-or-sle-ha/

by default it uses SLES 15 SP2 for SAP, you can use any other image by adding the option -i and image Urn, or to use -s for shared disk setup

also both options can be used.

examples:
  ./build_infra_github_v2.sh -i <Image URN> -s # to use both options
  ./build_infra_github_v2.sh -s # to use default image with shared disk options

--------------------

## The V2 script will do the below:
* Ask user for input for username and password, to be used for accessing the VM
* An option could be passed of "-s" to allow the use of shared disk

NOTE: Another option is to create a file username.txt contains the username and password.txt contains the password in the same location as script so that it will automatically read them for username and password
* Create a resource group, load balancer and availability set
* Crete 3 VMs, 2 for cluster and one as ISCSI target for SBD device
* Attach the machines to the load balancer, and update the NSG created to allow SSH from users public IP only
* Starting a custom script extension to configure:
  * ISCSI initiators and connect them to ISCSI target
  * format the local disks and create the LVM to prepare them for DRBD
  * SBD device setup
  * DRBD setup 
  * Cluster installtion and creation of the nodes
  * make sure packages  version and other cluster configuration matching MS documentation mentioned in the usage section 
* In case a shared disk was used
  * Only the 2 main VMs would be created without the SBD node
  * 2 new shared disks would created and added to the VMs 
  * volume group is built on one of them to used for sharing the NFS, and the other disk would be the SBD disk
  * A LVM activation resource would be added to determine on which node the volume group should be activated.


---------------------

## Tools required to run it:
* WSL (windows subsystem for linux) or any Linux system
* Azure CLI installed on the machine and already logged in
* A ready ssh RSA key pair for the user running the script on the Linux VM (you can use ssh-keygen -t rsa to generate).

---------------------
## limitations:
* Unfortunately, the names of the VMs cannot be changed as there is a dependency  on the scripts that configures the cluster on the hostname. Although the resource group name can be changed by editing rgname variable directly on the script.

---------------------
## To do list:
* Asks for input from user for prefix to be added for the machines name, to remove the dependancy on current names
* Enhance logging mechanism and log file content.



