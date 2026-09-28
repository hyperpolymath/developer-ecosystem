/*
 * CfkBridge.h - C bridging header for Czech File Knife iOS integration
 *
 * This header exposes the Rust FFI functions to Swift/Objective-C.
 * Include this in your File Provider extension's bridging header.
 */

#ifndef CFK_BRIDGE_H
#define CFK_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* --- Initialization --- */

/**
 * Initialize the CFK iOS runtime.
 * Must be called before any other CFK functions.
 * Returns 0 on success, negative on error.
 */
int32_t cfk_ios_init(void);

/**
 * Shutdown the CFK iOS runtime.
 * Call when the extension is terminating.
 */
void cfk_ios_shutdown(void);

/**
 * Initialize the provider manager.
 * @param storage_path Path to store domain configuration
 * @param cache_path Path for cached file contents
 * @param temp_path Path for temporary files
 * Returns 0 on success.
 */
int32_t cfk_provider_init(
    const char *storage_path,
    const char *cache_path,
    const char *temp_path
);

/* --- Error Handling --- */

/**
 * Error structure returned by CFK functions.
 */
typedef struct {
    int32_t code;       /* Error code (0 = success) */
    char *message;      /* Error message (caller must free) */
} CfkError;

/**
 * Free an error structure.
 */
void cfk_error_free(CfkError *error);

/**
 * Free a string returned by CFK functions.
 */
void cfk_string_free(char *s);

/* --- Domain Management --- */

/**
 * Domain information structure.
 */
typedef struct {
    char *identifier;       /* Unique domain ID */
    char *display_name;     /* Name shown in Files app */
    char *backend_type;     /* Backend type (dropbox, gdrive, etc.) */
    bool enabled;           /* Whether domain is enabled */
} CfkDomain;

/**
 * Free a domain structure.
 */
void cfk_domain_free(CfkDomain *domain);

/**
 * Add a new domain.
 * @param identifier Unique identifier for the domain
 * @param display_name Name shown in Files app
 * @param backend_type Type of backend (dropbox, gdrive, onedrive, etc.)
 * @param config_json JSON configuration for the backend (can be NULL)
 * Returns 0 on success.
 */
int32_t cfk_domain_add(
    const char *identifier,
    const char *display_name,
    const char *backend_type,
    const char *config_json
);

/**
 * Remove a domain.
 * @param identifier Domain identifier to remove
 * Returns 0 on success.
 */
int32_t cfk_domain_remove(const char *identifier);

/* --- Item Operations --- */

/**
 * Item information structure.
 */
typedef struct {
    char *identifier;           /* Unique item identifier */
    char *parent_identifier;    /* Parent item identifier */
    char *filename;             /* File/folder name */
    uint32_t item_type;         /* 0=file, 1=directory, 2=symlink */
    uint64_t size;              /* File size in bytes */
    bool has_size;              /* Whether size is valid */
    uint64_t capabilities;      /* Capability flags */
    bool is_downloaded;         /* Whether content is cached locally */
    bool is_uploaded;           /* Whether content is synced to server */
} CfkItem;

/**
 * Free an item structure.
 */
void cfk_item_free(CfkItem *item);

/**
 * Get item by identifier.
 * @param identifier Item identifier
 * @param out_item Output item structure
 * Returns 0 on success.
 */
int32_t cfk_item_get(
    const char *identifier,
    CfkItem *out_item
);

/**
 * Item list for enumeration results.
 */
typedef struct {
    CfkItem *items;         /* Array of items */
    size_t count;           /* Number of items */
    char *next_page_token;  /* Token for next page (NULL if no more) */
} CfkItemList;

/**
 * Free an item list.
 */
void cfk_item_list_free(CfkItemList *list);

/**
 * Enumerate items in a container.
 * @param container Container identifier (use "root" for root)
 * @param page_token Page token for pagination (can be NULL)
 * @param out_list Output item list
 * Returns 0 on success.
 */
int32_t cfk_enumerate_items(
    const char *container,
    const char *page_token,
    CfkItemList *out_list
);

/**
 * Fetch file contents to local storage.
 * @param identifier File identifier
 * @param out_path Output path where file was downloaded
 * Returns 0 on success.
 */
int32_t cfk_fetch_contents(
    const char *identifier,
    char **out_path
);

/**
 * Create a new item.
 * @param parent Parent container identifier
 * @param filename Name of the new item
 * @param item_type Type (0=file, 1=directory)
 * @param contents File contents (can be NULL for directories)
 * @param contents_len Length of contents
 * @param out_item Output item structure
 * Returns 0 on success.
 */
int32_t cfk_create_item(
    const char *parent,
    const char *filename,
    uint32_t item_type,
    const uint8_t *contents,
    size_t contents_len,
    CfkItem *out_item
);

/**
 * Delete an item.
 * @param identifier Item identifier
 * Returns 0 on success.
 */
int32_t cfk_delete_item(const char *identifier);

/* --- Error Codes (matching NSFileProviderErrorCode) --- */

#define CFK_ERROR_SUCCESS               0
#define CFK_ERROR_NO_SUCH_ITEM         -1000
#define CFK_ERROR_ITEM_ALREADY_EXISTS  -1001
#define CFK_ERROR_NOT_AUTHENTICATED    -1002
#define CFK_ERROR_SERVER_UNREACHABLE   -1003
#define CFK_ERROR_QUOTA_EXCEEDED       -1004
#define CFK_ERROR_FILENAME_INVALID     -1005
#define CFK_ERROR_VERSION_OUT_OF_DATE  -1006
#define CFK_ERROR_CANNOT_SYNC          -1010
#define CFK_ERROR_UNKNOWN              -9999

/* --- Item Capabilities --- */

#define CFK_CAP_READING               (1ULL << 0)
#define CFK_CAP_WRITING               (1ULL << 1)
#define CFK_CAP_REPARENTING           (1ULL << 2)
#define CFK_CAP_RENAMING              (1ULL << 3)
#define CFK_CAP_TRASHING              (1ULL << 4)
#define CFK_CAP_DELETING              (1ULL << 5)
#define CFK_CAP_EVICTING              (1ULL << 6)
#define CFK_CAP_ADDING_SUBITEM        (1ULL << 7)
#define CFK_CAP_CONTENT_ENUMERATION   (1ULL << 8)
#define CFK_CAP_PLAYING               (1ULL << 9)

/* --- Item Types --- */

#define CFK_ITEM_TYPE_FILE            0
#define CFK_ITEM_TYPE_DIRECTORY       1
#define CFK_ITEM_TYPE_SYMLINK         2
#define CFK_ITEM_TYPE_PACKAGE         3

#ifdef __cplusplus
}
#endif

#endif /* CFK_BRIDGE_H */
