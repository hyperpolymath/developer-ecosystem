/*
 * CfkFileProviderExtension.swift - File Provider Extension implementation
 *
 * This class implements NSFileProviderReplicatedExtension for full
 * file provider support in iOS/macOS.
 */

import FileProvider
import UniformTypeIdentifiers

/// Czech File Knife File Provider Extension
@available(iOS 16.0, macOS 13.0, *)
open class CfkFileProviderExtension: NSObject, NSFileProviderReplicatedExtension {

    // MARK: - Properties

    /// The domain this extension is serving
    public let domain: NSFileProviderDomain

    /// Manager instance (initialized lazily)
    private var isInitialized = false

    // MARK: - Initialization

    public required init(domain: NSFileProviderDomain) {
        self.domain = domain
        super.init()
    }

    /// Initialize the CFK backend
    private func ensureInitialized() throws {
        guard !isInitialized else { return }

        let containerURL = NSFileProviderManager(for: domain)?.documentStorageURL
            ?? FileManager.default.temporaryDirectory

        let storageURL = containerURL.appendingPathComponent("cfk-storage")
        let cacheURL = containerURL.appendingPathComponent("cfk-cache")
        let tempURL = containerURL.appendingPathComponent("cfk-temp")

        // Create directories
        try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        try initializeCfk(storagePath: storageURL, cachePath: cacheURL, tempPath: tempURL)
        isInitialized = true
    }

    // MARK: - NSFileProviderReplicatedExtension

    public func invalidate() {
        shutdownCfk()
        isInitialized = false
    }

    public func item(
        for identifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 1)

        Task {
            do {
                try ensureInitialized()

                let id = identifier == .rootContainer ? "root" : identifier.rawValue
                let item = try CfkFileProviderItem.fetch(identifier: id)

                progress.completedUnitCount = 1
                completionHandler(item, nil)
            } catch {
                completionHandler(nil, error)
            }
        }

        return progress
    }

    public func fetchContents(
        for itemIdentifier: NSFileProviderItemIdentifier,
        version requestedVersion: NSFileProviderItemVersion?,
        request: NSFileProviderRequest,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 100)

        Task {
            do {
                try ensureInitialized()

                var pathPtr: UnsafeMutablePointer<CChar>?
                let result = itemIdentifier.rawValue.withCString { id in
                    cfk_fetch_contents(id, &pathPtr)
                }

                guard result == CFK_ERROR_SUCCESS, let path = pathPtr else {
                    throw CfkError.from(code: result)
                }

                let localPath = URL(fileURLWithPath: String(cString: path))
                cfk_string_free(pathPtr)

                let item = try CfkFileProviderItem.fetch(identifier: itemIdentifier.rawValue)

                progress.completedUnitCount = 100
                completionHandler(localPath, item, nil)
            } catch {
                completionHandler(nil, nil, error)
            }
        }

        return progress
    }

    public func createItem(
        basedOn itemTemplate: NSFileProviderItem,
        fields: NSFileProviderItemFields,
        contents url: URL?,
        options: NSFileProviderCreateItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 100)

        Task {
            do {
                try ensureInitialized()

                let parentId = itemTemplate.parentItemIdentifier == .rootContainer
                    ? "root"
                    : itemTemplate.parentItemIdentifier.rawValue
                let filename = itemTemplate.filename
                let isDirectory = itemTemplate.contentType == .folder

                // Read contents if file
                var contentsData: Data?
                if let url = url, !isDirectory {
                    contentsData = try Data(contentsOf: url)
                }

                var cItem = CfkItem()
                let result: Int32 = parentId.withCString { parent in
                    filename.withCString { name in
                        if let data = contentsData {
                            return data.withUnsafeBytes { bytes in
                                cfk_create_item(
                                    parent,
                                    name,
                                    isDirectory ? UInt32(CFK_ITEM_TYPE_DIRECTORY) : UInt32(CFK_ITEM_TYPE_FILE),
                                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                                    data.count,
                                    &cItem
                                )
                            }
                        } else {
                            return cfk_create_item(
                                parent,
                                name,
                                isDirectory ? UInt32(CFK_ITEM_TYPE_DIRECTORY) : UInt32(CFK_ITEM_TYPE_FILE),
                                nil,
                                0,
                                &cItem
                            )
                        }
                    }
                }

                guard result == CFK_ERROR_SUCCESS else {
                    throw CfkError.from(code: result)
                }

                defer { cfk_item_free(&cItem) }
                let item = CfkFileProviderItem(from: cItem)

                progress.completedUnitCount = 100
                completionHandler(item, [], false, nil)
            } catch {
                completionHandler(nil, [], false, error)
            }
        }

        return progress
    }

    public func modifyItem(
        _ item: NSFileProviderItem,
        baseVersion version: NSFileProviderItemVersion,
        changedFields: NSFileProviderItemFields,
        contents newContents: URL?,
        options: NSFileProviderModifyItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 100)

        Task {
            do {
                try ensureInitialized()

                // For now, just refetch the item
                let updated = try CfkFileProviderItem.fetch(identifier: item.itemIdentifier.rawValue)

                progress.completedUnitCount = 100
                completionHandler(updated, [], false, nil)
            } catch {
                completionHandler(nil, [], false, error)
            }
        }

        return progress
    }

    public func deleteItem(
        identifier: NSFileProviderItemIdentifier,
        baseVersion version: NSFileProviderItemVersion,
        options: NSFileProviderDeleteItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (Error?) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 1)

        Task {
            do {
                try ensureInitialized()

                let result = identifier.rawValue.withCString { id in
                    cfk_delete_item(id)
                }

                guard result == CFK_ERROR_SUCCESS else {
                    throw CfkError.from(code: result)
                }

                progress.completedUnitCount = 1
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }

        return progress
    }

    // MARK: - Enumeration

    public func enumerator(
        for containerItemIdentifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest
    ) throws -> NSFileProviderEnumerator {
        try ensureInitialized()
        return CfkEnumerator(containerIdentifier: containerItemIdentifier)
    }
}

