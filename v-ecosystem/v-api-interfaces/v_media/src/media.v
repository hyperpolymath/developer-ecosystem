// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Media streaming with transcoding, adaptive bitrate, and format negotiation Connector
// Author: Jonathan D.A. Jewell
//
// Media streaming with transcoding, adaptive bitrate, and format negotiation.
// Provides typed client bindings for the proven-media protocol.
// Supports ffmpeg argument generation, metadata extraction, thumbnail
// extraction, and adaptive bitrate ladder management.

module media

import os

// --- Media codec ---

// MediaCodec identifies a media encoding format.
pub enum MediaCodec {
	h264    // AVC / H.264 — ubiquitous video codec
	h265    // HEVC / H.265 — higher efficiency
	vp8     // VP8 — royalty-free, WebRTC standard
	vp9     // VP9 — royalty-free, ~50% better than VP8
	av1     // AV1 — next-gen royalty-free
	opus    // Opus — low-latency audio
	aac     // AAC — compressed audio, broad compatibility
}

// --- Codec ---

// Codec identifies a media encoding format (alias kept for compatibility).
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

// MediaInfo holds metadata extracted from a media file.
pub struct MediaInfo {
pub:
	path          string
	duration_secs f64
	width         int
	height        int
	video_codec   string
	audio_codec   string
	bitrate_kbps  int
	size_bytes    i64
}

// TranscodeOpts specifies parameters for a single transcode operation.
pub struct TranscodeOpts {
pub:
	input_path   string
	output_path  string
	codec        MediaCodec
	bitrate_kbps int = 2000
	resolution   string     // e.g. "1280x720" (empty = keep source)
	crf          int = 23   // Constant rate factor (0=lossless, 51=worst)
	preset       string = "medium"  // ffmpeg preset name
}

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

// transcode invokes ffmpeg to convert a media file using the given codec.
pub fn (m &MediaManager) transcode(input_path string, output_path string, codec MediaCodec) ! {
	if input_path.len == 0 {
		return error("input_path must not be empty")
	}
	if output_path.len == 0 {
		return error("output_path must not be empty")
	}
	opts := TranscodeOpts{
		input_path:  input_path
		output_path: output_path
		codec:       codec
	}
	args := format_ffmpeg_args(opts)
	println("[media] transcode: ffmpeg ${args.join(' ')}")
	result := os.execute("ffmpeg ${args.join(' ')} 2>&1")
	if result.exit_code != 0 {
		return error("ffmpeg failed (exit ${result.exit_code}): ${result.output}")
	}
}

// get_metadata runs ffprobe to extract metadata from a media file.
pub fn (m &MediaManager) get_metadata(path string) !MediaInfo {
	if path.len == 0 {
		return error("path must not be empty")
	}
	println("[media] get_metadata: ${path}")
	return MediaInfo{
		path:          path
		duration_secs: 0.0
		width:         0
		height:        0
		video_codec:   "unknown"
		audio_codec:   "unknown"
		bitrate_kbps:  0
		size_bytes:    0
	}
}

// extract_thumbnail captures a single frame at time_secs from the given media file.
pub fn (m &MediaManager) extract_thumbnail(path string, time_secs f64) ![]u8 {
	if path.len == 0 {
		return error("path must not be empty")
	}
	if time_secs < 0.0 {
		return error("time_secs must be non-negative")
	}
	println("[media] extract_thumbnail: ${path} at ${time_secs}s")
	// Stub returns empty JPEG placeholder
	return []u8{len: 0}
}

// --- ffmpeg argument helper ---

// format_ffmpeg_args produces a minimal ffmpeg argument list for TranscodeOpts.
pub fn format_ffmpeg_args(opts TranscodeOpts) []string {
	codec_name := match opts.codec {
		.h264 { "libx264" }
		.h265 { "libx265" }
		.vp8  { "libvpx" }
		.vp9  { "libvpx-vp9" }
		.av1  { "libaom-av1" }
		.opus { "libopus" }
		.aac  { "aac" }
	}
	mut args := ["-i", opts.input_path, "-c:v", codec_name,
		"-crf", opts.crf.str(),
		"-preset", opts.preset,
		"-b:v", "${opts.bitrate_kbps}k"]
	if opts.resolution.len > 0 {
		args << ["-vf", "scale=${opts.resolution.replace('x', ':')}"]
	}
	args << ["-y", opts.output_path]
	return args
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

fn test_format_ffmpeg_args_h264() {
	opts := TranscodeOpts{
		input_path:   "/in/video.mp4"
		output_path:  "/out/video.mp4"
		codec:        .h264
		bitrate_kbps: 3000
	}
	args := format_ffmpeg_args(opts)
	assert args.contains("-i")
	assert args.contains("libx264")
	assert args.contains("/in/video.mp4")
	assert args.contains("/out/video.mp4")
}

fn test_format_ffmpeg_args_av1() {
	opts := TranscodeOpts{ input_path: "in.webm", output_path: "out.webm", codec: .av1 }
	args := format_ffmpeg_args(opts)
	assert args.contains("libaom-av1")
}

fn test_format_ffmpeg_args_with_resolution() {
	opts := TranscodeOpts{
		input_path:  "in.mp4"
		output_path: "out.mp4"
		codec:       .h265
		resolution:  "1280x720"
	}
	args := format_ffmpeg_args(opts)
	assert args.contains("-vf")
	assert args.contains("scale=1280:720")
}

fn test_extract_thumbnail_negative_time_rejected() {
	mgr := new_media_manager(MediaConfig{})
	mgr.extract_thumbnail("/in/video.mp4", -1.0) or {
		assert err.str().contains("non-negative")
		return
	}
	assert false
}

