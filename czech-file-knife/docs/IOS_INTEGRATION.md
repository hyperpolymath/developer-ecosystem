# iOS Integration Guide

Czech File Knife (CFK) provides native iOS integration through Apple's File Provider framework, allowing cloud storage providers to appear in the iOS Files app.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     iOS Files App                                │
├─────────────────────────────────────────────────────────────────┤
│                File Provider Framework                           │
│              (NSFileProviderExtension)                           │
├─────────────────────────────────────────────────────────────────┤
│                Swift Wrapper Layer                               │
│    (CfkFileProviderItem, CfkFileProviderExtension)              │
├─────────────────────────────────────────────────────────────────┤
│                  C FFI Bridge                                    │
│              (CfkBridge.h, ffi.rs)                               │
├─────────────────────────────────────────────────────────────────┤
│                Rust Core Library                                 │
│         (cfk-ios, cfk-core, cfk-providers)                      │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### cfk-ios Crate

The `cfk-ios` crate provides:

- **error.rs**: iOS-specific error types mapping to `NSFileProviderError`
- **domain.rs**: File Provider domain management
- **item.rs**: `NSFileProviderItem` representation
- **provider.rs**: Main provider manager coordinating backends
- **ffi.rs**: C FFI layer for Swift interop

### Swift Integration

Swift files in `cfk-ios/swift/`:

- **CfkBridge.h**: C header for bridging
- **CfkFileProviderItem.swift**: `NSFileProviderItem` implementation
- **CfkFileProviderExtension.swift**: `NSFileProviderReplicatedExtension` implementation

## Building for iOS

### Prerequisites

1. Xcode 14+ with iOS 16+ SDK
2. Rust with iOS targets:

```bash
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim  # For simulator
```

3. `cargo-lipo` for universal binaries (optional):

```bash
cargo install cargo-lipo
```

### Build Static Library

```bash
# For device
cargo build --release --target aarch64-apple-ios -p cfk-ios

# For simulator
cargo build --release --target aarch64-apple-ios-sim -p cfk-ios

# Universal binary (both architectures)
cargo lipo --release -p cfk-ios
```

The static library will be at:
- Device: `target/aarch64-apple-ios/release/libcfk_ios.a`
- Simulator: `target/aarch64-apple-ios-sim/release/libcfk_ios.a`

## Xcode Project Setup

### 1. Create File Provider Extension

1. In Xcode, File → New → Target
2. Select "File Provider Extension"
3. Name it (e.g., "CfkFileProvider")

### 2. Add Static Library

1. Drag `libcfk_ios.a` into your project
2. In target settings → Build Phases → Link Binary:
   - Add `libcfk_ios.a`
   - Add `libresolv.tbd` (for networking)

### 3. Configure Bridging Header

1. Create `YourExtension-Bridging-Header.h`
2. Add:

```objc
#import "CfkBridge.h"
```

3. In Build Settings → Swift Compiler → Objective-C Bridging Header:
   - Set to `$(SRCROOT)/YourExtension/YourExtension-Bridging-Header.h`

### 4. Add Swift Files

Copy the Swift files from `cfk-ios/swift/` into your extension:
- `CfkFileProviderItem.swift`
- `CfkFileProviderExtension.swift`

### 5. Configure Info.plist

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionFileProviderDocumentGroup</key>
    <string>group.com.yourcompany.cfk</string>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.fileprovider-nonui</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).CfkFileProviderExtension</string>
    <key>NSExtensionFileProviderSupportsEnumeration</key>
    <true/>
</dict>
```

### 6. Configure Entitlements

```xml
<key>com.apple.developer.fileprovider.testing-mode</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourcompany.cfk</string>
</array>
```

## Usage

### Register Domains

In your main app, register file provider domains:

```swift
import FileProvider

class StorageManager {
    func addDropboxAccount() async throws {
        // Initialize CFK
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.yourcompany.cfk"
        )!

        try initializeCfk(
            storagePath: container.appendingPathComponent("storage"),
            cachePath: container.appendingPathComponent("cache"),
            tempPath: container.appendingPathComponent("temp")
        )

