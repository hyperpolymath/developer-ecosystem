# Distributed Filesystems Support

Czech File Knife (CFK) provides unified access to various distributed and network filesystems through its provider abstraction layer.

## Supported Filesystems

### Network File Systems

#### NFS (Network File System)
- **Module**: `cfk-providers/src/nfs.rs`
- **Feature**: `nfs`
- **Versions**: NFSv3, NFSv4, NFSv4.1
- **Status**: Stub (uses system mount)

```rust
use cfk_providers::nfs::{NfsBackend, NfsConfig, NfsVersion};

let config = NfsConfig {
    server: "nas.local".into(),
    export_path: "/exports/data".into(),
    version: NfsVersion::V4,
    ..Default::default()
};

let backend = NfsBackend::new("my-nfs", config);
```

#### SMB/CIFS (Server Message Block)
- **Module**: `cfk-providers/src/smb.rs`
- **Feature**: `smb`
- **Versions**: SMB2, SMB3, SMB3.1.1
- **Status**: Stub (uses system mount or libsmbclient)

```rust
use cfk_providers::smb::{SmbBackend, SmbConfig, SmbVersion};

let config = SmbConfig {
    server: "fileserver".into(),
    share: "Documents".into(),
    username: Some("user".into()),
    password: Some("pass".into()),
    version: SmbVersion::Smb3,
    ..Default::default()
};

let backend = SmbBackend::new("my-smb", config);
```

#### SFTP (SSH File Transfer Protocol)
- **Module**: `cfk-providers/src/sftp.rs`
- **Feature**: `sftp`
- **Status**: Stub (requires ssh2 or russh crate)

```rust
use cfk_providers::sftp::{SftpBackend, SftpConfig, SftpAuth};

let config = SftpConfig {
    host: "server.example.com".into(),
    port: 22,
    auth: SftpAuth::Agent { username: "user".into() },
    ..Default::default()
};

let backend = SftpBackend::new("my-sftp", config);
```

### Plan 9 Protocol

#### 9P (Plan 9 File Protocol)
- **Module**: `cfk-providers/src/ninep.rs`
- **Feature**: `ninep`
- **Versions**: 9P2000, 9P2000.L, 9P2000.u
- **Use Cases**: WSL2 file sharing, QEMU virtio-9p, Plan 9 systems

```rust
use cfk_providers::ninep::{NinePBackend, NinePConfig, NinePVersion};

// WSL2 connection
let backend = NinePBackend::wsl2("my-9p", "/mnt/c");

// QEMU virtio-9p
let config = NinePConfig {
    transport: "virtio".into(),
    aname: "shared".into(),
    version: NinePVersion::L,
    ..Default::default()
};
let backend = NinePBackend::new("qemu-9p", config);
```

### Distributed Storage Systems

#### Ceph
- **Module**: `cfk-providers/src/ceph.rs`
- **Feature**: `ceph`
- **Interfaces**: RADOS, CephFS, RGW (S3-compatible)

```rust
use cfk_providers::ceph::{CephBackend, CephConfig, CephMode};

// CephFS (POSIX-like)
let config = CephConfig {
    monitors: vec!["mon1:6789".into(), "mon2:6789".into()],
    mode: CephMode::Fs {
        fs_name: "cephfs".into(),
        mount_point: "/mnt/ceph".into(),
    },
    user: "admin".into(),
    keyring_path: Some("/etc/ceph/ceph.client.admin.keyring".into()),
    ..Default::default()
};

let backend = CephBackend::new("my-ceph", config);

// RGW (S3-compatible)
let rgw_backend = CephBackend::rgw(
    "my-rgw",
    "https://rgw.example.com",
    "access_key",
    "secret_key",
    "my-bucket"
);
```

#### IPFS (InterPlanetary File System)
- **Module**: `cfk-providers/src/ipfs.rs`
- **Feature**: `ipfs`
- **Features**: Content-addressing, MFS, Pinning, IPNS

```rust
use cfk_providers::ipfs::{IpfsBackend, IpfsConfig};

let config = IpfsConfig {
    api_url: "http://localhost:5001".into(),
    gateway_url: Some("http://localhost:8080".into()),
    use_mfs: true,  // Mutable File System
    mfs_root: "/cfk".into(),
    ..Default::default()
};

let backend = IpfsBackend::new("my-ipfs", config);
```

#### AFS (Andrew File System)
- **Module**: `cfk-providers/src/afs.rs`
- **Feature**: `afs`
- **Features**: Kerberos auth, ACLs, distributed cells

```rust
use cfk_providers::afs::{AfsBackend, AfsConfig};

let config = AfsConfig {
    cell: "example.edu".into(),
    realm: Some("EXAMPLE.EDU".into()),
    cache_dir: Some("/var/cache/openafs".into()),
    afs_mount: "/afs".into(),
    ..Default::default()
};

let backend = AfsBackend::new("my-afs", config);
```

### Cloud Storage

#### S3-Compatible
- **Module**: `cfk-providers/src/s3.rs`
- **Feature**: `s3`
- **Providers**: AWS, MinIO, Cloudflare R2, Backblaze B2, DigitalOcean Spaces, Wasabi

