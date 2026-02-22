$ErrorActionPreference = "Continue"

Write-Host "=========================================="
Write-Host "Installing VirtualBox Guest Additions"
Write-Host "=========================================="

$guestAdditionsPath = "E:\VBoxWindowsAdditions.exe"
$certPath = "E:\cert\VBoxCertUtil.exe"

if (Test-Path $guestAdditionsPath) {
    Write-Host "Found Guest Additions at: $guestAdditionsPath"
    
    Write-Host "Installing certificates..."
    if (Test-Path $certPath) {
        $certDir = "E:\cert\"
        $certFiles = Get-ChildItem -Path $certDir -Filter "*.cer" -ErrorAction SilentlyContinue
        foreach ($certFile in $certFiles) {
            Write-Host "Adding certificate: $($certFile.Name)"
            & $certPath add-trusted-publisher $certFile.FullName | Out-Null
        }
    }
    
    Write-Host "Installing VBoxWindowsAdditions (without reboot)..."
    $installProcess = Start-Process -FilePath $guestAdditionsPath -ArgumentList "/S", "/l", "/noreboot" -Wait -PassThru
    
    Write-Host "Guest Additions installation completed with exit code: $($installProcess.ExitCode)"
} else {
    Write-Host "Guest Additions not found at: $guestAdditionsPath"
    Write-Host "Searching for VBoxWindowsAdditions.exe..."
    
    $drives = Get-WmiObject -Class Win32_CDROMDrive
    foreach ($drive in $drives) {
        $driveLetter = $drive.Drive
        $vboxAdditions = "$driveLetter\VBoxWindowsAdditions.exe"
        if (Test-Path $vboxAdditions) {
            Write-Host "Found Guest Additions at: $vboxAdditions"
            $installProcess = Start-Process -FilePath $vboxAdditions -ArgumentList "/S", "/l", "/noreboot" -Wait -PassThru
            Write-Host "Guest Additions installation completed with exit code: $($installProcess.ExitCode)"
            break
        }
    }
}

Write-Host "=========================================="
Write-Host "Guest Additions installation finished"
Write-Host "System will restart to complete installation"
Write-Host "=========================================="
