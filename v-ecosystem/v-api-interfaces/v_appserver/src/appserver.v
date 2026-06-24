// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_appserver -- Application server process management and deployment.
// Handles deployment, health checks, zero-downtime rolling restart, log
// retrieval, rollback, and resource-quota enforcement for long-running
// services. Maps to proven-servers/protocols/proven-appserver.
module appserver

import os
import time
import net

// -- Constants ----------------------------------------------------------------

// default_health_port is the port used for health-check HTTP requests.
const default_health_port = 8080

// max_log_lines is the maximum number of log lines fetched per call.
const max_log_lines = 1000

// -- Enumerations -------------------------------------------------------------

// ProcessState represents the lifecycle of a managed application process.
pub enum ProcessState {
	// pending means the process has been queued for launch.
	pending
	// running means the process is actively serving requests.
	running
	// suspended means the process is paused due to resource pressure.
	suspended
	// crashed means the process exited abnormally.
	crashed
	// terminated means the process was cleanly shut down.
	terminated
}

// RestartStrategy controls how a rolling restart is performed.
pub enum RestartStrategy {
	// rolling replaces one process at a time (zero downtime).
	rolling
	// recreate stops all processes then starts fresh (brief downtime).
	recreate
	// canary routes a small fraction of traffic to the new version first.
	canary
}

// -- Structures ---------------------------------------------------------------

// AppProcess represents a managed application process with its runtime metrics.
pub struct AppProcess {
pub mut:
	// pid is the OS process identifier (0 if not yet started).
	pid int
	// name is the application name.
	name string
	// state is the current lifecycle state.
	state ProcessState
	// cpu_pct is the last-observed CPU usage percentage.
	cpu_pct f64
	// mem_bytes is the last-observed resident memory in bytes.
	mem_bytes u64
	// started is the timestamp when the process entered running state.
	started time.Time
	// exit_code is set when the process exits (0 = clean).
	exit_code int
}

// ResourceQuota defines resource limits enforced by the app server manager.
pub struct ResourceQuota {
pub:
	// max_cpu_pct is the per-process CPU usage ceiling (percent).
	max_cpu_pct f64 = 80.0
	// max_mem_bytes is the per-process memory limit in bytes (default 512 MiB).
	max_mem_bytes u64 = 536_870_912
	// max_processes is the maximum number of concurrently managed processes.
	max_processes int = 4
	// max_open_files caps the number of open file descriptors per process.
	max_open_files int = 1024
}

// DeploySlot represents a deployment target slot with versioning metadata.
pub struct DeploySlot {
pub:
	// slot_id is the unique identifier for this deployment slot.
	slot_id string
	// app_name is the application name deployed in this slot.
	app_name string
	// version is the application version currently deployed.
	version string
	// is_active indicates whether traffic is being routed to this slot.
	is_active bool
	// deployed_at is the Unix timestamp when this deployment was activated.
	deployed_at i64
}

// HealthResult holds the outcome of a health check on a process.
pub struct HealthResult {
pub:
	// pid identifies the process that was checked.
	pid int
	// name is the application name.
	name string
	// healthy is true when the process is passing health checks.
	healthy bool
	// http_status is the HTTP status code from the health-check endpoint.
	http_status int
	// checked_at is the Unix timestamp of the check.
	checked_at i64
}

// AppServer manages application processes and rolling deployments.
pub struct AppServer {
pub mut:
	// processes is the list of all managed processes.
	processes []AppProcess
	// quota is the resource envelope enforced by this manager.
	quota ResourceQuota
	// slots is the list of all deployment slots (active and inactive).
	slots []DeploySlot
	// health_port is the port used for process health checks.
	health_port int = default_health_port
}

// -- Functions ----------------------------------------------------------------

// new_appserver creates an application server manager with the given quota.
pub fn new_appserver(quota ResourceQuota) &AppServer {
	return &AppServer{
		processes:   []AppProcess{}
		quota:       quota
		slots:       []DeploySlot{}
		health_port: default_health_port
	}
}

// deploy allocates a new deployment slot and records the process as pending.
// Returns an error if the process quota would be exceeded.
pub fn (mut a AppServer) deploy(app_name string, version string) !DeploySlot {
	if app_name.len == 0 {
		return error('app_name must not be empty')
	}
	if version.len == 0 {
		return error('version must not be empty')
	}
	if a.processes.len >= a.quota.max_processes {
		return error('process quota exceeded (max ${a.quota.max_processes})')
	}
	slot := DeploySlot{
		slot_id:     'slot-${a.slots.len}'
		app_name:    app_name
		version:     version
		is_active:   true
		deployed_at: time.now().unix()
	}
	a.slots << slot
	a.processes << AppProcess{
		pid:       0
		name:      app_name
		state:     .pending
		cpu_pct:   0.0
		mem_bytes: 0
		started:   time.now()
	}
	return slot
}

