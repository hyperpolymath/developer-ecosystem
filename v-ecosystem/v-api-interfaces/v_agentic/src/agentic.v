// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_agentic -- AI agent task delegation, supervision, and result retrieval.
// Provides HTTP-based orchestration of autonomous agents: submit tasks, poll
// status, retrieve results, and manage capability grants. Maps to
// proven-servers/protocols/proven-agentic.
module agentic

import net
import time
import rand
import encoding.base64

// -- Constants ----------------------------------------------------------------

// default_supervisor_port is the default TCP port for the agent supervisor.
const default_supervisor_port = 9090

// poll_interval_ms is the milliseconds between status poll retries.
const poll_interval_ms = 500

// max_task_id_len is the maximum permitted task ID length.
const max_task_id_len = 128

// http_ok is the HTTP 200 status string prefix.
const http_ok = 'HTTP/1.1 200'

// -- Enumerations -------------------------------------------------------------

// Capability defines a permission that can be granted to an autonomous agent.
// Capabilities follow the principle of least privilege: agents receive only
// the capabilities required for their assigned tasks.
pub enum Capability {
	// read_only permits the agent to read data sources.
	read_only
	// write permits the agent to modify data sources.
	write
	// execute permits the agent to invoke tools and subprocesses.
	execute
	// delegate permits the agent to spawn and control sub-agents.
	delegate
	// supervise permits the agent to monitor and terminate other agents.
	supervise
}

// AgentStatus tracks the lifecycle of an agent task.
pub enum AgentStatus {
	// pending means the task has been submitted but not started.
	pending
	// running means the task is actively executing.
	running
	// suspended means the task is paused awaiting resources.
	suspended
	// completed means the task finished successfully.
	completed
	// failed means the task exited with an error.
	failed
	// cancelled means the task was cancelled before completion.
	cancelled
}

// -- Structures ---------------------------------------------------------------

// AgentSpec defines the configuration for a registered autonomous agent,
// including its capability set and resource constraints.
pub struct AgentSpec {
pub:
	// id is the unique agent identifier. Must not be empty.
	id string
	// name is the human-readable agent name.
	name string
	// capabilities lists the permissions granted to this agent.
	capabilities []Capability
	// max_delegation is the maximum allowed delegation depth (0 = no delegation).
	max_delegation int
	// timeout_secs is the maximum execution time in seconds (default 300).
	timeout_secs int = 300
}

// AgentTask represents a unit of work submitted to an agent.
pub struct AgentTask {
pub:
	// task_id is the unique task identifier assigned by the orchestrator.
	task_id string
	// agent_id references the AgentSpec that should execute this task.
	agent_id string
	// description is a human-readable summary of the task.
	description string
	// input_json is the JSON-encoded task input payload.
	input_json string
pub mut:
	// status is the current task lifecycle state.
	status AgentStatus
	// result_json is the JSON-encoded result (set on completion).
	result_json string
	// error_msg contains the error description on failure.
	error_msg string
	// started_at is the Unix timestamp when the task started.
	started_at i64
	// finished_at is the Unix timestamp when the task completed.
	finished_at i64
}

// AgentConfig holds the parameters for connecting to the supervisor.
pub struct AgentConfig {
pub:
	// supervisor_url is the base URL of the agent supervisor (e.g. "http://host:9090").
	supervisor_url string
	// auth_token is the bearer token for authenticating to the supervisor.
	auth_token string
	// max_agents is the maximum number of concurrently registered agents.
	max_agents int = 16
	// connect_timeout is the TCP dial timeout for supervisor connections.
	connect_timeout time.Duration = 10 * time.second
}

// AgentOrchestrator manages agent lifecycles, capability grants, and task submission.
pub struct AgentOrchestrator {
pub mut:
	// config holds the supervisor connection parameters.
	config AgentConfig
	// agents is the registry of known agent specifications.
	agents []AgentSpec
	// tasks is the list of all submitted tasks (pending, running, or finished).
	tasks []AgentTask
}

// -- Functions ----------------------------------------------------------------

