<#
    .SYNOPSIS
        Rapidly provisions Hyper-V VMs from source VHDXs specified by user to quickly make VMs for lab/testing
    .DESCRIPTION
        Serves as a tool to rapidly create a specified number of VMs quickly.  The user can specify several basic details such as sourcevhdx to build off of, hostdevice to build on, gen1 or gen2, VMSwitch to attach VM to, basic naming prefix, and destination to place VM/VHDXs at.  Memory is set as a static variable for dynamic RAM of starting 1GB, Max 8GB, min 1GB.  CPU is set as a static variable with 2 vCPU. The primarily purpose of this tool is to simply generate a rapid number of simple VMs off of a source VHDX to quickly start testing/lab work. Only one VHDX can be sourced per run, so only one OS type can be built each run.
    .PARAMETER NumberOfVms
        Specify the number of vms you wish to be build.
    .PARAMETER HostDevice
        Specify the name of the Hyper-V host you wish to build the VMs on
    .PARAMETER NumberOfVms
        Specify the total number of VMs you wish to create in one run
    .PARAMETER SourceVHDXPath
        Specify the location that contains the parent OS VHDX file
    .PARAMETER Path
        Specify the file path where you want the new VMs to be placed at
    .PARAMETER VMGeneration
        Specify the generation type of the VM (1 or 2)
    .PARAMETER VMSwitchName
        Specify the VMSwitch to associate with the NIC of the VM
    .PARAMETER VMNamePrefix
        This is the beginning of the name of the VM.  Example: Prefix is set as: TestVM --> This results in VMs being built with this sequence based on VM number: ie TestVM-1, TestVM-2, TestVM-3, etc.  This parameter must adhere to normal windows computer name guidelines except that it must also be between 5 and 13 characters.
    .EXAMPLE
        New-QuickVMLab -HostDevice localhost -NumberOfVms 1 -SourceVHDXPath D:\VMBaseImages\2008R2.vhdx -Path C:\ClusterStorage\Volume1\VMs -VMGeneration 1 -VMSwitchName Outbound -VMNamePrefix TestVM

        This will build 1 VM on the local device you are running on and source the VHDX from D:\VMBaseImages\2008R2.vhdx.  VMs will be placed in C:\ClusterStorage\Volume1\VMs and will be built as Gen 1 VMs.  They will be attached to VMSwitch Outbound and will carry the prefix of TestVM-$i.  Verbose is not specified so only brief confirmation messaging will be output to the user.
    .EXAMPLE
        New-QuickVMLab -HostDevice HYP2 -NumberOfVms 2 -SourceVHDXPath D:\VMBaseImages\2012R2.vhdx -Path C:\ClusterStorage\Volume1\VMs -VMGeneration 2 -VMSwitchName Outbound -VMNamePrefix TestVM

        This will build 2 VMs on HYP2 and source the VHDX from D:\VMBaseImages\2012R2.vhdx.  VMs will be placed in C:\ClusterStorage\Volume1\VMs and will be built as Gen 2 VMs.  They will be attached to VMSwitch Outbound and will carry the prefix of TestVM-$i.  Verbose is not specified so only brief confirmation messaging will be output to the user.
    .EXAMPLE
        New-QuickVMLab -HostDevice HYP1 -NumberOfVms 5 -SourceVHDXPath D:\VMBaseImages\2016.vhdx -Path C:\ClusterStorage\Volume1\VMs -VMGeneration 2 -VMSwitchName Outbound -VMNamePrefix TestVM -Verbose

        This will build 5 VMs on HYP1 and source the VHDX from D:\VMBaseImages\2016.vhdx.  VMs will be placed in C:\ClusterStorage\Volume1\VMs and will be built as Gen 2 VMs.  They will be attached to VMSwitch Outbound and will carry the prefix of TestVM-$i.  Verbose is specified so a detailed build process will be output to the user.
    .NOTES
        You can only source one VHDX per execution.  As such you can only build one OS flavor per run.  Varying OS flavors on a single run is not supported.
        Author: Jacob Morrison
        http://techthoughts.info
        This script can be run from an external management machine as long as the hostname is specified for the destination hyp and run as a user that has administrative privileges on the Hypervisor
        Git Source: https://github.com/techthoughts2/QuickVMLab
