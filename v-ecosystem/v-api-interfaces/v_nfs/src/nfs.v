// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Network File System v4 with Kerberos auth and delegations Connector
// Author: Jonathan D.A. Jewell
//
// Network File System v4 with Kerberos auth and delegations.
// Provides typed client bindings for the proven-nfs protocol.

module nfs

import os
import time
import net

// --- NFS version ---

// NfsVersion selects the NFS protocol version.
pub enum NfsVersion {
	v3
	v4
	v41   // pNFS
	v42   // Server-side copy
}

// --- Export security ---

// ExportSecurity selects the NFS security flavour.
pub enum ExportSecurity {
	sys          // AUTH_SYS (UID/GID)
	krb5         // Kerberos authentication
	krb5i        // Kerberos integrity
	krb5p        // Kerberos privacy
}

// --- Data structures ---

// NfsExport defines an NFS export.
pub struct NfsExport {
pub:
	path         string
	clients      []string    // Allowed client CIDRs
	security     ExportSecurity = .krb5p
	read_only    bool = false
}

// NfsConfig holds NFS server parameters.
pub struct NfsConfig {
pub:
	version      NfsVersion = .v42
	nfsd_count   int = 8
	port         int = 2049
}

// NfsManager manages NFS exports.
pub struct NfsManager {
mut:
	config   NfsConfig
	exports  []NfsExport
}

// --- Manager lifecycle ---

// new_nfs_manager creates a new NFS manager.
pub fn new_nfs_manager(config NfsConfig) &NfsManager {
	return &NfsManager{
		config:  config
		exports: []NfsExport{}
	}
}

// add_export registers an NFS export.
pub fn (mut m NfsManager) add_export(exp NfsExport) ! {
	if exp.path.len == 0 {
		return error("export path must not be empty")
	}
	m.exports << exp
	println("[nfs] exported: ${exp.path} (${exp.security})")
}

// remove_export removes an export by path.
pub fn (mut m NfsManager) remove_export(path string) ! {
	m.exports = m.exports.filter(it.path != path)
	println("[nfs] removed export: ${path}")
}

// --- Tests ---

fn test_empty_export_path_rejected() {
	mut mgr := new_nfs_manager(NfsConfig{})
	mgr.add_export(NfsExport{ path: "", clients: [], security: .krb5p }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
