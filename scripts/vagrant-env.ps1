$ErrorActionPreference = "Continue"

Write-Host "=========================================="
Write-Host "Configuring Vagrant Environment"
Write-Host "=========================================="

Write-Host "Enabling WinRM..."
winrm quickconfig -q
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

Write-Host "Disabling UAC..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0 -Force

Write-Host "Setting Chinese locale..."
Set-WinSystemLocale zh-CN
try {
    Set-WinHomeLocation 0x00000804 -ErrorAction SilentlyContinue
} catch {
    Write-Host "Warning: Could not set home location, continuing..."
}
Set-WinUserLanguageList zh-CN -Force

Write-Host "Setting time zone..."
tzutil /s "China Standard Time"

Write-Host "Disabling password complexity..."
secedit /export /cfg C:\secpol.cfg /quiet
(Get-Content C:\secpol.cfg) | Where-Object { $_ -notmatch "PasswordComplexity" } | Set-Content C:\secpol.cfg.tmp
Add-Content C:\secpol.cfg.tmp "PasswordComplexity = 0"
secedit /configure /db C:\Windows\security\local.sdb /cfg C:\secpol.cfg.tmp /areas SECURITYPOLICY /quiet
Remove-Item C:\secpol.cfg, C:\secpol.cfg.tmp -Force -ErrorAction SilentlyContinue

Write-Host "Enabling RDP..."
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
try {
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
} catch {
    Write-Host "Warning: Could not enable RDP firewall rules, continuing..."
}

Write-Host "Disabling Windows Update..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f | Out-Null

Write-Host "Setting power plan to High Performance..."
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

Write-Host "=========================================="
Write-Host "Vagrant Environment Configuration Complete"
Write-Host "=========================================="