```rust
use cfk_providers::s3::{S3Backend, S3Config};

// AWS S3
let backend = S3Backend::aws(
    "my-s3",
    "my-bucket",
    "us-west-2",
    "AKIAIOSFODNN7EXAMPLE",
    "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
);

// MinIO
let backend = S3Backend::minio(
    "my-minio",
    "http://localhost:9000",
    "my-bucket",
    "minioadmin",
    "minioadmin"
);

// Cloudflare R2
let backend = S3Backend::cloudflare_r2(
    "my-r2",
    "account-id",
    "my-bucket",
    "access_key",
    "secret_key"
);
```

#### WebDAV
- **Module**: `cfk-providers/src/webdav.rs`
- **Feature**: `webdav`
- **Servers**: NextCloud, ownCloud, Apache mod_dav, nginx

```rust
use cfk_providers::webdav::{WebDavBackend, WebDavConfig, WebDavAuth};

// Generic WebDAV
let config = WebDavConfig {
    base_url: "https://dav.example.com/files/".into(),
    auth: Some(WebDavAuth::Basic {
        username: "user".into(),
        password: "pass".into(),
    }),
    ..Default::default()
};

let backend = WebDavBackend::new("my-webdav", config);

// NextCloud
let backend = WebDavBackend::nextcloud(
    "my-nextcloud",
    "https://cloud.example.com",
    "username",
    "app-password"
);
```

## Feature Comparison

| Feature | NFS | SMB | SFTP | 9P | Ceph | IPFS | AFS | S3 | WebDAV |
|---------|-----|-----|------|-----|------|------|-----|-----|--------|
| Read | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Write | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Delete | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Rename | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ✗¹ | ✓ |
| Copy | ✓ | ✓ | ✗ | ✓ | ✓ | ✗ | ✓ | ✓² | ✓ |
| List | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Streaming | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Resume | ✗ | ✗ | ✓ | ✗ | ✗ | ✓ | ✗ | ✓ | ✓ |
| Versioning | ✗ | ✓³ | ✗ | ✗ | ✗ | ✓⁴ | ✗ | ✓ | ✓ |
| Watch | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| ACLs | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ | ✓ | ✓ | ✗ |

¹ S3 rename is copy+delete
² S3 copy is server-side for same bucket
³ SMB Previous Versions
⁴ IPFS content is immutable; IPNS provides mutability

## Performance Considerations

### Latency

| Protocol | Typical Latency | Best For |
|----------|-----------------|----------|
| NFS v4 | 1-10ms (LAN) | Enterprise storage |
| SMB 3 | 1-10ms (LAN) | Windows environments |
| SFTP | 10-100ms | Secure remote access |
| 9P | <1ms (virtio) | VM/container sharing |
| Ceph | 1-5ms | Scalable storage |
| IPFS | Variable | Content distribution |
| S3 | 50-200ms | Object storage |
| WebDAV | 50-500ms | Web-based access |

### Caching Strategy

CFK automatically uses the caching layer (`cfk-cache`) to optimize performance:

1. **Metadata Cache**: TTL-based caching of file/directory metadata
2. **Content Cache**: Content-addressed blob storage with LZ4 compression
3. **Eviction Policies**: LRU, LFU, FIFO, or adaptive policies

```rust
use cfk_cache::{CachePolicy, PolicyConfig, EvictionPolicy};

let policy = CachePolicy::new(PolicyConfig {
    max_size: 10 * 1024 * 1024 * 1024,  // 10 GB
    max_entries: 100_000,
    eviction_policy: EvictionPolicy::Adaptive,
    ..Default::default()
});
```

## Security

### Authentication Methods

| Protocol | Methods |
|----------|---------|
| NFS | Kerberos (sec=krb5), AUTH_SYS |
| SMB | NTLM, Kerberos, Guest |
| SFTP | Password, Public Key, Agent |
| 9P | None (transport security), Custom |
| Ceph | Cephx, None |
| IPFS | None (public), Key-based |
| AFS | Kerberos |
| S3 | AWS Sig V4, IAM |
| WebDAV | Basic, Digest, OAuth |

### Encryption

| Protocol | In-Transit | At-Rest |
|----------|------------|---------|
| NFS v4 | Optional (krb5p) | No |
| SMB 3 | Yes (AES-128-GCM) | No |
| SFTP | Yes (SSH) | No |
| 9P | No (use TLS wrapper) | No |
| Ceph | Optional | Optional |
| IPFS | Optional | No |
| AFS | Yes | No |
| S3 | Yes (HTTPS) | Optional (SSE) |
| WebDAV | Yes (HTTPS) | No |

## Enabling Features

Add the desired features to your `Cargo.toml`:

```toml
[dependencies]
cfk-providers = { path = "../cfk-providers", features = [
    "nfs",
    "smb",
    "sftp",
    "ninep",
    "ceph",
    "ipfs",
    "afs",
    "s3",
    "webdav",
] }
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Application Layer                             │
│                    (cfk-cli, cfk-vfs, cfk-tui)                       │
├─────────────────────────────────────────────────────────────────────┤
│                     StorageBackend Trait                             │
│      (unified interface for all filesystem operations)               │
├───────┬───────┬───────┬───────┬───────┬───────┬───────┬────────────┤
│  NFS  │  SMB  │ SFTP  │  9P   │ Ceph  │ IPFS  │  AFS  │ S3/WebDAV  │
├───────┴───────┴───────┴───────┴───────┴───────┴───────┴────────────┤
│                        Cache Layer (cfk-cache)                       │
│              (metadata cache, blob store, eviction)                  │
└─────────────────────────────────────────────────────────────────────┘
```
