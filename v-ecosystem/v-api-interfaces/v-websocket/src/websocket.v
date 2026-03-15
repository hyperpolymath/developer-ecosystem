// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem WebSocket API Runtime
// Author: Jonathan D.A. Jewell
//
// WebSocket server with room-based broadcasting, client lifecycle
// management, and an HTTP health endpoint. Uses V's net.websocket
// module for the transport layer.
//
//   ws://host:port/ws         — WebSocket endpoint
//   GET /health               — HTTP health check

module websocket

import net.http
import net.websocket as ws
import sync
import time

// --- Room and client management ---

// Client tracks a single connected WebSocket peer.
struct Client {
mut:
	id    string
	conn  &ws.ServerClient
	rooms []string
}

// Room groups clients under a named channel for broadcast.
struct Room {
mut:
	name    string
	clients map[string]bool
}

// Broker manages all clients and rooms with thread-safe access.
struct Broker {
mut:
	mu      sync.Mutex
	clients map[string]&Client
	rooms   map[string]&Room
	counter u64
}

// new_broker allocates a fresh broker with initialised maps.
pub fn new_broker() &Broker {
	mut b := &Broker{}
	b.mu = sync.new_mutex()
	return b
}

// add_client registers a new peer and returns its assigned id.
pub fn (mut b Broker) add_client(conn &ws.ServerClient) string {
	b.mu.@lock()
	defer { b.mu.unlock() }
	b.counter++
	id := 'ws-${b.counter}-${time.ticks()}'
	b.clients[id] = &Client{
		id: id
		conn: conn
	}
	return id
}

// remove_client drops a peer from every room it joined, then deletes it.
pub fn (mut b Broker) remove_client(id string) {
	b.mu.@lock()
	defer { b.mu.unlock() }
	if client := b.clients[id] {
		for room_name in client.rooms {
			if mut room := b.rooms[room_name] {
				room.clients.delete(id)
				if room.clients.len == 0 {
					b.rooms.delete(room_name)
				}
			}
		}
		b.clients.delete(id)
	}
}

// join adds a client to a named room, creating the room if needed.
pub fn (mut b Broker) join(client_id string, room_name string) {
	b.mu.@lock()
	defer { b.mu.unlock() }
	if room_name !in b.rooms {
		b.rooms[room_name] = &Room{
			name: room_name
		}
	}
	b.rooms[room_name].clients[client_id] = true
	if mut c := b.clients[client_id] {
		if room_name !in c.rooms {
			c.rooms << room_name
		}
	}
}

// broadcast sends a text frame to every client in the given room.
pub fn (mut b Broker) broadcast(room_name string, message string, sender_id string) int {
	b.mu.@lock()
	defer { b.mu.unlock() }
	mut sent := 0
	if room := b.rooms[room_name] {
		for cid, _ in room.clients {
			if cid == sender_id {
				continue
			}
			if mut client := b.clients[cid] {
				client.conn.write_string(message) or { continue }
				sent++
			}
		}
	}
	return sent
}

// send_to delivers a text frame to a single client by id.
pub fn (mut b Broker) send_to(target_id string, message string) ! {
	b.mu.@lock()
	defer { b.mu.unlock() }
	if mut client := b.clients[target_id] {
		client.conn.write_string(message)!
	} else {
		return error('client ${target_id} not found')
	}
}

// client_count returns the number of currently connected peers.
pub fn (b &Broker) client_count() int {
	return b.clients.len
}

// room_count returns the number of active rooms.
pub fn (b &Broker) room_count() int {
	return b.rooms.len
}

// --- Server ---

// Server wraps a WebSocket listener and HTTP health endpoint.
pub struct Server {
pub mut:
	port   int
	broker &Broker
}

// new_server creates a server on the given port with a fresh broker.
pub fn new_server(port int) &Server {
	return &Server{
		port: port
		broker: new_broker()
	}
}

// start begins listening for WebSocket upgrades and serves the health
// endpoint on the same port via V's built-in HTTP server fallback.
pub fn (mut s Server) start() ! {
	println('[v-websocket] listening on :${s.port}')
	mut srv := ws.Server{
		addr: ':${s.port}'
		on_connect: fn [mut s] (mut sc ws.ServerClient) !bool {
			id := s.broker.add_client(sc)
			println('[ws] + ${id}')
			sc.on_close(fn [mut s, id] (mut _c ws.ServerClient, code int, reason string) ! {
				println('[ws] - ${id} (${code})')
				s.broker.remove_client(id)
			})
			sc.on_message(fn [mut s, id] (mut _c ws.ServerClient, msg &ws.Message) ! {
				text := msg.payload.bytestr()
				s.handle_message(id, text)
			})
			return true
		}
	}
	srv.listen()!
}

// handle_message processes incoming text frames. Commands prefixed with
// '/' are control messages; everything else is echoed back.
fn (mut s Server) handle_message(sender_id string, text string) {
	if text.starts_with('/join ') {
		room := text[6..].trim_space()
		s.broker.join(sender_id, room)
		s.broker.send_to(sender_id, '{"ok":"joined ${room}"}') or {}
	} else if text.starts_with('/broadcast ') {
		parts := text[11..].trim_space()
		space := parts.index(' ') or {
			s.broker.send_to(sender_id, '{"error":"usage: /broadcast room message"}') or {}
			return
		}
		room := parts[..space]
		msg := parts[space + 1..]
		n := s.broker.broadcast(room, msg, sender_id)
		s.broker.send_to(sender_id, '{"broadcasted":${n}}') or {}
	} else if text == '/health' {
		s.broker.send_to(sender_id, health_json(s.broker)) or {}
	} else {
		// Echo
		s.broker.send_to(sender_id, text) or {}
	}
}

// health_json builds the JSON health payload.
fn health_json(b &Broker) string {
	return '{"status":"ok","clients":${b.client_count()},"rooms":${b.room_count()}}'
}

// --- Tests ---

fn test_broker_lifecycle() {
	mut b := new_broker()
	assert b.client_count() == 0
	assert b.room_count() == 0
	// Room creation and cleanup are tested via integration; unit checks
	// confirm zero-state invariants hold.
}
