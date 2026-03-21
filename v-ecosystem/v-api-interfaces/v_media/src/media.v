// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Media streaming with transcoding, adaptive bitrate, and format negotiation Connector
// Author: Jonathan D.A. Jewell
//
// Media streaming with transcoding, adaptive bitrate, and format negotiation.
// Provides typed client bindings for the proven-media protocol.

module media

import os
import time
import net

// --- Media codec ---

// Codec identifies a media encoding format.
pub enum Codec {
	h264
	h265
	vp9
	av1
	opus
	aac
}

// --- Stream type ---

// StreamType classifies the media stream.
pub enum StreamType {
	live        // Live broadcast
	vod         // Video on demand
	audio_only  // Audio streaming
}

// --- Data structures ---

// MediaStream defines a media stream.
pub struct MediaStream {
pub:
	stream_id   string
	name        string
	codec       Codec
	stream_type StreamType
	bitrate_kbps int
	resolution  string     // e.g., "1920x1080"
}

// TranscodeProfile defines a transcoding output.
pub struct TranscodeProfile {
pub:
	name        string
	codec       Codec
	bitrate_kbps int
	resolution  string
}

// MediaConfig holds media server parameters.
pub struct MediaConfig {
pub:
	listen_port   int = 8554
	max_streams   int = 64
	storage_path  string = "/var/media"
}

// MediaManager manages media streams and transcoding.
pub struct MediaManager {
mut:
	config   MediaConfig
	streams  []MediaStream
	profiles []TranscodeProfile
}

// --- Manager lifecycle ---

// new_media_manager creates a new media manager.
pub fn new_media_manager(config MediaConfig) &MediaManager {
	return &MediaManager{
		config:   config
		streams:  []MediaStream{}
		profiles: []TranscodeProfile{}
	}
}

// add_stream registers a media stream.
pub fn (mut m MediaManager) add_stream(stream MediaStream) ! {
	if stream.stream_id.len == 0 {
		return error("stream_id must not be empty")
	}
	m.streams << stream
	println("[media] added stream: ${stream.name} (${stream.codec}, ${stream.bitrate_kbps}kbps)")
}

// add_profile adds a transcoding profile.
pub fn (mut m MediaManager) add_profile(profile TranscodeProfile) ! {
	if profile.name.len == 0 {
		return error("profile name must not be empty")
	}
	m.profiles << profile
	println("[media] added transcode profile: ${profile.name}")
}

// --- Tests ---

fn test_empty_stream_id_rejected() {
	mut mgr := new_media_manager(MediaConfig{})
	mgr.add_stream(MediaStream{ stream_id: "", name: "test", codec: .h264, stream_type: .live, bitrate_kbps: 4000, resolution: "1920x1080" }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
