provider "proxmox" {
  #pm_api_url          = "https://10.0.0.10:8006/api2/json"
  #pm_api_token_id     = "terraform@pam!beeab060-094e-11ec-9a03-0242ac130003"
  #pm_api_token_secret = "c20b0aa9-5965-4d54-abd9-4dc2325aa848"
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
  pm_log_enable       = true
  pm_log_file         = "terraform-plugin-proxmox.log"
  pm_log_levels       = {
    _default    = "debug"
    _capturelog = ""
  }
} # end promox provider

############################################
### Source the cloud-init config file and 
### transfer them over to proxmox                          
############################################

# Source the Cloud Init Config file for the domain controller
data "template_file" "cloud_init_dc" {
  template  = "${file("${path.module}/files/user_data_dc_template.cfg")}"
} # end template file declaration for dc

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_dc" {
  content   = data.template_file.cloud_init_dc.rendered
  filename  = "${path.module}/files/user_data_dc.cfg"
} # end local file creation of template for dc

# Transfer the file to the Proxmox Host
resource "null_resource" "cloud_init_dc" {
  connection {
    type    = "ssh"
    user    = "root"
    private_key = file("~/.ssh/pve01")
    host    = "10.0.0.10"
  }

  provisioner "file" {
    source       = local_file.cloud_init_dc.filename
    destination  = "/var/lib/vz/snippets/user_data_dc.yml"
  }
} # end transfer of config file for dc to proxmox

# Source the Cloud Init Config file for the wef
data "template_file" "cloud_init_wef" {
  template  = "${file("${path.module}/files/user_data_wef_template.cfg")}"
} # end template file declaration for wef

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_wef" {
  content   = data.template_file.cloud_init_wef.rendered
  filename  = "${path.module}/files/user_data_wef.cfg"
} # end local file creation of template for wef

# Transfer the file to the Proxmox Host
resource "null_resource" "cloud_init_wef" {
  connection {
    type    = "ssh"
    user    = "root"
    private_key = file("~/.ssh/pve01")
    host    = "10.0.0.10"
  }

  provisioner "file" {
    source       = local_file.cloud_init_wef.filename
    destination  = "/var/lib/vz/snippets/user_data_wef.yml"
  }
} # end transfer of config file for wef to proxmox

# Source the Cloud Init Config file for the win10 client
data "template_file" "cloud_init_win10" {
  template  = "${file("${path.module}/files/user_data_win10_template.cfg")}"
} # end template file declaration for win10

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_win10" {
  content   = data.template_file.cloud_init_win10.rendered
  filename  = "${path.module}/files/user_data_win10.cfg"
} # end local file creation of template for win10

# Transfer the file to the Proxmox Host
resource "null_resource" "cloud_init_win10" {
  connection {
    type    = "ssh"
    user    = "root"
    private_key = file("~/.ssh/pve01")
    host    = "10.0.0.10"
  }

  provisioner "file" {
    source       = local_file.cloud_init_win10.filename
    destination  = "/var/lib/vz/snippets/user_data_win10.yml"
  }
} # end transfer of config file for win10 to proxmox

# Source the Cloud Init Config file for the logger linux box
data "template_file" "cloud_init_logger" {
  template  = "${file("${path.module}/files/user_data_logger_template.cfg")}"
} # end template file declaration for logger linux box

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_logger" {
  content   = data.template_file.cloud_init_logger.rendered
  filename  = "${path.module}/files/user_data_logger.cfg"
} # end local file creation of template for logger linux box

# Transfer the file to the Proxmox Host
resource "null_resource" "cloud_init_logger" {
  connection {
    type    = "ssh"
    user    = "root"
    private_key = file("~/.ssh/pve01")
    host    = "10.0.0.10"
  }

  provisioner "file" {
    source       = local_file.cloud_init_logger.filename
    destination  = "/var/lib/vz/snippets/user_data_logger.yml"
  }
} # end transfer of config file for logger to proxmox

############################################
### Create the VMs based on VM templates
############################################

# Create the logger VM
resource "proxmox_vm_qemu" "logger" {

  depends_on = [
    null_resource.cloud_init_logger,
  ]

  name        = "logger"
  target_node = "pve-node1"
  tags        = "test"

  # Clone from windows linux-cloudinit template
  clone = "linux-cloudinit"
  os_type = "cloud-init"

  # Cloud init options
  cicustom = "user=local:snippets/user_data_logger.yml"
  cloudinit_cdrom_storage = "local"
  
  ipconfig0 = "ip=dhcp"
  ipconfig1 = "ip=dhcp"

  memory       = 4096
  agent        = 1
  sockets      = 1
  cores        = 2

  # Set the boot disk paramters
  bootdisk     = "scsi0"
  scsihw       = "virtio-scsi-pci"

  disk {
    size            = "35G"
    type            = "scsi"
    storage         = "ceph-vm"
  } # end disk

  # Set the network
  network {
    model = "virtio"
    bridge = "vmbr0"
  } # end first network block

  network {
    model = "virtio"
    bridge = "vmbr1"
    macaddr = "00:01:42:60:3a:51"
  } # end second network block

  # Ignore changes to the network
  ## MAC address is generated on every apply, causing
  ## TF to think this needs to be rebuilt on every apply
  lifecycle {
     ignore_changes = [
       network
     ]
  } # end lifecycle
} # end proxmox_vm_qemu logger resource declaration

