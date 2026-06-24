// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_bfd -- Bidirectional Forwarding Detection (BFD) session management and
// fast failure detection for the V-Ecosystem.
// Maps to proven-servers/protocols/proven-bfd.
// Implements the BFD state machine, interval negotiation, and diagnostic
// codes per RFC 5880.
module v_bfd

import rand
import time

// SessionState enumerates the BFD session states per RFC 5880 section 4.1.
pub enum SessionState as u8 {
	admin_down = 0
	down       = 1
	init       = 2
	up         = 3
}

// session_state_to_string returns the human-readable label for a SessionState.
pub fn session_state_to_string(ss SessionState) string {
	return match ss {
		.admin_down { 'AdminDown' }
		.down { 'Down' }
		.init { 'Init' }
		.up { 'Up' }
	}
}

// DiagnosticCode enumerates the BFD diagnostic codes per RFC 5880 section 4.1.
pub enum DiagnosticCode as u8 {
	none              = 0
	control_expired   = 1
	echo_failed       = 2
	neighbor_down     = 3
	forwarding_reset  = 4
	path_down         = 5
}

// diagnostic_to_string returns the human-readable label for a DiagnosticCode.
pub fn diagnostic_to_string(dc DiagnosticCode) string {
	return match dc {
		.none { 'No Diagnostic' }
		.control_expired { 'Control Detection Time Expired' }
		.echo_failed { 'Echo Function Failed' }
		.neighbor_down { 'Neighbor Signaled Session Down' }
		.forwarding_reset { 'Forwarding Plane Reset' }
		.path_down { 'Path Down' }
	}
}

// BfdSession represents a single BFD session with a remote peer including
// discriminators, state, timing parameters, and diagnostic information.
pub struct BfdSession {
pub:
	// local_disc is the locally-assigned session discriminator.
	local_disc u32
	// remote_addr is the IP address of the remote BFD peer.
	remote_addr string
	// desired_min_tx is the minimum desired transmit interval in microseconds.
	desired_min_tx u32 = 1_000_000
	// required_min_rx is the minimum required receive interval in microseconds.
	required_min_rx u32 = 1_000_000
	// detect_mult is the detection time multiplier.
	detect_mult u8 = 3
pub mut:
	// remote_disc is the discriminator assigned by the remote peer.
	remote_disc u32
	// state is the current session state.
	state SessionState = .down
	// remote_state is the last known state of the remote peer.
	remote_state SessionState = .down
	// diag is the current diagnostic code.
	diag DiagnosticCode = .none
	// local_min_tx is the negotiated transmit interval in microseconds.
	local_min_tx u32 = 1_000_000
	// remote_min_rx is the remote peer's minimum receive interval.
	remote_min_rx u32 = 1_000_000
	// last_rx is the timestamp of the last received packet.
	last_rx ?time.Time
	// demand_mode indicates whether demand mode is active.
	demand_mode bool
}

// detection_time computes the detection time in microseconds based on the
// negotiated intervals and the detection multiplier.
pub fn (s BfdSession) detection_time() u64 {
	// Detection time = detect_mult * max(negotiated tx, remote min rx)
	agreed_interval := if s.local_min_tx > s.remote_min_rx {
		u64(s.local_min_tx)
	} else {
		u64(s.remote_min_rx)
	}
	return u64(s.detect_mult) * agreed_interval
}

// is_timed_out checks whether the session has exceeded its detection time
// without receiving a packet from the remote peer.
pub fn (s BfdSession) is_timed_out() bool {
	rx := s.last_rx or { return true }
	elapsed := u64(time.since(rx).microseconds())
	return elapsed > s.detection_time()
}

// BfdServer manages multiple BFD sessions and handles packet processing.
pub struct BfdServer {
pub:
	// listen_port is the UDP port for BFD control packets (default 3784).
	listen_port int = 3784
pub mut:
	// sessions contains all active BFD sessions indexed by local discriminator.
	sessions []BfdSession
	// next_disc is the next discriminator value to assign.
	next_disc u32 = 1
}

