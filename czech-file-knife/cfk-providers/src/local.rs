//! Local filesystem backend

use async_trait::async_trait;
use bytes::Bytes;
use cfk_core::{
    backend::{ByteStream, SpaceInfo, StorageBackend, StorageCapabilities},
    entry::{DirectoryListing, Entry, EntryKind},
    error::{CfkError, CfkResult},
    metadata::{Metadata, Permissions},
    operations::*,
    VirtualPath,
};
use std::path::{Path, PathBuf};
use tokio::fs;
use tokio::io::AsyncReadExt;

/// Local filesystem backend
pub struct LocalBackend {
    id: String,
    root: PathBuf,
    capabilities: StorageCapabilities,
}

impl LocalBackend {
    pub fn new(id: impl Into<String>, root: impl AsRef<Path>) -> Self {
        Self {
            id: id.into(),
            root: root.as_ref().to_path_buf(),
            capabilities: StorageCapabilities::local_filesystem(),
        }
    }

    fn to_real_path(&self, path: &VirtualPath) -> PathBuf {
        let mut real = self.root.clone();
        for seg in &path.segments {
            real.push(seg);
        }
        real
    }

    fn to_virtual_path(&self, real: &Path) -> CfkResult<VirtualPath> {
        let relative = real
            .strip_prefix(&self.root)
            .map_err(|_| CfkError::InvalidPath(real.display().to_string()))?;
        Ok(VirtualPath::new(&self.id, relative.to_string_lossy()))
    }

    async fn metadata_from_path(&self, path: &Path) -> CfkResult<(EntryKind, Metadata)> {
        let meta = fs::metadata(path).await?;
        let kind = if meta.is_dir() {
            EntryKind::Directory
        } else if meta.is_file() {
            EntryKind::File
        } else if meta.is_symlink() {
            EntryKind::Symlink
        } else {
            EntryKind::Unknown
        };

        let mut metadata = Metadata::new();
        metadata.size = Some(meta.len());

        #[cfg(unix)]
        {
            use std::os::unix::fs::MetadataExt;
            metadata.permissions = Some(Permissions::new(meta.mode()));
        }

        if let Ok(modified) = meta.modified() {
            metadata.modified = Some(modified.into());
        }
        if let Ok(created) = meta.created() {
            metadata.created = Some(created.into());
        }

        Ok((kind, metadata))
    }
}

