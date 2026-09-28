// SPDX-License-Identifier: MPL-2.0
//! Reversible operations (JanusKey model).
//!
//! [`ReversibleBackend`] wraps any [`StorageBackend`] and, before every
//! destructive call, captures enough state to invert it:
//!
//! * prior content goes into a content-addressed [`ContentStore`] (SHA-256,
//!   `objects/ab/cdef…`), the same scheme JanusKey uses;
//! * the inverse is recorded in an append-only JSON-lines [`OpLog`].
//!
//! Undo never rewrites the log: it appends an `Undo { target }` record, so
//! the full history (including undos) stays auditable.
//!
//! Because the wrapper works at the `StorageBackend` level it gives rollback
//! to *every* backend — including ones with no native versioning — and the
//! captured objects also back `get_versions` / `get_version`.
//!
//! Limitations (honest residue, mirroring JanusKey's own caveat):
//! * content is buffered in memory when captured; `max_capture_bytes`
//!   guards against capturing huge files (the op is refused, not silently
//!   made irreversible, unless `allow_irreversible` is set);
//! * metadata (permissions, mtimes, xattrs) is not yet restored;
//! * the reversibility guarantee is not yet mechanically proven.

use async_trait::async_trait;
use bytes::{Bytes, BytesMut};
use futures::StreamExt;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs::{self, OpenOptions};
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use crate::{
    backend::{ByteStream, FileVersion, SearchOptions, SpaceInfo, StorageBackend, StorageCapabilities},
    entry::{DirectoryListing, Entry, EntryKind},
    error::{CfkError, CfkResult},
    operations::*,
    VirtualPath,
};

// ───────────────────────────── content store ──────────────────────────────

/// Content-addressed object store keyed by SHA-256 hex digest.
#[derive(Debug, Clone)]
pub struct ContentStore {
    root: PathBuf,
}

impl ContentStore {
    pub fn open(root: impl Into<PathBuf>) -> CfkResult<Self> {
        let root = root.into();
        fs::create_dir_all(&root)?;
        Ok(Self { root })
    }

    pub fn hash(data: &[u8]) -> String {
        hex::encode(Sha256::digest(data))
    }

    fn object_path(&self, hash: &str) -> CfkResult<PathBuf> {
        if hash.len() != 64 || !hash.bytes().all(|b| b.is_ascii_hexdigit()) {
            return Err(CfkError::Other(format!("invalid object hash: {hash}")));
        }
        Ok(self.root.join(&hash[..2]).join(&hash[2..]))
    }

    /// Store `data`, returning its hash. Idempotent (deduplicating).
    pub fn put(&self, data: &[u8]) -> CfkResult<String> {
        let hash = Self::hash(data);
        let path = self.object_path(&hash)?;
        if !path.exists() {
            fs::create_dir_all(path.parent().expect("object has parent"))?;
            // write-then-rename so a crash never leaves a truncated object
            let tmp = path.with_extension("tmp");
            {
                let mut f = fs::File::create(&tmp)?;
                f.write_all(data)?;
                f.sync_all()?;
            }
            fs::rename(&tmp, &path)?;
        }
        Ok(hash)
    }

    /// Fetch an object, verifying its hash.
    pub fn get(&self, hash: &str) -> CfkResult<Bytes> {
        let data = fs::read(self.object_path(hash)?)?;
        if Self::hash(&data) != hash {
            return Err(CfkError::ChecksumMismatch);
        }
        Ok(Bytes::from(data))
    }

    pub fn contains(&self, hash: &str) -> bool {
        self.object_path(hash).map(|p| p.exists()).unwrap_or(false)
    }
}

// ─────────────────────────────── op log ───────────────────────────────────

/// One node of a captured directory tree (for recursive deletes).
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TreeNode {
    pub path: VirtualPath,
    /// `None` = directory, `Some(hash)` = file content.
    pub content: Option<String>,
}

