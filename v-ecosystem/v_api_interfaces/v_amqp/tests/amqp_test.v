// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// amqp_test -- Protocol conformance tests for v_amqp.
// Covers exchange type mapping, message construction, queue declaration,
// binding, publishing, consuming, acknowledgement, and topic pattern matching.
module v_amqp

// test_exchange_type_to_string verifies string labels for all exchange types.
fn test_exchange_type_to_string() {
	assert exchange_type_to_string(.direct) == 'direct'
	assert exchange_type_to_string(.fanout) == 'fanout'
	assert exchange_type_to_string(.topic) == 'topic'
	assert exchange_type_to_string(.headers) == 'headers'
}

// test_new_message verifies message construction from a string body.
fn test_new_message() {
	msg := new_message('hello world', 'text/plain')
	assert msg.body_str() == 'hello world'
	assert msg.content_type == 'text/plain'
	assert msg.delivery_mode == .non_persistent
	assert msg.timestamp > 0
}

// test_new_persistent_message verifies persistent message construction.
fn test_new_persistent_message() {
	msg := new_persistent_message('durable payload', 'application/json')
	assert msg.body_str() == 'durable payload'
	assert msg.delivery_mode == .persistent
}

// test_message_headers verifies that message headers are preserved.
fn test_message_headers() {
	msg := Message{
		body: 'test'.bytes()
		headers: {
			'x-custom': 'value1'
			'x-other':  'value2'
		}
		correlation_id: 'corr-123'
		reply_to: 'reply-queue'
	}
	assert msg.headers['x-custom'] == 'value1'
	assert msg.correlation_id == 'corr-123'
	assert msg.reply_to == 'reply-queue'
}

// test_connect verifies that a connection can be established with valid
// credentials and that empty credentials are rejected.
fn test_connect() {
	conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	assert conn.is_open
	assert conn.host == 'localhost'
	assert conn.port == 5672
	assert conn.vhost == '/'
}

// test_connect_empty_credentials verifies that empty credentials are rejected.
fn test_connect_empty_credentials() {
	connect('localhost', 5672, '/', '', 'pass') or {
		assert err.msg().contains('username')
		return
	}
	assert false, 'expected error for empty username'
}

// test_channel_creation verifies that channels can be opened on a connection
// with sequentially-assigned IDs.
fn test_channel_creation() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	mut ch1 := conn.channel()!
	assert ch1.id == 1
	assert ch1.is_open
	mut ch2 := conn.channel()!
	assert ch2.id == 2
}

// test_exchange_declare verifies exchange declaration and idempotency.
fn test_exchange_declare() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	mut ch := conn.channel()!
	ch.exchange_declare('test-exchange', .direct, true)!
	assert 'test-exchange' in ch.exchanges
	exch := ch.exchanges['test-exchange']
	assert exch.exchange_type == .direct
	assert exch.durable == true

	// Idempotent redeclaration with same settings
	ch.exchange_declare('test-exchange', .direct, true)!

	// Conflicting redeclaration should fail
	ch.exchange_declare('test-exchange', .fanout, true) or {
		assert err.msg().contains('different settings')
		return
	}
	assert false, 'expected error for conflicting exchange redeclaration'
}

// test_queue_declare verifies queue declaration and anonymous queue naming.
fn test_queue_declare() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	mut ch := conn.channel()!

	q := ch.queue_declare('test-queue', true)!
	assert q.name == 'test-queue'
	assert q.durable == true
	assert 'test-queue' in ch.queues
}

// test_queue_declare_anonymous verifies that empty-name queues get
// auto-generated names.
fn test_queue_declare_anonymous() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	mut ch := conn.channel()!

	q := ch.queue_declare('', false)!
	assert q.name.starts_with('amq.gen-')
}

// test_queue_bind verifies binding a queue to an exchange.
fn test_queue_bind() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	mut ch := conn.channel()!
	ch.exchange_declare('logs', .fanout, false)!
	ch.queue_declare('log-consumer', false)!
	ch.queue_bind('log-consumer', 'logs', '')!
	assert ch.bindings.len == 1
	assert ch.bindings[0].exchange == 'logs'
	assert ch.bindings[0].queue == 'log-consumer'
}

// test_queue_bind_nonexistent verifies that binding to a missing queue
// or exchange fails.
fn test_queue_bind_nonexistent() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	mut ch := conn.channel()!
	ch.exchange_declare('existing', .direct, false)!

	ch.queue_bind('missing-queue', 'existing', 'key') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing queue'
}

