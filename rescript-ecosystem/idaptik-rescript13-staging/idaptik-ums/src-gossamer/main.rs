// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
//! # IDApTIK Universal Modding Studio — Gossamer backend
//!
//! Author: Jonathan D.A. Jewell
//!
//! Visual level editor for the IDApTIK asymmetric co-op stealth puzzle-platformer.
//! Manages level I/O, ABI validation, and ReScript config export.
//!
//! ## Validation philosophy
//!
//! The IDApTIK level data model has three verification layers:
//!
//!   1. **Idris2 ABI** (`src/abi/Validation.idr`): Compile-time dependent-type
//!      proofs. Five invariants are expressed as erased proof fields on
//!      `ValidatedLevel`, costing zero bytes at runtime.
//!
//!   2. **Zig FFI** (`ffi/zig/src/validate.zig`): Runtime materialisation of
//!      the same invariants for C callers that cannot carry type-level witnesses.
//!      Produces a `ValidationResult` struct with boolean flags.
//!
//!   3. **Rust (this file)**: Mirrors the Zig checks so the Gossamer shell can
//!      validate levels without calling across the FFI boundary. This is useful
//!      during development before `libidaptik_ums.so` is linked, and also
//!      provides user-friendly error messages for each failed proof.
//!
//! All three layers check the same five conditions:
//!
//!   1. All guards reference valid zones           (GuardsInZones)
//!   2. Defence failover/cascade/mirror targets    (DefenceTargetsValid)
//!      exist in the device registry
//!   3. Zone transitions are monotonically ordered (ZonesOrdered)
//!      by X position
//!   4. PBX consistency — when enabled, the PBX    (PBXConsistent)
//!      IP must be in the device registry
//!   5. All defence config IPs exist in the        (DevicesExist — subset of #2)
//!      device registry
//!
//! ## Migration from Tauri
//!
//! This crate was migrated from Tauri 2.0 to Gossamer. All six `#[tauri::command]`
//! async handlers are now synchronous closures registered via `app.command()`.
//! The ReScript frontend calls `invoke()` identically — Gossamer's RuntimeBridge
//! dispatches JSON payloads through the same IPC protocol.

#![forbid(unsafe_code)]

use gossamer_rs::{App, WindowConfig};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::fs;
use std::path::{Path, PathBuf};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Base directory for level storage. During development we use `/tmp` to avoid
/// polluting the user's home directory; production builds will use the Gossamer
/// app data directory.
const LEVELS_DIR: &str = "/tmp/idaptik-ums/levels";

// ---------------------------------------------------------------------------
// Data types — mirrors of the Idris2/Zig level structures
// ---------------------------------------------------------------------------

/// A device in the level's network topology.
///
/// Corresponds to `DeviceSpec` in `src/abi/Devices.idr` and
/// `types.DeviceSpec` in `ffi/zig/src/types.zig`.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct DeviceSpec {
    /// IPv4 address string (e.g. "192.168.1.10").
    ip: String,
    /// Device category (laptop, server, router, etc.).
    kind: String,
    /// Human-readable label shown in the editor.
    label: Option<String>,
}

/// Defence configuration flags for a device.
///
/// Corresponds to the `DefenceFlags` record in `src/abi/Devices.idr`.
/// Optional IP fields (`failover_target`, `cascade_trap`, `mirror_target`)
/// are `Option<String>` — `None` maps to the Idris2 `Nothing` / Zig
/// `OptionalIpAddress { .has_value = false }`.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
struct DefenceFlags {
    /// If set, traffic fails over to this device when the primary goes down.
    failover_target: Option<String>,
    /// If set, a trap cascades to this device on intrusion detection.
    cascade_trap: Option<String>,
    /// If set, traffic is mirrored to this device for monitoring.
    mirror_target: Option<String>,
}

