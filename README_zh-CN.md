# Windows 10 中文版 Vagrant Box 构建项目

使用 Packer + VirtualBox 从官方 Windows 10 中文版 ISO 文件生成 Vagrant Box，实现自动化构建虚拟机镜像。

[English Documentation](README.md)

## 特性

- 基于官方 Windows 10 中文版 ISO
- 自动安装 VirtualBox Guest Additions
- 预配置 WinRM 远程管理
- 支持共享文件夹
- 中文语言环境

## 环境要求

| 软件 | 版本要求 | 下载地址 |
|------|----------|----------|
| VirtualBox | 7.x | https://www.virtualbox.org/wiki/Downloads |
| Vagrant | 2.4+ | https://developer.hashicorp.com/vagrant/downloads |
| Packer | 1.10+ | https://developer.hashicorp.com/packer/downloads |
| Windows 10 ISO | 中文版 | 见下方下载链接 |

## 快速开始

### 方式一：直接下载预构建 Box

如果你不想自己构建，可以直接下载预构建的 Box 文件：

- **百度网盘**: https://pan.baidu.com/s/1JN5BTfWDrKS3uHis-k1zsQ?pwd=zwrn
- **提取码**: zwrn

下载后添加到 Vagrant：

```powershell
vagrant box add windows10-zhcn windows10-zhcn-22H2.box
```

### 方式二：自行构建 Box

#### 1. 准备 ISO 文件

下载 Windows 10 中文版 ISO：

- **百度网盘**: https://pan.baidu.com/s/107Mgo68hThnzcS6Uh9l7ZQ?pwd=64n4
- **提取码**: 64n4

将 ISO 文件放到项目目录或指定位置。

#### 2. 获取 ISO 校验和

```powershell
Get-FileHash -Path "Windows10.iso" -Algorithm SHA256 | Select-Object -ExpandProperty Hash
```

#### 3. 修改配置文件

编辑 `configs/build.json`，更新以下配置：

```json
{
  "iso_url": "Windows10.iso",
  "iso_checksum": "sha256:你的ISO校验和"
}
```

**Windows 环境获取 SHA256 校验和：**

```powershell
# PowerShell 方式
Get-FileHash -Path "Windows10.iso" -Algorithm SHA256 | Select-Object -ExpandProperty Hash

# CMD 方式
certutil -hashfile Windows10.iso SHA256
```

输出示例：
```
0319E2BAE274E6DD433719E687D79B63E6FDA911E6768B6D86C801E802D21D29
```

#### 4. 执行构建

```powershell
packer build configs/build.json
```

#### 5. 添加 Box

```powershell
vagrant box add windows10-zhcn windows10-zhcn-22H2.box
```

## 目录结构

```
.
├── README.md                   # 项目说明文档
├── configs/                    # 配置文件目录
│   ├── build.json              # Packer 构建配置
│   └── autounattend.xml        # Windows 自动应答文件
├── scripts/                    # 脚本文件目录
│   ├── vagrant-env.ps1         # Vagrant 环境配置脚本
│   └── install-guest-additions.ps1  # Guest Additions 安装脚本
└── examples/                   # 示例文件目录
    └── Vagrantfile             # Vagrant 项目配置示例
```

## 使用构建好的 Box

### 1. 创建项目目录

```powershell
mkdir my-win10-project
cd my-win10-project
```

### 2. 创建 Vagrantfile

参考 `examples/Vagrantfile` 创建配置文件：

**基础配置：**

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

**带共享文件夹配置：**

参考 `examples/Vagrantfile.with-share`，在虚拟机中创建 Z 盘映射到宿主机目录：

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

    # 共享文件夹配置：宿主机 ./share_data 映射到虚拟机 Z: 盘
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

  # 挂载共享文件夹并配置系统
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

  # 刷新盘符并重启资源管理器
  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    cmd.exe /c "net use Z: /delete /y 2>NUL && ^
    net use Z: \\\\vboxsvr\\shared_data /persistent:yes && ^
    taskkill /f /im explorer.exe && ^
    start explorer.exe"
  SHELL
end
```

**配置说明：**

| 配置项 | 说明 |
|--------|------|
| 共享文件夹 | 宿主机 `./share_data` 映射到虚拟机 `Z:` 盘 |
| 创建目录 | 自动创建 `Z:\app`、`Z:\logs`、`Z:\scripts` |
| 禁用密码复杂度 | 允许设置简单密码 |
| 禁用 UAC | 关闭用户账户控制提示 |
| 禁用 Windows Update | 关闭自动更新 |

使用前宿主机需创建共享目录：

```powershell
mkdir share_data
```

### 3. 启动虚拟机

```powershell
vagrant up
```

### 4. 登录虚拟机

- **用户名**: `vagrant`
- **密码**: `vagrant`

## 构建时间

预计构建时间：**1.5 - 2 小时**

## 已知问题

### WinRM 连接等待

构建过程中可能长时间等待 WinRM 连接：

```
==> virtualbox-iso: Waiting for WinRM to become available...
```

**解决方案**：在虚拟机中以管理员身份运行 PowerShell，执行：

```powershell
winrm quickconfig -q
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
net start winrm
```

执行后，Packer 将自动继续构建流程。

## 虚拟机配置

| 配置项 | 默认值 |
|--------|--------|
| 内存 | 8GB |
| CPU | 2 核 |
| 硬盘 | 60GB |
| 显存 | 256MB |
| 显卡控制器 | VMSVGA |
| 3D 加速 | 启用 |

## 默认账户

| 项目 | 值 |
|------|------|
| 用户名 | vagrant |
| 密码 | vagrant |
| 权限 | Administrators |

## 端口转发

| 宿主机端口 | 虚拟机端口 | 用途 |
|------------|------------|------|
| 53389 | 3389 | RDP 远程桌面 |
| 55985 | 5985 | WinRM HTTP |
| 55986 | 5986 | WinRM HTTPS |

## 常用命令

| 命令 | 说明 |
|------|------|
| `vagrant up` | 启动虚拟机 |
| `vagrant halt` | 关闭虚拟机 |
| `vagrant reload` | 重启虚拟机 |
| `vagrant suspend` | 挂起虚拟机 |
| `vagrant resume` | 恢复虚拟机 |
| `vagrant destroy -f` | 销毁虚拟机 |
| `vagrant status` | 查看状态 |
| `vagrant box list` | 查看已安装 Box |

## 参考链接

- [Packer 官方文档](https://developer.hashicorp.com/packer/docs)
- [Vagrant 官方文档](https://developer.hashicorp.com/vagrant/docs)
- [VirtualBox 官方文档](https://www.virtualbox.org/wiki/Documentation)
- [Windows 自动应答文件参考](https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/)

## License

MIT License