# Create the domain controller VM
resource "proxmox_vm_qemu" "dc" {

  depends_on = [
    null_resource.cloud_init_dc,
    proxmox_vm_qemu.logger,
  ]

  name        = "dc"
  target_node = "pve-node1"
  tags        = "test"

  # Clone from windows 2k19-cloudinit template
  clone = "win-2k19-cloudinit"
  os_type = "cloud-init"

  # Cloud init options
  cicustom = "user=local:snippets/user_data_dc.yml"
  cloudinit_cdrom_storage = "local"
  
  ipconfig0 = "ip=dhcp"
  ipconfig1 = "ip=dhcp"

  memory       = 4096
  agent        = 1
  sockets      = 1
  cores        = 2

  # Set the boot disk paramters
  bootdisk     = "scsi0"
  scsihw       = "virtio-scsi-pci"

  disk {
    size            = "35G"
    type            = "scsi"
    storage         = "ceph-vm"
  } # end disk

  # Set the network
  network {
    model = "virtio"
    bridge = "vmbr0"
  } # end first network block

  network {
    model = "virtio"
    bridge = "vmbr1"
    macaddr = "00:01:42:06:4d:3d"
  } # end second network block

  # Ignore changes to the network
  ## MAC address is generated on every apply, causing
  ## TF to think this needs to be rebuilt on every apply
  lifecycle {
     ignore_changes = [
       network
     ]
  } # end lifecycle
} # end proxmox_vm_qemu dc resource declaration

# Create the wef VM
resource "proxmox_vm_qemu" "wef" {

  depends_on = [
    null_resource.cloud_init_wef,
    proxmox_vm_qemu.dc,
  ]

  name        = "wef"
  target_node = "pve-node1"
  tags        = "test"

  # Clone from windows 2k19-cloudinit template
  clone = "win-2k19-cloudinit"
  os_type = "cloud-init"

  # Cloud init options
  cicustom = "user=local:snippets/user_data_wef.yml"
  cloudinit_cdrom_storage = "local"
  
  ipconfig0 = "ip=dhcp"
  ipconfig1 = "ip=dhcp"

  memory       = 4096
  agent        = 1
  sockets      = 1
  cores        = 2

  # Set the boot disk paramters
  bootdisk     = "scsi0"
  scsihw       = "virtio-scsi-pci"

  disk {
    size            = "35G"
    type            = "scsi"
    storage         = "ceph-vm"
  } # end disk

  # Set the network
  network {
    model = "virtio"
    bridge = "vmbr0"
  } # end first network block

  network {
    model = "virtio"
    bridge = "vmbr1"
    macaddr = "00:01:42:12:84:13"
  } # end second network block

  # Ignore changes to the network
  ## MAC address is generated on every apply, causing
  ## TF to think this needs to be rebuilt on every apply
  lifecycle {
     ignore_changes = [
       network
     ]
  } # end lifecycle
} # end proxmox_vm_qemu wef resource declaration

# Create the win10 VM
resource "proxmox_vm_qemu" "win10" {

  depends_on = [
    null_resource.cloud_init_win10,
    proxmox_vm_qemu.wef,
  ]

  name        = "win10"
  target_node = "pve-node1"
  tags        = "test"

  # Clone from windows 2k19-cloudinit template
  clone = "win-10-cloudinit"
  os_type = "cloud-init"

  # Cloud init options
  cicustom = "user=local:snippets/user_data_win10.yml"
  cloudinit_cdrom_storage = "local"
  
  ipconfig0 = "ip=dhcp"
  ipconfig1 = "ip=dhcp"

  memory       = 8192
  agent        = 1
  sockets      = 1
  cores        = 3

  # Set the boot disk paramters
  bootdisk     = "scsi0"
  scsihw       = "virtio-scsi-pci"

  disk {
    size            = "45G"
    type            = "scsi"
    storage         = "ceph-vm"
  } # end disk

  # Set the network
  network {
    model = "virtio"
    bridge = "vmbr0"
  } # end first network block

  network {
    model = "virtio"
    bridge = "vmbr1"
    macaddr = "00:01:42:a9:4e:66"
  } # end second network block

  # Ignore changes to the network
  ## MAC address is generated on every apply, causing
  ## TF to think this needs to be rebuilt on every apply
  lifecycle {
     ignore_changes = [
       network
     ]
  } # end lifecycle
} # end proxmox_vm_qemu win10 resource declaration

