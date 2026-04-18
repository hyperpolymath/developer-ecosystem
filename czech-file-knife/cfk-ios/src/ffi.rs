//! C FFI layer for iOS integration
//!
//! This module exposes a C API that can be called from Swift/Objective-C.

use crate::domain::{DomainIdentifier, FileDomain};
use crate::error::{FfiError, FileProviderErrorCode};
use crate::item::{FileProviderItem, ItemIdentifier};
use crate::provider::FileProviderManager;
use once_cell::sync::OnceCell;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::PathBuf;
use std::sync::Arc;

/// Global provider manager
static MANAGER: OnceCell<Arc<FileProviderManager>> = OnceCell::new();

/// Initialize the FFI layer
fn get_manager() -> Result<&'static Arc<FileProviderManager>, FfiError> {
    MANAGER
        .get()
        .ok_or_else(|| FfiError::from_error(&crate::error::IosError::Ffi(
            "Manager not initialized".into(),
        )))
}

// --- Initialization ---

/// Initialize the provider manager
///
/// # Safety
/// All string parameters must be valid null-terminated UTF-8 strings.
#[no_mangle]
pub unsafe extern "C" fn cfk_provider_init(
    storage_path: *const c_char,
    cache_path: *const c_char,
    temp_path: *const c_char,
) -> i32 {
    let storage = match CStr::from_ptr(storage_path).to_str() {
        Ok(s) => PathBuf::from(s),
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let cache = match CStr::from_ptr(cache_path).to_str() {
        Ok(s) => PathBuf::from(s),
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let temp = match CStr::from_ptr(temp_path).to_str() {
        Ok(s) => PathBuf::from(s),
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let manager = FileProviderManager::new(storage, cache, temp);

    // Initialize async
    let rt = crate::runtime();
    if let Err(e) = rt.block_on(Arc::new(manager).initialize()) {
        tracing::error!("Failed to initialize: {}", e);
        return FileProviderErrorCode::Unknown as i32;
    }

    let manager = FileProviderManager::new(
        CStr::from_ptr(storage_path).to_str().unwrap_or(""),
        CStr::from_ptr(cache_path).to_str().unwrap_or(""),
        CStr::from_ptr(temp_path).to_str().unwrap_or(""),
    );

    let _ = MANAGER.set(Arc::new(manager));

    FileProviderErrorCode::Success as i32
}

// --- Domain Management ---

/// FFI-safe domain structure
#[repr(C)]
pub struct CfkDomain {
    pub identifier: *mut c_char,
    pub display_name: *mut c_char,
    pub backend_type: *mut c_char,
    pub enabled: bool,
}

impl CfkDomain {
    fn from_domain(domain: &FileDomain) -> Self {
        Self {
            identifier: CString::new(domain.identifier.0.clone())
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut()),
            display_name: CString::new(domain.display_name.clone())
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut()),
            backend_type: CString::new(domain.backend_type.clone())
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut()),
            enabled: domain.enabled,
        }
    }
}

/// Free a domain structure
///
/// # Safety
/// The pointer must have been returned by a CFK function.
#[no_mangle]
pub unsafe extern "C" fn cfk_domain_free(domain: *mut CfkDomain) {
    if !domain.is_null() {
        let d = &mut *domain;
        if !d.identifier.is_null() {
            drop(CString::from_raw(d.identifier));
        }
        if !d.display_name.is_null() {
            drop(CString::from_raw(d.display_name));
        }
        if !d.backend_type.is_null() {
            drop(CString::from_raw(d.backend_type));
        }
    }
}

