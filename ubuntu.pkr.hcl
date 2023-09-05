packer {
  required_plugins {
    # see https://github.com/hashicorp/packer-plugin-qemu
    qemu = {
      version = ">= 1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
    # see https://github.com/hashicorp/packer-plugin-hyperv
    hyperv = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/hyperv"
    }
    # see https://github.com/hashicorp/packer-plugin-virtualbox
    virtualbox = {
      version = ">= 1.0.5"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

variable "disk_size" {
  type    = string
  default = 8 * 1024
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:a4acfda10b18da50e2ec50ccaf860d7f20b389df8765611142305c0e911d16fd"
}

variable "hyperv_switch_name" {
  type    = string
  default = env("HYPERV_SWITCH_NAME")
}

variable "hyperv_vlan_id" {
  type    = string
  default = env("HYPERV_VLAN_ID")
}

variable "vagrant_box" {
  type = string
}

locals {
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz",
    " net.ifnames=0",
    " autoinstall",
    "<enter><wait5s>",
    "initrd /casper/initrd",
    "<enter><wait5s>",
    "boot",
    "<enter><wait5s>",
  ]
}

source "hyperv-iso" "ubuntu-amd64" {
  cd_label = "cidata"
  cd_files = [
    "tmp/hyperv-autoinstall-cloud-init-data/user-data",
    "autoinstall-cloud-init-data/meta-data",
  ]
  boot_command      = local.boot_command
  boot_wait         = "5s"
  boot_order        = ["SCSI:0:0"]
  first_boot_device = "DVD"
  cpus              = 2
  memory            = 2048
  disk_size         = var.disk_size
  generation        = 2
  headless          = true
  iso_checksum      = var.iso_checksum
  iso_url           = var.iso_url
  switch_name       = var.hyperv_switch_name
  temp_path         = "tmp"
  vlan_id           = var.hyperv_vlan_id
  ssh_username      = "vagrant"
  ssh_password      = "vagrant"
  ssh_timeout       = "60m"
  shutdown_command  = "sudo -S poweroff"
}

source "qemu" "ubuntu-amd64" {
  accelerator = "kvm"
  cd_label    = "cidata"
  cd_files = [
    "autoinstall-cloud-init-data/user-data",
    "autoinstall-cloud-init-data/meta-data",
  ]
  machine_type   = "q35"
  boot_command   = local.boot_command
  boot_wait      = "5s"
  disk_cache     = "unsafe"
  disk_discard   = "unmap"
  disk_interface = "virtio-scsi"
  disk_size      = var.disk_size
  format         = "qcow2"
  headless       = true
  net_device     = "virtio-net"
  iso_checksum   = var.iso_checksum
  iso_url        = var.iso_url
  cpus           = 2
  memory         = 2048
  qemuargs = [
    ["-cpu", "host"],
  ]
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "60m"
  shutdown_command = "sudo -S poweroff"
}

source "qemu" "ubuntu-uefi-amd64" {
  accelerator = "kvm"
  cd_label    = "cidata"
  cd_files = [
    "tmp/libvirt-uefi-autoinstall-cloud-init-data/user-data",
    "autoinstall-cloud-init-data/meta-data",
  ]
  machine_type   = "q35"
  boot_command   = local.boot_command
  boot_wait      = "5s"
  disk_discard   = "unmap"
  disk_interface = "virtio-scsi"
  disk_size      = var.disk_size
  format         = "qcow2"
  headless       = true
  net_device     = "virtio-net"
  iso_checksum   = var.iso_checksum
  iso_url        = var.iso_url
  cpus           = 2
  memory         = 2048
  qemuargs = [
    ["-cpu", "host"],
    ["-bios", "/usr/share/ovmf/OVMF.fd"],
    ["-device", "virtio-vga"],
    ["-device", "virtio-scsi-pci,id=scsi0"],
    ["-device", "scsi-hd,bus=scsi0.0,drive=drive0"],
  ]
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "60m"
  shutdown_command = "sudo -S poweroff"
}

source "virtualbox-iso" "ubuntu-amd64" {
  cd_label = "cidata"
  cd_files = [
    "autoinstall-cloud-init-data/user-data",
    "autoinstall-cloud-init-data/meta-data",
  ]
  boot_command         = local.boot_command
  boot_wait            = "5s"
  disk_size            = var.disk_size
  guest_additions_mode = "attach"
  guest_os_type        = "Ubuntu_64"
  hard_drive_discard   = true
  hard_drive_interface = "sata"
  headless             = true
  iso_checksum         = var.iso_checksum
  iso_url              = var.iso_url
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--memory", "2048"],
    ["modifyvm", "{{.Name}}", "--cpus", "2"],
    ["modifyvm", "{{.Name}}", "--vram", "16"],
    ["modifyvm", "{{.Name}}", "--audio", "none"],
    ["modifyvm", "{{.Name}}", "--nictype1", "82540EM"],
    ["modifyvm", "{{.Name}}", "--nictype2", "82540EM"],
    ["modifyvm", "{{.Name}}", "--nictype3", "82540EM"],
    ["modifyvm", "{{.Name}}", "--nictype4", "82540EM"],
  ]
  vboxmanage_post = [
    ["storagectl", "{{.Name}}", "--name", "IDE Controller", "--remove"],
  ]
  ssh_username        = "vagrant"
  ssh_password        = "vagrant"
  ssh_timeout         = "60m"
  shutdown_command    = "sudo -S poweroff"
  post_shutdown_delay = "2m"
}

build {
  sources = [
    "source.hyperv-iso.ubuntu-amd64",
    "source.qemu.ubuntu-amd64",
    "source.qemu.ubuntu-uefi-amd64",
    "source.virtualbox-iso.ubuntu-amd64",
  ]

  provisioner "shell" {
    execute_command = "echo vagrant | sudo -S {{ .Vars }} bash {{ .Path }}"
    scripts = [
      "upgrade.sh",
    ]
  }

  provisioner "shell" {
    execute_command   = "sudo -S {{ .Vars }} bash {{ .Path }}"
    expect_disconnect = true
    scripts = [
      "reboot.sh",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo -S {{ .Vars }} bash {{ .Path }}"
    scripts = [
      "provision-guest-additions.sh",
    ]
  }

  provisioner "shell" {
    execute_command   = "sudo -S {{ .Vars }} bash {{ .Path }}"
    expect_disconnect = true
    scripts = [
      "reboot.sh",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo -S {{ .Vars }} bash {{ .Path }}"
    scripts = [
      "provision.sh",
    ]
  }

  provisioner "shell-local" {
    environment_vars = [
      "PACKER_VERSION=${packer.version}",
      "PACKER_VM_NAME=${build.ID}",
    ]
    only = [
      "hyperv-iso.ubuntu-amd64",
    ]
    scripts = ["provision-local-hyperv.cmd"]
  }

  post-processor "vagrant" {
    only = [
      "qemu.ubuntu-amd64",
      "virtualbox-iso.ubuntu-amd64",
      "hyperv-iso.ubuntu-amd64",
    ]
    output               = var.vagrant_box
    vagrantfile_template = "Vagrantfile.template"
  }

  post-processor "vagrant" {
    only = [
      "qemu.ubuntu-uefi-amd64",
    ]
    output               = var.vagrant_box
    vagrantfile_template = "Vagrantfile-uefi.template"
  }
}
