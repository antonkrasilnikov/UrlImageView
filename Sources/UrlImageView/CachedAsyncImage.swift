import Foundation
import SwiftUI

#if os(iOS)
typealias ViewRepresentable = UIViewRepresentable
#elseif os(macOS)
typealias ViewRepresentable = NSViewRepresentable
#endif

public struct CachedAsyncImage: ViewRepresentable {
    let url: String
    let contentMode: ContentMode

    public init(url: String, contentMode: ContentMode = .fit) {
        self.url = url
        self.contentMode = contentMode
    }

    private func make(context: Context) -> ContentView {
        {
            $0.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
#if os(iOS)
            $0.isUserInteractionEnabled = true
#endif
            return $0
        }(ContentView())
    }

    private func update(_ uiView: ContentView, context: Context) {
        uiView.url = url
    }

#if os(iOS)
    public func makeUIView(context: Context) -> some ContentView {
        make(context: context)
    }

    public func updateUIView(_ uiView: UIViewType, context: Context) {
        update(uiView, context: context)
    }
#elseif os(macOS)
    public func makeNSView(context: Context) -> some ContentView {
        make(context: context)
    }

    public func updateNSView(_ nsView: NSViewType, context: Context) {
        update(nsView, context: context)
    }
#endif
}

public extension CachedAsyncImage {
    class ContentView: SystemView {
        var url: String? { didSet { iconView.url = url } }

        let iconView = UrlImageView()

#if os(iOS)
        public override var contentMode: SystemView.ContentMode { didSet { iconView.contentMode = contentMode } }
#elseif os(macOS)
        public var contentMode: SystemView.ContentMode = .scaleAspectFill { didSet { iconView.contentMode = contentMode } }
#endif
        private func setup() {
            
            clipsToBounds = true
            addSubview(iconView)
            iconView.clipsToBounds = true
            iconView.frame = bounds
        }

#if os(iOS)
        public override func didMoveToSuperview() {
            super.didMoveToSuperview()
            setup()
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            iconView.frame = bounds
        }
#elseif os(macOS)
        public override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            setup()
        }

        public override func layout() {
            super.layout()
            iconView.frame = bounds
        }
#endif
    }
}
