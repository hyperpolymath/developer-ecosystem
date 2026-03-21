// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Line Printer Daemon protocol for print queue management Connector
// Author: Jonathan D.A. Jewell
//
// Line Printer Daemon protocol for print queue management.
// Provides typed client bindings for the proven-lpd protocol.

module lpd

import os
import time
import net

// --- Job state ---

// PrintJobState tracks a print job lifecycle.
pub enum PrintJobState {
	queued
	printing
	completed
	cancelled
	error
}

// --- Data structures ---

// PrintQueue defines a print queue.
pub struct PrintQueue {
pub:
	name        string
	device      string  // e.g., "/dev/lp0" or network URI
	enabled     bool = true
}

// PrintJob represents a queued print job.
pub struct PrintJob {
pub:
	job_id      int
	queue_name  string
	filename    string
	state       PrintJobState
	copies      int = 1
}

// LpdConfig holds LPD server parameters.
pub struct LpdConfig {
pub:
	listen_port  int = 515
	spool_dir    string = "/var/spool/lpd"
}

// LpdManager manages print queues and jobs.
pub struct LpdManager {
mut:
	config  LpdConfig
	queues  []PrintQueue
	jobs    []PrintJob
}

// --- Manager lifecycle ---

// new_lpd_manager creates a new LPD manager.
pub fn new_lpd_manager(config LpdConfig) &LpdManager {
	return &LpdManager{
		config: config
		queues: []PrintQueue{}
		jobs:   []PrintJob{}
	}
}

// add_queue registers a print queue.
pub fn (mut m LpdManager) add_queue(queue PrintQueue) ! {
	if queue.name.len == 0 {
		return error("queue name must not be empty")
	}
	m.queues << queue
	println("[lpd] added queue: ${queue.name} -> ${queue.device}")
}

// submit_job queues a print job.
pub fn (mut m LpdManager) submit_job(job PrintJob) ! {
	if job.filename.len == 0 {
		return error("filename must not be empty")
	}
	m.jobs << job
	println("[lpd] queued job ${job.job_id} on ${job.queue_name}")
}

// --- Tests ---

fn test_empty_queue_name_rejected() {
	mut mgr := new_lpd_manager(LpdConfig{})
	mgr.add_queue(PrintQueue{ name: "", device: "/dev/lp0" }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