// new_orchestrator creates a new AgentOrchestrator bound to the given config.
pub fn new_orchestrator(config AgentConfig) &AgentOrchestrator {
	return &AgentOrchestrator{
		config: config
		agents: []AgentSpec{}
		tasks:  []AgentTask{}
	}
}

// register_agent adds an agent to the orchestrator registry. Returns an error
// if the agent id is empty or if the orchestrator has reached max_agents.
pub fn (mut o AgentOrchestrator) register_agent(spec AgentSpec) ! {
	if spec.id.len == 0 {
		return error('agent id must not be empty')
	}
	if o.agents.len >= o.config.max_agents {
		return error('orchestrator at capacity: max_agents=${o.config.max_agents}')
	}
	for a in o.agents {
		if a.id == spec.id {
			return error('agent already registered: ${spec.id}')
		}
	}
	o.agents << spec
}

// submit_task assigns a task to a registered agent and sends it to the
// supervisor over HTTP POST. Returns the generated task_id.
pub fn (mut o AgentOrchestrator) submit_task(agent_id string, description string, input_json string) !string {
	if agent_id.len == 0 {
		return error('agent_id must not be empty')
	}
	// Verify agent is registered.
	mut found := false
	for a in o.agents {
		if a.id == agent_id {
			found = true
			break
		}
	}
	if !found {
		return error('agent not registered: ${agent_id}')
	}
	// Generate a task id from random bytes.
	rand_bytes := rand.bytes(8) or { return error('failed to generate task id') }
	mut hex := ''
	for b in rand_bytes {
		hex += '${b:02x}'
	}
	task_id := 'task-${hex}'

	// Build the HTTP POST body as a JSON payload.
	body := '{"task_id":"${task_id}","agent_id":"${agent_id}","description":"${description}","input":${input_json}}'

	// Send to supervisor via raw TCP HTTP POST.
	_ = o.http_post('/tasks', body) or {
		// Non-fatal: record task locally even if supervisor unreachable.
		eprintln('[agentic] supervisor unreachable, recording task locally: ${err}')
	}

	task := AgentTask{
		task_id:     task_id
		agent_id:    agent_id
		description: description
		input_json:  input_json
		status:      .pending
	}
	o.tasks << task
	return task_id
}

// poll_status queries the supervisor for the current status of a task.
// Updates the local task record and returns the current AgentStatus.
pub fn (mut o AgentOrchestrator) poll_status(task_id string) !AgentStatus {
	if task_id.len == 0 {
		return error('task_id must not be empty')
	}
	// Find local task record.
	mut idx := -1
	for i, t in o.tasks {
		if t.task_id == task_id {
			idx = i
			break
		}
	}
	if idx < 0 {
		return error('task not found: ${task_id}')
	}
	// Query supervisor.
	resp := o.http_get('/tasks/${task_id}') or {
		// Return the cached local status on network error.
		return o.tasks[idx].status
	}
	// Parse a minimal status field from the response body.
	if resp.contains('"status":"completed"') {
		o.tasks[idx].status = .completed
		o.tasks[idx].finished_at = time.now().unix()
	} else if resp.contains('"status":"failed"') {
		o.tasks[idx].status = .failed
		o.tasks[idx].finished_at = time.now().unix()
	} else if resp.contains('"status":"running"') {
		o.tasks[idx].status = .running
		if o.tasks[idx].started_at == 0 {
			o.tasks[idx].started_at = time.now().unix()
		}
	}
	return o.tasks[idx].status
}

// get_result retrieves the result payload for a completed task.
// Returns an error if the task is not yet complete.
pub fn (o &AgentOrchestrator) get_result(task_id string) !string {
	for t in o.tasks {
		if t.task_id == task_id {
			if t.status != .completed {
				return error('task ${task_id} not completed (status: ${t.status})')
			}
			return t.result_json
		}
	}
	return error('task not found: ${task_id}')
}

