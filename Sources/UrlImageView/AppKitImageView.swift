#if os(macOS)
import AppKit

public extension NSView {
    public enum ContentMode {
        case scaleAspectFill
        case scaleAspectFit
    }
}

public class AppKitImageView: NSView {

    var contentMode: ContentMode = .scaleAspectFill {
        didSet {
            updateAspect()
        }
    }

    var image: NSImage? {
        didSet {
            layer?.contents = image
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer = CALayer()
        layer?.masksToBounds = true
        wantsLayer = true
        updateAspect()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func updateAspect() {
        layer?.contentsGravity = contentMode == .scaleAspectFill ? .resizeAspectFill : .resizeAspect
    }
}

#endif
