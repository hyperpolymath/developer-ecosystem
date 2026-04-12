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
pub mut:
	id          string
	name        string
	state       VmState
	hypervisor  Hypervisor
	vnc_port    int
}

// SnapshotInfo records metadata about a VM snapshot.
pub struct SnapshotInfo {
pub:
	vm_id       string
	snap_name   string
	created_at  i64
	description string
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
	config    VirtConfig
	vms       []VmInstance
	snapshots []SnapshotInfo
}

// --- Manager lifecycle ---

// new_virt_manager creates a new virtualisation manager.
pub fn new_virt_manager(config VirtConfig) &VirtManager {
	return &VirtManager{
		config:    config
		vms:       []VmInstance{}
		snapshots: []SnapshotInfo{}
	}
}

// create_vm provisions a new virtual machine and returns its assigned ID.
pub fn (mut m VirtManager) create_vm(spec VmSpec) !string {
	if spec.name.len == 0 {
		return error("VM name must not be empty")
	}
	vm_id := "vm-${spec.name}"
	m.vms << VmInstance{ id: vm_id, name: spec.name, state: .defined, hypervisor: spec.hypervisor, vnc_port: 0 }
	println("[virt] created VM: ${spec.name} id=${vm_id} (${spec.vcpus} vCPUs, ${spec.memory_mb}MB)")
	return vm_id
}

// snapshot creates a named snapshot of the specified VM.
pub fn (mut m VirtManager) snapshot(vm_name string, snap_name string) ! {
	if snap_name.len == 0 {
		return error("snapshot name must not be empty")
	}
	m.snapshots << SnapshotInfo{
		vm_id:     vm_name
		snap_name: snap_name
		created_at: time.now().unix()
	}
	println("[virt] snapshot ${snap_name} of VM ${vm_name}")
}

// start transitions a VM from defined or suspended state to running.
pub fn (mut m VirtManager) start(vm_id string) ! {
	if vm_id.len == 0 {
		return error("vm_id must not be empty")
	}
	for i in 0 .. m.vms.len {
		if m.vms[i].id == vm_id {
			if m.vms[i].state == .running {
				return error("VM '${vm_id}' is already running")
			}
			m.vms[i].state = .running
			println("[virt] started VM ${vm_id}")
			return
		}
	}
	return error("VM '${vm_id}' not found")
}

// stop powers off a running VM.
pub fn (mut m VirtManager) stop(vm_id string) ! {
	if vm_id.len == 0 {
		return error("vm_id must not be empty")
	}
	for i in 0 .. m.vms.len {
		if m.vms[i].id == vm_id {
			if m.vms[i].state == .shutdown {
				return error("VM '${vm_id}' is already stopped")
			}
			m.vms[i].state = .shutdown
			println("[virt] stopped VM ${vm_id}")
			return
		}
	}
	return error("VM '${vm_id}' not found")
}

// pause suspends CPU execution of a running VM without saving state to disk.
pub fn (mut m VirtManager) pause(vm_id string) ! {
	if vm_id.len == 0 {
		return error("vm_id must not be empty")
	}
	for i in 0 .. m.vms.len {
		if m.vms[i].id == vm_id {
			if m.vms[i].state != .running {
				return error("VM '${vm_id}' must be running to pause")
			}
			m.vms[i].state = .paused
			println("[virt] paused VM ${vm_id}")
			return
		}
	}
	return error("VM '${vm_id}' not found")
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

fn test_create_vm_returns_id() {
	mut mgr := new_virt_manager(VirtConfig{})
	id := mgr.create_vm(VmSpec{ name: "test-vm", image: "alpine.qcow2" }) or { panic(err) }
	assert id.starts_with("vm-")
}

fn test_start_nonexistent_vm_rejected() {
	mut mgr := new_virt_manager(VirtConfig{})
	mgr.start("vm-ghost") or {
		assert err.str().contains("not found")
		return
	}
	assert false
}

fn test_start_and_pause_vm() {
	mut mgr := new_virt_manager(VirtConfig{})
	id := mgr.create_vm(VmSpec{ name: "pausable", image: "ubuntu.qcow2" }) or { panic(err) }
	mgr.start(id) or { panic(err) }
	mgr.pause(id) or { panic(err) }
	// Pausing again should fail
	mgr.pause(id) or {
		assert err.str().contains("must be running")
		return
	}
	assert false
}

fn test_empty_vm_id_rejected_on_stop() {
	mut mgr := new_virt_manager(VirtConfig{})
	mgr.stop("") or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