/// Per-device defence configuration.
///
/// Each entry ties a device IP to its defence flags. The IP must exist in the
/// level's device registry — this is the `InRegistry` proof in Idris2.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct DeviceDefenceConfig {
    /// IP address of the device this config applies to.
    ip: String,
    /// Defence behaviour flags.
    flags: DefenceFlags,
}

/// A guard placement in the level.
///
/// Corresponds to `GuardPlacement` in `src/abi/Guards.idr`. The `zone` field
/// must name a zone that exists in the level's zone list — this is the
/// `GuardsInZones` proof.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct GuardPlacement {
    /// Zone name where this guard patrols.
    zone: String,
    /// Guard rank (basic_guard, enforcer, anti_hacker, etc.).
    rank: String,
}

/// A zone in the level layout.
///
/// Corresponds to `Zone` in `src/abi/Zones.idr`.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct Zone {
    /// Unique zone name (referenced by guards, transitions, etc.).
    name: String,
}

/// A zone transition boundary.
///
/// When the player crosses this X coordinate, they enter a new zone.
/// Transitions must be monotonically ordered by `world_x` — this is the
/// `ZonesOrdered` proof.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct ZoneTransition {
    /// World X position of the transition boundary.
    world_x: f64,
    /// Target zone name.
    target_zone: String,
}

/// Complete level data bundle.
///
/// This is the JSON-serialisable mirror of `LevelData` in `src/abi/Level.idr`.
/// Not all Idris2 fields are represented here — only those needed for
/// validation and export. The full level data flows through the ReScript
/// frontend; Rust only needs the validation-relevant subset.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct LevelData {
    /// Human-readable level name.
    name: String,
    /// Devices in the level's network.
    devices: Vec<DeviceSpec>,
    /// Zones in the level layout.
    zones: Vec<Zone>,
    /// Guard placements.
    guards: Vec<GuardPlacement>,
    /// Zone transition boundaries.
    zone_transitions: Vec<ZoneTransition>,
    /// Per-device defence configurations.
    device_defences: Vec<DeviceDefenceConfig>,
    /// Whether the level has a PBX (phone system).
    has_pbx: bool,
    /// IP address of the PBX device (only meaningful when `has_pbx` is true).
    pbx_ip: Option<String>,
}

/// Result of running the five ABI validation checks.
///
/// Mirrors `ValidationResult` in `ffi/zig/src/types.zig`. Each boolean
/// corresponds to one of the erased proof fields on `ValidatedLevel` in
/// `src/abi/Validation.idr`.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct ValidationResult {
    /// True if all five checks pass.
    valid: bool,
    /// Check 1: every guard references a zone that exists.
    guards_in_zones: bool,
    /// Check 2: defence failover/cascade/mirror targets exist in registry.
    defence_targets_valid: bool,
    /// Check 3: zone transitions are monotonically increasing by X.
    zones_ordered: bool,
    /// Check 4: if PBX is enabled, its IP is in the device registry.
    pbx_consistent: bool,
    /// Check 5: every defence config IP exists in the device registry.
    defence_ips_exist: bool,
    /// Human-readable error messages for each failed check.
    errors: Vec<String>,
}

// ---------------------------------------------------------------------------
// Validation logic — mirrors ffi/zig/src/validate.zig
// ---------------------------------------------------------------------------

/// Check whether an IP address exists in the device list.
///
/// This is the runtime equivalent of `InRegistry` in `src/abi/Validation.idr`.
fn ip_exists_in_devices(ip: &str, devices: &[DeviceSpec]) -> bool {
    devices.iter().any(|d| d.ip == ip)
}

/// Check 1: Every guard's zone field names a zone in the level.
///
/// Mirrors `Validation.GuardsInZones` (Idris2) and
/// `validate.checkGuardsInZones` (Zig).
fn check_guards_in_zones(level: &LevelData) -> (bool, Vec<String>) {
    let zone_names: Vec<&str> = level.zones.iter().map(|z| z.name.as_str()).collect();
    let mut errors = Vec::new();

    for guard in &level.guards {
        if !zone_names.contains(&guard.zone.as_str()) {
            errors.push(format!(
                "Guard (rank: {}) references non-existent zone '{}'",
                guard.rank, guard.zone
            ));
        }
    }

    (errors.is_empty(), errors)
}

