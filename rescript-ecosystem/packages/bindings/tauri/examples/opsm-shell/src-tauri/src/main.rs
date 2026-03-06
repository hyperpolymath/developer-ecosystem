// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// main.rs - Rust backend for OPSM shell example

#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

use std::collections::HashMap;
use std::process::Command;
use tauri::{CustomMenuItem, Menu, MenuItem, Submenu};

#[tauri::command]
fn check_backend(backend: String) -> String {
    let commands: HashMap<&str, Vec<&str>> = HashMap::from([
        ("rpm-ostree", vec!["rpm-ostree"]),
        ("toolbox", vec!["toolbox"]),
        ("distrobox", vec!["distrobox"]),
        ("container", vec!["podman", "docker"]),
        ("dnfinition", vec!["dnfinition"]),
        ("flatpak", vec!["flatpak"]),
        ("snap", vec!["snap"]),
        ("native", vec![]),
        ("git", vec![]),
        ("source", vec![]),
        ("auto", vec![]),
    ]);

    if let Some(cmds) = commands.get(backend.as_str()) {
        if cmds.is_empty() {
            return "available".to_string();
        }
        for cmd in cmds {
            if which::which(cmd).is_ok() {
                return "available".to_string();
            }
        }
        return "missing".to_string();
    }

    "unknown".to_string()
}

#[tauri::command]
fn opsm_dry_run(args: String) -> String {
    let mut parts = vec!["install".to_string(), "--dry-run".to_string()];
    if !args.trim().is_empty() {
        parts.extend(args.split_whitespace().map(|s| s.to_string()));
    }

    let output = Command::new("opsm")
        .args(parts)
        .output();

    match output {
        Ok(out) => {
            let mut buf = String::new();
            buf.push_str(&String::from_utf8_lossy(&out.stdout));
            buf.push_str(&String::from_utf8_lossy(&out.stderr));
            buf
        }
        Err(err) => format!("Failed to run opsm: {err}"),
    }
}

fn main() {
    let mode_user = CustomMenuItem::new("mode_user".to_string(), "WYSIWYG (User)");
    let mode_maint = CustomMenuItem::new("mode_maint".to_string(), "WYSIWYGM (Maintainer)");
    let mode_dev = CustomMenuItem::new("mode_dev".to_string(), "WYMIWYG (Developer)");
    let dry_run = CustomMenuItem::new("dry_run".to_string(), "Dry-Run Focus");

    let mode_menu = Menu::new()
        .add_item(mode_user)
        .add_item(mode_maint)
        .add_item(mode_dev)
        .add_native_item(MenuItem::Separator)
        .add_item(dry_run);

    let menu = Menu::new().add_submenu(Submenu::new("Mode", mode_menu));

    tauri::Builder::default()
        .menu(menu)
        .invoke_handler(tauri::generate_handler![check_backend, opsm_dry_run])
        .on_menu_event(|event| {
            let window = event.window();
            match event.menu_item_id() {
                "mode_user" => {
                    let _ = window.emit("opsm:mode", "wysiwyg");
                }
                "mode_maint" => {
                    let _ = window.emit("opsm:mode", "wysiwygm");
                }
                "mode_dev" => {
                    let _ = window.emit("opsm:mode", "wymiwyg");
                }
                "dry_run" => {
                    let _ = window.emit("opsm:dry-run", "focus");
                }
                _ => {}
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