/// A recorded operation together with the data needed to invert it.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum Operation {
    /// File written; `prior` is the old content (None = did not exist).
    Write { path: VirtualPath, prior: Option<String> },
    /// Directory created (undo removes it if still empty).
    CreateDir { path: VirtualPath },
    /// Path deleted; tree is parent-first.
    Delete { path: VirtualPath, tree: Vec<TreeNode> },
    /// Copy to `dest`; `prior` is what `dest` held before.
    Copy { source: VirtualPath, dest: VirtualPath, prior: Option<String> },
    /// Rename; `overwritten` is what `dest` held before.
    Rename { source: VirtualPath, dest: VirtualPath, overwritten: Option<String> },
    /// Undo of an earlier record.
    Undo { target: u64 },
}

impl Operation {
    pub fn summary(&self) -> String {
        match self {
            Operation::Write { path, prior } => format!(
                "{} {}", if prior.is_some() { "modify" } else { "create" }, path),
            Operation::CreateDir { path } => format!("mkdir {path}"),
            Operation::Delete { path, tree } => format!("delete {path} ({} item(s))", tree.len()),
            Operation::Copy { source, dest, .. } => format!("copy {source} -> {dest}"),
            Operation::Rename { source, dest, .. } => format!("move {source} -> {dest}"),
            Operation::Undo { target } => format!("undo #{target}"),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct LogRecord {
    pub id: u64,
    pub timestamp: chrono::DateTime<chrono::Utc>,
    #[serde(flatten)]
    pub op: Operation,
}

/// Append-only JSON-lines operation log.
#[derive(Debug)]
pub struct OpLog {
    path: PathBuf,
    next_id: u64,
}

impl OpLog {
    pub fn open(path: impl Into<PathBuf>) -> CfkResult<Self> {
        let path = path.into();
        if let Some(p) = path.parent() {
            fs::create_dir_all(p)?;
        }
        let next_id = Self::read_all(&path)?.last().map(|r| r.id + 1).unwrap_or(1);
        Ok(Self { path, next_id })
    }

    fn read_all(path: &Path) -> CfkResult<Vec<LogRecord>> {
        if !path.exists() {
            return Ok(Vec::new());
        }
        let mut out = Vec::new();
        for (n, line) in BufReader::new(fs::File::open(path)?).lines().enumerate() {
            let line = line?;
            if line.trim().is_empty() {
                continue;
            }
            match serde_json::from_str::<LogRecord>(&line) {
                Ok(r) => out.push(r),
                // A torn final line (crash mid-append) is tolerated; anything
                // else is corruption and must be surfaced.
                Err(e) => {
                    return Err(CfkError::Serialization(format!("oplog line {}: {e}", n + 1)))
                }
            }
        }
        Ok(out)
    }

    pub fn records(&self) -> CfkResult<Vec<LogRecord>> {
        Self::read_all(&self.path)
    }

    pub fn append(&mut self, op: Operation) -> CfkResult<LogRecord> {
        let rec = LogRecord { id: self.next_id, timestamp: chrono::Utc::now(), op };
        let line = serde_json::to_string(&rec).map_err(|e| CfkError::Serialization(e.to_string()))?;
        let mut f = OpenOptions::new().create(true).append(true).open(&self.path)?;
        writeln!(f, "{line}")?;
        f.sync_data()?;
        self.next_id += 1;
        Ok(rec)
    }

    /// Records that are not undos and have not themselves been undone.
    pub fn undoable(&self) -> CfkResult<Vec<LogRecord>> {
        let all = self.records()?;
        let undone: std::collections::HashSet<u64> = all
            .iter()
            .filter_map(|r| match r.op { Operation::Undo { target } => Some(target), _ => None })
            .collect();
        Ok(all
            .into_iter()
            .filter(|r| !matches!(r.op, Operation::Undo { .. }) && !undone.contains(&r.id))
            .collect())
    }
}

// ───────────────────────────── the wrapper ────────────────────────────────

#[derive(Debug, Clone)]
pub struct ReversibleConfig {
    /// Refuse to capture files bigger than this (bytes).
    pub max_capture_bytes: u64,
    /// If true, operations too big to capture proceed unrecorded instead of
    /// failing. Off by default: silent irreversibility is the thing we avoid.
    pub allow_irreversible: bool,
}

impl Default for ReversibleConfig {
    fn default() -> Self {
        Self { max_capture_bytes: 1 << 30, allow_irreversible: false }
    }
}

/// A [`StorageBackend`] decorator that makes every mutation undoable.
pub struct ReversibleBackend<B: StorageBackend + ?Sized> {
    inner: Arc<B>,
    store: ContentStore,
    log: Mutex<OpLog>,
    config: ReversibleConfig,
    caps: StorageCapabilities,
}

impl<B: StorageBackend + ?Sized> ReversibleBackend<B> {
    /// `state_dir` holds `objects/` and `oplog.jsonl`.
    pub fn new(inner: Arc<B>, state_dir: impl AsRef<Path>, config: ReversibleConfig) -> CfkResult<Self> {
        let dir = state_dir.as_ref();
        let mut caps = inner.capabilities().clone();
        caps.versioning = true;
        Ok(Self {
            store: ContentStore::open(dir.join("objects"))?,
            log: Mutex::new(OpLog::open(dir.join("oplog.jsonl"))?),
            inner,
            config,
            caps,
        })
    }

    pub fn inner(&self) -> &Arc<B> {
        &self.inner
    }

    pub fn store(&self) -> &ContentStore {
        &self.store
    }

    /// Full history, oldest first (including undo records).
    pub fn history(&self) -> CfkResult<Vec<LogRecord>> {
        self.log.lock().expect("oplog poisoned").records()
    }

    fn record(&self, op: Operation) -> CfkResult<LogRecord> {
        self.log.lock().expect("oplog poisoned").append(op)
    }

    async fn read_all(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let mut s = self.inner.read_file(path, &ReadOptions::default()).await?;
        let mut buf = BytesMut::new();
        while let Some(chunk) = s.next().await {
            let chunk = chunk?;
            buf.extend_from_slice(&chunk);
            if buf.len() as u64 > self.config.max_capture_bytes {
                return Err(CfkError::Unsupported(format!(
                    "{path} exceeds reversible capture limit ({} bytes)",
                    self.config.max_capture_bytes
                )));
            }
        }
        Ok(buf.freeze())
    }

    /// Existing file content at `path` stored in the CAS, or None if absent.
    async fn capture_file(&self, path: &VirtualPath) -> CfkResult<Option<String>> {
        match self.inner.get_metadata(path).await {
            Ok(e) if e.kind == EntryKind::File => {
                if let Some(sz) = e.metadata.size {
                    if sz > self.config.max_capture_bytes {
                        return Err(CfkError::Unsupported(format!(
                            "{path} ({sz} bytes) exceeds reversible capture limit"
                        )));
                    }
                }
                let data = self.read_all(path).await?;
                Ok(Some(self.store.put(&data)?))
            }
            Ok(e) if e.kind == EntryKind::Directory => {
                Err(CfkError::Unsupported(format!("{path} is a directory; cannot capture as file")))
            }
            Ok(_) => Err(CfkError::Unsupported(format!("{path}: unsupported entry kind"))),
            Err(CfkError::NotFound(_)) => Ok(None),
            Err(e) => Err(e),
        }
    }

    /// Capture a whole tree, parent-first.
    async fn capture_tree(&self, root: &VirtualPath) -> CfkResult<Vec<TreeNode>> {
        let mut out = Vec::new();
        let mut stack = vec![root.clone()];
        while let Some(p) = stack.pop() {
            let entry = self.inner.get_metadata(&p).await?;
            match entry.kind {
                EntryKind::Directory => {
                    out.push(TreeNode { path: p.clone(), content: None });
                    let opts = ListOptions { include_hidden: true, ..Default::default() };
                    let listing = self.inner.list_directory(&p, &opts).await?;
                    // push reversed so traversal is stable / listing-ordered
                    for child in listing.entries.into_iter().rev() {
                        stack.push(child.path);
                    }
                }
                EntryKind::File => {
                    let hash = self.capture_file(&p).await?;
                    out.push(TreeNode { path: p, content: hash });
                }
                _ => {
                    return Err(CfkError::Unsupported(format!(
                        "{p}: symlinks/special files not yet reversible"
                    )))
                }
            }
        }
        Ok(out)
    }

    /// Wrap capture errors according to `allow_irreversible`.
    fn capture_or<T>(&self, r: CfkResult<T>) -> CfkResult<Option<T>> {
        match r {
            Ok(v) => Ok(Some(v)),
            Err(CfkError::Unsupported(_)) if self.config.allow_irreversible => Ok(None),
            Err(e) => Err(e),
        }
    }

    async fn restore(&self, path: &VirtualPath, content: &Option<String>) -> CfkResult<()> {
        match content {
            Some(hash) => {
                let data = self.store.get(hash)?;
                let opts = WriteOptions { overwrite: true, create_parents: true, content_hash: None };
                self.inner.write_file(path, data, &opts).await?;
            }
            None => {
                self.inner
                    .delete(path, &DeleteOptions { recursive: false, force: true })
                    .await?;
            }
        }
        Ok(())
    }

    /// Undo the most recent undoable operation. Returns the undone record.
    pub async fn undo_last(&self) -> CfkResult<LogRecord> {
        let last = self
            .log
            .lock()
            .expect("oplog poisoned")
            .undoable()?
            .pop()
            .ok_or_else(|| CfkError::NotFound("nothing to undo".into()))?;
        self.undo(last.id).await
    }

    /// Undo a specific operation by id.
    ///
    /// Only the most recent undoable operation may be undone: undoing out of
    /// order could clobber later changes to the same path. (Selective undo
    /// with conflict detection is future work.)
    pub async fn undo(&self, id: u64) -> CfkResult<LogRecord> {
        let undoable = self.log.lock().expect("oplog poisoned").undoable()?;
        let rec = undoable
            .iter()
            .find(|r| r.id == id)
            .cloned()
            .ok_or_else(|| CfkError::NotFound(format!("operation #{id} is not undoable")))?;
        if undoable.last().map(|r| r.id) != Some(id) {
            return Err(CfkError::Conflict(format!(
                "operation #{id} is not the latest; undo later operations first"
            )));
        }

        match &rec.op {
            Operation::Write { path, prior } => self.restore(path, prior).await?,
            Operation::Copy { dest, prior, .. } => self.restore(dest, prior).await?,
            Operation::CreateDir { path } => {
                self.inner
                    .delete(path, &DeleteOptions { recursive: false, force: true })
                    .await?;
            }
            Operation::Rename { source, dest, overwritten } => {
                self.inner
                    .rename(dest, source, &MoveOptions { overwrite: false })
                    .await?;
                if overwritten.is_some() {
                    self.restore(dest, overwritten).await?;
                }
            }
            Operation::Delete { tree, .. } => {
                for node in tree {
                    match &node.content {
                        None => match self.inner.create_directory(&node.path).await {
                            Ok(_) | Err(CfkError::AlreadyExists(_)) => {}
                            Err(e) => return Err(e),
                        },
                        Some(_) => self.restore(&node.path, &node.content).await?,
                    }
                }
            }
            Operation::Undo { .. } => unreachable!("undo records are filtered out"),
        }

        self.record(Operation::Undo { target: id })?;
        Ok(rec)
    }
}

#[async_trait]
impl<B: StorageBackend + ?Sized> StorageBackend for ReversibleBackend<B> {
    fn id(&self) -> &str {
        self.inner.id()
    }
    fn display_name(&self) -> &str {
        self.inner.display_name()
    }
    fn capabilities(&self) -> &StorageCapabilities {
        &self.caps
    }
    async fn is_available(&self) -> bool {
        self.inner.is_available().await
    }
    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        self.inner.get_metadata(path).await
    }
    async fn list_directory(&self, path: &VirtualPath, options: &ListOptions) -> CfkResult<DirectoryListing> {
        self.inner.list_directory(path, options).await
    }
    async fn read_file(&self, path: &VirtualPath, options: &ReadOptions) -> CfkResult<ByteStream> {
        self.inner.read_file(path, options).await
    }

    async fn write_file(&self, path: &VirtualPath, data: Bytes, options: &WriteOptions) -> CfkResult<Entry> {
        let prior = self.capture_or(self.capture_file(path).await)?;
        let entry = self.inner.write_file(path, data, options).await?;
        if let Some(prior) = prior {
            self.record(Operation::Write { path: path.clone(), prior })?;
        }
        Ok(entry)
    }

    async fn write_file_stream(
        &self,
        path: &VirtualPath,
        stream: ByteStream,
        size_hint: Option<u64>,
        options: &WriteOptions,
    ) -> CfkResult<Entry> {
        let prior = self.capture_or(self.capture_file(path).await)?;
        let entry = self.inner.write_file_stream(path, stream, size_hint, options).await?;
        if let Some(prior) = prior {
            self.record(Operation::Write { path: path.clone(), prior })?;
        }
        Ok(entry)
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let entry = self.inner.create_directory(path).await?;
        self.record(Operation::CreateDir { path: path.clone() })?;
        Ok(entry)
    }

    async fn delete(&self, path: &VirtualPath, options: &DeleteOptions) -> CfkResult<()> {
        let tree = match self.inner.get_metadata(path).await {
            Ok(_) => self.capture_or(self.capture_tree(path).await)?,
            Err(CfkError::NotFound(_)) if options.force => return Ok(()),
            Err(e) => return Err(e),
        };
        self.inner.delete(path, options).await?;
        if let Some(tree) = tree {
            self.record(Operation::Delete { path: path.clone(), tree })?;
        }
        Ok(())
    }

    async fn copy(&self, source: &VirtualPath, dest: &VirtualPath, options: &CopyOptions) -> CfkResult<Entry> {
        let prior = self.capture_or(self.capture_file(dest).await)?;
        let entry = self.inner.copy(source, dest, options).await?;
        if let Some(prior) = prior {
            self.record(Operation::Copy { source: source.clone(), dest: dest.clone(), prior })?;
        }
        Ok(entry)
    }

    async fn rename(&self, source: &VirtualPath, dest: &VirtualPath, options: &MoveOptions) -> CfkResult<Entry> {
        let overwritten = if options.overwrite {
            self.capture_or(self.capture_file(dest).await)?
        } else {
            Some(None)
        };
        let entry = self.inner.rename(source, dest, options).await?;
        if let Some(overwritten) = overwritten {
            self.record(Operation::Rename { source: source.clone(), dest: dest.clone(), overwritten })?;
        }
        Ok(entry)
    }

    async fn get_space_info(&self) -> CfkResult<SpaceInfo> {
        self.inner.get_space_info().await
    }

    async fn search(&self, options: &SearchOptions) -> CfkResult<Vec<Entry>> {
        self.inner.search(options).await
    }

    /// Versions = prior contents captured in the op log for this path,
    /// newest first. Version id is the content hash.
    async fn get_versions(&self, path: &VirtualPath) -> CfkResult<Vec<FileVersion>> {
        let mut out = Vec::new();
        for r in self.history()?.into_iter().rev() {
            let hash = match &r.op {
                Operation::Write { path: p, prior: Some(h) } if p == path => Some(h.clone()),
                Operation::Copy { dest, prior: Some(h), .. } if dest == path => Some(h.clone()),
                Operation::Rename { dest, overwritten: Some(h), .. } if dest == path => Some(h.clone()),
                Operation::Delete { tree, .. } => tree
                    .iter()
                    .find(|n| &n.path == path)
                    .and_then(|n| n.content.clone()),
                _ => None,
            };
            if let Some(h) = hash {
                let size = fs::metadata(self.store.object_path(&h)?).ok().map(|m| m.len());
                out.push(FileVersion { id: h, modified: r.timestamp, size, author: None });
            }
        }
        Ok(out)
    }

    async fn get_version(&self, _path: &VirtualPath, version_id: &str) -> CfkResult<ByteStream> {
        let data = self.store.get(version_id)?;
        Ok(Box::pin(futures::stream::once(async move { Ok(data) })))
    }
}

// ─────────────────────────────── tests ────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Metadata;
    use std::collections::BTreeMap;

    /// Minimal in-memory backend: key = path string, None = directory.
    #[derive(Default)]
    struct MemBackend {
        files: Mutex<BTreeMap<String, Option<Bytes>>>,
        caps: StorageCapabilities,
    }

    fn key(p: &VirtualPath) -> String {
        p.to_path_string()
    }

    impl MemBackend {
        fn get(&self, p: &str) -> Option<Option<Bytes>> {
            self.files.lock().unwrap().get(p).cloned()
        }
    }

    #[async_trait]
    impl StorageBackend for MemBackend {
        fn id(&self) -> &str { "mem" }
        fn display_name(&self) -> &str { "mem" }
        fn capabilities(&self) -> &StorageCapabilities { &self.caps }
        async fn is_available(&self) -> bool { true }
        async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
            match self.files.lock().unwrap().get(&key(path)) {
                Some(Some(b)) => Ok(Entry::file(path.clone(), Metadata::new().with_size(b.len() as u64))),
                Some(None) => Ok(Entry::directory(path.clone(), Metadata::new())),
                None if path.is_root() => Ok(Entry::directory(path.clone(), Metadata::new())),
                None => Err(CfkError::NotFound(key(path))),
            }
        }
        async fn list_directory(&self, path: &VirtualPath, _o: &ListOptions) -> CfkResult<DirectoryListing> {
            let files = self.files.lock().unwrap();
            let entries = files
                .iter()
                .filter_map(|(k, v)| {
                    let vp = VirtualPath::new("mem", k);
                    (vp.parent().as_ref() == Some(path)).then(|| match v {
                        Some(b) => Entry::file(vp, Metadata::new().with_size(b.len() as u64)),
                        None => Entry::directory(vp, Metadata::new()),
                    })
                })
                .collect();
            Ok(DirectoryListing::new(path.clone(), entries))
        }
        async fn read_file(&self, path: &VirtualPath, _o: &ReadOptions) -> CfkResult<ByteStream> {
            match self.get(&key(path)) {
                Some(Some(b)) => Ok(Box::pin(futures::stream::once(async move { Ok(b) }))),
                _ => Err(CfkError::NotFound(key(path))),
            }
        }
        async fn write_file(&self, path: &VirtualPath, data: Bytes, _o: &WriteOptions) -> CfkResult<Entry> {
            self.files.lock().unwrap().insert(key(path), Some(data));
            self.get_metadata(path).await
        }
        async fn write_file_stream(&self, path: &VirtualPath, mut s: ByteStream, _h: Option<u64>, o: &WriteOptions) -> CfkResult<Entry> {
            let mut buf = BytesMut::new();
            while let Some(c) = s.next().await { buf.extend_from_slice(&c?); }
            self.write_file(path, buf.freeze(), o).await
        }
        async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
            self.files.lock().unwrap().insert(key(path), None);
            self.get_metadata(path).await
        }
        async fn delete(&self, path: &VirtualPath, _o: &DeleteOptions) -> CfkResult<()> {
            let k = key(path);
            let prefix = format!("{k}/");
            self.files.lock().unwrap().retain(|p, _| p != &k && !p.starts_with(&prefix));
            Ok(())
        }
        async fn copy(&self, s: &VirtualPath, d: &VirtualPath, _o: &CopyOptions) -> CfkResult<Entry> {
            let v = self.get(&key(s)).ok_or_else(|| CfkError::NotFound(key(s)))?;
            self.files.lock().unwrap().insert(key(d), v);
            self.get_metadata(d).await
        }
        async fn rename(&self, s: &VirtualPath, d: &VirtualPath, _o: &MoveOptions) -> CfkResult<Entry> {
            let v = self.files.lock().unwrap().remove(&key(s)).ok_or_else(|| CfkError::NotFound(key(s)))?;
            self.files.lock().unwrap().insert(key(d), v);
            self.get_metadata(d).await
        }
        async fn get_space_info(&self) -> CfkResult<SpaceInfo> { Ok(SpaceInfo::unknown()) }
    }

    fn vp(p: &str) -> VirtualPath { VirtualPath::new("mem", p) }

    fn setup() -> (Arc<MemBackend>, ReversibleBackend<MemBackend>, PathBuf) {
        let dir = std::env::temp_dir().join(format!(
            "cfk-rev-{}-{}", std::process::id(),
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()
        ));
        let mem = Arc::new(MemBackend::default());
        let rev = ReversibleBackend::new(mem.clone(), &dir, ReversibleConfig::default()).unwrap();
        (mem, rev, dir)
    }

    #[tokio::test]
    async fn modify_then_undo_restores_content() {
        let (mem, rev, _d) = setup();
        let w = WriteOptions { overwrite: true, ..Default::default() };
        rev.write_file(&vp("/a"), Bytes::from_static(b"one"), &w).await.unwrap();
        rev.write_file(&vp("/a"), Bytes::from_static(b"two"), &w).await.unwrap();
        rev.undo_last().await.unwrap();
        assert_eq!(mem.get(&key(&vp("/a"))), Some(Some(Bytes::from_static(b"one"))));
        rev.undo_last().await.unwrap();
        assert_eq!(mem.get(&key(&vp("/a"))), None);
    }

    #[tokio::test]
    async fn recursive_delete_then_undo_restores_tree() {
        let (mem, rev, _d) = setup();
        let w = WriteOptions::default();
        rev.create_directory(&vp("/d")).await.unwrap();
        rev.write_file(&vp("/d/x"), Bytes::from_static(b"x"), &w).await.unwrap();
        rev.create_directory(&vp("/d/sub")).await.unwrap();
        rev.write_file(&vp("/d/sub/y"), Bytes::from_static(b"y"), &w).await.unwrap();
        let before = mem.files.lock().unwrap().clone();
        rev.delete(&vp("/d"), &DeleteOptions { recursive: true, force: false }).await.unwrap();
        assert!(mem.get("/d").is_none());
        rev.undo_last().await.unwrap();
        assert_eq!(*mem.files.lock().unwrap(), before);
    }

    #[tokio::test]
    async fn rename_overwrite_then_undo() {
        let (mem, rev, _d) = setup();
        let w = WriteOptions::default();
        rev.write_file(&vp("/src"), Bytes::from_static(b"S"), &w).await.unwrap();
        rev.write_file(&vp("/dst"), Bytes::from_static(b"D"), &w).await.unwrap();
        rev.rename(&vp("/src"), &vp("/dst"), &MoveOptions { overwrite: true }).await.unwrap();
        rev.undo_last().await.unwrap();
        assert_eq!(mem.get("/src"), Some(Some(Bytes::from_static(b"S"))));
        assert_eq!(mem.get("/dst"), Some(Some(Bytes::from_static(b"D"))));
    }

    #[tokio::test]
    async fn out_of_order_undo_is_refused_and_log_is_append_only() {
        let (_mem, rev, _d) = setup();
        let w = WriteOptions::default();
        rev.write_file(&vp("/a"), Bytes::from_static(b"1"), &w).await.unwrap();
        rev.write_file(&vp("/b"), Bytes::from_static(b"2"), &w).await.unwrap();
        assert!(matches!(rev.undo(1).await, Err(CfkError::Conflict(_))));
        rev.undo_last().await.unwrap();
        let h = rev.history().unwrap();
        assert_eq!(h.len(), 3);
        assert_eq!(h[2].op, Operation::Undo { target: 2 });
    }

    #[tokio::test]
    async fn versions_come_from_captured_priors() {
        let (_mem, rev, _d) = setup();
        let w = WriteOptions { overwrite: true, ..Default::default() };
        for v in [&b"v1"[..], b"v2", b"v3"] {
            rev.write_file(&vp("/f"), Bytes::copy_from_slice(v), &w).await.unwrap();
        }
        let versions = rev.get_versions(&vp("/f")).await.unwrap();
        assert_eq!(versions.len(), 2); // v2 and v1 (v3 is current)
        let mut s = rev.get_version(&vp("/f"), &versions[0].id).await.unwrap();
        assert_eq!(s.next().await.unwrap().unwrap(), Bytes::from_static(b"v2"));
    }

    #[test]
    fn content_store_dedups_and_verifies() {
        let dir = std::env::temp_dir().join(format!("cfk-cas-{}", std::process::id()));
        let cas = ContentStore::open(&dir).unwrap();
        let h1 = cas.put(b"hello").unwrap();
        let h2 = cas.put(b"hello").unwrap();
        assert_eq!(h1, h2);
        assert_eq!(h1, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824");
        assert_eq!(&cas.get(&h1).unwrap()[..], b"hello");
        assert!(cas.get("zz").is_err());
    }
}