/// Check 2: Defence failover/cascade/mirror targets reference real devices.
///
/// Mirrors `Validation.DefenceTargetsValid` (Idris2) and
/// `validate.checkDefenceTargetsValid` (Zig).
fn check_defence_targets_valid(level: &LevelData) -> (bool, Vec<String>) {
    let mut errors = Vec::new();

    for def in &level.device_defences {
        if let Some(ref ft) = def.flags.failover_target {
            if !ip_exists_in_devices(ft, &level.devices) {
                errors.push(format!(
                    "Defence on {} has failover_target '{}' not in device registry",
                    def.ip, ft
                ));
            }
        }
        if let Some(ref ct) = def.flags.cascade_trap {
            if !ip_exists_in_devices(ct, &level.devices) {
                errors.push(format!(
                    "Defence on {} has cascade_trap '{}' not in device registry",
                    def.ip, ct
                ));
            }
        }
        if let Some(ref mt) = def.flags.mirror_target {
            if !ip_exists_in_devices(mt, &level.devices) {
                errors.push(format!(
                    "Defence on {} has mirror_target '{}' not in device registry",
                    def.ip, mt
                ));
            }
        }
    }

    (errors.is_empty(), errors)
}

/// Check 3: Zone transitions are monotonically increasing by world X.
///
/// Mirrors `Validation.ZonesOrdered` (Idris2) and
/// `validate.checkZonesOrdered` (Zig).
fn check_zones_ordered(level: &LevelData) -> (bool, Vec<String>) {
    let mut errors = Vec::new();
    let transitions = &level.zone_transitions;

    if transitions.len() <= 1 {
        return (true, errors);
    }

    for i in 1..transitions.len() {
        if transitions[i].world_x < transitions[i - 1].world_x {
            errors.push(format!(
                "Zone transition {} (x={}) is before transition {} (x={}) — not monotonically ordered",
                i, transitions[i].world_x, i - 1, transitions[i - 1].world_x
            ));
        }
    }

    (errors.is_empty(), errors)
}

/// Check 4: PBX consistency — when enabled, the PBX IP must be in the registry.
///
/// Mirrors `Validation.PBXConsistent` (Idris2) and
/// `validate.checkPBXConsistent` (Zig).
fn check_pbx_consistent(level: &LevelData) -> (bool, Vec<String>) {
    let mut errors = Vec::new();

    if level.has_pbx {
        match &level.pbx_ip {
            Some(ip) => {
                if !ip_exists_in_devices(ip, &level.devices) {
                    errors.push(format!(
                        "PBX is enabled but pbx_ip '{}' is not in the device registry",
                        ip
                    ));
                }
            }
            None => {
                errors.push("PBX is enabled but pbx_ip is null".to_string());
            }
        }
    }

    (errors.is_empty(), errors)
}

/// Check 5: Every defence config's own IP exists in the device registry.
///
/// This is part of `DefenceTargetsValid` in Idris2 (the `InRegistry (ip d) devs`
/// premise), broken out as a separate check for clearer error messages.
fn check_defence_ips_exist(level: &LevelData) -> (bool, Vec<String>) {
    let mut errors = Vec::new();

    for def in &level.device_defences {
        if !ip_exists_in_devices(&def.ip, &level.devices) {
            errors.push(format!(
                "Defence config references device '{}' which is not in the device registry",
                def.ip
            ));
        }
    }

    (errors.is_empty(), errors)
}

