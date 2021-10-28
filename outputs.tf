output "logger_public_ip" {
  value = proxmox_vm_qemu.logger.default_ipv4_address
}

output "dc_public_ip" {
  value = proxmox_vm_qemu.dc.default_ipv4_address
}

output "wef_public_ip" {
  value = proxmox_vm_qemu.wef.default_ipv4_address
}

output "win10_public_ip" {
  value = proxmox_vm_qemu.win10.default_ipv4_address
}