// SPDX-License-Identifier: PMPL-1.0-or-later
module v_trpc

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
	println('V-TRPC (Dodeca-API) starting on port ${s.port}...')
}