/// Run all five validation checks and produce a composite result.
///
/// This is the Rust equivalent of `validate.validateLevel` in the Zig FFI
/// and the `ValidatedLevel` record in `src/abi/Validation.idr`.
fn validate_level_data(level: &LevelData) -> ValidationResult {
    let (giz, mut errs1) = check_guards_in_zones(level);
    let (dtv, mut errs2) = check_defence_targets_valid(level);
    let (zo, mut errs3) = check_zones_ordered(level);
    let (pbx, mut errs4) = check_pbx_consistent(level);
    let (die, mut errs5) = check_defence_ips_exist(level);

    let mut all_errors = Vec::new();
    all_errors.append(&mut errs1);
    all_errors.append(&mut errs2);
    all_errors.append(&mut errs3);
    all_errors.append(&mut errs4);
    all_errors.append(&mut errs5);

    ValidationResult {
        valid: giz && dtv && zo && pbx && die,
        guards_in_zones: giz,
        defence_targets_valid: dtv,
        zones_ordered: zo,
        pbx_consistent: pbx,
        defence_ips_exist: die,
        errors: all_errors,
    }
}

// ---------------------------------------------------------------------------
// Filesystem helpers
// ---------------------------------------------------------------------------

/// Ensure the levels directory exists, creating it if necessary.
///
/// Returns the canonical path to the levels directory.
fn ensure_levels_dir() -> Result<PathBuf, String> {
    let path = PathBuf::from(LEVELS_DIR);
    fs::create_dir_all(&path).map_err(|e| format!("Failed to create levels directory: {e}"))?;
    Ok(path)
}

/// Derive a filesystem-safe filename from a level name.
///
/// Replaces non-alphanumeric characters (except hyphens and underscores) with
/// underscores, then appends `.json`.
fn level_filename(name: &str) -> String {
    let safe: String = name
        .chars()
        .map(|c| {
            if c.is_alphanumeric() || c == '-' || c == '_' {
                c
            } else {
                '_'
            }
        })
        .collect();
    format!("{safe}.json")
}

// ---------------------------------------------------------------------------
// Command handlers (synchronous — Gossamer dispatches on its own thread)
// ---------------------------------------------------------------------------

/// Load a level JSON file from disk.
///
/// Reads the file at the given path (or looks it up by name in the levels
/// directory) and returns the parsed `LevelData` as a JSON value. The
/// ReScript frontend receives this via `invoke("load_level", { path })`.
fn cmd_load_level(payload: Value) -> Result<Value, String> {
    let path = payload["path"]
        .as_str()
        .ok_or_else(|| "Missing 'path' parameter".to_string())?;

    let file_path = if Path::new(path).is_absolute() {
        PathBuf::from(path)
    } else {
        let dir = ensure_levels_dir()?;
        dir.join(level_filename(path))
    };

    let contents = fs::read_to_string(&file_path)
        .map_err(|e| format!("Failed to read level file '{}': {e}", file_path.display()))?;

    let value: Value = serde_json::from_str(&contents)
        .map_err(|e| format!("Failed to parse level JSON: {e}"))?;

    Ok(value)
}

/// Save a level JSON to disk.
///
/// Writes the provided level data to the levels directory, using the level
/// name to derive the filename. Returns the path where the file was written.
fn cmd_save_level(payload: Value) -> Result<Value, String> {
    let level = payload
        .get("level")
        .ok_or_else(|| "Missing 'level' parameter".to_string())?;

    let dir = ensure_levels_dir()?;

    let name = level
        .get("name")
        .and_then(|v| v.as_str())
        .ok_or_else(|| "Level data must have a 'name' field".to_string())?;

    let file_path = dir.join(level_filename(name));

    let json_str = serde_json::to_string_pretty(level)
        .map_err(|e| format!("Failed to serialise level: {e}"))?;

    fs::write(&file_path, &json_str)
        .map_err(|e| format!("Failed to write level file: {e}"))?;

    Ok(json!({ "path": file_path.display().to_string() }))
}

