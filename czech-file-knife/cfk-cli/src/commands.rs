// SPDX-License-Identifier: AGPL-3.0-or-later
//! CLI command implementations

use cfk_core::{
    entry::EntryKind,
    operations::{CopyOptions, DeleteOptions, ListOptions, MoveOptions, ReadOptions, WriteOptions},
    CfkError, CfkResult, VirtualPath,
};
use cfk_providers::{BackendRegistry, LocalBackend};
use chrono::{DateTime, Utc};
use console::style;
use futures::StreamExt;
use std::path::PathBuf;
use std::sync::Arc;
use tabled::{Table, Tabled};

/// Initialize the backend registry with available backends
fn init_registry() -> BackendRegistry {
    let mut registry = BackendRegistry::new();

    // Register local filesystem with root as base
    registry.register(Arc::new(LocalBackend::new("local", "/")));

    // Future: register cloud backends based on config

    registry
}

/// Parse a path string into a VirtualPath
/// Supports:
/// - cfk://backend/path - explicit URI
/// - /absolute/path - local absolute path
/// - relative/path - local relative path
fn parse_path(path: &str) -> CfkResult<VirtualPath> {
    if let Some(vpath) = VirtualPath::parse_uri(path) {
        return Ok(vpath);
    }

    // Treat as local path
    let path_buf = if path.starts_with('/') {
        PathBuf::from(path)
    } else {
        let cwd = std::env::current_dir().map_err(|e| CfkError::Io(e))?;
        cwd.join(path)
    };

    // Canonicalize if exists, otherwise use as-is
    let canonical = path_buf
        .canonicalize()
        .unwrap_or_else(|_| path_buf.clone());

    Ok(VirtualPath::new("local", canonical.to_string_lossy()))
}

/// Format a timestamp for display
fn format_time(dt: Option<DateTime<Utc>>) -> String {
    dt.map(|t| t.format("%Y-%m-%d %H:%M").to_string())
        .unwrap_or_else(|| "-".to_string())
}

/// Format file size
fn format_size(size: Option<u64>, human: bool) -> String {
    match size {
        Some(s) if human => bytesize::ByteSize(s).to_string(),
        Some(s) => s.to_string(),
        None => "-".to_string(),
    }
}

/// Format entry kind
fn format_kind(kind: EntryKind) -> String {
    match kind {
        EntryKind::Directory => style("d").cyan().to_string(),
        EntryKind::File => "-".to_string(),
        EntryKind::Symlink => style("l").magenta().to_string(),
        EntryKind::Unknown => "?".to_string(),
    }
}

/// Format permissions
fn format_permissions(mode: Option<u32>) -> String {
    match mode {
        Some(m) => {
            let r = if m & 0o400 != 0 { 'r' } else { '-' };
            let w = if m & 0o200 != 0 { 'w' } else { '-' };
            let x = if m & 0o100 != 0 { 'x' } else { '-' };
            let gr = if m & 0o040 != 0 { 'r' } else { '-' };
            let gw = if m & 0o020 != 0 { 'w' } else { '-' };
            let gx = if m & 0o010 != 0 { 'x' } else { '-' };
            let or = if m & 0o004 != 0 { 'r' } else { '-' };
            let ow = if m & 0o002 != 0 { 'w' } else { '-' };
            let ox = if m & 0o001 != 0 { 'x' } else { '-' };
            format!("{r}{w}{x}{gr}{gw}{gx}{or}{ow}{ox}")
        }
        None => "---------".to_string(),
    }
}

#[derive(Tabled)]
struct LsEntry {
    #[tabled(rename = "Type")]
    kind: String,
    #[tabled(rename = "Permissions")]
    perms: String,
    #[tabled(rename = "Size")]
    size: String,
    #[tabled(rename = "Modified")]
    modified: String,
    #[tabled(rename = "Name")]
    name: String,
}

