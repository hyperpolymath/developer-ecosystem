// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Line Printer Daemon protocol for print queue management Connector
// Author: Jonathan D.A. Jewell
//
// Line Printer Daemon protocol for print queue management.
// Implements LPD wire format per RFC 1179.
// Provides typed client bindings for the proven-lpd protocol.

module lpd

// --- LPD command codes (RFC 1179 §5) ---

// lpd_cmd_start_printing is the daemon command to print waiting jobs (0x01).
pub const lpd_cmd_start_printing = u8(0x01)

// lpd_cmd_receive_job is the daemon command to receive a print job (0x02).
pub const lpd_cmd_receive_job = u8(0x02)

// lpd_cmd_send_queue_state_short is the command to report queue state (short) (0x03).
pub const lpd_cmd_send_queue_state_short = u8(0x03)

// lpd_cmd_send_queue_state_long is the command to report queue state (long) (0x04).
pub const lpd_cmd_send_queue_state_long = u8(0x04)

// lpd_cmd_remove_jobs is the command to remove print jobs (0x05).
pub const lpd_cmd_remove_jobs = u8(0x05)

// lpd_sub_abort_job is the sub-command to abort the current job (0x01).
pub const lpd_sub_abort_job = u8(0x01)

// lpd_sub_receive_control_file is the sub-command to receive a control file (0x02).
pub const lpd_sub_receive_control_file = u8(0x02)

// lpd_sub_receive_data_file is the sub-command to receive a data file (0x03).
pub const lpd_sub_receive_data_file = u8(0x03)

// lpd_port is the IANA-registered LPD port.
pub const lpd_port = 515

// lpd_ack is the single-byte acknowledgement value (0x00).
pub const lpd_ack = u8(0x00)

// --- Control file field characters (RFC 1179 §7) ---

// cf_hostname is the H command: hostname of client machine.
pub const cf_hostname = u8('H')

// cf_person is the P command: user identification (person).
pub const cf_person = u8('P')

// cf_job_name is the J command: job name for banner page.
pub const cf_job_name = u8('J')

// cf_class is the C command: class for banner page.
pub const cf_class = u8('C')

// cf_mail_on_completion is the M command: mail to user on completion.
pub const cf_mail_on_completion = u8('M')

// cf_print_file is the f command: print formatted file.
pub const cf_print_file = u8('f')

// cf_unlink_data_file is the U command: unlink data file on completion.
pub const cf_unlink_data_file = u8('U')

// cf_count is the N command: name of source file.
pub const cf_count = u8('N')

// --- Job state ---

// PrintJobState tracks a print job lifecycle.
pub enum PrintJobState {
	queued     // Waiting in spool
	printing   // Actively printing
	completed  // Successfully finished
	cancelled  // Cancelled by user or admin
	error      // Stopped due to error
}

// --- Data structures ---

// PrintQueue defines a print queue.
pub struct PrintQueue {
pub:
	name    string   // Logical queue name (e.g. "lp", "laser1")
	device  string   // Device path (e.g. "/dev/lp0") or network URI
	enabled bool = true
}

// PrintJob represents a queued print job with RFC 1179 control file fields.
pub struct PrintJob {
pub:
	job_id     int            // Numeric job identifier (3 digits per RFC 1179)
	queue_name string         // Target queue name
	filename   string         // Data file name (e.g. "dfA001host")
	state      PrintJobState
	copies     int = 1
	hostname   string         // H: originating host
	person     string         // P: submitting user
	job_name   string         // J: display name for the job
	class_name string         // C: banner page class
	data_size  int            // Byte count of data file
}

// QueueEntry holds a single line from an LPD queue state response.
pub struct QueueEntry {
pub:
	rank       string   // e.g. "active", "1st", "2nd"
	owner      string
	job_id     int
	files      string
	total_size int
}

// LpdJob holds the metadata for submitting a new print job.
pub struct LpdJob {
pub:
	job_id     int     // 3-digit job number (RFC 1179 §6.1)
	hostname   string  // H: originating host
	person     string  // P: submitting user
	job_name   string  // J: display name
	class_name string  // C: banner class (optional)
	filename   string  // Data file name (e.g. "dfA001host")
	copies     int = 1 // Number of copies to print
}

// LpdQueueEntry is a parsed entry from a queue-state response.
pub struct LpdQueueEntry {
pub:
	rank       string
	owner      string
	job_id     int
	files      string
	total_size int
}

// LpdConfig holds LPD server parameters.
pub struct LpdConfig {
pub:
	listen_port int = lpd_port
	spool_dir   string = '/var/spool/lpd'
}

