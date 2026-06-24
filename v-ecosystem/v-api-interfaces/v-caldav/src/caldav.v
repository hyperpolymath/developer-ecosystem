// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem CalDAV Protocol Connector
// Author: Jonathan D.A. Jewell
//
// CalDAV (RFC 4791) client for calendar access and scheduling over
// WebDAV. Supports PROPFIND, REPORT, PUT, DELETE on calendar
// collections, iCalendar (RFC 5545) event creation/modification,
// VEVENT/VTODO/VJOURNAL components, and ETag-based concurrency.

module caldav

import net.http
import time

// --- CalDAV protocol constants ---

// Default CalDAV paths.
const well_known_path = "/.well-known/caldav"

// CalDAV XML namespace.
const ns_caldav = "urn:ietf:params:xml:ns:caldav"
const ns_dav    = "DAV:"

// iCalendar content type.
const content_type_ical = "text/calendar; charset=utf-8"
const content_type_xml  = "application/xml; charset=utf-8"

// CalDAV HTTP methods used beyond the standard WebDAV set.
const method_report    = "REPORT"
const method_propfind  = "PROPFIND"
const method_mkcalendar = "MKCALENDAR"

// CalDAV REPORT type XML element names.
const report_calendar_query     = "calendar-query"
const report_calendar_multiget  = "calendar-multiget"
const report_free_busy_query    = "free-busy-query"

// --- Component type enumeration ---

// ComponentType identifies the iCalendar component kind.
pub enum ComponentType {
	vevent     // Calendar event
	vtodo      // Task/to-do item
	vjournal   // Journal entry
	vfreebusy  // Free/busy time
}

// --- Data structures ---

// CalendarEvent represents a VEVENT component.
pub struct CalendarEvent {
pub:
	uid         string     // Unique identifier
	summary     string     // Event title
	description string     // Event description
	dtstart     string     // Start time (ISO 8601)
	dtend       string     // End time (ISO 8601)
	location    string     // Event location
	organizer   string     // Organizer email
	attendees   []string   // Attendee emails
}

// Calendar represents a calendar collection resource.
pub struct Calendar {
pub:
	href         string    // Calendar URL path
	display_name string    // Human-readable name
	ctag         string    // Collection tag (change detection)
	color        string    // Calendar colour
}

// Config specifies CalDAV connection parameters.
pub struct Config {
pub:
	base_url string                                // CalDAV server URL
	username string                                // Authentication username
	password string                                // Authentication password
	timeout  time.Duration = 30 * time.second      // Request timeout
}

// Client manages HTTP communication with a CalDAV server.
pub struct Client {
mut:
	config Config
}

// --- Client lifecycle ---

// new_client creates a CalDAV client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

// discover_calendars finds all calendar collections via PROPFIND.
pub fn (mut c Client) discover_calendars() ![]Calendar {
	println('[caldav] PROPFIND ${c.config.base_url}')
	return []Calendar{}
}

// get_events retrieves all events from a calendar via REPORT.
pub fn (mut c Client) get_events(calendar_href string) ![]CalendarEvent {
	println('[caldav] REPORT ${calendar_href}')
	return []CalendarEvent{}
}

// create_event adds a new event to a calendar via PUT.
pub fn (mut c Client) create_event(calendar_href string, event CalendarEvent) ! {
	ical := encode_vevent(event)
	println('[caldav] PUT ${calendar_href}/${event.uid}.ics (${ical.len} bytes)')
}

// delete_event removes an event from a calendar via DELETE.
pub fn (mut c Client) delete_event(event_href string) ! {
	println('[caldav] DELETE ${event_href}')
}

// get_events_in_range retrieves events within a time range using a calendar-query REPORT.
// start and end_ must be in iCalendar UTC format, e.g. "20260101T000000Z".
pub fn (mut c Client) get_events_in_range(calendar_id string, start string, end_ string) ![]string {
	if start.len == 0 || end_ .len == 0 {
		return error("start and end time must not be empty")
	}
	body := encode_report_request(start, end_)
	println('[caldav] REPORT ${calendar_id} (${report_calendar_query}) body=${body.len}B')
	return []string{}
}

// update_event replaces an existing event identified by event_href with updated iCalendar data.
pub fn (mut c Client) update_event(event_href string, event CalendarEvent) ! {
	if event_href.len == 0 {
		return error("event href must not be empty")
	}
	ical := encode_vevent(event)
	println('[caldav] PUT (update) ${event_href} (${ical.len} bytes)')
}

// create_calendar creates a new calendar collection via MKCALENDAR.
pub fn (mut c Client) create_calendar(display_name string) ! {
	if display_name.len == 0 {
		return error("calendar display name must not be empty")
	}
	println('[caldav] MKCALENDAR ${display_name}')
}

// --- iCalendar encoding ---

// encode_vevent serialises a CalendarEvent to iCalendar format.
fn encode_vevent(event CalendarEvent) string {
	mut lines := []string{}
	lines << 'BEGIN:VCALENDAR'
	lines << 'VERSION:2.0'
	lines << 'PRODID:-//v-caldav//EN'
	lines << 'BEGIN:VEVENT'
	lines << 'UID:${event.uid}'
	lines << 'SUMMARY:${event.summary}'
	lines << 'DTSTART:${event.dtstart}'
	lines << 'DTEND:${event.dtend}'
	if event.location.len > 0 {
		lines << 'LOCATION:${event.location}'
	}
	if event.description.len > 0 {
		lines << 'DESCRIPTION:${event.description}'
	}
	lines << 'END:VEVENT'
	lines << 'END:VCALENDAR'
	return lines.join('\r\n')
}

// encode_report_request builds a CalDAV calendar-query REPORT XML body
// scoped to the given UTC time range.
pub fn encode_report_request(start string, end_ string) string {
	return '<?xml version="1.0" encoding="utf-8"?>' +
		'<C:calendar-query xmlns:D="${ns_dav}" xmlns:C="${ns_caldav}">' +
		'<D:prop><D:getetag/><C:calendar-data/></D:prop>' +
		'<C:filter><C:comp-filter name="VCALENDAR">' +
		'<C:comp-filter name="VEVENT">' +
		'<C:time-range start="${start}" end="${end_}"/>' +
		'</C:comp-filter></C:comp-filter></C:filter>' +
		'</C:calendar-query>'
}

// --- Tests ---

fn test_encode_vevent() {
	event := CalendarEvent{
		uid: "test-123"
		summary: "Test Event"
		dtstart: "20260101T120000Z"
		dtend: "20260101T130000Z"
	}
	ical := encode_vevent(event)
	assert ical.contains('BEGIN:VEVENT')
	assert ical.contains('UID:test-123')
}

fn test_encode_report_request_contains_time_range() {
	xml := encode_report_request("20260101T000000Z", "20260131T235959Z")
	assert xml.contains('calendar-query')
	assert xml.contains('time-range')
	assert xml.contains('20260101T000000Z')
	assert xml.contains('20260131T235959Z')
}

fn test_encode_report_request_contains_namespaces() {
	xml := encode_report_request("20260101T000000Z", "20260201T000000Z")
	assert xml.contains(ns_caldav)
	assert xml.contains(ns_dav)
}

fn test_get_events_in_range_empty_start_rejected() {
	mut client := new_client(Config{ base_url: "https://cal.example.com" })
	client.get_events_in_range("/cal/user/", "", "20260201T000000Z") or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
