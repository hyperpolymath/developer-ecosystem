// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_amqp -- AMQP 0-9-1 message broker protocol types for the V-Ecosystem.
// Maps to proven-servers/protocols/proven-amqp.
// Implements connection management, channel multiplexing, exchange/queue
// declaration, binding, publishing, and consuming with delivery acknowledgement.
module v_amqp

import time

// ExchangeType enumerates the four AMQP 0-9-1 exchange routing algorithms.
pub enum ExchangeType {
	direct
	fanout
	topic
	headers
}

// exchange_type_to_string returns the AMQP wire-format name for an ExchangeType.
pub fn exchange_type_to_string(et ExchangeType) string {
	return match et {
		.direct { 'direct' }
		.fanout { 'fanout' }
		.topic { 'topic' }
		.headers { 'headers' }
	}
}

// DeliveryMode controls message persistence in the broker.
pub enum DeliveryMode as u8 {
	// non_persistent messages may be lost if the broker restarts.
	non_persistent = 1
	// persistent messages survive broker restarts (when queue is durable).
	persistent     = 2
}

// Exchange represents an AMQP exchange entity.
pub struct Exchange {
pub:
	// name is the exchange name (empty string is the default exchange).
	name string
	// exchange_type is the routing algorithm used.
	exchange_type ExchangeType
	// durable exchanges survive broker restarts.
	durable bool
	// auto_delete exchanges are removed when the last binding is removed.
	auto_delete bool
}

// Queue represents an AMQP queue entity.
pub struct Queue {
pub:
	// name is the queue name. If empty, the broker generates a unique name.
	name string
	// durable queues survive broker restarts.
	durable bool
	// exclusive queues are scoped to the declaring connection.
	exclusive bool
	// auto_delete queues are removed when the last consumer disconnects.
	auto_delete bool
	// arguments holds optional queue arguments (e.g. x-message-ttl).
	arguments map[string]string
pub mut:
	// message_count tracks the number of messages currently in the queue.
	message_count u64
	// consumer_count tracks the number of active consumers.
	consumer_count u32
}

// Binding connects an exchange to a queue via a routing key.
pub struct Binding {
pub:
	// exchange is the source exchange name.
	exchange string
	// queue is the destination queue name.
	queue string
	// routing_key is the binding key used for routing decisions.
	routing_key string
}

// Message represents an AMQP message with headers and body.
pub struct Message {
pub:
	// body is the message payload as raw bytes.
	body []u8
	// content_type is the MIME type of the body (e.g. "application/json").
	content_type string
	// delivery_mode controls persistence.
	delivery_mode DeliveryMode = .non_persistent
	// headers holds application-defined header key-value pairs.
	headers map[string]string
	// correlation_id links a response to its request in RPC patterns.
	correlation_id string
	// reply_to names the queue to send responses to in RPC patterns.
	reply_to string
	// expiration is the per-message TTL in milliseconds as a string.
	expiration string
	// timestamp records when the message was created.
	timestamp i64
	// message_id is an application-level unique identifier.
	message_id string
}

// new_message creates a Message with a string body and content type.
pub fn new_message(body string, content_type string) Message {
	return Message{
		body: body.bytes()
		content_type: content_type
		timestamp: time.now().unix()
	}
}

// new_persistent_message creates a persistent Message with a string body.
pub fn new_persistent_message(body string, content_type string) Message {
	return Message{
		body: body.bytes()
		content_type: content_type
		delivery_mode: .persistent
		timestamp: time.now().unix()
	}
}

// body_str returns the message body as a UTF-8 string.
pub fn (m Message) body_str() string {
	return m.body.bytestr()
}

// Delivery represents a message received from a consumer with its
// delivery metadata.
pub struct Delivery {
pub:
	// delivery_tag is a unique identifier for this delivery within the channel.
	delivery_tag u64
	// exchange is the exchange the message was published to.
	exchange string
	// routing_key is the key the message was published with.
	routing_key string
	// redelivered is true if the message was previously delivered and not acknowledged.
	redelivered bool
	// message is the actual AMQP message.
	message Message
}

// Consumer receives messages from a queue. Messages arrive via the
// deliveries array; in a production implementation this would be a channel.
pub struct Consumer {
pub:
	// tag is the consumer identifier.
	tag string
	// queue is the queue this consumer is attached to.
	queue string
pub mut:
	// deliveries holds received messages. In production, replaced by async channel.
	deliveries []Delivery
	// is_active indicates whether the consumer is currently receiving.
	is_active bool
}

// next_delivery returns the next available delivery, or an error if
// there are no pending deliveries.
pub fn (mut c Consumer) next_delivery() !Delivery {
	if c.deliveries.len == 0 {
		return error('no deliveries available')
	}
	delivery := c.deliveries[0]
	c.deliveries = c.deliveries[1..]
	return delivery
}