/// List directory contents
pub async fn ls(path: &str, long: bool, all: bool, human: bool, verbose: bool) -> CfkResult<()> {
    let registry = init_registry();
    let vpath = parse_path(path)?;

    if verbose {
        eprintln!("Listing: {}", vpath);
    }

    let backend = registry.get_or_err(&vpath.backend)?;
    let options = ListOptions {
        include_hidden: all,
        ..Default::default()
    };

    let listing = backend.list_directory(&vpath, &options).await?;

    if long {
        let entries: Vec<LsEntry> = listing
            .entries
            .iter()
            .filter(|e| all || !e.name().map(|n| n.starts_with('.')).unwrap_or(false))
            .map(|e| LsEntry {
                kind: format_kind(e.kind),
                perms: format_permissions(e.metadata.permissions.map(|p| p.mode)),
                size: format_size(e.metadata.size, human),
                modified: format_time(e.metadata.modified),
                name: e.name().unwrap_or("?").to_string(),
            })
            .collect();

        if entries.is_empty() {
            println!("(empty directory)");
        } else {
            let table = Table::new(entries).to_string();
            println!("{table}");
        }
    } else {
        let names: Vec<&str> = listing
            .entries
            .iter()
            .filter(|e| all || !e.name().map(|n| n.starts_with('.')).unwrap_or(false))
            .filter_map(|e| e.name())
            .collect();

        if names.is_empty() {
            println!("(empty directory)");
        } else {
            for name in names {
                println!("{name}");
            }
        }
    }

    Ok(())
}

/// Display file contents
pub async fn cat(path: &str, verbose: bool) -> CfkResult<()> {
    let registry = init_registry();
    let vpath = parse_path(path)?;

    if verbose {
        eprintln!("Reading: {}", vpath);
    }

    let backend = registry.get_or_err(&vpath.backend)?;
    let options = ReadOptions::default();

    let mut stream = backend.read_file(&vpath, &options).await?;
    while let Some(chunk) = stream.next().await {
        let bytes = chunk?;
        // Write raw bytes to stdout
        use std::io::Write;
        std::io::stdout().write_all(&bytes).map_err(CfkError::Io)?;
    }

    Ok(())
}

/// Copy files
pub async fn cp(source: &str, dest: &str, _recursive: bool, force: bool, verbose: bool) -> CfkResult<()> {
    let registry = init_registry();
    let src_path = parse_path(source)?;
    let dst_path = parse_path(dest)?;

    if verbose {
        eprintln!("Copying: {} -> {}", src_path, dst_path);
    }

    // Check if source and dest are on the same backend
    if src_path.backend == dst_path.backend {
        let backend = registry.get_or_err(&src_path.backend)?;
        let options = CopyOptions {
            overwrite: force,
            preserve_metadata: true,
        };
        backend.copy(&src_path, &dst_path, &options).await?;
    } else {
        // Cross-backend copy: read from source, write to dest
        let src_backend = registry.get_or_err(&src_path.backend)?;
        let dst_backend = registry.get_or_err(&dst_path.backend)?;

        let read_options = ReadOptions::default();
        let stream = src_backend.read_file(&src_path, &read_options).await?;

        let write_options = WriteOptions {
            overwrite: force,
            create_parents: true,
            ..Default::default()
        };

        // Get source metadata for size hint
        let src_meta = src_backend.get_metadata(&src_path).await?;
        dst_backend
            .write_file_stream(&dst_path, stream, src_meta.metadata.size, &write_options)
            .await?;
    }

    println!("Copied {} -> {}", source, dest);
    Ok(())
}

/// Move/rename files
pub async fn mv(source: &str, dest: &str, force: bool, verbose: bool) -> CfkResult<()> {
    let registry = init_registry();
    let src_path = parse_path(source)?;
    let dst_path = parse_path(dest)?;

    if verbose {
        eprintln!("Moving: {} -> {}", src_path, dst_path);
    }

    if src_path.backend == dst_path.backend {
        // Same backend: use rename
        let backend = registry.get_or_err(&src_path.backend)?;
        let options = MoveOptions { overwrite: force };
        backend.rename(&src_path, &dst_path, &options).await?;
    } else {
        // Cross-backend: copy then delete
        cp(source, dest, true, force, verbose).await?;
        rm(&[source.to_string()], true, true, verbose).await?;
    }

    println!("Moved {} -> {}", source, dest);
    Ok(())
}

