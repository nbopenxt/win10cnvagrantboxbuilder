# Windows 10 Chinese Version Vagrant Box Builder

Use Packer + VirtualBox to generate Vagrant Box from official Windows 10 Chinese ISO, enabling automated virtual machine image building.

[中文文档](README_zh-CN.md)

## Features

- Based on official Windows 10 Chinese ISO
- Automatic VirtualBox Guest Additions installation
- Pre-configured WinRM remote management
- Shared folder support
- Chinese language environment

## Requirements

| Software | Version | Download |
|----------|---------|----------|
| VirtualBox | 7.x | https://www.virtualbox.org/wiki/Downloads |
| Vagrant | 2.4+ | https://developer.hashicorp.com/vagrant/downloads |
| Packer | 1.10+ | https://developer.hashicorp.com/packer/downloads |
| Windows 10 ISO | Chinese | See download link below |

## Quick Start

### Option 1: Download Pre-built Box

If you don't want to build it yourself, download the pre-built Box file:

- **Baidu Netdisk**: https://pan.baidu.com/s/1JN5BTfWDrKS3uHis-k1zsQ?pwd=zwrn
- **Access Code**: zwrn

Add to Vagrant:

```powershell
vagrant box add windows10-zhcn windows10-zhcn-22H2.box
```

### Option 2: Build Box Yourself

#### 1. Prepare ISO File

Download Windows 10 Chinese ISO:

- **Baidu Netdisk**: https://pan.baidu.com/s/107Mgo68hThnzcS6Uh9l7ZQ?pwd=64n4
- **Access Code**: 64n4

Place the ISO file in the project directory or specified location.

#### 2. Get ISO Checksum

```powershell
Get-FileHash -Path "Windows10.iso" -Algorithm SHA256 | Select-Object -ExpandProperty Hash
```

#### 3. Modify Configuration

Edit `configs/build.json` and update:

```json
{
  "iso_url": "Windows10.iso",
  "iso_checksum": "sha256:YOUR_ISO_SHA256_CHECKSUM"
}
```

**Get SHA256 checksum on Windows:**

```powershell
# PowerShell
Get-FileHash -Path "Windows10.iso" -Algorithm SHA256 | Select-Object -ExpandProperty Hash

# CMD
certutil -hashfile Windows10.iso SHA256
```

Example output:
```
0319E2BAE274E6DD433719E687D79B63E6FDA911E6768B6D86C801E802D21D29
```

#### 4. Build

```powershell
packer build configs/build.json
```

#### 5. Add Box

```powershell
vagrant box add windows10-zhcn windows10-zhcn-22H2.box
```

## Directory Structure

```
.
├── README.md                   # Documentation (English)
├── README_zh-CN.md             # Documentation (Chinese)
├── configs/                    # Configuration files
│   ├── build.json              # Packer build configuration
│   └── autounattend.xml        # Windows unattended answer file
├── scripts/                    # Script files
│   ├── vagrant-env.ps1         # Vagrant environment setup script
│   └── install-guest-additions.ps1  # Guest Additions installation script
└── examples/                   # Example files
    ├── Vagrantfile             # Basic Vagrantfile example
    └── Vagrantfile.with-share  # Vagrantfile with shared folder
```

## Using the Built Box

### 1. Create Project Directory

```powershell
mkdir my-win10-project
cd my-win10-project
```

### 2. Create Vagrantfile

Refer to `examples/Vagrantfile`:

**Basic Configuration:**

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "windows10-zhcn"
  config.vm.define "win10-dev"
  config.vm.boot_timeout = 300
  
  config.vm.network "forwarded_port", guest: 3389, host: 53389
  config.vm.network "forwarded_port", guest: 5985, host: 55985

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 8192
    vb.cpus = 2
    vb.gui = true
    vb.name = "Win10-Dev"
  end

  config.vm.communicator = "winrm"
  config.winrm.username = "vagrant"
  config.winrm.password = "vagrant"