// new_server creates a new BfdServer listening on the given port.
pub fn new_server(port int) &BfdServer {
	return &BfdServer{
		listen_port: port
	}
}

// create_session establishes a new BFD session with the given remote address
// and timing parameters. Returns the local discriminator.
pub fn (mut s BfdServer) create_session(remote_addr string, desired_min_tx u32, required_min_rx u32, detect_mult u8) u32 {
	disc := s.next_disc
	s.next_disc++
	s.sessions << BfdSession{
		local_disc: disc
		remote_addr: remote_addr
		desired_min_tx: desired_min_tx
		required_min_rx: required_min_rx
		detect_mult: detect_mult
		state: .down
		local_min_tx: desired_min_tx
	}
	return disc
}

// find_session looks up a session by its local discriminator.
// Returns an error if no session with that discriminator exists.
pub fn (s BfdServer) find_session(local_disc u32) !&BfdSession {
	for i, _ in s.sessions {
		if s.sessions[i].local_disc == local_disc {
			return unsafe { &s.sessions[i] }
		}
	}
	return error('BFD session not found: discriminator ${local_disc}')
}

// process_packet handles an incoming BFD control packet by updating the
// corresponding session's state machine. The state transitions follow
// RFC 5880 section 6.8.6.
pub fn (mut s BfdServer) process_packet(local_disc u32, remote_disc u32, remote_state SessionState, remote_diag DiagnosticCode) ! {
	mut idx := -1
	for i, session in s.sessions {
		if session.local_disc == local_disc {
			idx = i
			break
		}
	}
	if idx < 0 {
		return error('BFD session not found: discriminator ${local_disc}')
	}

	s.sessions[idx].remote_disc = remote_disc
	s.sessions[idx].remote_state = remote_state
	s.sessions[idx].last_rx = time.now()

	// BFD state machine transitions per RFC 5880 section 6.8.6
	match s.sessions[idx].state {
		.admin_down {
			// No transitions from AdminDown via received packets
		}
		.down {
			match remote_state {
				.down {
					s.sessions[idx].state = .init
				}
				.init {
					s.sessions[idx].state = .up
					s.sessions[idx].diag = .none
				}
				else {}
			}
		}
		.init {
			match remote_state {
				.init, .up {
					s.sessions[idx].state = .up
					s.sessions[idx].diag = .none
				}
				else {}
			}
		}
		.up {
			match remote_state {
				.down, .admin_down {
					s.sessions[idx].state = .down
					s.sessions[idx].diag = .neighbor_down
				}
				else {}
			}
		}
	}
}

// set_intervals updates the timing parameters for a session and triggers
// renegotiation of the actual transmit interval.
pub fn (mut s BfdServer) set_intervals(local_disc u32, desired_min_tx u32, required_min_rx u32) ! {
	for i, session in s.sessions {
		if session.local_disc == local_disc {
			s.sessions[i] = BfdSession{
				...s.sessions[i]
				desired_min_tx: desired_min_tx
				required_min_rx: required_min_rx
				local_min_tx: if desired_min_tx > s.sessions[i].remote_min_rx {
					desired_min_tx
				} else {
					s.sessions[i].remote_min_rx
				}
			}
			return
		}
	}
	return error('BFD session not found: discriminator ${local_disc}')
}

// get_session_state returns the current state and diagnostic for a session.
pub fn (s BfdServer) get_session_state(local_disc u32) !(SessionState, DiagnosticCode) {
	for session in s.sessions {
		if session.local_disc == local_disc {
			return session.state, session.diag
		}
	}
	return error('BFD session not found: discriminator ${local_disc}')
}

// session_count returns the number of active BFD sessions.
pub fn (s BfdServer) session_count() int {
	return s.sessions.len
}

// admin_down forces a session into AdminDown state.
pub fn (mut s BfdServer) admin_down(local_disc u32) ! {
	for i, session in s.sessions {
		if session.local_disc == local_disc {
			s.sessions[i].state = .admin_down
			s.sessions[i].diag = .none
			return
		}
	}
	return error('BFD session not found: discriminator ${local_disc}')
}