/// Add a domain
///
/// # Safety
/// All string parameters must be valid null-terminated UTF-8 strings.
#[no_mangle]
pub unsafe extern "C" fn cfk_domain_add(
    identifier: *const c_char,
    display_name: *const c_char,
    backend_type: *const c_char,
    config_json: *const c_char,
) -> i32 {
    let manager = match get_manager() {
        Ok(m) => m,
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let id = match CStr::from_ptr(identifier).to_str() {
        Ok(s) => s,
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let name = match CStr::from_ptr(display_name).to_str() {
        Ok(s) => s,
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let backend = match CStr::from_ptr(backend_type).to_str() {
        Ok(s) => s,
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let config = if config_json.is_null() {
        "{}".to_string()
    } else {
        CStr::from_ptr(config_json)
            .to_str()
            .unwrap_or("{}")
            .to_string()
    };

    let domain = FileDomain::new(id, name, backend).with_config(config);

    let rt = crate::runtime();
    match rt.block_on(manager.add_domain(domain)) {
        Ok(_) => FileProviderErrorCode::Success as i32,
        Err(_) => FileProviderErrorCode::Unknown as i32,
    }
}

/// Remove a domain
///
/// # Safety
/// The identifier must be a valid null-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn cfk_domain_remove(identifier: *const c_char) -> i32 {
    let manager = match get_manager() {
        Ok(m) => m,
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let id = match CStr::from_ptr(identifier).to_str() {
        Ok(s) => DomainIdentifier::new(s),
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let rt = crate::runtime();
    match rt.block_on(manager.remove_domain(&id)) {
        Ok(_) => FileProviderErrorCode::Success as i32,
        Err(_) => FileProviderErrorCode::NoSuchItem as i32,
    }
}

// --- Item Operations ---

/// FFI-safe item structure
#[repr(C)]
pub struct CfkItem {
    pub identifier: *mut c_char,
    pub parent_identifier: *mut c_char,
    pub filename: *mut c_char,
    pub item_type: u32,
    pub size: u64,
    pub has_size: bool,
    pub capabilities: u64,
    pub is_downloaded: bool,
    pub is_uploaded: bool,
}

impl CfkItem {
    fn from_item(item: &FileProviderItem) -> Self {
        Self {
            identifier: CString::new(item.identifier.0.clone())
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut()),
            parent_identifier: CString::new(item.parent_identifier.0.clone())
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut()),
            filename: CString::new(item.filename.clone())
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut()),
            item_type: item.item_type,
            size: item.size.unwrap_or(0),
            has_size: item.size.is_some(),
            capabilities: item.capabilities,
            is_downloaded: item.is_downloaded,
            is_uploaded: item.is_uploaded,
        }
    }
}

/// Free an item structure
///
/// # Safety
/// The pointer must have been returned by a CFK function.
#[no_mangle]
pub unsafe extern "C" fn cfk_item_free(item: *mut CfkItem) {
    if !item.is_null() {
        let i = &mut *item;
        if !i.identifier.is_null() {
            drop(CString::from_raw(i.identifier));
        }
        if !i.parent_identifier.is_null() {
            drop(CString::from_raw(i.parent_identifier));
        }
        if !i.filename.is_null() {
            drop(CString::from_raw(i.filename));
        }
    }
}

/// Get item by identifier
///
/// # Safety
/// The identifier must be a valid null-terminated UTF-8 string.
/// The caller must free the returned item with cfk_item_free.
#[no_mangle]
pub unsafe extern "C" fn cfk_item_get(
    identifier: *const c_char,
    out_item: *mut CfkItem,
) -> i32 {
    let manager = match get_manager() {
        Ok(m) => m,
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let id = match CStr::from_ptr(identifier).to_str() {
        Ok(s) => ItemIdentifier(s.to_string()),
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let rt = crate::runtime();
    match rt.block_on(manager.item(&id)) {
        Ok(item) => {
            if !out_item.is_null() {
                *out_item = CfkItem::from_item(&item);
            }
            FileProviderErrorCode::Success as i32
        }
        Err(_) => FileProviderErrorCode::NoSuchItem as i32,
    }
}

/// Item list for enumeration
#[repr(C)]
pub struct CfkItemList {
    pub items: *mut CfkItem,
    pub count: usize,
    pub next_page_token: *mut c_char,
}

/// Free an item list
///
/// # Safety
/// The pointer must have been returned by a CFK function.
#[no_mangle]
pub unsafe extern "C" fn cfk_item_list_free(list: *mut CfkItemList) {
    if !list.is_null() {
        let l = &mut *list;
        if !l.items.is_null() {
            let items = std::slice::from_raw_parts_mut(l.items, l.count);
            for item in items {
                cfk_item_free(item);
            }
            drop(Vec::from_raw_parts(l.items, l.count, l.count));
        }
        if !l.next_page_token.is_null() {
            drop(CString::from_raw(l.next_page_token));
        }
    }
}

/// Enumerate items in a container
///
/// # Safety
/// All string parameters must be valid null-terminated UTF-8 strings.
#[no_mangle]
pub unsafe extern "C" fn cfk_enumerate_items(
    container: *const c_char,
    page_token: *const c_char,
    out_list: *mut CfkItemList,
) -> i32 {
    let manager = match get_manager() {
        Ok(m) => m,
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let container_id = match CStr::from_ptr(container).to_str() {
        Ok(s) => ItemIdentifier(s.to_string()),
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let token = if page_token.is_null() {
        None
    } else {
        CStr::from_ptr(page_token).to_str().ok()
    };

    let rt = crate::runtime();
    match rt.block_on(manager.enumerate_items(&container_id, token)) {
        Ok(page) => {
            if !out_list.is_null() {
                let items: Vec<CfkItem> = page.items.iter().map(CfkItem::from_item).collect();
                let count = items.len();
                let ptr = items.as_ptr() as *mut CfkItem;
                std::mem::forget(items);

                (*out_list).items = ptr;
                (*out_list).count = count;
                (*out_list).next_page_token = page
                    .next_page_token
                    .and_then(|t| CString::new(t).ok())
                    .map(|s| s.into_raw())
                    .unwrap_or(std::ptr::null_mut());
            }
            FileProviderErrorCode::Success as i32
        }
        Err(_) => FileProviderErrorCode::NoSuchItem as i32,
    }
}

/// Fetch file contents to local path
///
/// # Safety
/// All string parameters must be valid null-terminated UTF-8 strings.
/// The caller must free the returned path string.
#[no_mangle]
pub unsafe extern "C" fn cfk_fetch_contents(
    identifier: *const c_char,
    out_path: *mut *mut c_char,
) -> i32 {
    let manager = match get_manager() {
        Ok(m) => m,
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let id = match CStr::from_ptr(identifier).to_str() {
        Ok(s) => ItemIdentifier(s.to_string()),
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let rt = crate::runtime();
    match rt.block_on(manager.fetch_contents(&id)) {
        Ok(path) => {
            if !out_path.is_null() {
                *out_path = CString::new(path.to_string_lossy().as_ref())
                    .map(|s| s.into_raw())
                    .unwrap_or(std::ptr::null_mut());
            }
            FileProviderErrorCode::Success as i32
        }
        Err(_) => FileProviderErrorCode::NoSuchItem as i32,
    }
}

/// Create a new item
///
/// # Safety
/// All string parameters must be valid null-terminated UTF-8 strings.
#[no_mangle]
pub unsafe extern "C" fn cfk_create_item(
    parent: *const c_char,
    filename: *const c_char,
    item_type: u32,
    contents: *const u8,
    contents_len: usize,
    out_item: *mut CfkItem,
) -> i32 {
    let manager = match get_manager() {
        Ok(m) => m,
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let parent_id = match CStr::from_ptr(parent).to_str() {
        Ok(s) => ItemIdentifier(s.to_string()),
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let name = match CStr::from_ptr(filename).to_str() {
        Ok(s) => s,
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let data = if contents.is_null() || contents_len == 0 {
        None
    } else {
        Some(std::slice::from_raw_parts(contents, contents_len))
    };

    let rt = crate::runtime();
    match rt.block_on(manager.create_item(&parent_id, name, item_type, data)) {
        Ok(item) => {
            if !out_item.is_null() {
                *out_item = CfkItem::from_item(&item);
            }
            FileProviderErrorCode::Success as i32
        }
        Err(_) => FileProviderErrorCode::Unknown as i32,
    }
}

/// Delete an item
///
/// # Safety
/// The identifier must be a valid null-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn cfk_delete_item(identifier: *const c_char) -> i32 {
    let manager = match get_manager() {
        Ok(m) => m,
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let id = match CStr::from_ptr(identifier).to_str() {
        Ok(s) => ItemIdentifier(s.to_string()),
        Err(_) => return FileProviderErrorCode::Unknown as i32,
    };

    let rt = crate::runtime();
    match rt.block_on(manager.delete_item(&id)) {
        Ok(_) => FileProviderErrorCode::Success as i32,
        Err(_) => FileProviderErrorCode::NoSuchItem as i32,
    }
}

/// Free a string returned by CFK functions
///
/// # Safety
/// The pointer must have been returned by a CFK function.
#[no_mangle]
pub unsafe extern "C" fn cfk_string_free(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}
