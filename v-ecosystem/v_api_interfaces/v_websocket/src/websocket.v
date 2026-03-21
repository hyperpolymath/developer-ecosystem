// SPDX-License-Identifier: PMPL-1.0-or-later
module v_websocket

pub struct Server {
pub mut:
	port int
}

pub fn new_server(port int) &Server {
	return &Server{
		port: port
	}
}

pub fn (s Server) start() {
	println('V-Websocket (Dodeca-API) starting on port ${s.port}...')
}
