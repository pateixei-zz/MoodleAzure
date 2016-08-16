# MoodleAzure
Moodle deployment using Azure Resource Manager Template

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https://raw.githubusercontent.com/pateixei/MoodleAzure/master/azuredeploy.json)
This Azure Resource Manager template creates a clustered moodle environment. 

The following resources will be created:

- a Virtual Machine Scale Set (up to 10 instances) for the web tier, with auto-scale configured
- 04 nodes Gluster Cluster  (2 Premium disks attached, raid0, a gluster brick in each virtual machine)
- 02 nodes MariaDb Active-Active Cluster
- an Internal Load Balancer in front of the MariaDb clustered
- an public Load Balancer in front of the Virtual Machine Scale Set (web tier)
- a virtual machine used as a JumpBox for the environment, acessible via SSH and http
- a lot of underlying resources need for the environment (virtual network, storage accounts, etc)

Hope it helps.
Feedbacks are welcome.