// MARK: - Enumerator

@available(iOS 16.0, macOS 13.0, *)
class CfkEnumerator: NSObject, NSFileProviderEnumerator {

    let containerIdentifier: NSFileProviderItemIdentifier

    init(containerIdentifier: NSFileProviderItemIdentifier) {
        self.containerIdentifier = containerIdentifier
        super.init()
    }

    func invalidate() {
        // Clean up if needed
    }

    func enumerateItems(
        for observer: NSFileProviderEnumerationObserver,
        startingAt page: NSFileProviderPage
    ) {
        let containerId = containerIdentifier == .rootContainer
            ? "root"
            : containerIdentifier.rawValue

        var itemList = CfkItemList()
        let pageToken: String? = page == NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage
            || page == NSFileProviderPage.initialPageSortedByName as NSFileProviderPage
            ? nil
            : String(data: page.rawValue, encoding: .utf8)

        let result: Int32 = containerId.withCString { container in
            if let token = pageToken {
                return token.withCString { tokenPtr in
                    cfk_enumerate_items(container, tokenPtr, &itemList)
                }
            } else {
                return cfk_enumerate_items(container, nil, &itemList)
            }
        }

        guard result == CFK_ERROR_SUCCESS else {
            observer.finishEnumeratingWithError(CfkError.from(code: result).fileProviderError)
            return
        }

        defer { cfk_item_list_free(&itemList) }

        // Convert items
        var items: [CfkFileProviderItem] = []
        if let itemsPtr = itemList.items {
            for i in 0..<itemList.count {
                let cItem = itemsPtr[i]
                items.append(CfkFileProviderItem(from: cItem))
            }
        }

        observer.didEnumerate(items)

        // Handle pagination
        if let nextToken = itemList.next_page_token.map({ String(cString: $0) }) {
            let nextPage = NSFileProviderPage(nextToken.data(using: .utf8)!)
            observer.finishEnumerating(upTo: nextPage)
        } else {
            observer.finishEnumerating(upTo: nil)
        }
    }

    func enumerateChanges(
        for observer: NSFileProviderChangeObserver,
        from syncAnchor: NSFileProviderSyncAnchor
    ) {
        // For now, just report no changes
        observer.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        // Return a simple anchor based on current time
        let anchor = NSFileProviderSyncAnchor(Date().timeIntervalSince1970.description.data(using: .utf8)!)
        completionHandler(anchor)
    }
}
