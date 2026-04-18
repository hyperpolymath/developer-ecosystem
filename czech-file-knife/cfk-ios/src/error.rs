// SPDX-License-Identifier: AGPL-3.0-or-later
//! iOS-specific error types

use cfk_core::CfkError as CoreError;
use std::ffi::CString;
use thiserror::Error;

/// iOS-specific errors
#[derive(Debug, Error)]
pub enum IosError {
    #[error("Core error: {0}")]
    Core(#[from] CoreError),

    #[error("Invalid identifier: {0}")]
    InvalidIdentifier(String),

    #[error("Item not found: {0}")]
    NotFound(String),

    #[error("Operation not supported: {0}")]
    NotSupported(String),

    #[error("Authentication required")]
    AuthRequired,

    #[error("Network unavailable")]
    NetworkUnavailable,

    #[error("Quota exceeded")]
    QuotaExceeded,

    #[error("Conflict: {0}")]
    Conflict(String),

    #[error("Server error: {0}")]
    ServerError(String),

    #[error("FFI error: {0}")]
    Ffi(String),

    #[error("Sync error: {0}")]
    Sync(String),
}

/// iOS result type
pub type IosResult<T> = Result<T, IosError>;

/// NSFileProviderError codes (matching Apple's NSFileProviderErrorCode)
#[repr(i32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FileProviderErrorCode {
    /// No error
    Success = 0,
    /// Item not found
    NoSuchItem = -1000,
    /// Item already exists
    ItemAlreadyExists = -1001,
    /// Not authenticated
    NotAuthenticated = -1002,
    /// Server unreachable
    ServerUnreachable = -1003,
    /// Quota exceeded
    QuotaExceeded = -1004,
    /// Invalid filename
    FilenameInvalid = -1005,
    /// Version out of date
    VersionOutOfDate = -1006,
    /// Page expired
    PageExpired = -1007,
    /// Sync anchor expired
    SyncAnchorExpired = -1008,
    /// Insufficient quota
    InsufficientQuota = -1009,
    /// Cannot sync
    CannotSync = -1010,
    /// Unknown error
    Unknown = -9999,
}

impl From<&IosError> for FileProviderErrorCode {
    fn from(err: &IosError) -> Self {
        match err {
            IosError::NotFound(_) => FileProviderErrorCode::NoSuchItem,
            IosError::AuthRequired => FileProviderErrorCode::NotAuthenticated,
            IosError::NetworkUnavailable => FileProviderErrorCode::ServerUnreachable,
            IosError::QuotaExceeded => FileProviderErrorCode::QuotaExceeded,
            IosError::Conflict(_) => FileProviderErrorCode::VersionOutOfDate,
            IosError::Sync(_) => FileProviderErrorCode::CannotSync,
            _ => FileProviderErrorCode::Unknown,
        }
    }
}

/// FFI-safe error structure
#[repr(C)]
pub struct FfiError {
    /// Error code
    pub code: i32,
    /// Error message (null-terminated, caller must free)
    pub message: *mut libc::c_char,
}

impl FfiError {
    /// Create a success result
    pub fn success() -> Self {
        Self {
            code: 0,
            message: std::ptr::null_mut(),
        }
    }

    /// Create from IosError
    pub fn from_error(err: &IosError) -> Self {
        let code: FileProviderErrorCode = err.into();
        let message = CString::new(err.to_string())
            .map(|s| s.into_raw())
            .unwrap_or(std::ptr::null_mut());

        Self {
            code: code as i32,
            message,
        }
    }
}

/// Free an error message
///
/// # Safety
/// The pointer must have been returned by a CFK function.
#[no_mangle]
pub unsafe extern "C" fn cfk_error_free(error: *mut FfiError) {
    if !error.is_null() {
        let err = &mut *error;
        if !err.message.is_null() {
            drop(CString::from_raw(err.message));
            err.message = std::ptr::null_mut();
        }
    }
}
