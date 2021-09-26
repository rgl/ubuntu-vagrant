variable "disk_size" {
  type    = string
  default = "61440"
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/21.10/ubuntu-21.10-beta-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:9359978b0a800b4df71fefc14d0dff87d606f50008581c0127a519256f04e3a8"
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

source "hyperv-iso" "ubuntu-amd64" {
  cd_label = "cidata"
  cd_files = [
    "tmp/hyperv-autoinstall-cloud-init-data/user-data",
    "autoinstall-cloud-init-data/meta-data",
  ]
  boot_command = [
    "e",
    "<leftCtrlOn>kkkkkkkkkkkkkkkkkkkk<leftCtrlOff>",
    "linux /casper/vmlinuz",
    " net.ifnames=0",
    " autoinstall",
    "<enter>",
    "initrd /casper/initrd",
    "<enter>",
    "<f10>",
  ]
  boot_wait         = "5s"
  boot_order        = ["SCSI:0:0"]
  first_boot_device = "DVD"
  cpus              = 2
  memory            = 2048
  disk_size         = var.disk_size
  generation        = 2
  headless          = true
  http_directory    = "."
  iso_checksum      = var.iso_checksum
  iso_url           = var.iso_url
  switch_name       = var.hyperv_switch_name
  temp_path         = "tmp"
  vlan_id           = var.hyperv_vlan_id
  ssh_username      = "vagrant"
  ssh_password      = "vagrant"
  ssh_timeout       = "60m"
  shutdown_command  = "echo vagrant | sudo -S poweroff"
}

source "qemu" "ubuntu-amd64" {
  accelerator = "kvm"
  cd_label    = "cidata"
  cd_files = [
    "autoinstall-cloud-init-data/user-data",
    "autoinstall-cloud-init-data/meta-data",
  ]
  boot_command = [
    "e",
    "<leftCtrlOn>kkkkkkkkkkkkkkkkkkkk<leftCtrlOff>",
    "linux /casper/vmlinuz",
    " net.ifnames=0",
    " autoinstall",
    "<enter>",
    "initrd /casper/initrd",
    "<enter>",
    "<f10>",
  ]
  boot_wait      = "5s"
  disk_discard   = "unmap"
  disk_interface = "virtio-scsi"
  disk_size      = var.disk_size
  format         = "qcow2"
  headless       = true
  http_directory = "."
  iso_checksum   = var.iso_checksum
  iso_url        = var.iso_url
  qemuargs = [
    ["-m", "2048"],
    ["-smp", "2"],
  ]
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "60m"
  shutdown_command = "echo vagrant | sudo -S poweroff"
}

source "qemu" "ubuntu-uefi-amd64" {
  accelerator = "kvm"
  cd_label    = "cidata"
  cd_files = [
    "tmp/libvirt-uefi-autoinstall-cloud-init-data/user-data",
    "autoinstall-cloud-init-data/meta-data",
  ]
  boot_command = [
    "e",
    "<leftCtrlOn>kkkkkkkkkkkkkkkkkkkk<leftCtrlOff>",
    "linux /casper/vmlinuz",
    " net.ifnames=0",
    " autoinstall",
    "<enter>",
    "initrd /casper/initrd",
    "<enter>",
    "<f10>",
  ]
  boot_wait      = "5s"
  disk_discard   = "unmap"
  disk_interface = "virtio-scsi"
  disk_size      = var.disk_size
  format         = "qcow2"
  headless       = true
  http_directory = "."
  iso_checksum   = var.iso_checksum
  iso_url        = var.iso_url
  qemuargs = [
    ["-bios", "/usr/share/ovmf/OVMF.fd"],
    ["-device", "virtio-vga"],
    ["-device", "virtio-scsi-pci,id=scsi0"],
    ["-device", "scsi-hd,bus=scsi0.0,drive=drive0"],
    ["-m", "2048"],
    ["-smp", "2"],
  ]
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "60m"
  shutdown_command = "echo vagrant | sudo -S poweroff"
}

source "virtualbox-iso" "ubuntu-amd64" {
  cd_label = "cidata"
  cd_files = [
    "autoinstall-cloud-init-data/user-data",
    "autoinstall-cloud-init-data/meta-data",
  ]
  boot_command = [
    "e",
    "<leftCtrlOn>kkkkkkkkkkkkkkkkkkkk<leftCtrlOff>",
    "linux /casper/vmlinuz",
    " net.ifnames=0",
    " autoinstall",
    "<enter>",
    "initrd /casper/initrd",
    "<enter>",
    "<f10>",
  ]
  boot_wait            = "5s"
  disk_size            = var.disk_size
  guest_additions_mode = "attach"
  guest_os_type        = "Ubuntu_64"
  hard_drive_discard   = true
  hard_drive_interface = "sata"
  headless             = true
  http_directory       = "."
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
  shutdown_command    = "echo vagrant | sudo -S poweroff"
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
    execute_command   = "echo vagrant | sudo -S {{ .Vars }} bash {{ .Path }}"
    expect_disconnect = true
    scripts = [
      "upgrade.sh",
      "provision-guest-additions.sh",
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
