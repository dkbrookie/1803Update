#region functions
Function Get-Tree($Path,$Include='*'){
  @(Get-Item $Path -Include $Include -Force) +
    (Get-ChildItem $Path -Recurse -Include $Include -Force) | Sort PSPath -Descending -Unique
}

Function Remove-Tree($Path,$Include='*'){
  Get-Tree $Path $Include | Remove-Item -Force -Recurse
}
#endregion functions


#region checkOSInfo
If([System.Environment]::OSVersion.Version.Major -ne 10){
  Write-Output "Your version of Windows does not support the 1803 upgrade. Exiting script."
  Break
}

$osBuild = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId).ReleaseId
If($osBuild -ge 1803){
  Write-Output "Your machine already has this patch installed! Exiting script."
  Break
}

If($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){
  $osVer = 'x64'
} Else {
  $osVer = 'x86'
}
#endregion checkOSInfo


#region dirChecks
$ltDir = "C:\Windows\LTSvc"
$packageDir = "$ltDir\packages"
$osDir = "$packageDir\OS"
$1803Dir = "$osDir\win10.1803"

If(!$packageDir){
  New-Item -ItemType Directory -Path $packageDir
}

If(!$osDir){
  New-Item -ItemType Directory -Path $osDir
}

If(!$1803Dir){
  New-Item -ItemType Directory -Path $1803Dir
}
#endregion dirChecks


#region fileChecks
If($osVer -eq 'x64'){
  $ltServFile = 3927745135
}

If($osVer -eq 'x86'){
  $ltServFile = 2942440134
}

$zipPath = "$1803Dir\Pro$osVer.1803.zip"
$checkZip = Test-Path $zipPath -PathType Leaf

If($checkZip){
  $clientFile = Get-Item $zipPath
  If($ltServFile -gt $clientFile.Length){
    Remove-Tree -Path $1803Dir
    $checkFile = Test-Path $zipPath -PathType Leaf
    If(!$checkFile){
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