#[async_trait]
impl StorageBackend for LocalBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        "Local Filesystem"
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        self.root.exists()
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let real = self.to_real_path(path);
        if !real.exists() {
            return Err(CfkError::NotFound(path.to_string()));
        }
        let (kind, metadata) = self.metadata_from_path(&real).await?;
        Ok(Entry { path: path.clone(), kind, metadata })
    }

    async fn list_directory(&self, path: &VirtualPath, _options: &ListOptions) -> CfkResult<DirectoryListing> {
        let real = self.to_real_path(path);
        if !real.is_dir() {
            return Err(CfkError::NotADirectory(path.to_string()));
        }

        let mut entries = Vec::new();
        let mut read_dir = fs::read_dir(&real).await?;

        while let Some(entry) = read_dir.next_entry().await? {
            let entry_path = entry.path();
            let vpath = self.to_virtual_path(&entry_path)?;
            let (kind, metadata) = self.metadata_from_path(&entry_path).await?;
            entries.push(Entry { path: vpath, kind, metadata });
        }

        Ok(DirectoryListing::new(path.clone(), entries))
    }

    async fn read_file(&self, path: &VirtualPath, options: &ReadOptions) -> CfkResult<ByteStream> {
        let real = self.to_real_path(path);
        if !real.is_file() {
            return Err(CfkError::NotAFile(path.to_string()));
        }

        let mut file = fs::File::open(&real).await?;
        let mut buffer = Vec::new();

        if let Some((start, end)) = options.range {
            use tokio::io::AsyncSeekExt;
            file.seek(std::io::SeekFrom::Start(start)).await?;
            let len = (end - start) as usize;
            buffer.resize(len, 0);
            file.read_exact(&mut buffer).await?;
        } else {
            file.read_to_end(&mut buffer).await?;
        }

        let bytes = Bytes::from(buffer);
        Ok(Box::pin(futures::stream::once(async { Ok(bytes) })))
    }

    async fn write_file(&self, path: &VirtualPath, data: Bytes, options: &WriteOptions) -> CfkResult<Entry> {
        let real = self.to_real_path(path);

        if real.exists() && !options.overwrite {
            return Err(CfkError::AlreadyExists(path.to_string()));
        }

        if options.create_parents {
            if let Some(parent) = real.parent() {
                fs::create_dir_all(parent).await?;
            }
        }

        fs::write(&real, &data).await?;
        self.get_metadata(path).await
    }

    async fn write_file_stream(&self, path: &VirtualPath, mut stream: ByteStream, _size_hint: Option<u64>, options: &WriteOptions) -> CfkResult<Entry> {
        use futures::StreamExt;

        let mut data = Vec::new();
        while let Some(chunk) = stream.next().await {
            data.extend_from_slice(&chunk?);
        }
        self.write_file(path, Bytes::from(data), options).await
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let real = self.to_real_path(path);
        fs::create_dir_all(&real).await?;
        self.get_metadata(path).await
    }

    async fn delete(&self, path: &VirtualPath, options: &DeleteOptions) -> CfkResult<()> {
        let real = self.to_real_path(path);

        if !real.exists() {
            if options.force {
                return Ok(());
            }
            return Err(CfkError::NotFound(path.to_string()));
        }

        if real.is_dir() {
            if options.recursive {
                fs::remove_dir_all(&real).await?;
            } else {
                fs::remove_dir(&real).await?;
            }
        } else {
            fs::remove_file(&real).await?;
        }
        Ok(())
    }

    async fn copy(&self, source: &VirtualPath, dest: &VirtualPath, options: &CopyOptions) -> CfkResult<Entry> {
        let src_real = self.to_real_path(source);
        let dst_real = self.to_real_path(dest);

        if !src_real.exists() {
            return Err(CfkError::NotFound(source.to_string()));
        }
        if dst_real.exists() && !options.overwrite {
            return Err(CfkError::AlreadyExists(dest.to_string()));
        }

        fs::copy(&src_real, &dst_real).await?;
        self.get_metadata(dest).await
    }

    async fn rename(&self, source: &VirtualPath, dest: &VirtualPath, options: &MoveOptions) -> CfkResult<Entry> {
        let src_real = self.to_real_path(source);
        let dst_real = self.to_real_path(dest);

        if !src_real.exists() {
            return Err(CfkError::NotFound(source.to_string()));
        }
        if dst_real.exists() && !options.overwrite {
            return Err(CfkError::AlreadyExists(dest.to_string()));
        }

        fs::rename(&src_real, &dst_real).await?;
        self.get_metadata(dest).await
    }

    async fn get_space_info(&self) -> CfkResult<SpaceInfo> {
        #[cfg(unix)]
        {
            use std::ffi::CString;
            use std::mem::MaybeUninit;

            let path_cstr = CString::new(self.root.to_string_lossy().as_bytes())
                .map_err(|_| CfkError::InvalidPath(self.root.display().to_string()))?;

            let mut stat: MaybeUninit<libc::statvfs> = MaybeUninit::uninit();
            let result = unsafe { libc::statvfs(path_cstr.as_ptr(), stat.as_mut_ptr()) };

            if result == 0 {
                let stat = unsafe { stat.assume_init() };
                let block_size = stat.f_frsize as u64;
                let total = stat.f_blocks as u64 * block_size;
                let available = stat.f_bavail as u64 * block_size;
                let free = stat.f_bfree as u64 * block_size;
                let used = total - free;

                Ok(SpaceInfo {
                    total: Some(total),
                    used: Some(used),
                    available: Some(available),
                })
            } else {
                Ok(SpaceInfo::unknown())
            }
        }

        #[cfg(not(unix))]
        {
            Ok(SpaceInfo::unknown())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use futures::StreamExt;
    use tempfile::TempDir;

    fn make_backend(dir: &TempDir) -> LocalBackend {
        LocalBackend::new("test", dir.path())
    }

    fn make_path(backend: &LocalBackend, p: &str) -> VirtualPath {
        VirtualPath::new(backend.id(), p)
    }

    #[tokio::test]
    async fn test_backend_properties() {
        let tmp = TempDir::new().unwrap();
        let backend = make_backend(&tmp);

        assert_eq!(backend.id(), "test");
        assert_eq!(backend.display_name(), "Local Filesystem");
        assert!(backend.is_available().await);
        assert!(backend.capabilities().read);
        assert!(backend.capabilities().write);
    }

    #[tokio::test]
    async fn test_create_and_read_file() {
        let tmp = TempDir::new().unwrap();
        let backend = make_backend(&tmp);
        let path = make_path(&backend, "/test.txt");

        // Write file
        let data = Bytes::from("Hello, World!");
        let options = WriteOptions { overwrite: true, ..Default::default() };
        let entry = backend.write_file(&path, data.clone(), &options).await.unwrap();

        assert!(entry.is_file());
        assert_eq!(entry.name(), Some("test.txt"));

        // Read file
        let read_opts = ReadOptions::default();
        let mut stream = backend.read_file(&path, &read_opts).await.unwrap();
        let mut content = Vec::new();
        while let Some(chunk) = stream.next().await {
            content.extend_from_slice(&chunk.unwrap());
        }
        assert_eq!(content, b"Hello, World!");
    }

    #[tokio::test]
    async fn test_write_without_overwrite_fails() {
        let tmp = TempDir::new().unwrap();
        let backend = make_backend(&tmp);
        let path = make_path(&backend, "/test.txt");

        // First write succeeds
        let options = WriteOptions { overwrite: false, ..Default::default() };
        backend.write_file(&path, Bytes::from("first"), &options).await.unwrap();

        // Second write should fail
        let result = backend.write_file(&path, Bytes::from("second"), &options).await;
        assert!(matches!(result, Err(CfkError::AlreadyExists(_))));
    }

    #[tokio::test]
    async fn test_create_directory() {
        let tmp = TempDir::new().unwrap();
        let backend = make_backend(&tmp);
        let path = make_path(&backend, "/subdir/nested");

        let entry = backend.create_directory(&path).await.unwrap();
        assert!(entry.is_directory());
    }

    #[tokio::test]
    async fn test_list_directory() {
        let tmp = TempDir::new().unwrap();
        let backend = make_backend(&tmp);

        // Create some files and dirs
        backend.write_file(
            &make_path(&backend, "/file1.txt"),
            Bytes::from("content1"),
            &WriteOptions { overwrite: true, ..Default::default() },
        ).await.unwrap();

        backend.write_file(
            &make_path(&backend, "/file2.txt"),
            Bytes::from("content2"),
            &WriteOptions { overwrite: true, ..Default::default() },
        ).await.unwrap();

        backend.create_directory(&make_path(&backend, "/subdir")).await.unwrap();

        // List root
        let listing = backend
            .list_directory(&VirtualPath::root("test"), &ListOptions::default())
            .await
            .unwrap();

        assert_eq!(listing.entries.len(), 3);
        let names: Vec<_> = listing.entries.iter().filter_map(|e| e.name()).collect();
        assert!(names.contains(&"file1.txt"));
        assert!(names.contains(&"file2.txt"));
        assert!(names.contains(&"subdir"));
    }

    #[tokio::test]
    async fn test_delete_file() {
        let tmp = TempDir::new().unwrap();
        let backend = make_backend(&tmp);
        let path = make_path(&backend, "/to_delete.txt");

        backend.write_file(&path, Bytes::from("delete me"), &WriteOptions::default()).await.unwrap();

        // Delete
        backend.delete(&path, &DeleteOptions::default()).await.unwrap();

        // Should not exist now
        let result = backend.get_metadata(&path).await;
        assert!(matches!(result, Err(CfkError::NotFound(_))));
    }

    #[tokio::test]
    async fn test_delete_nonexistent_with_force() {
        let tmp = TempDir::new().unwrap();
        let backend = make_backend(&tmp);
        let path = make_path(&backend, "/nonexistent.txt");

        // Without force - should fail
        let result = backend.delete(&path, &DeleteOptions::default()).await;
        assert!(matches!(result, Err(CfkError::NotFound(_))));

        // With force - should succeed
        let options = DeleteOptions { force: true, ..Default::default() };
        backend.delete(&path, &options).await.unwrap();
    }

    #[tokio::test]
    async fn test_copy_file() {
        let tmp = TempDir::new().unwrap();
        let backend = make_backend(&tmp);
        let src = make_path(&backend, "/original.txt");
        let dst = make_path(&backend, "/copied.txt");

        backend.write_file(&src, Bytes::from("original content"), &WriteOptions::default()).await.unwrap();

        // Copy
        let entry = backend.copy(&src, &dst, &CopyOptions::default()).await.unwrap();
        assert!(entry.is_file());
        assert_eq!(entry.name(), Some("copied.txt"));

        // Verify content
        let mut stream = backend.read_file(&dst, &ReadOptions::default()).await.unwrap();
        let mut content = Vec::new();
        while let Some(chunk) = stream.next().await {
            content.extend_from_slice(&chunk.unwrap());
        }
        assert_eq!(content, b"original content");
    }

    #[tokio::test]
    async fn test_rename_file() {
        let tmp = TempDir::new().unwrap();
        let backend = make_backend(&tmp);
        let src = make_path(&backend, "/old_name.txt");
        let dst = make_path(&backend, "/new_name.txt");

        backend.write_file(&src, Bytes::from("content"), &WriteOptions::default()).await.unwrap();

        // Rename
        let entry = backend.rename(&src, &dst, &MoveOptions::default()).await.unwrap();
        assert!(entry.is_file());
        assert_eq!(entry.name(), Some("new_name.txt"));

        // Old path should not exist
        let result = backend.get_metadata(&src).await;
        assert!(matches!(result, Err(CfkError::NotFound(_))));
    }

    #[tokio::test]
    async fn test_read_file_range() {
        let tmp = TempDir::new().unwrap();
        let backend = make_backend(&tmp);
        let path = make_path(&backend, "/ranged.txt");

        backend.write_file(&path, Bytes::from("0123456789"), &WriteOptions::default()).await.unwrap();

        // Read range 3-7 (bytes 3, 4, 5, 6)
        let options = ReadOptions { range: Some((3, 7)), ..Default::default() };
        let mut stream = backend.read_file(&path, &options).await.unwrap();
        let mut content = Vec::new();
        while let Some(chunk) = stream.next().await {
            content.extend_from_slice(&chunk.unwrap());
        }
        assert_eq!(content, b"3456");
    }

    #[tokio::test]
    async fn test_get_metadata() {
        let tmp = TempDir::new().unwrap();
        let backend = make_backend(&tmp);
        let path = make_path(&backend, "/meta_test.txt");

        let content = "Test content for metadata";
        backend.write_file(&path, Bytes::from(content), &WriteOptions::default()).await.unwrap();

        let entry = backend.get_metadata(&path).await.unwrap();
        assert!(entry.is_file());
        assert_eq!(entry.size(), Some(content.len() as u64));
        assert!(entry.metadata.modified.is_some());
    }
}
