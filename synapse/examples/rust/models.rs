// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024 Synapse Contributors
//
// DRIFT - Example Rust Models
// These structs define the "World" - the Source of Truth.
// Synapse generates the Swift interface automatically.
//
// Mark structs with #[derive(Synapse)] to include them in generation.

/// A reef location with vibe scoring
#[derive(Debug, Clone, Synapse)]
pub struct Reef {
    pub lat: f64,
    pub lon: f64,
    pub vibe_score: i32,
    pub name: String,
    pub is_active: bool,
}

/// Player state for the Drift game
#[derive(Debug, Clone, Synapse)]
pub struct PlayerState {
    pub coffee_count: i32,
    pub is_drifting: bool,
    pub current_speed: f64,
    pub username: String,
}

/// GPS telemetry data
#[derive(Debug, Clone, Synapse)]
pub struct Telemetry {
    pub latitude: f64,
    pub longitude: f64,
    pub altitude: f64,
    pub accuracy: f32,
    pub timestamp: i64,
}

/// User preferences (synced to iCloud)
#[derive(Debug, Clone, Synapse)]
pub struct UserPreferences {
    pub haptic_enabled: bool,
    pub audio_cues_enabled: bool,
    pub dark_mode: bool,
    pub notification_radius: f64,
}

/// This struct is NOT marked with Synapse, so it won't be generated
#[derive(Debug, Clone)]
pub struct InternalState {
    pub cache_hit: bool,
    pub last_sync: i64,
}

// ================================
// USAGE:
// 1. Add your app's domain models here
// 2. Run: just gen-ui
// 3. Import Generated.swift in your Xcode project
// ================================
