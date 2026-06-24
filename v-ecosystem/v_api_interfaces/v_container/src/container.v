// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_container — OCI container management protocol types.
// Maps to proven-servers/protocols/proven-container.
//
// Provides container lifecycle management types (create, start, stop,
// remove, inspect), image operations, and a runtime abstraction that
// supports Podman, Docker, and containerd via Unix socket communication.
// Network I/O to the container runtime socket is stubbed with TODO markers.
module v_container

import time
import json

// ContainerState represents the lifecycle state of an OCI container.
pub enum ContainerState {
	created
	running
	paused
	stopped
	removing
	dead
}

// RestartPolicy defines the container restart behaviour.
pub enum RestartPolicy {
	no
	always
	on_failure
	unless_stopped
}

// ImagePullPolicy controls when images are fetched from a registry.
pub enum ImagePullPolicy {
	always
	if_not_present
	never
}

// RuntimeType identifies the container runtime backend.
pub enum RuntimeType {
	podman
	docker
	containerd
}

// Port maps a container port to a host port with a specified protocol.
pub struct Port {
pub:
	// container_port is the port inside the container.
	container_port int
	// host_port is the port on the host machine.
	host_port int
	// protocol is "tcp" or "udp".
	protocol string = 'tcp'
}

// Volume binds a host path to a container path, optionally read-only.
pub struct Volume {
pub:
	// source is the host filesystem path.
	source string
	// destination is the mount point inside the container.
	destination string
	// read_only prevents writes to the mount if true.
	read_only bool
}

// Container represents a running or stopped OCI container with its
// full metadata: image, network, volume, and state information.
pub struct Container {
pub:
	// id is the unique container identifier (hex hash).
	id string
	// name is the human-readable container name.
	name string
	// image is the image reference (e.g. "cgr.dev/chainguard/nginx:latest").
	image string
	// created_at is the time the container was created.
	created_at time.Time
	// ports lists the port mappings.
	ports []Port
	// volumes lists the volume mounts.
	volumes []Volume
	// env maps environment variable names to values.
	env map[string]string
	// labels maps label names to values.
	labels map[string]string
	// restart_policy defines restart behaviour.
	restart_policy RestartPolicy
pub mut:
	// state tracks the container's current lifecycle phase.
	state ContainerState
}

// ContainerSpec defines the desired state for creating a new container.
// Passed to ContainerRuntime.create().
pub struct ContainerSpec {
pub:
	// image is the container image reference (required).
	image string
	// name is the desired container name (optional; auto-generated if empty).
	name string
	// command overrides the image's default entrypoint/command.
	command []string
	// env sets environment variables as key-value pairs.
	env map[string]string
	// ports defines port mappings from host to container.
	ports []Port
	// volumes defines volume mounts.
	volumes []Volume
	// labels sets OCI labels on the container.
	labels map[string]string
	// restart_policy configures restart behaviour.
	restart_policy RestartPolicy = .no
	// memory_limit caps memory usage in bytes (0 = unlimited).
	memory_limit i64
	// cpu_limit caps CPU usage (e.g. 1.5 = 1.5 cores, 0 = unlimited).
	cpu_limit f64
}

// Image represents an OCI container image in the local store.
pub struct Image {
pub:
	// id is the image digest (sha256:...).
	id string
	// repo is the image repository (e.g. "cgr.dev/chainguard/nginx").
	repo string
	// tag is the image tag (e.g. "latest").
	tag string
	// size is the image size in bytes.
	size i64
	// created_at is the image creation timestamp.
	created_at time.Time
	// layers lists the layer digests that compose this image.
	layers []string
}

// ContainerRuntime is the client for communicating with a container
// runtime (Podman, Docker, or containerd) via its Unix socket API.
pub struct ContainerRuntime {
pub:
	// socket_path is the path to the runtime's Unix socket
	// (e.g. "/run/podman/podman.sock").
	socket_path string
	// runtime_type identifies which runtime we're talking to.
	runtime_type RuntimeType
pub mut:
	// connected tracks whether we have an active socket connection.
	connected bool
}

// connect establishes a connection to the container runtime at the
// given Unix socket path. Auto-detects the runtime type from the
// socket path if possible.
pub fn connect(socket_path string) !&ContainerRuntime {
	if socket_path.len == 0 {
		return error('socket_path must not be empty')
	}
	// Detect runtime type from the socket path.
	rt := if socket_path.contains('podman') {
		RuntimeType.podman
	} else if socket_path.contains('containerd') {
		RuntimeType.containerd
	} else {
		RuntimeType.docker
	}
	// TODO: Open Unix domain socket connection to socket_path.
	// Verify the runtime is responding with a version/ping request.
	return &ContainerRuntime{
		socket_path: socket_path
		runtime_type: rt
		connected: true
	}
}

