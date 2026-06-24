// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_container.
// Validates runtime connection, container lifecycle operations,
// image handling, and spec validation.
module main

import v_container

// test_connect_podman_detection verifies that the runtime type is
// auto-detected as Podman from the socket path.
fn test_connect_podman_detection() {
	rt := v_container.connect('/run/podman/podman.sock') or {
		assert false, 'connect failed: ${err}'
		return
	}
	assert rt.runtime_type == .podman
	assert rt.connected == true
	assert rt.socket_path == '/run/podman/podman.sock'
}

// test_connect_docker_detection verifies Docker runtime detection.
fn test_connect_docker_detection() {
	rt := v_container.connect('/var/run/docker.sock') or {
		assert false, 'connect failed: ${err}'
		return
	}
	assert rt.runtime_type == .docker
	assert rt.connected == true
}

// test_connect_containerd_detection verifies containerd runtime detection.
fn test_connect_containerd_detection() {
	rt := v_container.connect('/run/containerd/containerd.sock') or {
		assert false, 'connect failed: ${err}'
		return
	}
	assert rt.runtime_type == .containerd
}

// test_connect_empty_path_returns_error verifies that an empty socket
// path produces an error.
fn test_connect_empty_path_returns_error() {
	v_container.connect('') or {
		assert err.msg().contains('empty')
		return
	}
	assert false, 'expected error for empty socket path'
}

// test_create_container_with_spec verifies that creating a container
// from a spec returns correct metadata.
fn test_create_container_with_spec() {
	rt := v_container.connect('/run/podman/podman.sock') or {
		assert false, 'connect failed: ${err}'
		return
	}
	spec := v_container.ContainerSpec{
		image: 'cgr.dev/chainguard/nginx:latest'
		name: 'test-nginx'
		ports: [
			v_container.Port{
				container_port: 80
				host_port: 8080
				protocol: 'tcp'
			},
		]
		env: {
			'NGINX_PORT': '80'
		}
		labels: {
			'app': 'test'
		}
		restart_policy: .unless_stopped
		memory_limit: 256 * 1024 * 1024
		cpu_limit: 0.5
	}
	container := rt.create(spec) or {
		assert false, 'create failed: ${err}'
		return
	}
	assert container.name == 'test-nginx'
	assert container.image == 'cgr.dev/chainguard/nginx:latest'
	assert container.state == .created
	assert container.ports.len == 1
	assert container.ports[0].container_port == 80
	assert container.env['NGINX_PORT'] == '80'
	assert container.restart_policy == .unless_stopped
}

// test_create_container_no_image_returns_error verifies that a spec
// without an image produces an error.
fn test_create_container_no_image_returns_error() {
	rt := v_container.connect('/run/podman/podman.sock') or {
		assert false, 'connect failed: ${err}'
		return
	}
	spec := v_container.ContainerSpec{
		name: 'no-image'
	}
	rt.create(spec) or {
		assert err.msg().contains('image is required')
		return
	}
	assert false, 'expected error for missing image'
}

// test_start_empty_id_returns_error verifies that start rejects
// an empty container id.
fn test_start_empty_id_returns_error() {
	rt := v_container.connect('/run/podman/podman.sock') or {
		assert false, 'connect failed: ${err}'
		return
	}
	rt.start('') or {
		assert err.msg().contains('empty')
		return
	}
	assert false, 'expected error for empty id'
}

// test_stop_empty_id_returns_error verifies that stop rejects
// an empty container id.
fn test_stop_empty_id_returns_error() {
	rt := v_container.connect('/run/podman/podman.sock') or {
		assert false, 'connect failed: ${err}'
		return
	}
	rt.stop('', 10) or {
		assert err.msg().contains('empty')
		return
	}
	assert false, 'expected error for empty id'
}

// test_remove_empty_id_returns_error verifies that remove rejects
// an empty container id.
fn test_remove_empty_id_returns_error() {
	rt := v_container.connect('/run/podman/podman.sock') or {
		assert false, 'connect failed: ${err}'
		return
	}
	rt.remove('', false) or {
		assert err.msg().contains('empty')
		return
	}
	assert false, 'expected error for empty id'
}

// test_pull_image_splits_tag verifies that pull_image correctly
// separates the repository and tag.
fn test_pull_image_splits_tag() {
	rt := v_container.connect('/run/podman/podman.sock') or {
		assert false, 'connect failed: ${err}'
		return
	}
	image := rt.pull_image('cgr.dev/chainguard/nginx:1.27') or {
		assert false, 'pull failed: ${err}'
		return
	}
	assert image.repo == 'cgr.dev/chainguard/nginx'
	assert image.tag == '1.27'
}

// test_pull_image_default_tag verifies that images without a tag
// default to "latest".
fn test_pull_image_default_tag() {
	rt := v_container.connect('/run/podman/podman.sock') or {
		assert false, 'connect failed: ${err}'
		return
	}
	image := rt.pull_image('alpine') or {
		assert false, 'pull failed: ${err}'
		return
	}
	assert image.repo == 'alpine'
	assert image.tag == 'latest'
}

// test_pull_image_empty_returns_error verifies that pulling an empty
// image reference produces an error.
fn test_pull_image_empty_returns_error() {
	rt := v_container.connect('/run/podman/podman.sock') or {
		assert false, 'connect failed: ${err}'
		return
	}
	rt.pull_image('') or {
		assert err.msg().contains('empty')
		return
	}
	assert false, 'expected error for empty image'
}

// test_list_containers_returns_empty verifies that list_containers
// on a fresh runtime returns an empty list (stub behaviour).
fn test_list_containers_returns_empty() {
	rt := v_container.connect('/run/podman/podman.sock') or {
		assert false, 'connect failed: ${err}'
		return
	}
	containers := rt.list_containers(true) or {
		assert false, 'list failed: ${err}'
		return
	}
	assert containers.len == 0
}

// test_default_spec_values verifies ContainerSpec defaults.
fn test_default_spec_values() {
	spec := v_container.ContainerSpec{
		image: 'test'
	}
	assert spec.restart_policy == .no
	assert spec.memory_limit == 0
	assert spec.cpu_limit == 0.0
	assert spec.command.len == 0
}

// test_port_default_protocol verifies the default port protocol.
fn test_port_default_protocol() {
	port := v_container.Port{
		container_port: 80
		host_port: 8080
	}
	assert port.protocol == 'tcp'
}
