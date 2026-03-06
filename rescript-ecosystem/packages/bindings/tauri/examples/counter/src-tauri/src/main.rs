// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// main.rs - Rust backend for counter example
// Demonstrates typed Tauri commands with state management

#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

use std::sync::atomic::{AtomicI32, Ordering};
use tauri::State;

// Shared state for the counter
struct CounterState(AtomicI32);

/// Get the current count
#[tauri::command]
fn get_count(state: State<'_, CounterState>) -> i32 {
    state.0.load(Ordering::SeqCst)
}

/// Set the count to a specific value
#[tauri::command]
fn set_count(count: i32, state: State<'_, CounterState>) {
    state.0.store(count, Ordering::SeqCst);
}

/// Increment the count and return the new value
#[tauri::command]
fn increment(state: State<'_, CounterState>) -> i32 {
    state.0.fetch_add(1, Ordering::SeqCst) + 1
}

/// Decrement the count and return the new value
#[tauri::command]
fn decrement(state: State<'_, CounterState>) -> i32 {
    state.0.fetch_sub(1, Ordering::SeqCst) - 1
}

fn main() {
    tauri::Builder::default()
        .manage(CounterState(AtomicI32::new(0)))
        .invoke_handler(tauri::generate_handler![
            get_count,
            set_count,
            increment,
            decrement
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