#>
function New-QuickVMLab {
    [CmdletBinding(DefaultParameterSetName = 'Parameter Set 1', 
        SupportsShouldProcess = $true, 
        PositionalBinding = $false,
        ConfirmImpact = 'Medium')]
    param
    (
        [Parameter(Mandatory = $true,
            Position = 1,
            HelpMessage = 'Host device you wish VMs to be built on')]
        [ValidateNotNullOrEmpty()]
        [string]$HostDevice,
        [Parameter(Mandatory = $true,
            Position = 2,
            HelpMessage = '# of VMs you wish to build')]
        [ValidateRange(1, 100)]
        [int]$NumberOfVms,
        [Parameter(Mandatory = $true,
            Position = 3,
            HelpMessage = 'Directory path of the parent OS VHDXs')]
        [ValidateNotNullOrEmpty()]
        [string]$SourceVHDXPath,
        [Parameter(Mandatory = $true,
            Position = 4,
            HelpMessage = 'Path VMs will be built at')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [Parameter(Mandatory = $true,
            Position = 5,
            HelpMessage = 'Generation type of VM')]
        [ValidateSet('1', '2')]
        [string]$VMGeneration,
        [Parameter(Mandatory = $false,
            Position = 6,
            HelpMessage = 'VMSwitch that VM will be attached to')]
        [string]$VMSwitchName,
        [Parameter(Mandatory = $true,
            Position = 7,
            HelpMessage = 'VMSwitch that VM will be attached to')]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('(?i)(?=.{5,13}$)^(([a-z\d]|[a-z\d][a-z\d\-]*[a-z\d])\.)*([a-z\d]|[a-z\d][a-z\d\-]*[a-z\d])$')]
        [string]$VMNamePrefix
    )
    $quickLabVersion = "0.8"
    #__________________________________________________________
    Write-Verbose -Message "Starting QuickVMLab v$quickLabVersion"
    Write-Verbose -Message "Performing verifications..."
    #__________________________________________________________
    #maintain original path
    $origPath = $path
    #move to UNC path structure
    if ($SourceVHDXPath -like "*:*") {
        $SourceVHDXPath = $SourceVHDXPath -replace (":", "$")
    }
    if ($Path -like "*:*") {
        $Path = $Path -replace (":", "$")
    }
    #__________________________________________________________
    #determine source VHDX present
    Write-Verbose -Message "Verifying source VHDX present on specified Host..."
    #user may add trailing backslash - remove if present
    if ($SourceVHDXPath.Substring($SourceVHDXPath.Length - 1) -eq "\") {
        $SourceVHDXPath = $SourceVHDXPath.Substring(0, $SourceVHDXPath.Length - 1)
    }
    #$OSDisk = "\\$HostDevice\$SourceVHDXPath\$osVHDX"
    $OSDisk = "\\$HostDevice\$SourceVHDXPath"
    Write-Verbose -Message "Checking for source VHDX at: $OSDisk"
    try {
        if (Test-Path $OSDisk) {
            Write-Verbose -Message "VHDX verified."
        }
        else {
            Write-Verbose -Message "VHDX not found."
            Write-Output "The source VHDX could not be found. QuickVMLab has stopped."
            return
        }
    }
    catch {
        Write-Output "An error was encountered verifying $SourceVHDXPath :"
        Write-Error $_
    }
    #__________________________________________________________
    #determine status of destination path
    Write-Verbose -Message "Verifying destination VM path is present on specified Host..."
    #user may add trailing backslash - remove if present
    if ($Path.Substring($Path.Length - 1) -eq "\") {
        $Path = $Path.Substring(0, $Path.Length - 1)
    }
    $destPath = "\\$HostDevice\$Path"
    Write-Verbose -Message "Path to verify: $destPath"
    try {
        if (Test-Path $destPath) {
            Write-Verbose -Message "$destPath verified"
            $newVMPath = $destPath
            $vhdPath = "$destPath\VHDs"
            if (!(Test-Path $vhdPath)) {
                Write-Verbose -Message "The path has been verified but the destination is missing a VHD folder. Creating now..."
                try {
                    New-Item -ItemType Directory -Path $vhdPath -ErrorAction Stop | Out-Null
                    Write-Verbose -Message "VHD folder created at destination."
                }
                catch {
                    Write-Output "An error was encounted creating folders at the destination path:"
                    Write-Error $_
                    return
                }
            }
        }
        else {
            Write-Verbose -Message "$destPath path was not found."
            Write-Output "The destination path specified does not currently exist. QuickVMLab has stopped."
            return
        }
    }
    catch {
        Write-Output "An error was encountered verifying $destPath :"
        Write-Error $_
    }
    #__________________________________________________________
    Write-Verbose "Evaluating if VMSwitch $VMSwitchName exists on $hostDevice"
    try {
        $vmswitchResult = Get-VMSwitch -ComputerName $HostDevice -Name $VMSwitchName -ErrorAction SilentlyContinue
        if ($vmswitchResult -eq $null -or $vmswitchResult -eq "") {
            Write-Verbose -Message "The specified VMSwitch was not found on the host."
            Write-Output "The specified VMSwitch was not found on the host. QuickVMLab has stopped."
            return
        }
        else {
            Write-Verbose -Message "VMSwitch verified."
            $vmSwitch = $vmswitchResult.Name
        }
    }
    catch {
        Write-Output "An error was encountered verifying the VMSwitch:"
        Write-Error $_
        return
    }
    #__________________________________________________________
    [bool]$dynMemory = $true
    [int64]$minMemory = 1024
    [int64]$maxMemory = 8096
    [int64]$startMemory = 1024
    #convert to bytes
    $minMemory = 1MB * $minMemory
    $maxMemory = 1MB * $maxMemory
    $startMemory = 1MB * $startMemory
    [int64]$memory = $minMemory
    #__________________________________________________________
    [int32]$cpu = 2
    #__________________________________________________________
    [int64]$vhdSize = 60
    $vhdSize = [math]::round($vhdSize * 1Gb, 3) #converts GB to bytes
    #__________________________________________________________	
    $i = 1
    Write-Verbose -Message "Verifications completed."
    Write-Output "Building $NumberOfVms VM(s)..."
    for ($x = 1; $x -le $numberOfVMs; $x++) {
        try {
            if ($VMGeneration -eq "2") {
                $vmName = "$VMNamePrefix-$i"
                Write-Output "Creating $vmName ..."
                #verify that VM does not already exist
                $vmCheck = $null
                $vmCheck = Get-VM -Name $vmName -ComputerName $HostDevice -ErrorAction SilentlyContinue
                if ($vmCheck) {
                    Write-Output "$vmName already exists. QuickVMLab has stopped."
                    return
                }
                #################################################################################
                #Windows Gen2 VM Creation
                [string]$newVHD = $origPath + "\VHDs\" + $vmName + ".vhdx"
                $newVMPath = $origPath
                #-----------------VM Details----------------
                Write-Verbose -Message "VM Name: $vmName"
                Write-Verbose -Message "VM Gen: $VMGeneration"
                Write-Verbose -Message "Starting memory: $memory"
                Write-Verbose -Message "vCPU: $cpu"
                Write-Verbose -Message "Stored at: $newVMPath"
                Write-Verbose -Message "VHDX stored at: $newVHD"
                Write-Verbose -Message "VHDX size: $vhdSize"
                #---------------END VM Details--------------
				
                #------------------CREATE NEW VM-----------------------
                #New-VM -ComputerName $hostDevice –Name $vmName2016 -Generation $generation2016 –MemoryStartupBytes $memory `
                #-Path $newVMPath –NewVHDPath $newVHD –NewVHDSizeBytes $vhdSize -SwitchName $vmSwitch | Out-Null
                Write-Verbose -Message "Creating VM..."
                New-VM -ComputerName $hostDevice –Name $vmName -Generation $VMGeneration –MemoryStartupBytes $memory `
                    -Path $newVMPath -SwitchName $vmSwitch -ErrorAction Stop | Out-Null
                Write-Verbose -Message "VM creation successful. Sleeping 5 seconds."
                Start-Sleep 5 #pause script for a few seconds to allow VM creation to complete
                #----------------END CREATE NEW VM---------------------
				
                #---------------CONFIGURE NEW VM-----------------------
                #ADD-VMNetworkAdapter –VMName $vmName2012R2 –Switchname $vmSwitch
                #______________________________________________________
                Write-Verbose -Message "Setting VM Processor..."
                Set-VMProcessor -ComputerName $hostDevice –VMName $vmName –count $cpu -ErrorAction Stop
                Write-Verbose -Message "VM processor set successfully"
                #______________________________________________________
                Write-Verbose -Message "Setting VM Memory..."
                Set-VMMemory -ComputerName $hostDevice -VMName $vmName -DynamicMemoryEnabled $true -MinimumBytes $minMemory `
                    -StartupBytes $startMemory -MaximumBytes $maxMemory -ErrorAction Stop
                Write-Verbose -Message "VM memory set successfully. Sleeping 8 seconds."
                Start-Sleep 8 #pause script for a few seconds - allow VM config to complete
                #______________________________________________________
                Write-Verbose -Message "Setting VM boot order..."
                $vmNetworkAdapter = Get-VMNetworkAdapter -ComputerName $hostDevice -VMName $vmName -ErrorAction Stop
                Set-VMFirmware -ComputerName $hostDevice -VMName $vmName -FirstBootDevice $vmNetworkAdapter -ErrorAction Stop
                Write-Verbose -Message "VM boot order set successfully"
                #______________________________________________________
                Write-Verbose -Message "Setting VM AutomaticStopAction..."
                #set AutomaticStopAction
                Set-VM -ComputerName $hostDevice -Name $vmName -AutomaticStopAction ShutDown -ErrorAction Stop
                Write-Verbose -Message "VM AutomaticStopAction set successfully"
                #---------------END CONFIGURE NEW VM-------------------
                Write-Verbose "Sleeping 3 seconds..."
                Start-Sleep 3 #pause script for a few seconds - allow VM config to complete
                
                Write-Verbose "Displaying new VM information..."
                Get-VM -ComputerName $hostDevice -Name $vmName -ErrorAction Stop | Select-Object Name, State, Generation, ProcessorCount, `
                @{ Label = "MemoryStartup"; Expression = { ($_.MemoryStartup / 1MB) } }, `
                @{ Label = "MemoryMinimum"; Expression = { ($_.MemoryMinimum / 1MB) } }, `
                @{ Label = "MemoryMaximum"; Expression = { ($_.MemoryMaximum / 1MB) } } `
                    , Path, Status | Format-Table -AutoSize
                
                # Set OS disk
                Write-Output "$vmName created. Copying source vhdx."
                Write-Verbose -Message "Copying disk $OSDisk to $newVHD"
                #If (!(Test-Path $vhdPath)) { New-Item -Path $vhdPath -ItemType Directory | Out-Null }
                Copy-Item -Path $OSDisk -Destination "$vhdPath\$vmName.vhdx" -ErrorAction Stop
                Write-Verbose -Message "Copy completed."
                #---------------------------------------------------------------
                $CT = "SCSI"
                Write-Verbose -Message "Attaching disk $newVHD to $CT 0:0"
                Add-VMHardDiskDrive -VMName $vmName -ComputerName $hostDevice -ControllerType $CT -ControllerNumber 0 -ControllerLocation 0 -Path "$newVHD" -ErrorAction Stop
                Set-VMFirmware -VMName $vmName -ComputerName $hostDevice -FirstBootDevice (Get-VMHardDiskDrive $vmName -ComputerName $hostDevice -ControllerLocation 0 -ControllerNumber 0 -ErrorAction Stop) -ErrorAction Stop
                Write-Verbose -Message "Disk attached. Sleeping 3 seconds."
                Start-Sleep 3 #pause script for a few seconds - allow VM config to complete
                Write-Output "VM $vmName build completed."
            } #end If Gen2
            else {
                $vmName = "$VMNamePrefix-$i"
                Write-Output "Creating $vmName ..."
                #verify that VM does not already exist
                $vmCheck = $null
                $vmCheck = Get-VM -Name $vmName -ComputerName $HostDevice -ErrorAction SilentlyContinue
                if ($vmCheck) {
                    Write-Output "$vmName already exists. QuickVMLab has stopped."
                    return
                }
                #################################################################################
                #Windows Gen1 VM Creation
                [string]$newVHD = $origPath + "\VHDs\" + $vmName + ".vhdx"
                $newVMPath = $origPath
                #-----------------VM Details----------------
                Write-Verbose -Message "VM Name: $vmName"
                Write-Verbose -Message "VM Gen: $VMGeneration"
                Write-Verbose -Message "Starting memory: $memory"
                Write-Verbose -Message "vCPU: $cpu"
                Write-Verbose -Message "Stored at: $newVMPath"
                Write-Verbose -Message "VHDX stored at: $newVHD"
                Write-Verbose -Message "VHDX size: $vhdSize"
                #---------------END VM Details--------------
				
                #------------------CREATE NEW VM-----------------------
                Write-Verbose -Message "Creating VM..."
                New-VM -ComputerName $hostDevice –Name $vmName -Generation $VMGeneration –MemoryStartupBytes $memory `
                    -Path $newVMPath -SwitchName $vmSwitch -ErrorAction Stop | Out-Null
                Write-Verbose -Message "VM creation successful. Sleeping 5 seconds."
                Start-Sleep 5 #pause script for a few seconds to allow VM creation to complete
                #----------------END CREATE NEW VM---------------------
				
                #---------------CONFIGURE NEW VM-----------------------
                Write-Verbose -Message "Adding legacy adapter..."
                #on gen1 we have to remove the primary adapter and add a legacy one
                Get-VM -ComputerName $hostDevice -VMName $vmName -ErrorAction Stop | Get-VMNetworkAdapter -ErrorAction Stop | Remove-VMNetworkAdapter -Confirm:$false -ErrorAction Stop
                ADD-VMNetworkAdapter -ComputerName $hostDevice –VMName $vmName –Switchname $vmSwitch -IsLegacy $true -ErrorAction Stop
                Write-Verbose -Message "Legacy adapter successfully added."
                #______________________________________________________
                Write-Verbose -Message "Setting VM Processor..."
                Set-VMProcessor -ComputerName $hostDevice –VMName $vmName –count $cpu -ErrorAction Stop
                Write-Verbose -Message "VM processor set successfully"
                #______________________________________________________
                Write-Verbose -Message "Setting VM Memory..."
                Set-VMMemory -ComputerName $hostDevice -VMName $vmName -DynamicMemoryEnabled $true -MinimumBytes $minMemory `
                    -StartupBytes $startMemory -MaximumBytes $maxMemory -ErrorAction Stop
                Write-Verbose -Message "VM memory set successfully. Sleeping 8 seconds."
                Start-Sleep 8 #pause script for a few seconds - allow VM config to complete
                #______________________________________________________
                Write-Verbose -Message "Setting VM boot order..."
                Set-VMBios -ComputerName $hostDevice -VMName $vmName -StartupOrder @("LegacyNetworkAdapter", "Floppy", "CD", "IDE") -ErrorAction Stop
                Write-Verbose -Message "VM boot order set successfully"
                #______________________________________________________
                Write-Verbose -Message "Setting VM AutomaticStopAction..."
                #set AutomaticStopAction
                Set-VM -ComputerName $hostDevice -Name $vmName -AutomaticStopAction ShutDown -ErrorAction Stop
                Write-Verbose -Message "VM AutomaticStopAction set successfully"
                #---------------END CONFIGURE NEW VM-------------------
                Write-Verbose "Sleeping 3 seconds..."
                Start-Sleep 3 #pause script for a few seconds - allow VM config to complete

                Write-Verbose "Displaying new VM information..."
                Get-VM -ComputerName $hostDevice -Name $vmName -ErrorAction Stop | Select-Object Name, State, Generation, ProcessorCount, `
                @{ Label = "MemoryStartup"; Expression = { ($_.MemoryStartup / 1MB) } }, `
                @{ Label = "MemoryMinimum"; Expression = { ($_.MemoryMinimum / 1MB) } }, `
                @{ Label = "MemoryMaximum"; Expression = { ($_.MemoryMaximum / 1MB) } } `
                    , Path, Status | Format-Table -AutoSize
                
                # Set OS disk
                Write-Output "$vmName created. Copying source vhdx."
                Write-Verbose -Message "Copying disk $OSDisk to $newVHD"
                #If (!(Test-Path $vhdPath)) { New-Item -Path $vhdPath -ItemType Directory | Out-Null }
                Copy-Item -Path $OSDisk -Destination "$newVHD" -ErrorAction Stop
                Write-Verbose -Message "Copy completed."
                #---------------------------------------------------------------
                $CT = "IDE"
                Write-Verbose -Message "Attaching disk $newVHD to $CT 0:0"
                Add-VMHardDiskDrive -VMName $vmName -ComputerName $hostDevice -ControllerType $CT -ControllerNumber 0 -ControllerLocation 0 -Path "$newVHD" -ErrorAction Stop
                Write-Verbose -Message "Disk attached. Sleeping 3 seconds."
                Start-Sleep 3 #pause script for a few seconds - allow VM config to complete
                Write-Output "VM $vmName build completed."
            }#end Else Gen1
            $i++
        }
        catch {
            Write-OutPut "An error was encountered building the VM. QuickVMLab has stopped."
            Write-Error $_
            return
        }
    }#end Foreach VM
}#end Function1