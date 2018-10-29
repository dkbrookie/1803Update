#region functions
Function Get-Tree($Path,$Include='*') {
  @(Get-Item $Path -Include $Include -Force) +
    (Get-ChildItem $Path -Recurse -Include $Include -Force) | Sort PSPath -Descending -Unique
}

Function Remove-Tree($Path,$Include='*') {
  Get-Tree $Path $Include | Remove-Item -Force -Recurse
}
#endregion functions


#region checkOSInfo
If([System.Environment]::OSVersion.Version.Major -ne 10) {
  Write-Output "Your version of Windows does not support the 1803 upgrade. Exiting script."
  Break
}

$osBuild = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId).ReleaseId
If($osBuild -ge 1803) {
  Write-Output "Your machine already has this patch installed! Exiting script."
  Break
}

Try {
  If((Get-WmiObject win32_operatingsystem | Select-Object -ExpandProperty osarchitecture) -eq '64-bit') {
    $osVer = 'x64'
    $servFile = 3927745135
  } Else {
    $servFile = 2942440134
    $osVer = 'x86'
  }
} Catch {
  Write-Error 'Unable to determine OS architecture'
  Return
}
#endregion checkOSInfo


$1803Dir = "$env:windir\LTSvc\packages\OS\win10.1803"
$1803Zip = "$1803Dir\Pro$osVer.1803.zip"
$AutomateURL = "https://support.dkbinnovative.com/labtech/Transfer/OS/Windows10/Pro$osVer.1803.zip"


#region dirChecks
Try {
  If(!(Test-Path $1803Dir)) {
    New-Item -ItemType Directory -Path $1803Dir
  }
} Catch {
  Write-Error "Failed to create the following folder: $1803Dir"
  Return
}
#endregion dirChecks


#region fileChecks
$checkZip = Test-Path $1803Zip -PathType Leaf
If($checkZip) {
  If($servFile -gt (Get-Item $1803Zip)) {
    Remove-Tree -Path $1803Dir
    $checkFile = Test-Path $1803Zip -PathType Leaf
    If(!$checkFile) {
      $status = 'Download'
      Write-Output "The existing installation files for the 1803 update were incomplete or corrupt. Deleted existing files and now starting a new download."
    }
    Else{
      Write-Output "Failed to delete the installation files for 1803. Exiting script."
      Break
    }
  }
  Else{
    $status = 'Install'
    Write-Output "Verified all required files have been downloaded and are ready to install! Beginning your 1803 update installation."
  }
}
Else{
  $status = 'Download'
  Write-Output "The required files to install the 1803 update are not present, downloading required files now."
}
#endregion fileChecks


#region install1803
If($status -eq 'Download') {
  Try {
    IWR -Uri $AutomateURL -Outfile $1803Zip
    If($servFile -gt (Get-Item $1803Zip).length) {
      Write-Error 'The downloaded size of $1803Zip does not match the server version, unable to install the update.'
    } Else {
      Write-Information 'Successfully downloaded the 1803 update! Setup is currently unpacking the setup files, then will begin the installation.'
      $status = 'Install'
    }
  } Catch {
    Write-Error 'Encountered a problem when trying to download the Windows 10 1803 ISO'
  }
}
ElseIf($status -eq 'Install') {
  ##installhere
  Write-Output 'Install'
} Else {
    Write-Output "Could not find a known status of the var Status. Output: $status"
}
#endregion install1803
