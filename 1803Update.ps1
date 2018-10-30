#region functions
Function Get-Tree($Path,$Include='*') {
  @(Get-Item $Path -Include $Include -Force) +
    (Get-ChildItem $Path -Recurse -Include $Include -Force) | Sort PSPath -Descending -Unique
}

Function Remove-Tree($Path,$Include='*') {
  Get-Tree $Path $Include | Remove-Item -Force -Recurse
}

Function Install-withProgress{
  $localFolder= (Get-Location).path
  $process = Start-Process -FilePath "$localFolder\Installer.exe" -ArgumentList "/silent /accepteula" -PassThru
  For($i = 0; $i -le 100; $i = ($i + 1) % 100) {
    Write-Progress -Activity "Installer" -PercentComplete $i -Status "Installing"
    Start-Sleep -Milliseconds 100
    If ($process.HasExited) {
        Write-Progress -Activity "Installer" -Completed
        Break
    }
  }
}
#endregion functions


#region intro
$logFile = "C:\Users\Public\Desktop\1803 Upgrade Status.txt"
$dateTime = Get-Date
Write-Output "--------------------------------------------------------" | Out-File $logFile -Append
Write-Output "Installation start time triggered by user: $dateTime" | Out-File $logFile -Append
#endregion intro


#region checkOSInfo
$rbCheck1 = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore
$rbCheck2 = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore
$rbCheck3 = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore

If($rbCheck1 -ne $Null -or $rbCheck2 -ne $Null -or $rbCheck3 -ne $Null){
    Write-Output "This system is pending a reboot, unable to proceed. Please restart your computer and try again." | Out-File $logFile -Append
    Break
} Else {
    Write-Output "Automation has verified there is no reboot pending." | Out-File $logFile -Append
}

If([System.Environment]::OSVersion.Version.Major -ne 10) {
  Write-Output "Your version of Windows does not support the 1803 upgrade. Exiting script." | Out-File $logFile -Append
  Break
}

$osBuild = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId).ReleaseId
If($osBuild -ge 1803) {
  Write-Output "Your machine already has this patch installed! Exiting script." | Out-File $logFile -Append
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
  Write-Error 'Unable to determine OS architecture' | Out-File $logFile -Append
  Return
}
#endregion checkOSInfo


#region fileChecks
$1803Dir = "$env:windir\LTSvc\packages\OS\win10.1803"
$1803Zip = "$1803Dir\Pro$osVer.1803.zip"
$7zip = "$1803Dir\7za.exe"
$automate1803URL = "https://support.dkbinnovative.com/labtech/Transfer/OS/Windows10/Pro$osVer.1803.zip"
$automate7zipURL = "https://support.dkbinnovative.com/labtech/Transfer/OS/Windows10/7za.exe"

Try {
  If(!(Test-Path $1803Dir)) {
    New-Item -ItemType Directory -Path $1803Dir | Out-Null
  }
} Catch {
  Write-Error "Failed to create the following folder: $1803Dir" | Out-File $logFile -Append
  Return
}

$checkZip = Test-Path $1803Zip -PathType Leaf
If($checkZip) {
  If($servFile -gt (Get-Item $1803Zip).Length) {
    Remove-Tree -Path $1803Dir
    $checkFile = Test-Path $1803Zip -PathType Leaf
    If(!$checkFile) {
      $status = 'Download'
      Write-Output "The existing installation files for the 1803 update were incomplete or corrupt. Deleted existing files and started a new download." | Out-File $logFile -Append
    }
    Else {
      Write-Output "Failed to delete the installation files for 1803. Exiting script." | Out-File $logFile -Append
      Break
    }
  }
  Else {
    Write-Output "Verified the installation package downloaded successfully!" | Out-File $logFile -Append
    $status = 'Unzip'
  }
}
Else {
  $status = 'Download'
  Write-Output "The required files to install the 1803 update are not present, downloading required files now. Keep in mind this update is VERY large, and may take 30min+ to download (depending on your connection speed)." | Out-File $logFile -Append
}
#endregion fileChecks


#region download/install
If($status -eq 'Download') {
  Try {
    Start-BitsTransfer -Source $automate1803URL -Destination $1803Zip
    If($servFile -gt (Get-Item $1803Zip).Length) {
      Write-Error "The downloaded size of $1803Zip does not match the server version, unable to install the update." | Out-File $logFile -Append
    } Else {
      Write-Output 'Successfully downloaded the 1803 update!' | Out-File $logFile -Append
      $status = 'Unzip'
    }
  } Catch {
    Write-Error 'Encountered a problem when trying to download the Windows 10 1803 ISO' | Out-File $logFile -Append
  }
}
Try {
  If($status -eq 'Unzip') {
    $7zipCheck = Test-Path $7zip -PathType Leaf
    If(!$7zipCheck) {
      Start-BitsTransfer -Source $automate7zipURL -Destination $1803Dir
    }
    Write-Output 'Unpacking 1803 installation files...this will take awhile.' | Out-File $logFile -Append
    &$7zip x $1803Zip -o"$1803Dir" -y | Out-Null
    Write-Output 'Unpacking complete! Beginning 1803 upgrade installation.' | Out-File $logFile -Append
    $status = 'Install'
  }
  ##Install
  If($status -eq 'Install') {
    Write-Output 'The 1803 upgrade installation has now been started silently in the background. No action from you is required, but please note a reboot will be reqired during the installation prcoess. It is highly recommended you save all of your open files!' | Out-File $logFile -Append
    $localFolder= (Get-Location).path
    $process = Start-Process -FilePath "$1803Dir\Pro$osVer.1803\setup.exe" -ArgumentList "/auto upgrade /quiet" -PassThru
    For($i = 0; $i -le 100; $i = ($i + 1) % 100) {
      Write-Progress -Activity "Installer" -PercentComplete $i -Status "Installing"
      Start-Sleep -Milliseconds 100
      If ($process.HasExited) {
        Write-Progress -Activity "Installer" -Completed
        Write-Output "Installation has completed, deleting setup files" | Out-File $logFile -Append
        Remove-Tree -Path $1803Dir
        Write-Output "1803 upgrade process complete!"
        Break
      }
    }
  } Else {
      Write-Error "Could not find a known status of the var Status. Output: $status" | Out-File $logFile -Append
  }
} Catch {
  Write-Error 'Setup ran into an issue while attempting to install the 1803 upgrade.'
}
  #endregion download/install
