// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_gameserver — Game server client for multiplayer session lifecycle,
// lobby management, matchmaking, player state synchronisation,
// tick-rate control, and anti-cheat event reporting.
// Maps to proven-servers/protocols/proven-gameserver.
//
// Communication uses UDP for game state packets and an HTTP management
// API for session control. The protocol frame format uses a 12-byte
// header: magic(4) + sequence(4) + payload_type(2) + payload_len(2).
module gameserver

import net
import time
import rand

// magic_bytes is the 4-byte protocol frame identifier.
const magic_bytes = [u8(0x47), 0x53, 0x52, 0x56] // "GSRV"

// default_game_port is the standard UDP port for game traffic.
const default_game_port = 27015

// default_rcon_port is the standard TCP port for RCON management.
const default_rcon_port = 27016

// session_header_len is the fixed byte length of a game protocol frame header.
const session_header_len = 12

// PayloadType classifies the type of a game protocol frame.
pub enum PayloadType as u16 {
	ping         = 0x0001 // Latency probe
	pong         = 0x0002 // Latency probe reply
	state_update = 0x0003 // Game state delta
	player_join  = 0x0004 // Player join notification
	player_leave = 0x0005 // Player disconnect notification
	chat_message = 0x0006 // In-game chat
	anti_cheat   = 0x0007 // Anti-cheat event report
	server_info  = 0x0008 // Server metadata query response
}

// SessionState represents the lifecycle of a game session.
pub enum SessionState {
	lobby       // Waiting for players to ready up
	starting    // Countdown / map loading
	in_progress // Game is actively running
	paused      // Temporarily paused (admin or lag)
	ended       // Match concluded
}

// PlayerStatus represents the connectivity state of a player.
pub enum PlayerStatus {
	connected    // In the session
	ready        // Marked ready to start
	playing      // Actively in the game
	spectating   // Watching without participating
	disconnected // Left or timed out
}

// AntiCheatEvent classifies a suspicious player behaviour report.
pub enum AntiCheatEvent {
	speed_hack   // Movement faster than server-side limit
	aim_bot      // Statistical aim deviation anomaly
	wall_hack    // Interaction with geometry outside line-of-sight
	packet_abuse // Malformed or replay-attacked frames
	unknown      // Unclassified event for manual review
}

// Player holds the state of a connected player within a session.
pub struct Player {
pub:
	// id is the unique player identifier.
	id string
	// name is the display name.
	name string
	// joined_at is the time the player entered the session.
	joined_at time.Time
pub mut:
	// status tracks the player's current connection state.
	status PlayerStatus = .connected
	// score is the current in-game score.
	score int
	// ping_ms is the last measured round-trip latency in milliseconds.
	ping_ms int
}

// GameSession represents a multiplayer game session with its full state.
pub struct GameSession {
pub:
	// id uniquely identifies this session.
	id string
	// map_name is the game map or level name.
	map_name string
	// max_players is the player capacity.
	max_players int
	// tick_rate is the server simulation rate in Hz.
	tick_rate int
	// created_at is when the session was created.
	created_at time.Time
pub mut:
	// state is the current session lifecycle state.
	state SessionState = .lobby
	// players holds all current and recently departed players.
	players []Player
	// sequence is the outbound frame sequence counter.
	sequence u32
}

// player_count returns the number of currently connected players.
pub fn (s GameSession) player_count() int {
	return s.players.filter(it.status != .disconnected).len
}

// is_full returns true if no more players can join.
pub fn (s GameSession) is_full() bool {
	return s.player_count() >= s.max_players
}

// MatchmakingRequest describes an entry in the matchmaking queue.
pub struct MatchmakingRequest {
pub:
	// player_id is the player requesting a match.
	player_id string
	// skill_rating is the player's ELO or MMR.
	skill_rating int
	// game_mode is the requested game mode (e.g. "deathmatch", "ctf").
	game_mode string
	// region is the geographic region preference (e.g. "eu-west").
	region string
	// queued_at is the time the request was submitted.
	queued_at time.Time
}

// GameServerConfig holds game server process and network parameters.
pub struct GameServerConfig {
pub:
	// bind_addr is the IP address to bind UDP and TCP sockets to.
	bind_addr string = '0.0.0.0'
	// game_port is the UDP port for game traffic.
	game_port int = default_game_port
	// rcon_port is the TCP port for RCON management API.
	rcon_port int = default_rcon_port
	// tick_rate is the server simulation rate in Hz (default 64).
	tick_rate int = 64
	// max_players is the maximum concurrent player count.
	max_players int = 16
	// game_mode is the default game mode.
	game_mode string = 'deathmatch'
}