// list_containers returns all containers managed by the runtime.
// If all is false, only running containers are returned.
pub fn (r ContainerRuntime) list_containers(all bool) ![]Container {
	if !r.connected {
		return error('not connected to runtime')
	}
	// TODO: Send GET /containers/json?all={all} to the runtime socket.
	// Parse the JSON response into []Container.
	return []Container{}
}

// create creates a new container from the given spec without starting it.
// Returns the created container with its assigned id.
pub fn (r ContainerRuntime) create(spec ContainerSpec) !Container {
	if !r.connected {
		return error('not connected to runtime')
	}
	if spec.image.len == 0 {
		return error('image is required in ContainerSpec')
	}
	// TODO: Send POST /containers/create with JSON body to runtime socket.
	// Parse the response to get the container id.
	return Container{
		id: ''
		name: spec.name
		image: spec.image
		state: .created
		created_at: time.now()
		ports: spec.ports
		volumes: spec.volumes
		env: spec.env
		labels: spec.labels
		restart_policy: spec.restart_policy
	}
}

// start starts a stopped or newly created container by its id.
pub fn (r ContainerRuntime) start(id string) ! {
	if !r.connected {
		return error('not connected to runtime')
	}
	if id.len == 0 {
		return error('container id must not be empty')
	}
	// TODO: Send POST /containers/{id}/start to the runtime socket.
}

// stop gracefully stops a running container. The timeout parameter
// specifies seconds to wait before sending SIGKILL.
pub fn (r ContainerRuntime) stop(id string, timeout int) ! {
	if !r.connected {
		return error('not connected to runtime')
	}
	if id.len == 0 {
		return error('container id must not be empty')
	}
	// TODO: Send POST /containers/{id}/stop?t={timeout} to runtime socket.
}

// remove deletes a container. If force is true, a running container
// is stopped first. Returns an error if the container does not exist.
pub fn (r ContainerRuntime) remove(id string, force bool) ! {
	if !r.connected {
		return error('not connected to runtime')
	}
	if id.len == 0 {
		return error('container id must not be empty')
	}
	// TODO: Send DELETE /containers/{id}?force={force} to runtime socket.
}

// logs retrieves the stdout/stderr logs from a container. If follow
// is true, the stream stays open (blocking). Returns the collected
// log output as a string.
pub fn (r ContainerRuntime) logs(id string, follow bool) !string {
	if !r.connected {
		return error('not connected to runtime')
	}
	if id.len == 0 {
		return error('container id must not be empty')
	}
	// TODO: Send GET /containers/{id}/logs?follow={follow}&stdout=true&stderr=true
	// to the runtime socket and stream the response.
	return ''
}

// inspect returns detailed information about a container, including
// its full configuration, state, and network settings.
pub fn (r ContainerRuntime) inspect(id string) !Container {
	if !r.connected {
		return error('not connected to runtime')
	}
	if id.len == 0 {
		return error('container id must not be empty')
	}
	// TODO: Send GET /containers/{id}/json to runtime socket.
	// Parse the JSON response into a Container.
	return Container{
		id: id
		name: ''
		image: ''
		state: .created
		created_at: time.now()
		ports: []Port{}
		volumes: []Volume{}
		env: map[string]string{}
		labels: map[string]string{}
		restart_policy: .no
	}
}

// pull_image downloads an image from a registry. The image string
// may include a tag (e.g. "cgr.dev/chainguard/nginx:latest").
pub fn (r ContainerRuntime) pull_image(image string) !Image {
	if !r.connected {
		return error('not connected to runtime')
	}
	if image.len == 0 {
		return error('image reference must not be empty')
	}
	// Split image into repo and tag.
	mut repo := image
	mut tag := 'latest'
	if image.contains(':') {
		colon_idx := image.last_index(':') or { -1 }
		if colon_idx > 0 {
			repo = image[..colon_idx]
			tag = image[colon_idx + 1..]
		}
	}
	// TODO: Send POST /images/create?fromImage={repo}&tag={tag} to runtime socket.
	return Image{
		id: ''
		repo: repo
		tag: tag
		size: 0
		created_at: time.now()
		layers: []string{}
	}
}

// list_images returns all images in the local store.
pub fn (r ContainerRuntime) list_images() ![]Image {
	if !r.connected {
		return error('not connected to runtime')
	}
	// TODO: Send GET /images/json to the runtime socket.
	return []Image{}
}