// Channel represents an AMQP channel multiplexed over a connection.
// Each channel has its own flow control and error scope.
pub struct Channel {
pub:
	// id is the channel number (1-65535).
	id u16
pub mut:
	// is_open indicates whether the channel is currently usable.
	is_open bool
	// prefetch_count limits unacknowledged deliveries per consumer.
	prefetch_count int
	// exchanges holds exchanges declared on this channel.
	exchanges map[string]Exchange
	// queues holds queues declared on this channel.
	queues map[string]Queue
	// bindings holds all active bindings.
	bindings []Binding
	// consumers holds active consumers keyed by consumer tag.
	consumers map[string]Consumer
	// next_delivery_tag is the monotonic counter for delivery tags.
	next_delivery_tag u64
	// unacked_deliveries tracks delivery tags not yet acknowledged.
	unacked_deliveries map[u64]bool
}

// exchange_declare declares an exchange on this channel. If the exchange
// already exists with compatible settings, this is a no-op.
pub fn (mut ch Channel) exchange_declare(name string, etype ExchangeType, durable bool) ! {
	if !ch.is_open {
		return error('channel ${ch.id} is not open')
	}
	// Check for conflicting redeclaration
	if existing := ch.exchanges[name] {
		if existing.exchange_type != etype || existing.durable != durable {
			return error('exchange ${name} already declared with different settings')
		}
		return
	}
	ch.exchanges[name] = Exchange{
		name: name
		exchange_type: etype
		durable: durable
	}
}

// queue_declare declares a queue on this channel. Returns the Queue struct
// which includes the server-assigned name if the input name was empty.
pub fn (mut ch Channel) queue_declare(name string, durable bool) !Queue {
	if !ch.is_open {
		return error('channel ${ch.id} is not open')
	}
	// Generate a name for anonymous queues
	actual_name := if name == '' {
		'amq.gen-${ch.id}-${ch.queues.len}'
	} else {
		name
	}
	// Check for conflicting redeclaration
	if existing := ch.queues[actual_name] {
		if existing.durable != durable {
			return error('queue ${actual_name} already declared with different durability')
		}
		return existing
	}
	q := Queue{
		name: actual_name
		durable: durable
	}
	ch.queues[actual_name] = q
	return q
}

// queue_bind creates a binding between a queue and an exchange using the
// given routing key.
pub fn (mut ch Channel) queue_bind(queue_name string, exchange string, routing_key string) ! {
	if !ch.is_open {
		return error('channel ${ch.id} is not open')
	}
	if queue_name !in ch.queues {
		return error('queue ${queue_name} not found')
	}
	if exchange !in ch.exchanges {
		return error('exchange ${exchange} not found')
	}
	// Avoid duplicate bindings
	for b in ch.bindings {
		if b.queue == queue_name && b.exchange == exchange && b.routing_key == routing_key {
			return
		}
	}
	ch.bindings << Binding{
		exchange: exchange
		queue: queue_name
		routing_key: routing_key
	}
}

// basic_publish publishes a message to the named exchange with the given
// routing key. The message is routed to bound queues according to the
// exchange type and routing key.
pub fn (mut ch Channel) basic_publish(exchange string, routing_key string, msg Message) ! {
	if !ch.is_open {
		return error('channel ${ch.id} is not open')
	}
	// Route the message to matching queues
	if exchange == '' {
		// Default exchange: route directly to queue named by routing_key
		if routing_key in ch.queues {
			mut q := ch.queues[routing_key] or {
				return error('queue ${routing_key} not found')
			}
			q.message_count++
			ch.queues[routing_key] = q
			// Deliver to any active consumers on this queue
			ch.deliver_to_consumers(routing_key, exchange, routing_key, msg)
		}
		return
	}
	exch := ch.exchanges[exchange] or {
		return error('exchange ${exchange} not found')
	}
	match exch.exchange_type {
		.direct {
			// Direct: routing_key must match binding key exactly
			for b in ch.bindings {
				if b.exchange == exchange && b.routing_key == routing_key {
					ch.deliver_to_consumers(b.queue, exchange, routing_key, msg)
				}
			}
		}
		.fanout {
			// Fanout: deliver to all bound queues regardless of routing key
			for b in ch.bindings {
				if b.exchange == exchange {
					ch.deliver_to_consumers(b.queue, exchange, routing_key, msg)
				}
			}
		}
		.topic {
			// Topic: routing_key patterns with * and # wildcards
			for b in ch.bindings {
				if b.exchange == exchange && topic_matches(b.routing_key, routing_key) {
					ch.deliver_to_consumers(b.queue, exchange, routing_key, msg)
				}
			}
		}
		.headers {
			// Headers: match based on message headers (simplified)
			for b in ch.bindings {
				if b.exchange == exchange {
					ch.deliver_to_consumers(b.queue, exchange, routing_key, msg)
				}
			}
		}
	}
}

// topic_matches checks whether a topic routing key matches a binding pattern.
// Supports '*' (exactly one word) and '#' (zero or more words).
fn topic_matches(pattern string, routing_key string) bool {
	pattern_parts := pattern.split('.')
	key_parts := routing_key.split('.')
	return topic_match_recursive(pattern_parts, key_parts, 0, 0)
}