// GameServerManager manages game sessions, matchmaking, and player state.
pub struct GameServerManager {
pub:
	// config holds all server parameters.
	config GameServerConfig
pub mut:
	// sessions maps session IDs to their GameSession state.
	sessions map[string]GameSession
	// mm_queue holds pending matchmaking requests.
	mm_queue []MatchmakingRequest
	// anti_cheat_log holds all anti-cheat event reports.
	anti_cheat_log []string
}

// new_gameserver_manager creates a new GameServerManager.
pub fn new_gameserver_manager(config GameServerConfig) &GameServerManager {
	return &GameServerManager{
		config:         config
		sessions:       map[string]GameSession{}
		mm_queue:       []MatchmakingRequest{}
		anti_cheat_log: []string{}
	}
}

// create_session creates a new lobby session. Returns an error if
// map_name is empty or the config's max_players is non-positive.
pub fn (mut m GameServerManager) create_session(map_name string) !GameSession {
	if map_name.len == 0 {
		return error('map name must not be empty')
	}
	if m.config.max_players <= 0 {
		return error('max_players must be positive')
	}
	id := 'gs-${rand.int_in_range(0x1000, 0xFFFF) or { 0x1000 }:04X}'
	session := GameSession{
		id:          id
		map_name:    map_name
		max_players: m.config.max_players
		tick_rate:   m.config.tick_rate
		created_at:  time.now()
		state:       .lobby
		players:     []Player{}
		sequence:    0
	}
	m.sessions[id] = session
	return session
}

// join_session adds a player to an existing session. Returns an error if
// the session does not exist, is full, or the player is already present.
pub fn (mut m GameServerManager) join_session(session_id string, player_id string, player_name string) !Player {
	if session_id !in m.sessions {
		return error("session '${session_id}' not found")
	}
	mut session := m.sessions[session_id] or { return error("session '${session_id}' not found") }
	if session.is_full() {
		return error("session '${session_id}' is full (${session.max_players} max)")
	}
	if session.state == .ended {
		return error("session '${session_id}' has ended")
	}
	for p in session.players {
		if p.id == player_id {
			return error("player '${player_id}' is already in session '${session_id}'")
		}
	}
	player := Player{
		id:        player_id
		name:      player_name
		joined_at: time.now()
		status:    .connected
	}
	session.players << player
	m.sessions[session_id] = session
	return player
}

// leave_session marks a player as disconnected from the session.
pub fn (mut m GameServerManager) leave_session(session_id string, player_id string) ! {
	if session_id !in m.sessions {
		return error("session '${session_id}' not found")
	}
	mut session := m.sessions[session_id] or { return error("session '${session_id}' not found") }
	mut found := false
	for mut p in session.players {
		if p.id == player_id {
			p.status = .disconnected
			found = true
			break
		}
	}
	if !found {
		return error("player '${player_id}' not found in session '${session_id}'")
	}
	m.sessions[session_id] = session
}

// start_session transitions a session from lobby to starting. Returns an
// error if the session is not in lobby state.
pub fn (mut m GameServerManager) start_session(session_id string) ! {
	if session_id !in m.sessions {
		return error("session '${session_id}' not found")
	}
	mut session := m.sessions[session_id] or { return error("session '${session_id}' not found") }
	if session.state != .lobby {
		return error("session '${session_id}' is not in lobby state (current: ${session.state})")
	}
	session.state = .starting
	m.sessions[session_id] = session
}

// end_session transitions a session to the ended state.
pub fn (mut m GameServerManager) end_session(session_id string) ! {
	if session_id !in m.sessions {
		return error("session '${session_id}' not found")
	}
	mut session := m.sessions[session_id] or { return error("session '${session_id}' not found") }
	session.state = .ended
	m.sessions[session_id] = session
}

// get_session returns a copy of the session by ID.
pub fn (m GameServerManager) get_session(session_id string) !GameSession {
	return m.sessions[session_id] or { return error("session '${session_id}' not found") }
}

// list_players returns all players in the given session.
pub fn (m GameServerManager) list_players(session_id string) []Player {
	session := m.sessions[session_id] or { return []Player{} }
	return session.players
}

// ping measures round-trip latency to the game server. Sends a UDP
// frame with payload type .ping and waits for a .pong reply.
// Returns the round-trip time in milliseconds.
pub fn (m GameServerManager) ping(host string) !int {
	mut conn := net.dial_udp('${host}:${m.config.game_port}') or {
		return error('UDP connect to ${host}:${m.config.game_port} failed: ${err}')
	}
	defer {
		conn.close() or {}
	}
	frame := build_frame(.ping, 0, []u8{})
	start := time.now()
	conn.write(frame) or { return error('ping send failed: ${err}') }
	mut buf := []u8{len: 64}
	conn.read(mut buf) or { return error('pong receive failed') }
	rtt_us := time.since(start).microseconds()
	// Validate pong frame magic.
	if buf.len >= 4 && buf[0] == magic_bytes[0] && buf[1] == magic_bytes[1] {
		return int(rtt_us / 1000)
	}
	return error('invalid pong response')
}

