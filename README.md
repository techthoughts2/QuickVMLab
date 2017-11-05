## QuickVMLab
Powershell tool capable of rapidly building Hyper-V VMs from specified source VHDX

### Synopsis
Rapidly provisions Hyper-V VMs from source VHDXs specified by user to quickly make VMs for lab/testing

### Description
Serves as a tool to rapidly create a specified number of VMs quickly.  The user can specify several basic details such as sourcevhdx to build off of, hostdevice to build on, gen1 or gen2, VMSwitch to attach VM to, basic naming prefix, and destination to place VM/VHDXs at.  Memory is set as a static variable for dynamic RAM of starting 1GB, Max 8GB, min 1GB.  CPU is set as a static variable with 2 vCPU. The primarily purpose of this tool is to simply generate a rapid number of simple VMs off of a source VHDX to quickly start testing/lab work. Only one VHDX can be sourced per run, so only one OS type can be built each run.

### Prerequisites

* Script must be run by user with admin privelages on the Hyper-V host
* Tested on PowerShell 5.1
* Source VHDX
  * A VHDX that you have previously loaded with an OS and made ready for use (ie Server 2016 sysprepped VHDX)
* Hyper-V Server with enough storage and compute resources to handle the VM workload you are planning to quickly build out

### How to run

QuickVMLab can be run directly on the Hyper-V host by specifying localhost for the **HostDevice** parameter.

QuickVMLab can also be run from a management device if you specify the HostName of the Hyper-V host for the **HostDevice** parameter.

Examples:

```PowerShell
#This will build 1 VM on the local device you are running on and source the VHDX from D:\VMBaseImages\2008R2.vhdx.  VMs will be placed in C:\ClusterStorage\Volume1\VMs and will be built as Gen 1 VMs.  They will be attached to VMSwitch Outbound and will carry the prefix of TestVM-$i.  Verbose is not specified so only brief confirmation messaging will be output to the user.
New-QuickVMLab -HostDevice localhost -NumberOfVms 1 -SourceVHDXPath D:\VMBaseImages\2008R2.vhdx -Path C:\ClusterStorage\Volume1\VMs -VMGeneration 1 -VMSwitchName Outbound -VMNamePrefix TestVM
```

```PowerShell
#This will build 2 VMs on HYP2 and source the VHDX from D:\VMBaseImages\2012R2.vhdx.  VMs will be placed in C:\ClusterStorage\Volume1\VMs and will be built as Gen 2 VMs.  They will be attached to VMSwitch Outbound and will carry the prefix of TestVM-$i.  Verbose is not specified so only brief confirmation messaging will be output to the user.
New-QuickVMLab -HostDevice HYP2 -NumberOfVms 2 -SourceVHDXPath D:\VMBaseImages\2012R2.vhdx -Path C:\ClusterStorage\Volume1\VMs -VMGeneration 2 -VMSwitchName Outbound -VMNamePrefix TestVM
```

```PowerShell
#This will build 5 VMs on HYP1 and source the VHDX from D:\VMBaseImages\2016.vhdx.  VMs will be placed in C:\ClusterStorage\Volume1\VMs and will be built as Gen 2 VMs.  They will be attached to VMSwitch Outbound and will carry the prefix of TestVM-$i.  Verbose is specified so a detailed build process will be output to the user.
New-QuickVMLab -HostDevice HYP1 -NumberOfVms 5 -SourceVHDXPath D:\VMBaseImages\2016.vhdx -Path C:\ClusterStorage\Volume1\VMs -VMGeneration 2 -VMSwitchName Outbound -VMNamePrefix TestVM -Verbose
```
### Contributors

Author: Jacob Morrison

http://techthoughts.info

### Notes

* You can only source one VHDX per function execution.  As such you can only build one OS flavor per run.  Varying OS flavors on a single run is not supported.
* This script can be run from an external management machine as long as the hostname is specified for the destination hyp and run as a user that has administrative privelages on the Hypervisor
* You can only source one VHDX per execution.  As such you can only build one OS flavor per run.  Varying OS flavors on a single run is not supported.
* The purpose of this script is simply to rapidly generate a certain number of VMs quickly for testing or lab purposes.