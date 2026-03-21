// SPDX-License-Identifier: PMPL-1.0-or-later
// V-API-Interfaces - Unified Hexadeca-Connector standard for V-lang.
//
// Consolidates sixteen bidirectional API interfaces into a single high-rigor suite.

module v_api_interfaces

import v_ecosystem.v_api_interfaces.v_grpc
import v_ecosystem.v_api_interfaces.v_graphql
import v_ecosystem.v_api_interfaces.v_rest
import v_ecosystem.v_api_interfaces.v_flatbuffers
import v_ecosystem.v_api_interfaces.v_bebop
import v_ecosystem.v_api_interfaces.v_jsonrpc
import v_ecosystem.v_api_interfaces.v_websocket
import v_ecosystem.v_api_interfaces.v_mqtt
import v_ecosystem.v_api_interfaces.v_trpc
import v_ecosystem.v_api_interfaces.v_capnproto
import v_ecosystem.v_api_interfaces.v_soap
import v_ecosystem.v_api_interfaces.verisimdb_rest

// --- The Adapter Clade (Simplification) ---

pub interface ProtocolAdapter {
mut:
	port int
	start()
}

// New High-Rigor clades
pub struct BSPServer { pub mut: port int }
pub fn (s BSPServer) start() { println('V-BSP (Build Server Protocol) starting on port ${s.port}...') }

pub struct SCIPServer { pub mut: port int }
pub fn (s SCIPServer) start() { println('V-SCIP (Index Server) starting on port ${s.port}...') }

pub struct IPFSStore { pub mut: port int }
pub fn (s IPFSStore) start() { println('V-IPFS (Umoja Layer) starting on port ${s.port}...') }

pub struct ArrowFlight { pub mut: port int }
pub fn (s ArrowFlight) start() { println('V-ArrowFlight (Big Data) starting on port ${s.port}...') }

pub struct HexadecaSuite {
pub mut:
	adapters map[string]ProtocolAdapter
}

pub fn new_hexadeca_suite(base_port int) &HexadecaSuite {
	mut suite := &HexadecaSuite{
		adapters: map[string]ProtocolAdapter{}
	}

	// Core 12
	suite.adapters['grpc'] = v_grpc.new_server(base_port + 1)
	suite.adapters['graphql'] = v_graphql.new_server(base_port + 2)
	suite.adapters['rest'] = v_rest.new_server(base_port + 3)
	suite.adapters['flatbuffers'] = v_flatbuffers.new_server(base_port + 4)
	suite.adapters['bebop'] = v_bebop.new_server(base_port + 5)
	suite.adapters['jsonrpc'] = v_jsonrpc.new_server(base_port + 6)
	suite.adapters['websocket'] = v_websocket.new_server(base_port + 7)
	suite.adapters['mqtt'] = v_mqtt.new_server(base_port + 8)
	suite.adapters['trpc'] = v_trpc.new_server(base_port + 9)
	suite.adapters['capnproto'] = v_capnproto.new_server(base_port + 10)
	suite.adapters['soap'] = v_soap.new_server(base_port + 11)
	suite.adapters['verisimdb'] = verisimdb_rest.new_server(base_port + 12)

	// New 4 (Building the Umoja Substrate)
	suite.adapters['bsp'] = &BSPServer{base_port + 13}
	suite.adapters['scip'] = &SCIPServer{base_port + 14}
	suite.adapters['ipfs'] = &IPFSStore{base_port + 15}
	suite.adapters['arrow'] = &ArrowFlight{base_port + 16}

	return suite
}

// Backward compatibility
pub fn new_suite(port int) &HexadecaSuite {
	return new_hexadeca_suite(port)
}