// cancel_task requests cancellation of a running task.
pub fn (mut o AgentOrchestrator) cancel_task(task_id string) ! {
	for i, t in o.tasks {
		if t.task_id == task_id {
			if t.status == .completed || t.status == .failed {
				return error('task ${task_id} already finished')
			}
			o.http_post('/tasks/${task_id}/cancel', '{}') or {}
			o.tasks[i].status = .cancelled
			o.tasks[i].finished_at = time.now().unix()
			return
		}
	}
	return error('task not found: ${task_id}')
}

// agent_count returns the number of registered agents.
pub fn (o &AgentOrchestrator) agent_count() int {
	return o.agents.len
}

// task_count returns the total number of submitted tasks.
pub fn (o &AgentOrchestrator) task_count() int {
	return o.tasks.len
}

// -- Private helpers ----------------------------------------------------------

// http_post sends an HTTP POST to the supervisor and returns the response body.
// Parses the URL into host:port and path components.
fn (o &AgentOrchestrator) http_post(path string, body string) !string {
	host_port := extract_host_port(o.config.supervisor_url)
	mut conn := net.dial_tcp(host_port)!
	defer { conn.close() or {} }
	auth := base64.encode_str('${o.config.auth_token}:')
	request := 'POST ${path} HTTP/1.1\r\nHost: ${host_port}\r\nAuthorization: Basic ${auth}\r\nContent-Type: application/json\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}'
	conn.write_string(request)!
	mut buf := []u8{len: 8192}
	n := conn.read(mut buf)!
	return buf[..n].bytestr()
}

// http_get sends an HTTP GET to the supervisor and returns the response body.
fn (o &AgentOrchestrator) http_get(path string) !string {
	host_port := extract_host_port(o.config.supervisor_url)
	mut conn := net.dial_tcp(host_port)!
	defer { conn.close() or {} }
	auth := base64.encode_str('${o.config.auth_token}:')
	request := 'GET ${path} HTTP/1.1\r\nHost: ${host_port}\r\nAuthorization: Basic ${auth}\r\nConnection: close\r\n\r\n'
	conn.write_string(request)!
	mut buf := []u8{len: 8192}
	n := conn.read(mut buf)!
	return buf[..n].bytestr()
}

// extract_host_port strips the scheme from a URL and returns "host:port".
fn extract_host_port(url string) string {
	mut s := url
	if s.starts_with('https://') {
		s = s[8..]
	} else if s.starts_with('http://') {
		s = s[7..]
	}
	// Strip any trailing path.
	slash := s.index('/') or { -1 }
	if slash > 0 {
		s = s[..slash]
	}
	// Append default port if absent.
	if !s.contains(':') {
		s += ':${default_supervisor_port}'
	}
	return s
}

// -- Tests --------------------------------------------------------------------

fn test_empty_agent_id_rejected() {
	mut orch := new_orchestrator(AgentConfig{
		supervisor_url: 'http://localhost:9090'
		auth_token:     'test'
	})
	orch.register_agent(AgentSpec{
		id:           ''
		name:         'bad'
		capabilities: []Capability{}
	}) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false, 'should have returned an error'
}

fn test_duplicate_agent_rejected() {
	mut orch := new_orchestrator(AgentConfig{
		supervisor_url: 'http://localhost:9090'
		auth_token:     'test'
	})
	orch.register_agent(AgentSpec{
		id:           'agent-1'
		name:         'first'
		capabilities: [.read_only]
	}) or { assert false, 'first registration should succeed: ${err}' }
	orch.register_agent(AgentSpec{
		id:           'agent-1'
		name:         'duplicate'
		capabilities: []Capability{}
	}) or {
		assert err.str().contains('already registered')
		return
	}
	assert false, 'should have rejected duplicate'
}

fn test_submit_unregistered_agent_rejected() {
	mut orch := new_orchestrator(AgentConfig{
		supervisor_url: 'http://localhost:9090'
		auth_token:     'test'
	})
	orch.submit_task('ghost-agent', 'do something', '{}') or {
		assert err.str().contains('not registered')
		return
	}
	assert false, 'should have rejected unregistered agent'
}
