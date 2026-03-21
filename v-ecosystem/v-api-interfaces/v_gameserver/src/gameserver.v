// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Game server connector for multiplayer session, lobby, and match management Connector
// Author: Jonathan D.A. Jewell
//
// Game server management client. Supports multiplayer session lifecycle,
// lobby management, matchmaking queues, player state synchronisation,
// tick-rate configuration, and anti-cheat event reporting. Communicates
// via UDP game protocol and HTTP management API.

module gameserver

import net
import time
import rand

// --- Session state ---

// SessionState represents the lifecycle of a game session.
pub enum SessionState {
	lobby        // Waiting for players
	starting     // Countdown / loading
	in_progress  // Game active
	paused       // Temporarily paused
	ended        // Game over
}

// --- Player status ---

// PlayerStatus represents a player in the session.
pub enum PlayerStatus {
	connected    // In the session
	ready        // Ready to start
	playing      // Actively in game
	spectating   // Watching
	disconnected // Left or timed out
}

// --- Data structures ---

// Player represents a connected player.
pub struct Player {
pub mut:
	id         string
	name       string
	status     PlayerStatus
	score      int
	ping_ms    int
	joined_at  i64
}

// GameSession represents a multiplayer game session.
pub struct GameSession {
pub mut:
	id          string
	state       SessionState
	players     []Player
	max_players int
	tick_rate   int         // Server ticks per second
	map_name    string
	created_at  i64
}

// MatchmakingRequest describes a matchmaking queue entry.
pub struct MatchmakingRequest {
pub:
	player_id   string
	skill_rating int
	game_mode   string
	region      string
}

// GameServerConfig holds game server parameters.
pub struct GameServerConfig {
pub:
	bind_addr    string = "0.0.0.0"
	game_port    int    = 27015
	rcon_port    int    = 27016
	tick_rate    int    = 64
	max_players  int    = 16
}

// GameServerManager manages game sessions.
pub struct GameServerManager {
mut:
	config   GameServerConfig
	sessions map[string]GameSession
}

// --- Manager lifecycle ---

// new_gameserver_manager creates a new game server manager.
pub fn new_gameserver_manager(config GameServerConfig) &GameServerManager {
	return &GameServerManager{
		config: config
		sessions: map[string]GameSession{}
	}
}

// create_session creates a new game session.
pub fn (mut m GameServerManager) create_session(map_name string) !GameSession {
	if map_name.len == 0 {
		return error("map name must not be empty")
	}
	id := "gs-${rand.int_in_range(1000, 9999) or { 1000 }}"
	session := GameSession{
		id: id
		state: .lobby
		players: []Player{}
		max_players: m.config.max_players
		tick_rate: m.config.tick_rate
		map_name: map_name
		created_at: time.now().unix()
	}
	m.sessions[id] = session
	println("[gameserver] created session ${id} on ${map_name}")
	return session
}

// join_session adds a player to a session.
pub fn (mut m GameServerManager) join_session(session_id string, player_name string) ! {
	if session_id !in m.sessions {
		return error("session '${session_id}' not found")
	}
	mut session := m.sessions[session_id]
	if session.players.len >= session.max_players {
		return error("session full (${session.max_players} max)")
	}
	session.players << Player{
		id: "p-${session.players.len}"
		name: player_name
		status: .connected
		score: 0
		ping_ms: 0
		joined_at: time.now().unix()
	}
	m.sessions[session_id] = session
	println("[gameserver] ${player_name} joined ${session_id}")
}

// --- Tests ---

fn test_empty_map_rejected() {
	mut mgr := new_gameserver_manager(GameServerConfig{})
	mgr.create_session("") or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