end
```

**With Shared Folder:**

Refer to `examples/Vagrantfile.with-share` to map host directory to Z: drive in VM:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "windows10-zhcn"
  config.vm.define "win10-with-share"
  config.vm.boot_timeout = 300
  
  config.vm.network "forwarded_port", guest: 3389, host: 53389
  config.vm.network "forwarded_port", guest: 5985, host: 55985

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 8192
    vb.cpus = 2
    vb.gui = true
    vb.name = "Win10-With-Share"

    # Shared folder: host ./share_data maps to VM Z: drive
    vb.customize [
      "sharedfolder", "add", :id,
      "--name", "shared_data",
      "--hostpath", File.expand_path("./share_data"),
      "--automount"
    ]
  end

  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.communicator = "winrm"
  config.winrm.username = "vagrant"
  config.winrm.password = "vagrant"

  # Mount shared folder and configure system
  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    cmd.exe /c "@echo off && ^
    net use Z: /delete /y 2>NUL && ^
    net use Z: \\\\vboxsvr\\shared_data /persistent:yes 2>NUL && ^
    if exist \"Z:\\\" ( ^
      if not exist \"Z:\\app\" mkdir \"Z:\\app\" && ^
      if not exist \"Z:\\logs\" mkdir \"Z:\\logs\" && ^
      if not exist \"Z:\\scripts\" mkdir \"Z:\\scripts\" ^
    ) && ^
    secedit /export /cfg C:\\secpol.cfg /quiet && ^
    (findstr /v \"PasswordComplexity\" C:\\secpol.cfg) > C:\\secpol.cfg.tmp && ^
    echo PasswordComplexity = 0 >> C:\\secpol.cfg.tmp && ^
    secedit /configure /db C:\\Windows\\security\\local.sdb /cfg C:\\secpol.cfg.tmp /areas SECURITYPOLICY /quiet && ^
    del C:\\secpol.cfg C:\\secpol.cfg.tmp /f /q && ^
    reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System\" /v EnableLUA /t REG_DWORD /d 0 /f && ^
    reg add \"HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU\" /v NoAutoUpdate /t REG_DWORD /d 1 /f"
  SHELL

  # Refresh drive and restart explorer
  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    cmd.exe /c "net use Z: /delete /y 2>NUL && ^
    net use Z: \\\\vboxsvr\\shared_data /persistent:yes && ^
    taskkill /f /im explorer.exe && ^
    start explorer.exe"
  SHELL
end
```

**Configuration Details:**

| Setting | Description |
|---------|-------------|
| Shared Folder | Host `./share_data` maps to VM `Z:` drive |
| Create Directories | Auto-create `Z:\app`, `Z:\logs`, `Z:\scripts` |
| Disable Password Complexity | Allow simple passwords |
| Disable UAC | Turn off User Account Control prompts |
| Disable Windows Update | Turn off automatic updates |

Create shared directory on host before use:

```powershell
mkdir share_data
```

### 3. Start VM

```powershell
vagrant up
```

### 4. Login

- **Username**: `vagrant`
- **Password**: `vagrant`

## Build Time

Estimated build time: **1.5 - 2 hours**

## Known Issues

### WinRM Connection Wait

Build may wait for WinRM connection for a long time:

```
==> virtualbox-iso: Waiting for WinRM to become available...
```

**Solution**: Run PowerShell as Administrator in the VM and execute:

```powershell
winrm quickconfig -q
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
net start winrm
```

After execution, Packer will automatically continue the build process.

## VM Configuration

| Setting | Default |
|---------|---------|
| Memory | 8GB |
| CPU | 2 cores |
| Disk | 60GB |
| Video Memory | 256MB |
| Graphics Controller | VMSVGA |
| 3D Acceleration | Enabled |

## Default Account

| Item | Value |
|------|-------|
| Username | vagrant |
| Password | vagrant |
| Privileges | Administrators |

## Port Forwarding

| Host Port | Guest Port | Purpose |
|-----------|------------|---------|
| 53389 | 3389 | RDP Remote Desktop |
| 55985 | 5985 | WinRM HTTP |
| 55986 | 5986 | WinRM HTTPS |

## Common Commands

| Command | Description |
|---------|-------------|
| `vagrant up` | Start VM |
| `vagrant halt` | Stop VM |
| `vagrant reload` | Restart VM |
| `vagrant suspend` | Suspend VM |
| `vagrant resume` | Resume VM |
| `vagrant destroy -f` | Destroy VM |
| `vagrant status` | Check status |
| `vagrant box list` | List installed boxes |

## References

- [Packer Documentation](https://developer.hashicorp.com/packer/docs)
- [Vagrant Documentation](https://developer.hashicorp.com/vagrant/docs)
- [VirtualBox Documentation](https://www.virtualbox.org/wiki/Documentation)
- [Windows Unattended Answer File Reference](https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/)

## License

MIT License