// LpdManager manages print queues and jobs.
pub struct LpdManager {
mut:
	config LpdConfig
	queues []PrintQueue
	jobs   []PrintJob
}

// --- Wire format builders (RFC 1179) ---

// build_start_printing builds the LPD "Print any waiting jobs" command.
// Format: 0x01 SP queue LF
pub fn build_start_printing(queue_name string) ![]u8 {
	if queue_name.len == 0 {
		return error('queue name must not be empty')
	}
	mut out := []u8{}
	out << lpd_cmd_start_printing
	out << queue_name.bytes()
	out << u8('\n')
	return out
}

// build_receive_job builds the LPD "Receive a printer job" command.
// Format: 0x02 SP queue LF
pub fn build_receive_job(queue_name string) ![]u8 {
	if queue_name.len == 0 {
		return error('queue name must not be empty')
	}
	mut out := []u8{}
	out << lpd_cmd_receive_job
	out << queue_name.bytes()
	out << u8('\n')
	return out
}

// build_control_file builds an RFC 1179 control file for a print job.
// The control file encodes the job metadata as a series of single-char-prefixed lines.
pub fn build_control_file(job PrintJob) ![]u8 {
	if job.hostname.len == 0 {
		return error('job hostname must not be empty')
	}
	if job.person.len == 0 {
		return error('job person must not be empty')
	}
	mut lines := []string{}
	lines << '${cf_hostname.ascii_str()}${job.hostname}'
	lines << '${cf_person.ascii_str()}${job.person}'
	if job.job_name.len > 0 {
		lines << '${cf_job_name.ascii_str()}${job.job_name}'
	}
	if job.class_name.len > 0 {
		lines << '${cf_class.ascii_str()}${job.class_name}'
	}
	lines << '${cf_print_file.ascii_str()}${job.filename}'
	lines << '${cf_unlink_data_file.ascii_str()}${job.filename}'
	lines << '${cf_count.ascii_str()}${job.filename}'
	text := lines.join('\n') + '\n'
	return text.bytes()
}

// build_receive_control_file builds the sub-command to transfer a control file.
// Format: 0x02 SP count SP cfname LF  followed by control file bytes + 0x00
pub fn build_receive_control_file(cf_bytes []u8, cf_name string) ![]u8 {
	if cf_bytes.len == 0 {
		return error('control file must not be empty')
	}
	mut out := []u8{}
	out << lpd_sub_receive_control_file
	out << '${cf_bytes.len} ${cf_name}\n'.bytes()
	out << cf_bytes
	out << u8(0)  // Terminating null byte
	return out
}

// build_send_data_file builds the sub-command to transfer a data file.
// Format: 0x03 SP count SP dfname LF  followed by data bytes + 0x00
pub fn build_send_data_file(data []u8, df_name string) ![]u8 {
	if data.len == 0 {
		return error('data file must not be empty')
	}
	mut out := []u8{}
	out << lpd_sub_receive_data_file
	out << '${data.len} ${df_name}\n'.bytes()
	out << data
	out << u8(0)  // Terminating null byte
	return out
}

// --- Control file encoding (LpdJob variant) ---

// encode_control_file serialises an LpdJob to an RFC 1179 control file string.
// Returns a newline-terminated sequence of field lines.
pub fn encode_control_file(job LpdJob) string {
	mut lines := []string{}
	lines << '${cf_hostname.ascii_str()}${job.hostname}'
	lines << '${cf_person.ascii_str()}${job.person}'
	if job.job_name.len > 0 {
		lines << '${cf_job_name.ascii_str()}${job.job_name}'
	}
	if job.class_name.len > 0 {
		lines << '${cf_class.ascii_str()}${job.class_name}'
	}
	lines << '${cf_print_file.ascii_str()}${job.filename}'
	lines << '${cf_unlink_data_file.ascii_str()}${job.filename}'
	lines << '${cf_count.ascii_str()}${job.filename}'
	return lines.join('\n') + '\n'
}

// --- Queue state response parsing ---

// parse_queue_state_response parses the text response to a send_queue_state command.
// Each non-empty line is returned as a QueueEntry with rank + owner extracted.
pub fn parse_queue_state_response(response string) []QueueEntry {
	mut entries := []QueueEntry{}
	for line in response.split('\n') {
		trimmed := line.trim_space()
		if trimmed.len == 0 {
			continue
		}
		parts := trimmed.split_any(' \t')
		if parts.len >= 4 {
			entries << QueueEntry{
				rank:       parts[0]
				owner:      parts[1]
				job_id:     parts[2].int()
				files:      parts[3]
				total_size: if parts.len >= 5 { parts[4].int() } else { 0 }
			}
		}
	}
	return entries
}