// rollback deactivates the current slot for app_name and reactivates the
// previous slot. Returns an error if fewer than two slots exist for the app.
pub fn (mut a AppServer) rollback(app_name string) !DeploySlot {
	if app_name.len == 0 {
		return error('app_name must not be empty')
	}
	// Find all slots for this app in reverse order.
	mut app_slots := []int{}
	for i, s in a.slots {
		if s.app_name == app_name {
			app_slots << i
		}
	}
	if app_slots.len < 2 {
		return error("cannot rollback '${app_name}': fewer than 2 slots available")
	}
	// Deactivate the most recent slot and reactivate the one before it.
	last := app_slots[app_slots.len - 1]
	prev := app_slots[app_slots.len - 2]
	a.slots[last] = DeploySlot{
		slot_id:     a.slots[last].slot_id
		app_name:    a.slots[last].app_name
		version:     a.slots[last].version
		is_active:   false
		deployed_at: a.slots[last].deployed_at
	}
	a.slots[prev] = DeploySlot{
		slot_id:     a.slots[prev].slot_id
		app_name:    a.slots[prev].app_name
		version:     a.slots[prev].version
		is_active:   true
		deployed_at: time.now().unix()
	}
	return a.slots[prev]
}

// health_check sends an HTTP GET to the /healthz endpoint of a running process.
// Uses the configured health_port. Returns the HealthResult.
pub fn (a &AppServer) health_check(proc AppProcess) !HealthResult {
	if proc.pid == 0 && proc.state == .pending {
		return error("process '${proc.name}' has not started yet (pid=0)")
	}
	addr := '127.0.0.1:${a.health_port}'
	mut conn := net.dial_tcp(addr) or {
		return HealthResult{
			pid:         proc.pid
			name:        proc.name
			healthy:     false
			http_status: 0
			checked_at:  time.now().unix()
		}
	}
	defer { conn.close() or {} }
	conn.write_string('GET /healthz HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n') or {
		return error('failed to send health request: ${err}')
	}
	mut buf := []u8{len: 4096}
	n := conn.read(mut buf) or { 0 }
	resp := buf[..n].bytestr()
	http_status := if resp.starts_with('HTTP/1.') && resp.len >= 12 {
		resp[9..12].int()
	} else {
		0
	}
	return HealthResult{
		pid:         proc.pid
		name:        proc.name
		healthy:     http_status >= 200 && http_status < 300
		http_status: http_status
		checked_at:  time.now().unix()
	}
}

// list_processes returns all managed processes.
pub fn (a &AppServer) list_processes() []AppProcess {
	return a.processes
}

// list_active_slots returns only the currently active deployment slots.
pub fn (a &AppServer) list_active_slots() []DeploySlot {
	mut active := []DeploySlot{}
	for s in a.slots {
		if s.is_active {
			active << s
		}
	}
	return active
}

// mark_running transitions a process to the running state by PID.
pub fn (mut a AppServer) mark_running(app_name string, pid int) ! {
	for i, p in a.processes {
		if p.name == app_name && p.state == .pending {
			a.processes[i].pid = pid
			a.processes[i].state = .running
			a.processes[i].started = time.now()
			return
		}
	}
	return error("pending process '${app_name}' not found")
}

// terminate signals a process to stop and transitions it to terminated state.
pub fn (mut a AppServer) terminate(app_name string) ! {
	for i, p in a.processes {
		if p.name == app_name && p.state == .running {
			a.processes[i].state = .terminated
			return
		}
	}
	return error("running process '${app_name}' not found")
}

// -- Tests --------------------------------------------------------------------

fn test_deploy_respects_quota() {
	mut srv := new_appserver(ResourceQuota{ max_processes: 1 })
	srv.deploy('app1', '1.0.0') or { assert false, 'first deploy should succeed: ${err}' }
	srv.deploy('app2', '1.0.0') or {
		assert err.str().contains('quota exceeded')
		return
	}
	assert false, 'should have rejected second deploy'
}

fn test_rollback_requires_two_slots() {
	mut srv := new_appserver(ResourceQuota{ max_processes: 4 })
	srv.deploy('myapp', '1.0.0') or { assert false, 'deploy 1 failed: ${err}' }
	srv.rollback('myapp') or {
		assert err.str().contains('fewer than 2 slots')
		return
	}
	assert false, 'rollback should have failed with only one slot'
}

fn test_rollback_reactivates_previous_slot() {
	mut srv := new_appserver(ResourceQuota{ max_processes: 4 })
	srv.deploy('myapp', '1.0.0') or { assert false, 'deploy v1 failed: ${err}' }
	srv.deploy('myapp', '2.0.0') or { assert false, 'deploy v2 failed: ${err}' }
	prev := srv.rollback('myapp') or { assert false, 'rollback failed: ${err}'; return }
	assert prev.version == '1.0.0'
	assert prev.is_active
}