// test_direct_publish_and_consume verifies the full publish-consume cycle
// through a direct exchange.
fn test_direct_publish_and_consume() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	mut ch := conn.channel()!
	ch.exchange_declare('tasks', .direct, false)!
	ch.queue_declare('task-queue', false)!
	ch.queue_bind('task-queue', 'tasks', 'task.run')!

	// Start consuming
	mut consumer := ch.basic_consume('task-queue')!
	assert consumer.is_active

	// Publish a message
	msg := new_message('do the thing', 'text/plain')
	ch.basic_publish('tasks', 'task.run', msg)!

	// Retrieve the consumer's deliveries from the channel state
	updated_consumer := ch.consumers[consumer.tag] or {
		assert false, 'consumer not found'
		return
	}
	assert updated_consumer.deliveries.len == 1
	delivery := updated_consumer.deliveries[0]
	assert delivery.message.body_str() == 'do the thing'
	assert delivery.routing_key == 'task.run'
}

// test_fanout_publish verifies that fanout exchanges deliver to all
// bound queues regardless of routing key.
fn test_fanout_publish() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	mut ch := conn.channel()!
	ch.exchange_declare('broadcast', .fanout, false)!
	ch.queue_declare('q1', false)!
	ch.queue_declare('q2', false)!
	ch.queue_bind('q1', 'broadcast', '')!
	ch.queue_bind('q2', 'broadcast', '')!

	mut c1 := ch.basic_consume('q1')!
	mut c2 := ch.basic_consume('q2')!

	msg := new_message('announcement', 'text/plain')
	ch.basic_publish('broadcast', 'ignored', msg)!

	// Both consumers should have received the message
	uc1 := ch.consumers[c1.tag] or {
		assert false, 'consumer 1 not found'
		return
	}
	uc2 := ch.consumers[c2.tag] or {
		assert false, 'consumer 2 not found'
		return
	}
	assert uc1.deliveries.len == 1
	assert uc2.deliveries.len == 1
}

// test_topic_matching verifies AMQP topic pattern matching with * and #.
fn test_topic_matching() {
	// Exact match
	assert topic_matches('stock.nyse', 'stock.nyse') == true
	// * matches exactly one word
	assert topic_matches('stock.*', 'stock.nyse') == true
	assert topic_matches('stock.*', 'stock.nyse.ibm') == false
	// # matches zero or more words
	assert topic_matches('stock.#', 'stock.nyse') == true
	assert topic_matches('stock.#', 'stock.nyse.ibm') == true
	assert topic_matches('stock.#', 'stock') == true
	// # in the middle
	assert topic_matches('*.#.ibm', 'stock.nyse.ibm') == true
	// No match
	assert topic_matches('stock.nyse', 'bond.nyse') == false
}

// test_basic_ack verifies that acknowledging a delivery removes it from
// the unacknowledged set.
fn test_basic_ack() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	mut ch := conn.channel()!
	ch.exchange_declare('ack-test', .direct, false)!
	ch.queue_declare('ack-queue', false)!
	ch.queue_bind('ack-queue', 'ack-test', 'key')!
	ch.basic_consume('ack-queue')!
	ch.basic_publish('ack-test', 'key', new_message('ack me', 'text/plain'))!

	// There should be one unacked delivery
	assert ch.unacked_deliveries.len == 1
	ch.basic_ack(1)!
	assert ch.unacked_deliveries.len == 0
}

// test_basic_ack_invalid verifies that acknowledging a non-existent
// delivery tag fails.
fn test_basic_ack_invalid() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	mut ch := conn.channel()!
	ch.basic_ack(999) or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for invalid delivery tag'
}

// test_basic_qos verifies that prefetch count can be set and that
// negative values are rejected.
fn test_basic_qos() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	mut ch := conn.channel()!
	ch.basic_qos(10)!
	assert ch.prefetch_count == 10

	ch.basic_qos(-1) or {
		assert err.msg().contains('non-negative')
		return
	}
	assert false, 'expected error for negative prefetch_count'
}

// test_connection_close verifies that closing a connection marks it and
// all its channels as closed.
fn test_connection_close() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	conn.channel()!
	conn.channel()!
	assert conn.is_open
	conn.close()!
	assert !conn.is_open

	// Channels should also be closed
	for _, ch in conn.channels {
		assert !ch.is_open
	}
}

// test_closed_channel_operations verifies that operations on a closed
// channel return errors.
fn test_closed_channel_operations() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	mut ch := conn.channel()!
	conn.close()!

	ch.exchange_declare('test', .direct, false) or {
		assert err.msg().contains('not open')
		return
	}
	assert false, 'expected error on closed channel'
}

// test_closed_connection_channel verifies that opening a channel on a
// closed connection fails.
fn test_closed_connection_channel() {
	mut conn := connect('localhost', 5672, '/', 'guest', 'guest')!
	conn.close()!
	conn.channel() or {
		assert err.msg().contains('closed')
		return
	}
	assert false, 'expected error on closed connection'
}