// --- Manager lifecycle ---

// new_lpd_manager creates a new LPD manager.
pub fn new_lpd_manager(config LpdConfig) &LpdManager {
	return &LpdManager{
		config: config
		queues: []PrintQueue{}
		jobs:   []PrintJob{}
	}
}

// add_queue registers a print queue.
pub fn (mut m LpdManager) add_queue(queue PrintQueue) ! {
	if queue.name.len == 0 {
		return error('queue name must not be empty')
	}
	m.queues << queue
	println('[lpd] added queue: ${queue.name} -> ${queue.device}')
}

// submit_job queues a print job.
pub fn (mut m LpdManager) submit_job(job PrintJob) ! {
	if job.filename.len == 0 {
		return error('filename must not be empty')
	}
	m.jobs << job
	println('[lpd] queued job ${job.job_id} on ${job.queue_name}')
}

// queue_status returns all jobs currently queued on the named printer.
pub fn (m &LpdManager) queue_status(printer string) ![]LpdQueueEntry {
	if printer.len == 0 {
		return error('printer name must not be empty')
	}
	mut entries := []LpdQueueEntry{}
	for i, job in m.jobs {
		if job.queue_name == printer {
			entries << LpdQueueEntry{
				rank:       if i == 0 { "active" } else { "${i}st" }
				owner:      job.person
				job_id:     job.job_id
				files:      job.filename
				total_size: job.data_size
			}
		}
	}
	return entries
}

// remove_job removes a print job from the queue by ID.
pub fn (mut m LpdManager) remove_job(printer string, job_id int) ! {
	if printer.len == 0 {
		return error('printer name must not be empty')
	}
	before := m.jobs.len
	m.jobs = m.jobs.filter(!(it.queue_name == printer && it.job_id == job_id))
	if m.jobs.len == before {
		return error('job ${job_id} not found on printer ${printer}')
	}
	println('[lpd] removed job ${job_id} from ${printer}')
}

// --- Tests ---

fn test_empty_queue_name_rejected() {
	mut mgr := new_lpd_manager(LpdConfig{})
	mgr.add_queue(PrintQueue{ name: '', device: '/dev/lp0' }) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false
}

fn test_build_receive_job_command() {
	msg := build_receive_job('lp') or { panic(err) }
	assert msg[0] == lpd_cmd_receive_job
	assert msg[1] == u8('l')
	assert msg[2] == u8('p')
	assert msg[msg.len - 1] == u8('\n')
}

fn test_build_control_file_contains_fields() {
	job := PrintJob{
		job_id:     1
		queue_name: 'lp'
		filename:   'dfA001host'
		hostname:   'printclient'
		person:     'alice'
		job_name:   'Monthly Report'
		state:      .queued
	}
	cf := build_control_file(job) or { panic(err) }
	cf_text := cf.bytestr()
	assert cf_text.contains('Hprintclient')
	assert cf_text.contains('Palice')
	assert cf_text.contains('JMonthly Report')
}

fn test_parse_queue_state_response() {
	response := 'active  alice  001  report.pdf  10240\n1st  bob  002  slides.pdf  20480\n'
	entries := parse_queue_state_response(response)
	assert entries.len == 2
	assert entries[0].rank == 'active'
	assert entries[0].owner == 'alice'
	assert entries[1].job_id == 2
}

fn test_build_send_data_file_terminator() {
	data := 'PostScript data'.bytes()
	out := build_send_data_file(data, 'dfA001host') or { panic(err) }
	assert out[0] == lpd_sub_receive_data_file
	assert out[out.len - 1] == u8(0)  // null terminator
}

fn test_encode_control_file_fields() {
	job := LpdJob{
		job_id:   42
		hostname: 'printhost'
		person:   'carol'
		job_name: 'Budget2026'
		filename: 'dfA042printhost'
	}
	cf := encode_control_file(job)
	assert cf.contains('Hprinthost')
	assert cf.contains('Pcarol')
	assert cf.contains('JBudget2026')
	assert cf.contains('fdfA042printhost')
}

fn test_remove_job_not_found_rejected() {
	mut mgr := new_lpd_manager(LpdConfig{})
	mgr.remove_job('lp', 999) or {
		assert err.str().contains('not found')
		return
	}
	assert false
}
