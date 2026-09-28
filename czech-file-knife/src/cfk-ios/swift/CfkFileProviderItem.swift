/*
 * CfkFileProviderItem.swift - NSFileProviderItem implementation
 *
 * This class wraps CfkItem from the Rust FFI layer and implements
 * the NSFileProviderItem protocol for use in File Provider extensions.
 */

import FileProvider
import UniformTypeIdentifiers

/// File Provider Item backed by CFK Rust library
@available(iOS 16.0, macOS 13.0, *)
public class CfkFileProviderItem: NSObject, NSFileProviderItem {

    // MARK: - Properties

    private let cfkItem: CfkItemWrapper

    /// Unique identifier for this item
    public var itemIdentifier: NSFileProviderItemIdentifier {
        return NSFileProviderItemIdentifier(cfkItem.identifier)
    }

    /// Parent folder identifier
    public var parentItemIdentifier: NSFileProviderItemIdentifier {
        if cfkItem.parentIdentifier == "root" {
            return .rootContainer
        }
        return NSFileProviderItemIdentifier(cfkItem.parentIdentifier)
    }

    /// File or folder name
    public var filename: String {
        return cfkItem.filename
    }

    /// Content type (UTI)
    public var contentType: UTType {
        if cfkItem.itemType == CFK_ITEM_TYPE_DIRECTORY {
            return .folder
        }
        // Infer from filename
        if let type = UTType(filenameExtension: (filename as NSString).pathExtension) {
            return type
        }
        return .data
    }

    /// Document size
    public var documentSize: NSNumber? {
        guard cfkItem.hasSize else { return nil }
        return NSNumber(value: cfkItem.size)
    }

    /// Item capabilities
    public var capabilities: NSFileProviderItemCapabilities {
        var caps: NSFileProviderItemCapabilities = []

        if cfkItem.capabilities & UInt64(CFK_CAP_READING) != 0 {
            caps.insert(.allowsReading)
        }
        if cfkItem.capabilities & UInt64(CFK_CAP_WRITING) != 0 {
            caps.insert(.allowsWriting)
        }
        if cfkItem.capabilities & UInt64(CFK_CAP_REPARENTING) != 0 {
            caps.insert(.allowsReparenting)
        }
        if cfkItem.capabilities & UInt64(CFK_CAP_RENAMING) != 0 {
            caps.insert(.allowsRenaming)
        }
        if cfkItem.capabilities & UInt64(CFK_CAP_TRASHING) != 0 {
            caps.insert(.allowsTrashing)
        }
        if cfkItem.capabilities & UInt64(CFK_CAP_DELETING) != 0 {
            caps.insert(.allowsDeleting)
        }
        if cfkItem.capabilities & UInt64(CFK_CAP_EVICTING) != 0 {
            caps.insert(.allowsEvicting)
        }
        if cfkItem.capabilities & UInt64(CFK_CAP_ADDING_SUBITEM) != 0 {
            caps.insert(.allowsAddingSubItems)
        }
        if cfkItem.capabilities & UInt64(CFK_CAP_CONTENT_ENUMERATION) != 0 {
            caps.insert(.allowsContentEnumerating)
        }

        return caps
    }

    /// Whether content is downloaded
    public var isDownloaded: Bool {
        return cfkItem.isDownloaded
    }

    /// Whether content is uploaded
    public var isUploaded: Bool {
        return cfkItem.isUploaded
    }

    // MARK: - Initialization

    /// Initialize from CfkItem C structure
    public init(from cItem: CfkItem) {
        self.cfkItem = CfkItemWrapper(from: cItem)
        super.init()
    }

    /// Fetch item from Rust backend
    public static func fetch(identifier: String) throws -> CfkFileProviderItem {
        var cItem = CfkItem()
        let result = identifier.withCString { ptr in
            cfk_item_get(ptr, &cItem)
        }

        guard result == CFK_ERROR_SUCCESS else {
            throw CfkError.from(code: result)
        }

        defer { cfk_item_free(&cItem) }
        return CfkFileProviderItem(from: cItem)
    }
}

// MARK: - Swift Wrapper for C Structure

/// Swift-friendly wrapper around CfkItem
private struct CfkItemWrapper {
    let identifier: String
    let parentIdentifier: String
    let filename: String
    let itemType: UInt32
    let size: UInt64
    let hasSize: Bool
    let capabilities: UInt64
    let isDownloaded: Bool
    let isUploaded: Bool

    init(from cItem: CfkItem) {
        self.identifier = cItem.identifier.map { String(cString: $0) } ?? ""
        self.parentIdentifier = cItem.parent_identifier.map { String(cString: $0) } ?? "root"
        self.filename = cItem.filename.map { String(cString: $0) } ?? ""
        self.itemType = cItem.item_type
        self.size = cItem.size
        self.hasSize = cItem.has_size
        self.capabilities = cItem.capabilities
        self.isDownloaded = cItem.is_downloaded
        self.isUploaded = cItem.is_uploaded
    }
}

// MARK: - Error Handling

/// CFK Error type
public enum CfkError: Error {
    case noSuchItem
    case itemAlreadyExists
    case notAuthenticated
    case serverUnreachable
    case quotaExceeded
    case filenameInvalid
    case versionOutOfDate
    case cannotSync
    case unknown(Int32)

    static func from(code: Int32) -> CfkError {
        switch code {
        case CFK_ERROR_NO_SUCH_ITEM:
            return .noSuchItem
        case CFK_ERROR_ITEM_ALREADY_EXISTS:
            return .itemAlreadyExists
        case CFK_ERROR_NOT_AUTHENTICATED:
            return .notAuthenticated
        case CFK_ERROR_SERVER_UNREACHABLE:
            return .serverUnreachable
        case CFK_ERROR_QUOTA_EXCEEDED:
            return .quotaExceeded
        case CFK_ERROR_FILENAME_INVALID:
            return .filenameInvalid
        case CFK_ERROR_VERSION_OUT_OF_DATE:
            return .versionOutOfDate
        case CFK_ERROR_CANNOT_SYNC:
            return .cannotSync
        default:
            return .unknown(code)
        }
    }

    /// Convert to NSFileProviderError
    @available(iOS 16.0, macOS 13.0, *)
    public var fileProviderError: NSError {
        let code: NSFileProviderError.Code
        switch self {
        case .noSuchItem:
            code = .noSuchItem
        case .itemAlreadyExists:
            code = .filenameCollision
        case .notAuthenticated:
            code = .notAuthenticated
        case .serverUnreachable:
            code = .serverUnreachable
        case .quotaExceeded:
            code = .insufficientQuota
        case .filenameInvalid:
            code = .filenameCollision
        case .versionOutOfDate:
            code = .newerExtensionVersionFound
        case .cannotSync:
            code = .cannotSynchronize
        case .unknown:
            code = .cannotSynchronize
        }
        return NSError(domain: NSFileProviderErrorDomain, code: code.rawValue)
    }
}

// MARK: - Initialization Helper

/// Initialize CFK library
public func initializeCfk(storagePath: URL, cachePath: URL, tempPath: URL) throws {
    // Initialize runtime
    let initResult = cfk_ios_init()
    guard initResult == 0 else {
        throw CfkError.unknown(initResult)
    }

    // Initialize provider
    let result = storagePath.path.withCString { storage in
        cachePath.path.withCString { cache in
            tempPath.path.withCString { temp in
                cfk_provider_init(storage, cache, temp)
            }
        }
    }

    guard result == CFK_ERROR_SUCCESS else {
        throw CfkError.from(code: result)
    }
}

/// Shutdown CFK library
public func shutdownCfk() {
    cfk_ios_shutdown()
}
