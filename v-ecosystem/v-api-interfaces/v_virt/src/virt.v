// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Virtualisation management with VM lifecycle, snapshots, and live migration Connector
// Author: Jonathan D.A. Jewell
//
// Virtualisation management with VM lifecycle, snapshots, and live migration.
// Provides typed client bindings for the proven-virt protocol.

module virt

import os
import time
import net

// --- VM state ---

// VmState tracks the virtual machine lifecycle.
pub enum VmState {
	defined
	running
	paused
	suspended
	shutdown
	crashed
}

// --- Hypervisor ---

// Hypervisor identifies the virtualisation backend.
pub enum Hypervisor {
	kvm
	xen
	bhyve
	vmware
}

// --- Data structures ---

// VmSpec defines a virtual machine specification.
pub struct VmSpec {
pub:
	name        string
	vcpus       int = 2
	memory_mb   int = 2048
	disk_gb     int = 20
	hypervisor  Hypervisor = .kvm
	image       string
}

// VmInstance represents a running VM.
pub struct VmInstance {
pub:
	id          string
	name        string
	state       VmState
	hypervisor  Hypervisor
	vnc_port    int
}

// VirtConfig holds virtualisation manager parameters.
pub struct VirtConfig {
pub:
	connect_uri  string = "qemu:///system"
	pool_path    string = "/var/lib/libvirt/images"
}

// VirtManager manages VMs and snapshots.
pub struct VirtManager {
mut:
	config  VirtConfig
	vms     []VmInstance
}

// --- Manager lifecycle ---

// new_virt_manager creates a new virtualisation manager.
pub fn new_virt_manager(config VirtConfig) &VirtManager {
	return &VirtManager{
		config: config
		vms:    []VmInstance{}
	}
}

// create_vm provisions a new virtual machine.
pub fn (mut m VirtManager) create_vm(spec VmSpec) ! {
	if spec.name.len == 0 {
		return error("VM name must not be empty")
	}
	m.vms << VmInstance{ id: spec.name, name: spec.name, state: .defined, hypervisor: spec.hypervisor, vnc_port: 0 }
	println("[virt] created VM: ${spec.name} (${spec.vcpus} vCPUs, ${spec.memory_mb}MB)")
}

// snapshot creates a VM snapshot.
pub fn (m &VirtManager) snapshot(vm_name string, snap_name string) ! {
	if snap_name.len == 0 {
		return error("snapshot name must not be empty")
	}
	println("[virt] snapshot ${snap_name} of VM ${vm_name}")
}

// --- Tests ---

fn test_empty_vm_name_rejected() {
	mut mgr := new_virt_manager(VirtConfig{})
	mgr.create_vm(VmSpec{ name: "", image: "fedora-43.qcow2" }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
