// SPDX-License-Identifier: MPL-2.0
module v_flatbuffers

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
	println('V-FlatBuffers (Dodeca-API) starting on port ${s.port}...')
}