        // Add domain via FFI
        let result = "dropbox-main".withCString { id in
            "Dropbox".withCString { name in
                "dropbox".withCString { backend in
                    cfk_domain_add(id, name, backend, nil)
                }
            }
        }

        guard result == CFK_ERROR_SUCCESS else {
            throw CfkError.from(code: result)
        }

        // Register with system
        let domain = NSFileProviderDomain(
            identifier: NSFileProviderDomainIdentifier("dropbox-main"),
            displayName: "Dropbox"
        )

        try await NSFileProviderManager.add(domain)
    }
}
```

### Custom Extension Class

Subclass `CfkFileProviderExtension` for customization:

```swift
@available(iOS 16.0, *)
class MyFileProviderExtension: CfkFileProviderExtension {

    override func item(
        for identifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        // Custom handling
        return super.item(for: identifier, request: request, completionHandler: completionHandler)
    }
}
```

## Handling Authentication

### OAuth Flow

For cloud providers requiring OAuth:

```swift
import AuthenticationServices

class AuthManager {
    func authenticateDropbox() async throws -> String {
        // Build OAuth URL
        let authURL = URL(string: "https://www.dropbox.com/oauth2/authorize?...")!

        // Present auth session
        let callbackURL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "cfk"
            ) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                }
            }
            session.presentationContextProvider = self
            session.start()
        }

        // Extract token from callback
        let token = extractToken(from: callbackURL)

        // Store token and configure backend
        let config = """
        {"access_token": "\(token)"}
        """

        let result = "dropbox-main".withCString { id in
            "Dropbox".withCString { name in
                "dropbox".withCString { backend in
                    config.withCString { cfg in
                        cfk_domain_add(id, name, backend, cfg)
                    }
                }
            }
        }

        return token
    }
}
```

## File Coordination

For proper file coordination with other apps:

```swift
func coordinatedRead(at url: URL) async throws -> Data {
    let coordinator = NSFileCoordinator()
    var error: NSError?
    var data: Data?

    coordinator.coordinate(readingItemAt: url, options: [], error: &error) { coordURL in
        data = try? Data(contentsOf: coordURL)
    }

    if let error = error {
        throw error
    }

    return data ?? Data()
}
```

## Thumbnails

Implement thumbnail provider for preview support:

```swift
@available(iOS 16.0, *)
class CfkThumbnailProvider: NSFileProviderThumbnailRequest {

    func fetchThumbnails(
        for itemIdentifiers: [NSFileProviderItemIdentifier],
        requestedSize size: CGSize,
        perThumbnailCompletionHandler: @escaping (
            NSFileProviderItemIdentifier,
            Data?,
            Error?
        ) -> Void,
        completionHandler: @escaping (Error?) -> Void
    ) -> Progress {
        // Fetch thumbnails from backend
        // ...
    }
}
```

## Testing

### Simulator Testing

Enable File Provider testing in simulator:

1. Build and run extension
2. In Simulator → Features → Enable File Provider Testing

### Device Testing

1. Enable Developer Mode on device
2. Install provisioning profile with File Provider entitlement
3. Build and run

### Debug Logging

Enable verbose logging:

```swift
#if DEBUG
cfk_ios_init()  // Enables tracing in debug builds
#endif
```

## Troubleshooting

### Common Issues

1. **Extension not appearing in Files**
   - Check entitlements
   - Verify NSExtension configuration in Info.plist
   - Ensure domain is registered

2. **Authentication failures**
   - Check OAuth callback URL scheme
   - Verify token storage

3. **Crashes on launch**
   - Verify static library is linked
   - Check bridging header path
   - Ensure `cfk_ios_init()` is called first

4. **Slow enumeration**
   - Enable caching
   - Implement pagination properly

### Memory Considerations

File Provider extensions have limited memory. Best practices:

- Use streaming for large files
- Implement proper pagination
- Release cached items when memory warnings occur

```swift
override func didReceiveMemoryWarning() {
    // Release non-essential cached data
}
```

## Resources

- [Apple File Provider Documentation](https://developer.apple.com/documentation/fileprovider)
- [WWDC 2017: File Provider Enhancements](https://developer.apple.com/videos/play/wwdc2017/243/)
- [WWDC 2021: Meet the File Provider Replicated Extension](https://developer.apple.com/videos/play/wwdc2021/10182/)