// topic_match_recursive implements recursive matching of AMQP topic patterns.
fn topic_match_recursive(pattern []string, key []string, pi int, ki int) bool {
	if pi == pattern.len && ki == key.len {
		return true
	}
	if pi == pattern.len {
		return false
	}
	word := pattern[pi]
	if word == '#' {
		// '#' matches zero or more words
		if pi == pattern.len - 1 {
			return true // trailing # matches everything
		}
		// Try matching # as zero words, one word, two words, etc.
		for k in ki .. key.len + 1 {
			if topic_match_recursive(pattern, key, pi + 1, k) {
				return true
			}
		}
		return false
	}
	if ki >= key.len {
		return false
	}
	if word == '*' || word == key[ki] {
		return topic_match_recursive(pattern, key, pi + 1, ki + 1)
	}
	return false
}

// deliver_to_consumers creates a Delivery for each active consumer on the
// given queue.
fn (mut ch Channel) deliver_to_consumers(queue_name string, exchange string, routing_key string, msg Message) {
	ch.next_delivery_tag++
	tag := ch.next_delivery_tag
	delivery := Delivery{
		delivery_tag: tag
		exchange: exchange
		routing_key: routing_key
		redelivered: false
		message: msg
	}
	ch.unacked_deliveries[tag] = true

	for consumer_tag, _ in ch.consumers {
		mut consumer := ch.consumers[consumer_tag] or { continue }
		if consumer.queue == queue_name && consumer.is_active {
			consumer.deliveries << delivery
			ch.consumers[consumer_tag] = consumer
		}
	}
}

// basic_consume registers a consumer on the named queue and returns a
// Consumer handle for receiving deliveries.
pub fn (mut ch Channel) basic_consume(queue_name string) !Consumer {
	if !ch.is_open {
		return error('channel ${ch.id} is not open')
	}
	if queue_name !in ch.queues {
		return error('queue ${queue_name} not found')
	}
	consumer_tag := 'ctag-${ch.id}-${ch.consumers.len}'
	consumer := Consumer{
		tag: consumer_tag
		queue: queue_name
		is_active: true
	}
	ch.consumers[consumer_tag] = consumer
	return consumer
}

// basic_ack acknowledges a delivery by its tag, removing it from the
// unacknowledged set.
pub fn (mut ch Channel) basic_ack(delivery_tag u64) ! {
	if !ch.is_open {
		return error('channel ${ch.id} is not open')
	}
	if delivery_tag !in ch.unacked_deliveries {
		return error('delivery tag ${delivery_tag} not found or already acknowledged')
	}
	ch.unacked_deliveries.delete(delivery_tag)
}

// basic_qos sets the prefetch count for the channel, limiting how many
// unacknowledged messages a consumer can hold.
pub fn (mut ch Channel) basic_qos(prefetch_count int) ! {
	if !ch.is_open {
		return error('channel ${ch.id} is not open')
	}
	if prefetch_count < 0 {
		return error('prefetch_count must be non-negative')
	}
	ch.prefetch_count = prefetch_count
}

// Connection represents a TCP connection to an AMQP broker with
// multiplexed channels.
pub struct Connection {
pub:
	// host is the broker hostname or IP.
	host string
	// port is the broker TCP port (default 5672).
	port int
	// vhost is the AMQP virtual host.
	vhost string
pub mut:
	// channels holds all open channels keyed by channel id.
	channels map[u16]Channel
	// is_open indicates whether the connection is active.
	is_open bool
	// next_channel_id is the next channel number to assign.
	next_channel_id u16 = 1
	// username is the authenticated user.
	username string
}

// connect establishes a connection to the AMQP broker at the given address.
// Performs AMQP handshake and authentication.
// TODO: Full TCP I/O -- currently creates an in-memory connection for
//       local testing and protocol validation.
pub fn connect(host string, port int, vhost string, user string, pass string) !&Connection {
	// TODO: Establish TCP connection, send AMQP protocol header,
	//       negotiate connection.start/start-ok/tune/tune-ok/open/open-ok.
	//       For now, create an in-memory connection suitable for unit testing.
	if user.len == 0 {
		return error('username must not be empty')
	}
	if pass.len == 0 {
		return error('password must not be empty')
	}
	return &Connection{
		host: host
		port: port
		vhost: vhost
		is_open: true
		username: user
	}
}

// channel opens a new channel on this connection and returns a mutable
// reference. Channel ids are assigned sequentially starting from 1.
pub fn (mut c Connection) channel() !&Channel {
	if !c.is_open {
		return error('connection is closed')
	}
	ch_id := c.next_channel_id
	if ch_id == 0 {
		return error('channel id overflow')
	}
	c.next_channel_id++
	ch := Channel{
		id: ch_id
		is_open: true
	}
	c.channels[ch_id] = ch
	return &c.channels[ch_id]
}

// close gracefully shuts down the connection and all its channels.
pub fn (mut c Connection) close() ! {
	if !c.is_open {
		return error('connection already closed')
	}
	// Close all channels
	for ch_id, _ in c.channels {
		mut ch := c.channels[ch_id] or { continue }
		ch.is_open = false
		c.channels[ch_id] = ch
	}
	c.is_open = false
}