/// Validate level data against the five ABI proof conditions.
///
/// This command mirrors the Zig FFI validation (`validate.validateLevel`) and
/// the Idris2 dependent-type proofs (`Validation.ValidatedLevel`). It checks:
///
///   1. **GuardsInZones** — all guards reference valid zones
///   2. **DefenceTargetsValid** — failover/cascade/mirror targets exist
///   3. **ZonesOrdered** — zone transitions are monotonically ordered by X
///   4. **PBXConsistent** — when PBX is enabled, its IP is in the registry
///   5. **DefenceIpsExist** — all defence config IPs are in the registry
///
/// Returns a JSON object with a boolean for each check and an `errors` array
/// containing human-readable descriptions of any failures.
fn cmd_validate_level_abi(payload: Value) -> Result<Value, String> {
    // Accept either a JSON string in "level" or the level object directly.
    let level_str = if let Some(s) = payload.get("level").and_then(|v| v.as_str()) {
        s.to_string()
    } else if let Some(obj) = payload.get("level") {
        serde_json::to_string(obj).map_err(|e| format!("Failed to serialise level: {e}"))?
    } else {
        // Try treating the entire payload as the level data.
        serde_json::to_string(&payload).map_err(|e| format!("Failed to serialise payload: {e}"))?
    };

    let level_data: LevelData = serde_json::from_str(&level_str)
        .map_err(|e| format!("Failed to parse level data for validation: {e}"))?;

    let result = validate_level_data(&level_data);

    serde_json::to_value(&result)
        .map_err(|e| format!("Failed to serialise validation result: {e}"))
}

/// List level files in the project directory.
///
/// Scans the levels directory for `.json` files and returns an array of
/// objects with `name` and `path` fields.
fn cmd_list_levels(_payload: Value) -> Result<Value, String> {
    let dir = ensure_levels_dir()?;

    let entries: Vec<Value> = fs::read_dir(&dir)
        .map_err(|e| format!("Failed to read levels directory: {e}"))?
        .filter_map(|entry| {
            let entry = entry.ok()?;
            let path = entry.path();
            if path.extension()?.to_str()? == "json" {
                let name = path.file_stem()?.to_str()?.to_string();
                Some(json!({
                    "name": name,
                    "path": path.display().to_string(),
                }))
            } else {
                None
            }
        })
        .collect();

    Ok(json!(entries))
}

/// Export a level as a ReScript LevelConfig module.
///
/// Takes the level JSON and produces a ReScript source string that defines a
/// `LevelConfig` value matching `src/LevelConfigTypes.res.mjs`. This is used
/// for embedding level data directly into the game client.
fn cmd_export_level_config(payload: Value) -> Result<Value, String> {
    let level_str = if let Some(s) = payload.get("level").and_then(|v| v.as_str()) {
        s.to_string()
    } else if let Some(obj) = payload.get("level") {
        serde_json::to_string(obj).map_err(|e| format!("Failed to serialise level: {e}"))?
    } else {
        return Err("Missing 'level' parameter".to_string());
    };

    let level_data: LevelData = serde_json::from_str(&level_str)
        .map_err(|e| format!("Failed to parse level for export: {e}"))?;

    let mut out = String::new();

    out.push_str("// SPDX-License-Identifier: AGPL-3.0-or-later\n");
    out.push_str("// Generated by IDApTIK UMS — do not edit manually.\n\n");
    out.push_str(&format!(
        "let levelConfig_{} = {{\n",
        level_data
            .name
            .replace(|c: char| !c.is_alphanumeric() && c != '_', "_")
    ));
    out.push_str(&format!("  name: \"{}\",\n", level_data.name));
    out.push_str(&format!(
        "  deviceCount: {},\n",
        level_data.devices.len()
    ));
    out.push_str(&format!(
        "  zoneCount: {},\n",
        level_data.zones.len()
    ));
    out.push_str(&format!(
        "  guardCount: {},\n",
        level_data.guards.len()
    ));
    out.push_str(&format!("  hasPbx: {},\n", level_data.has_pbx));

    // Embed device IPs for quick reference.
    out.push_str("  devices: [\n");
    for dev in &level_data.devices {
        out.push_str(&format!(
            "    {{ ip: \"{}\", kind: \"{}\" }},\n",
            dev.ip, dev.kind
        ));
    }
    out.push_str("  ],\n");

    // Embed zone names.
    out.push_str("  zones: [\n");
    for zone in &level_data.zones {
        out.push_str(&format!("    \"{}\",\n", zone.name));
    }
    out.push_str("  ],\n");

    out.push_str("}\n");

    Ok(json!({ "config": out }))
}

