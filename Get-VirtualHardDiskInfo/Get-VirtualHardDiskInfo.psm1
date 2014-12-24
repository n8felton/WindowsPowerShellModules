Function Get-VirtualHardDiskInfo
{
	[CmdletBinding()]
	param
	(
		# VMName
		[Parameter(Mandatory=$true,
			ValueFromPipelineByPropertyName=$true,
			Position=0)]
		[string]
		$VMName,
		# ComputerName is used if the guest OS hostname is different than the 
		# name of the VM
		[Parameter(Mandatory=$false,
			ValueFromPipelineByPropertyName=$true,
			Position=1)]
		[string]
		$ComputerName
	)
	
	$VMView = Get-View -ViewType VirtualMachine -Filter @{'Name' = "$VMName"}
	if ($ComputerName)
	{
		$VMName = $ComputerName
	}
		
	$ServerDiskToVolume = @(
		Get-WmiObject -Class Win32_DiskDrive -ComputerName $VMName | ForEach {
			$Disk = $_
			$query = "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($_.DeviceID)'} WHERE ResultClass=Win32_DiskPartition" 
		
			Get-WmiObject -Query $query -ComputerName $VMName | ForEach { 
				$query = "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($_.DeviceID)'} WHERE ResultClass=Win32_LogicalDisk" 
			
				Get-WmiObject -Query $query -ComputerName $VMName | Select DeviceID,
					VolumeName,
					@{ label = "SerialNumber"; expression = {$Disk.SerialNumber} }
			}
		}
	)

	$VMDisks = ForEach ($VirtualHardDisk in ($VMView.Config.Hardware.Device | Where {$_.DeviceInfo.Label -match "Hard disk"}))
	{
		$VMDiskUUID = $VirtualHardDisk.Backing.UUID -replace '-',''
		$VMDiskDeviceID = ""

		$MatchingDisk = @( $ServerDiskToVolume | Where {$_.SerialNumber -like $VMDiskUUID} )
		if($MatchingDisk.count -eq 1)
		{
			$VMDiskDeviceID = $MatchingDisk.DeviceID
		}

		[pscustomobject]@{
			VMName = $VMView.Name
			GuestHostName = $VMView.Guest.HostName
			GuestOSDriveLetter = $VMDiskDeviceID
			VMWareDiskName = $VirtualHardDisk.DeviceInfo.Label			
			VMWareDiskUUID = $VMDiskUUID
			VMWareDiskFile = $VirtualHardDisk.Backing.FileName
		}		
	}
		
	Return $VMDisks
}