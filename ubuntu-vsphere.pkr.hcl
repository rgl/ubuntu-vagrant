variable "disk_size" {
  type    = string
  default = "8192"
}

variable "version" {
  type = string
}

variable "vsphere_host" {
  type    = string
  default = env("GOVC_HOST")
}

variable "vsphere_username" {
  type    = string
  default = env("GOVC_USERNAME")
}

variable "vsphere_password" {
  type      = string
  default   = env("GOVC_PASSWORD")
  sensitive = true
}

variable "vsphere_esxi_host" {
  type    = string
  default = env("VSPHERE_ESXI_HOST")
}

variable "vsphere_datacenter" {
  type    = string
  default = env("GOVC_DATACENTER")
}

variable "vsphere_cluster" {
  type    = string
  default = env("GOVC_CLUSTER")
}

variable "vsphere_datastore" {
  type    = string
  default = env("GOVC_DATASTORE")
}

variable "vsphere_folder" {
  type    = string
  default = env("VSPHERE_TEMPLATE_FOLDER")
}

variable "vsphere_network" {
  type    = string
  default = env("VSPHERE_VLAN")
}

variable "vsphere_ip_wait_address" {
  type        = string
  default     = env("VSPHERE_IP_WAIT_ADDRESS")
  description = "IP CIDR which guests will use to reach the host. see https://github.com/hashicorp/packer/blob/ff5b55b560095ca88421d3f1ad8b8a66646b7ab6/builder/vsphere/common/step_http_ip_discover.go#L32"
}

variable "vsphere_os_iso" {
  type        = string
  default     = env("VSPHERE_OS_ISO")
}

source "vsphere-iso" "ubuntu-amd64" {
  CPUs = 4
  RAM  = 2048
  boot_command = [
    "<tab>",
    "<leftCtrlOn>u<leftCtrlOff>",
    "linux initrd=initrd.gz",
    " auto=true",
    " url={{.HTTPIP}}:{{.HTTPPort}}/tmp/preseed-vsphere.txt",
    " hostname=vagrant",
    " net.ifnames=0",
    " DEBCONF_DEBUG=5",
    "<enter>",
  ]
  boot_wait           = "5s"
  convert_to_template = true
  insecure_connection = "true"
  vcenter_server      = var.vsphere_host
  username            = var.vsphere_username
  password            = var.vsphere_password
  vm_name             = "ubuntu-${var.version}-amd64-vsphere"
  datacenter          = var.vsphere_datacenter
  cluster             = var.vsphere_cluster
  host                = var.vsphere_esxi_host
  folder              = var.vsphere_folder
  datastore           = var.vsphere_datastore
  guest_os_type       = "ubuntu64Guest"
  http_directory      = "."
  ip_wait_address     = var.vsphere_ip_wait_address
  iso_paths = [
    var.vsphere_os_iso
  ]
  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }
  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }
  disk_controller_type = ["pvscsi"]
  ssh_password         = "vagrant"
  ssh_username         = "vagrant"
  shutdown_command     = "echo vagrant | sudo -S poweroff"
}

build {
  sources = ["source.vsphere-iso.ubuntu-amd64"]

  provisioner "shell" {
    execute_command   = "echo vagrant | sudo -S bash {{ .Path }}"
    expect_disconnect = true
    scripts = [
      "provision-guest-additions.sh",
      "provision.sh",
    ]
  }
}
