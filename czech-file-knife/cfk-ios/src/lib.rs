//! iOS File Provider extension for Czech File Knife
//!
//! This crate provides iOS integration via Apple's File Provider framework.
//! It exposes a C FFI layer that can be called from Swift/Objective-C.
//!
//! # Architecture
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────┐
//! │                     iOS App / Extension                      │
//! ├─────────────────────────────────────────────────────────────┤
//! │                    Swift File Provider                       │
//! │              (CfkFileProviderExtension.swift)                │
//! ├─────────────────────────────────────────────────────────────┤
//! │                    C FFI Bridge Layer                        │
//! │                      (ffi.rs + CfkBridge.h)                  │
//! ├─────────────────────────────────────────────────────────────┤
//! │                     Rust Core Library                        │
//! │              (cfk-core, cfk-providers, cfk-cache)            │
//! └─────────────────────────────────────────────────────────────┘
//! ```
//!
//! # Usage
//!
//! 1. Build as a static library for iOS targets
//! 2. Link with your File Provider extension
//! 3. Use the Swift wrapper classes

#![allow(dead_code)] // FFI functions may not be called from Rust

pub mod domain;
pub mod error;
pub mod ffi;
pub mod item;
pub mod provider;

pub use domain::FileDomain;
pub use error::{IosError, IosResult};
pub use item::{FileProviderItem, ItemIdentifier};
pub use provider::FileProviderManager;

use once_cell::sync::OnceCell;
use std::sync::Arc;
use tokio::runtime::Runtime;

/// Global Tokio runtime for async operations
static RUNTIME: OnceCell<Runtime> = OnceCell::new();

/// Initialize the global runtime
pub fn init_runtime() -> &'static Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .expect("Failed to create Tokio runtime")
    })
}

/// Get the global runtime
pub fn runtime() -> &'static Runtime {
    RUNTIME.get().expect("Runtime not initialized")
}

/// Initialize the iOS integration
///
/// Must be called before any other FFI functions.
#[no_mangle]
pub extern "C" fn cfk_ios_init() -> i32 {
    // Initialize tracing for iOS
    #[cfg(debug_assertions)]
    {
        use tracing_subscriber::prelude::*;
        let _ = tracing_subscriber::registry()
            .with(tracing_subscriber::fmt::layer())
            .try_init();
    }

    // Initialize runtime
    let _ = init_runtime();

    tracing::info!("CFK iOS initialized");
    0
}

/// Shutdown the iOS integration
#[no_mangle]
pub extern "C" fn cfk_ios_shutdown() {
    tracing::info!("CFK iOS shutting down");
    // Runtime will be dropped when the process exits
}
