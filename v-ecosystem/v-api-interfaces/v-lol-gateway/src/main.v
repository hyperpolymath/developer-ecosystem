// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// LOL (1000Langs) API Gateway — unified entry point for the triple API.
//
// Launches REST, gRPC, and GraphQL servers on consecutive ports.
// Default base port: 7800 (configurable via LOL_PORT).
//
//   REST:    :7800  — /api/v1/languages, /api/v1/corpus, /api/v1/crawl, /api/v1/health
//   gRPC:    :7801  — lol.CorpusService/* (JSON-over-HTTP, gRPC-Web compatible)
//   GraphQL: :7802  — /graphql (queries + GraphiQL playground)
//
// Usage:
//   v run api/v-gateway/src/main.v
//   LOL_PORT=9000 v run api/v-gateway/src/main.v

module main

import os
import net.http

fn main() {
	base_port := os.getenv_opt('LOL_PORT') or { '7800' }.int()
	data_dir := os.getenv_opt('LOL_DATA_DIR') or { 'corpus' }

	println('LOL (1000Langs) API Gateway v0.1.0')
	println('  Data directory: ${data_dir}')
	println('')
	println('  REST:    http://localhost:${base_port}/')
	println('  gRPC:    http://localhost:${base_port + 1}/')
	println('  GraphQL: http://localhost:${base_port + 2}/graphql')
	println('')

	// Launch all three servers concurrently.
	// REST on base port, gRPC on base+1, GraphQL on base+2.
	spawn start_rest(base_port, data_dir)
	spawn start_grpc(base_port + 1, data_dir)
	start_graphql(base_port + 2, data_dir)
}

fn start_rest(port int, data_dir string) {
	mut server := http.Server{
		addr: ':${port}'
		handler: &RestHandler{
			data_dir: data_dir
		}
	}
	server.listen_and_serve()
}

fn start_grpc(port int, data_dir string) {
	mut server := http.Server{
		addr: ':${port}'
		handler: &GrpcHandler{
			data_dir: data_dir
		}
	}
	server.listen_and_serve()
}

fn start_graphql(port int, data_dir string) {
	mut server := http.Server{
		addr: ':${port}'
		handler: &GraphqlHandler{
			data_dir: data_dir
		}
	}
	server.listen_and_serve()
}