// report_anti_cheat records an anti-cheat event for a player.
pub fn (mut m GameServerManager) report_anti_cheat(session_id string, player_id string, event AntiCheatEvent, detail string) {
	entry := '[${time.now()}] session=${session_id} player=${player_id} event=${event} detail=${detail}'
	m.anti_cheat_log << entry
}

// queue_matchmaking adds a player to the matchmaking queue.
pub fn (mut m GameServerManager) queue_matchmaking(req MatchmakingRequest) ! {
	if req.player_id.len == 0 {
		return error('player_id must not be empty')
	}
	for existing in m.mm_queue {
		if existing.player_id == req.player_id {
			return error("player '${req.player_id}' is already in the matchmaking queue")
		}
	}
	m.mm_queue << req
}

// build_frame constructs a game protocol frame with the standard 12-byte header.
// Format: magic(4) + sequence(4, big-endian) + payload_type(2, big-endian) + payload_len(2, big-endian) + payload.
pub fn build_frame(payload_type PayloadType, sequence u32, payload []u8) []u8 {
	mut frame := []u8{cap: session_header_len + payload.len}
	// Magic bytes.
	frame << magic_bytes
	// Sequence number (big-endian u32).
	frame << u8(sequence >> 24)
	frame << u8(sequence >> 16)
	frame << u8(sequence >> 8)
	frame << u8(sequence)
	// Payload type (big-endian u16).
	ptype := u16(payload_type)
	frame << u8(ptype >> 8)
	frame << u8(ptype)
	// Payload length (big-endian u16).
	plen := u16(payload.len)
	frame << u8(plen >> 8)
	frame << u8(plen)
	// Payload.
	frame << payload
	return frame
}

// parse_frame_header parses the 12-byte frame header from a byte slice.
// Returns (payload_type, sequence, payload_len) or an error.
pub fn parse_frame_header(data []u8) !(PayloadType, u32, int) {
	if data.len < session_header_len {
		return error('frame too short: ${data.len} bytes (need ${session_header_len})')
	}
	// Validate magic.
	if data[0] != magic_bytes[0] || data[1] != magic_bytes[1] || data[2] != magic_bytes[2]
		|| data[3] != magic_bytes[3] {
		return error('invalid frame magic')
	}
	seq := (u32(data[4]) << 24) | (u32(data[5]) << 16) | (u32(data[6]) << 8) | u32(data[7])
	ptype_raw := (u16(data[8]) << 8) | u16(data[9])
	plen := int((u16(data[10]) << 8) | u16(data[11]))
	ptype := PayloadType(ptype_raw)
	return ptype, seq, plen
}

// --- Tests ---

fn test_empty_map_rejected() {
	mut mgr := new_gameserver_manager(GameServerConfig{})
	mgr.create_session('') or {
		assert err.msg().contains('must not be empty')
		return
	}
	assert false, 'expected error for empty map name'
}

fn test_session_lifecycle() {
	mut mgr := new_gameserver_manager(GameServerConfig{ max_players: 2 })
	session := mgr.create_session('dust2') or {
		assert false, 'create_session failed: ${err}'
		return
	}
	assert session.state == .lobby
	mgr.join_session(session.id, 'p1', 'Alice') or { assert false, 'join failed: ${err}' }
	mgr.start_session(session.id) or { assert false, 'start failed: ${err}' }
	s2 := mgr.get_session(session.id) or { assert false; return }
	assert s2.state == .starting
}

fn test_build_and_parse_frame() {
	payload := 'hello'.bytes()
	frame := build_frame(.ping, 42, payload)
	assert frame.len == session_header_len + payload.len
	ptype, seq, plen := parse_frame_header(frame) or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert ptype == .ping
	assert seq == 42
	assert plen == payload.len
}

fn test_session_full_rejection() {
	mut mgr := new_gameserver_manager(GameServerConfig{ max_players: 1 })
	session := mgr.create_session('arena') or {
		assert false
		return
	}
	mgr.join_session(session.id, 'p1', 'Alice') or { assert false }
	mgr.join_session(session.id, 'p2', 'Bob') or {
		assert err.msg().contains('full')
		return
	}
	assert false, 'expected full-session error'
}