/// Return basic system info for the About dialog.
///
/// Reports the OS, architecture, and app version so the user can include it
/// in bug reports. No sensitive data is exposed.
fn cmd_get_system_info(_payload: Value) -> Result<Value, String> {
    Ok(json!({
        "app_name": "IDApTIK Universal Modding Studio",
        "app_version": env!("CARGO_PKG_VERSION"),
        "os": std::env::consts::OS,
        "arch": std::env::consts::ARCH,
        "levels_dir": LEVELS_DIR,
        "runtime": "gossamer",
        "gossamer_version": gossamer_rs::version(),
    }))
}

// ---------------------------------------------------------------------------
// Application entry point
// ---------------------------------------------------------------------------

/// Launch the IDApTIK Universal Modding Studio.
///
/// Creates a Gossamer webview window with the same dimensions as the former
/// Tauri configuration, registers all six IPC commands, and enters the event
/// loop. The ReScript frontend connects via Gossamer's RuntimeBridge which
/// provides the same `invoke()` API as Tauri.
fn main() -> Result<(), gossamer_rs::Error> {
    let mut app = App::with_config(WindowConfig {
        title: "IDApTIK Universal Modding Studio".to_string(),
        width: 1400,
        height: 900,
        resizable: true,
        decorations: true,
        fullscreen: false,
    })?;

    // Register all six IPC commands — direct replacements for #[tauri::command].
    app.command("load_level", cmd_load_level);
    app.command("save_level", cmd_save_level);
    app.command("validate_level_abi", cmd_validate_level_abi);
    app.command("list_levels", cmd_list_levels);
    app.command("export_level_config", cmd_export_level_config);
    app.command("get_system_info", cmd_get_system_info);

    // Navigate to the frontend. In dev mode, Vite serves on localhost:8000.
    // In production, the bundled dist/ is served as a file URL.
    #[cfg(debug_assertions)]
    app.navigate("http://localhost:8000")?;

    #[cfg(not(debug_assertions))]
    {
        // Production: load from the bundled dist/ directory.
        // The gossamer.conf.json specifies frontendDist: "../dist".
        let exe_dir = std::env::current_exe()
            .ok()
            .and_then(|p| p.parent().map(|d| d.to_path_buf()))
            .unwrap_or_else(|| PathBuf::from("."));
        let index = exe_dir.join("dist").join("index.html");
        if index.exists() {
            app.navigate(&format!("file://{}", index.display()))?;
        } else {
            app.load_html(
                "<html><body><h1>IDApTIK UMS</h1><p>Frontend not found. Run <code>deno task build</code> first.</p></body></html>"
            )?;
        }
    }

    app.run();
    Ok(())
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    /// Helper: build a minimal valid level for testing.
    fn make_valid_level() -> LevelData {
        LevelData {
            name: "test_level".to_string(),
            devices: vec![
                DeviceSpec {
                    ip: "192.168.1.1".to_string(),
                    kind: "server".to_string(),
                    label: Some("Main Server".to_string()),
                },
                DeviceSpec {
                    ip: "192.168.1.2".to_string(),
                    kind: "router".to_string(),
                    label: Some("Edge Router".to_string()),
                },
                DeviceSpec {
                    ip: "192.168.1.3".to_string(),
                    kind: "laptop".to_string(),
                    label: None,
                },
            ],
            zones: vec![
                Zone {
                    name: "lobby".to_string(),
                },
                Zone {
                    name: "server_room".to_string(),
                },
            ],
            guards: vec![GuardPlacement {
                zone: "lobby".to_string(),
                rank: "basic_guard".to_string(),
            }],
            zone_transitions: vec![
                ZoneTransition {
                    world_x: 0.0,
                    target_zone: "lobby".to_string(),
                },
                ZoneTransition {
                    world_x: 500.0,
                    target_zone: "server_room".to_string(),
                },
            ],
            device_defences: vec![DeviceDefenceConfig {
                ip: "192.168.1.1".to_string(),
                flags: DefenceFlags {
                    failover_target: Some("192.168.1.2".to_string()),
                    cascade_trap: None,
                    mirror_target: None,
                },
            }],
            has_pbx: true,
            pbx_ip: Some("192.168.1.3".to_string()),
        }
    }

    /// Helper: clean up test level files after a test run.
    fn cleanup_test_level(name: &str) {
        let path = PathBuf::from(LEVELS_DIR).join(level_filename(name));
        let _ = fs::remove_file(path);
    }

    // -- Validation unit tests ---------------------------------------------

    #[test]
    fn test_valid_level_passes_all_checks() {
        let level = make_valid_level();
        let result = validate_level_data(&level);
        assert!(result.valid, "Valid level should pass all checks");
        assert!(result.guards_in_zones);
        assert!(result.defence_targets_valid);
        assert!(result.zones_ordered);
        assert!(result.pbx_consistent);
        assert!(result.defence_ips_exist);
        assert!(result.errors.is_empty());
    }

    #[test]
    fn test_guard_references_invalid_zone() {
        let mut level = make_valid_level();
        level.guards.push(GuardPlacement {
            zone: "nonexistent_zone".to_string(),
            rank: "enforcer".to_string(),
        });

        let result = validate_level_data(&level);
        assert!(!result.valid, "Should fail with invalid guard zone");
        assert!(!result.guards_in_zones);
        assert!(
            result
                .errors
                .iter()
                .any(|e| e.contains("nonexistent_zone")),
            "Error should mention the bad zone name"
        );
    }

    #[test]
    fn test_defence_failover_target_missing() {
        let mut level = make_valid_level();
        level.device_defences.push(DeviceDefenceConfig {
            ip: "192.168.1.1".to_string(),
            flags: DefenceFlags {
                failover_target: Some("10.0.0.99".to_string()),
                cascade_trap: None,
                mirror_target: None,
            },
        });

        let result = validate_level_data(&level);
        assert!(!result.valid, "Should fail with missing failover target");
        assert!(!result.defence_targets_valid);
        assert!(result.errors.iter().any(|e| e.contains("10.0.0.99")));
    }

    #[test]
    fn test_zone_transitions_out_of_order() {
        let mut level = make_valid_level();
        level.zone_transitions = vec![
            ZoneTransition {
                world_x: 500.0,
                target_zone: "server_room".to_string(),
            },
            ZoneTransition {
                world_x: 100.0,
                target_zone: "lobby".to_string(),
            },
        ];

        let result = validate_level_data(&level);
        assert!(!result.valid, "Should fail with unordered transitions");
        assert!(!result.zones_ordered);
    }

    #[test]
    fn test_pbx_enabled_but_ip_missing_from_registry() {
        let mut level = make_valid_level();
        level.has_pbx = true;
        level.pbx_ip = Some("10.0.0.1".to_string());

        let result = validate_level_data(&level);
        assert!(!result.valid, "Should fail with PBX IP not in registry");
        assert!(!result.pbx_consistent);
    }

    #[test]
    fn test_pbx_disabled_skips_check() {
        let mut level = make_valid_level();
        level.has_pbx = false;
        level.pbx_ip = Some("10.0.0.99".to_string()); // IP not in registry

        let result = validate_level_data(&level);
        assert!(
            result.pbx_consistent,
            "PBX check should pass when PBX is disabled"
        );
    }

    #[test]
    fn test_defence_config_ip_not_in_registry() {
        let mut level = make_valid_level();
        level.device_defences.push(DeviceDefenceConfig {
            ip: "10.0.0.50".to_string(),
            flags: DefenceFlags::default(),
        });

        let result = validate_level_data(&level);
        assert!(!result.valid, "Should fail with defence IP not in registry");
        assert!(!result.defence_ips_exist);
    }

    #[test]
    fn test_empty_level_is_valid() {
        let level = LevelData {
            name: "empty".to_string(),
            devices: vec![],
            zones: vec![],
            guards: vec![],
            zone_transitions: vec![],
            device_defences: vec![],
            has_pbx: false,
            pbx_ip: None,
        };

        let result = validate_level_data(&level);
        assert!(result.valid, "Empty level should be trivially valid");
    }

    // -- Command integration tests (synchronous) ---------------------------

    #[test]
    fn test_save_and_load_roundtrip() {
        let level = serde_json::to_value(&make_valid_level()).expect("TODO: handle error");
        let save_result = cmd_save_level(json!({ "level": level }));
        assert!(save_result.is_ok(), "Save should succeed");

        let save_response = save_result.expect("TODO: handle error");
        let path = save_response["path"].as_str().expect("TODO: handle error");
        let load_result = cmd_load_level(json!({ "path": path }));
        assert!(load_result.is_ok(), "Load should succeed");

        let loaded = load_result.expect("TODO: handle error");
        assert_eq!(
            loaded.get("name").and_then(|v| v.as_str()),
            Some("test_level"),
            "Loaded level name should match saved name"
        );

        cleanup_test_level("test_level");
    }

    #[test]
    fn test_list_levels_returns_array() {
        // Ensure the directory exists.
        let _ = ensure_levels_dir();

        let result = cmd_list_levels(json!({}));
        assert!(result.is_ok(), "list_levels should succeed");

        let entries = result.expect("TODO: handle error");
        assert!(entries.is_array(), "Result should be a JSON array");
    }

    #[test]
    fn test_validate_command_returns_result() {
        let level = make_valid_level();
        let json_str = serde_json::to_string(&level).expect("TODO: handle error");

        let result = cmd_validate_level_abi(json!({ "level": json_str }));
        assert!(result.is_ok(), "validate_level_abi should succeed");

        let val = result.expect("TODO: handle error");
        assert_eq!(
            val.get("valid").and_then(|v| v.as_bool()),
            Some(true),
            "Valid level should produce valid=true"
        );
    }

    #[test]
    fn test_export_level_config_produces_rescript() {
        let level = make_valid_level();
        let json_str = serde_json::to_string(&level).expect("TODO: handle error");

        let result = cmd_export_level_config(json!({ "level": json_str }));
        assert!(result.is_ok(), "export_level_config should succeed");

        let output = result.expect("TODO: handle error");
        let config = output["config"].as_str().expect("TODO: handle error");
        assert!(
            config.contains("levelConfig_test_level"),
            "Export should contain the level config binding"
        );
        assert!(
            config.contains("SPDX-License-Identifier"),
            "Export should contain SPDX header"
        );
        assert!(
            config.contains("192.168.1.1"),
            "Export should contain device IPs"
        );
    }

    #[test]
    fn test_get_system_info() {
        let result = cmd_get_system_info(json!({}));
        assert!(result.is_ok(), "get_system_info should succeed");

        let info = result.expect("TODO: handle error");
        assert_eq!(
            info["app_name"].as_str(),
            Some("IDApTIK Universal Modding Studio")
        );
        assert_eq!(info["runtime"].as_str(), Some("gossamer"));
        assert!(info["os"].as_str().is_some());
        assert!(info["arch"].as_str().is_some());
    }
}
