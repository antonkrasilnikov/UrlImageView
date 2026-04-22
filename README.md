# UrlImageView

**UrlImageView** is a lightweight cross-platform (iOS / macOS) image view for loading and displaying remote images with caching support.

It also includes a SwiftUI wrapper — **CachedAsyncImage** — for seamless integration into SwiftUI apps.

---

## ✨ Features

- Async image loading from URL
- Built-in caching support
- Optional synchronous cache rendering
- Placeholder support
- UIKit / AppKit compatible
- SwiftUI wrapper included
- Minimal and dependency-free

---

## 📦 Installation (Swift Package Manager)

```swift
.package(url: "https://github.com/yourname/UrlImageView.git", from: "1.0.0")
```

---

## 🚀 UIKit / AppKit Usage

### Basic Example

```swift
let imageView = UrlImageView()
imageView.url = "https://example.com/image.png"
```

---

### With Placeholder

```swift
imageView.placeholder = UIImage(named: "placeholder")
imageView.url = "https://example.com/image.png"
```

---

### Synchronous Cache Loading

```swift
imageView.syncStorageLoad = true
imageView.url = "https://example.com/image.png"
```

📌 When enabled:

- First tries in-memory cache
- Then tries already loaded images
- Falls back to async loading

---

## ⚙️ UrlImageView API

### Properties

```swift
public var url: String?
public var placeholder: SystemImage? (UIImage | NSImage)
public var syncStorageLoad: Bool
```

---

### Behavior

- Automatically cancels previous requests when `url` changes
- Displays `placeholder` while loading or if image is `nil`
- Ensures correct image assignment for reused views

---

## 🧩 SwiftUI: CachedAsyncImage

`CachedAsyncImage` is a SwiftUI wrapper around `UrlImageView`.

---

### Basic Usage

```swift
CachedAsyncImage(
    url: "https://example.com/image.png"
)
```

---

### Content Mode

```swift
CachedAsyncImage(
    url: "https://example.com/image.png",
    contentMode: .fill
)
```

Supported modes:

- `.fit` (default)
- `.fill`

---

## ⚙️ CachedAsyncImage API

```swift
init(
    url: String,
    contentMode: ContentMode = .fit
)
```

---

## 🧠 How It Works

- `CachedAsyncImage` wraps a UIKit/AppKit view (`UrlImageView`)
- Internally uses `UIViewRepresentable` / `NSViewRepresentable`
- Updates are applied by setting the `url` property
- Layout is handled automatically via SwiftUI

---

## ⚡ Behavior Details

- Image view resizes to fit container
- `clipsToBounds = true` by default
- Reuses underlying `UrlImageView` instance
- Automatically updates when `url` changes



---

## 📱 Platforms

- iOS
- macOS
- SwiftUI
- UIKit / AppKit

---

## 📄 License

MIT
