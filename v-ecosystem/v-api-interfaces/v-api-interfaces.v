// SPDX-License-Identifier: PMPL-1.0-or-later
// V-API-Interfaces - Unified API standard for V-lang.

module v_api_interfaces

import v_ecosystem.v_api_interfaces.v_grpc
import v_ecosystem.v_api_interfaces.v_graphql
import v_ecosystem.v_api_interfaces.v_rest

pub struct ApiSuite {
pub mut:
	grpc    &v_grpc.Server
	graphql &v_graphql.Server
	rest    &v_rest.Server
}

pub fn new_suite(port int) &ApiSuite {
	return &ApiSuite{
		grpc: v_grpc.new_server(port + 1)
		graphql: v_graphql.new_server(port + 2)
		rest: v_rest.new_server(port + 3)
	}
}