/// Remove files or directories
pub async fn rm(paths: &[String], recursive: bool, force: bool, verbose: bool) -> CfkResult<()> {
    let registry = init_registry();

    for path in paths {
        let vpath = parse_path(path)?;

        if verbose {
            eprintln!("Removing: {}", vpath);
        }

        let backend = registry.get_or_err(&vpath.backend)?;
        let options = DeleteOptions { recursive, force };

        backend.delete(&vpath, &options).await?;
        println!("Removed {}", path);
    }

    Ok(())
}

/// Create directories
pub async fn mkdir(paths: &[String], parents: bool, verbose: bool) -> CfkResult<()> {
    let registry = init_registry();

    for path in paths {
        let vpath = parse_path(path)?;

        if verbose {
            eprintln!("Creating directory: {}", vpath);
        }

        let backend = registry.get_or_err(&vpath.backend)?;

        if parents {
            // Create with parents - create_directory already does this
            backend.create_directory(&vpath).await?;
        } else {
            // Check parent exists first
            if let Some(parent) = vpath.parent() {
                let parent_meta = backend.get_metadata(&parent).await;
                if parent_meta.is_err() {
                    return Err(CfkError::NotFound(format!(
                        "Parent directory does not exist: {}",
                        parent
                    )));
                }
            }
            backend.create_directory(&vpath).await?;
        }

        println!("Created {}", path);
    }

    Ok(())
}

/// Show file/directory information
pub async fn stat(path: &str, verbose: bool) -> CfkResult<()> {
    let registry = init_registry();
    let vpath = parse_path(path)?;

    if verbose {
        eprintln!("Getting info: {}", vpath);
    }

    let backend = registry.get_or_err(&vpath.backend)?;
    let entry = backend.get_metadata(&vpath).await?;

    println!("  Path: {}", entry.path);
    println!("  Type: {:?}", entry.kind);

    if let Some(size) = entry.metadata.size {
        println!("  Size: {} ({})", size, bytesize::ByteSize(size));
    }

    if let Some(perms) = entry.metadata.permissions {
        println!("  Mode: {:o} ({})", perms.mode, format_permissions(Some(perms.mode)));
    }

    if let Some(modified) = entry.metadata.modified {
        println!("  Modified: {}", modified);
    }

    if let Some(created) = entry.metadata.created {
        println!("  Created: {}", created);
    }

    if let Some(hash) = &entry.metadata.content_hash {
        println!("  Hash: {}", hash);
    }

    Ok(())
}

/// List registered backends
pub async fn backends(_verbose: bool) -> CfkResult<()> {
    let registry = init_registry();

    println!("Registered backends:");
    for id in registry.list() {
        if let Some(backend) = registry.get(id) {
            let available = if backend.is_available().await {
                style("available").green()
            } else {
                style("unavailable").red()
            };
            println!("  {} ({}) - {}", id, backend.display_name(), available);
        }
    }

    Ok(())
}

/// Show storage space information
pub async fn df(backend_id: &str, verbose: bool) -> CfkResult<()> {
    let registry = init_registry();

    if verbose {
        eprintln!("Getting space info for: {}", backend_id);
    }

    let backend = registry.get_or_err(backend_id)?;
    let info = backend.get_space_info().await?;

    println!("Storage: {} ({})", backend_id, backend.display_name());

    match (info.total, info.used, info.available) {
        (Some(total), Some(used), Some(avail)) => {
            let pct = (used as f64 / total as f64) * 100.0;
            println!("  Total:     {}", bytesize::ByteSize(total));
            println!("  Used:      {} ({:.1}%)", bytesize::ByteSize(used), pct);
            println!("  Available: {}", bytesize::ByteSize(avail));
        }
        _ => {
            println!("  Space information not available for this backend");
        }
    }

    Ok(())
}
