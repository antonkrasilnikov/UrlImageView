//
//  ImageLoader.swift
//  Created by Антон Красильников on 07.03.2022.
//

import Foundation
import UIKit

public protocol ImageLoaderListener: AnyObject {
    func imageDidLoad(url: String, image: UIImage)
    func imageDidFail(url: String)
    func imageDidStartLoading(url: String)
}

public extension ImageLoaderListener {
    func imageDidStartLoading(url: String) {}
    func imageDidFail(url: String) {}
}

/// provide remote image loading, keeping images in RAM and storage cache
open class ImageLoader {
    
    // MARK: Inerface
    
    /// add image link to loading queue
    /// - Parameter url: image link to load
    /// - Parameter listener: weak reference of listener
    open class func load(url: String, for listener: ImageLoaderListener) {
        loader.load(url: url, for: listener)
    }
    
    /// unsubscribe listener from notifications
    /// - Parameter listener: reference of listener that should be unsubscribed
    /// - Parameter url: image link. If it's not nil then listener is unsubscribed from notifications about it only.
    open class func remove(listener: ImageLoaderListener, url: String? = nil) {
        loader.remove(listener: listener, url: url)
    }

    /// add image's links to loading queue
    /// - Parameter urls: image's links to load
    /// - Parameter timeout: timeout
    /// - Parameter completion: callback that calls in load completion or timeout
    open class func load(urls: [String], timeout: TimeInterval? = nil, completion: @escaping ([String:UIImage]) -> Void) {
        UrlImageLoader.load(urls: urls, timeout: timeout, completion: completion)
    }
    
    /// get image from RAM cache
    /// - Parameter url: image link
    /// - Returns: image, can be nil
    open class func cachedImage(url: String) -> UIImage? {
        loader.cachedImage(for: url)?.image
    }
    
    /// get image from storage cache
    /// - Parameter url: image link
    /// - Returns: image, can be nil
    open class func loadedImage(url: String) -> UIImage? {
        guard let data = loader.loadCache(url: url) else { return nil }
        return UIImage(data: data)
    }

    /// check if image loaded
    /// - Parameter url: image link
    /// - Returns: bool
    open class func isImageLoaded(url: String) -> Bool {
        loader.isImageLoaded(url: url)
    }

    /// clear cached image
    /// - Parameter url: image link
    open class func clearCache(url: String) {
        loader.clearCached(url: url)
    }

    /// clear all cache
    open class func clearCache() {
        loader.clearCache()
    }

    // MARK: Internal
    
    struct Values {
        static let MAX_LOADING_COUNT     = 5
        static let MAX_IMAGE_CACHE_COUNT = 50
        static let MAX_CACHE_WEIGHT      = 2097152
        
        static var imagesDirectoryPath: String {
            NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                .userDomainMask,
                                                true).first! + "/ImageCache"
        }
    }
    
    static var loader = ImageLoader()
    
    private var listeners: [String:NSPointerArray] = [:]

    private var cachedImages: [CachedImage] = []
    private var toLoadImages: [String] = []
    private var loadingImages: [String] = []
    private let loaderQueue: OperationQueue = {
        $0.qualityOfService = .userInitiated
        $0.maxConcurrentOperationCount = Values.MAX_LOADING_COUNT
        return $0
    }(OperationQueue())
    
    private var cacheSize: Int { cachedImages.reduce(0, { $0 + $1.length }) }

    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(memoryWarningAction),
                                               name: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil)
    }
    
    @objc
    private
    func memoryWarningAction() {
        cachedImages.removeAll()
    }
    
    private func add(listener: ImageLoaderListener, url: String) {
        guard url.count > 0 else { return }
        if let urlListeners = listeners[url] {
            if !urlListeners.contains(listener) {
                listeners[url]?.append(listener)
            }
        }else{
            listeners[url] = NSPointerArray.weakObjects()
            listeners[url]?.append(listener)
        }
    }
    
    private func remove(listener: ImageLoaderListener, url: String? = nil) {
        for url in (url != nil ? [url!] : Array(listeners.keys)) {
            listeners[url]?.remove(listener: listener)
        }
    }

    private func listeners(for url: String) -> [ImageLoaderListener] {
        listeners[url]?.compact()
        return listeners[url]?.allObjects.compactMap({ $0 as? ImageLoaderListener }) ?? []
    }
    
    func cachedImage(for url: String) -> CachedImage? {
        guard let image = cachedImages.first(where: { $0.url == url }) else { return nil }
        // move requested image to top of cache
        cachedImages.removeAll(where: { $0 == image })
        cachedImages.insert(image, at: 0)
        return image
    }
    
    private func notifyImageDidLoad(cachedImage: CachedImage) {
        let urlListeners = listeners(for: cachedImage.url)
        listeners[cachedImage.url] = NSPointerArray.weakObjects()
        urlListeners.forEach({ $0.imageDidLoad(url: cachedImage.url, image: cachedImage.image) })
    }
    
    private func notifyImageDidFail(url: String) {
        let urlListeners = listeners(for: url)
        listeners[url] = NSPointerArray.weakObjects()
        urlListeners.forEach({ $0.imageDidFail(url: url) })
    }
    
    func load(url: String, for listener: ImageLoaderListener) {

        guard URL(string: url) != nil else {
            listener.imageDidFail(url: url)
            return
        }

        // add listener
        add(listener: listener, url: url)
        
        // check if image has been cached
        if let cachedImage = cachedImage(for: url) {
            notifyImageDidLoad(cachedImage: cachedImage)
            return
        }
        
        // check if image has been added to load, else add image to load queue
        if !(toLoadImages + loadingImages).contains(url) {
            toLoadImages.append(url)
            taskUpdate()
        }
        
        listener.imageDidStartLoading(url: url)
    }
    
    private func taskUpdate() {
        // hold image loading in case of max tasks count
        guard
            loadingImages.count < Values.MAX_LOADING_COUNT,
            let url = toLoadImages.last
        else {
            return
        }
        loadingImages.append(url)
        toLoadImages.removeAll(where: { $0 == url })

        let completion: (Data?, _ precreatedImage: UIImage?) -> Void = { data, precreatedImage in
            let cachedImage: CachedImage? =
            if let data, let image = precreatedImage ?? UIImage(data: data) {
                CachedImage(url: url, image: image, length: data.count)
            }else{
                nil
            }
            OperationQueue.main.addOperation { [weak self] in
                guard let self else { return }
                self.loadingImages.removeAll(where: { $0 == url })
                if let cachedImage = cachedImage {
                    self.renewCache(with: cachedImage)
                    self.notifyImageDidLoad(cachedImage: cachedImage)
                }else{
                    self.clearCached(url: url) // clear cache in case if any corrupted data has been saved
                    self.notifyImageDidFail(url: url)
                }
                self.taskUpdate()
            }
        }

        // check if image has been loaded and get it from storage, else start loading
        let operation: ImageLoadOperation
        if isImageLoaded(url: url) {
            operation = .init(block: { finishCallback in
                completion(self.loadCache(url: url),nil)
                finishCallback()
            })
        }else{
            operation = .init(block: { finishCallback in
                self.load(url: url) { [weak self] data in
                    defer { finishCallback() }
                    guard let self else { return }
                    guard let data, let image = UIImage(data: data) else {
                        completion(nil,nil)
                        return
                    }
                    self.cache(data: data, url: url)
                    completion(data,image)
                }
            })
        }
        loaderQueue.addOperation(operation)
    }
    
    func isImageLoaded(url: String) -> Bool {
        FileManager.default.fileExists(atPath: cachePath(for: url))
    }
    
    private func renewCache(with cachedImage: CachedImage) {
        if !cachedImages.contains(cachedImage) {
            // check if cache's max size has reached and pop useless one
            if cachedImages.count > Values.MAX_IMAGE_CACHE_COUNT || cacheSize > Values.MAX_CACHE_WEIGHT {
                cachedImages.removeLast()
            }else{
                cachedImages.removeAll(where: { $0 == cachedImage })
            }
            cachedImages.insert(cachedImage, at: 0)
        }
    }
    
    private func cache(data: Data, url: String) {
        if !FileManager.default.fileExists(atPath: Values.imagesDirectoryPath) {
            do {
                try FileManager.default.createDirectory(at: URL(fileURLWithPath: Values.imagesDirectoryPath),
                                                        withIntermediateDirectories: false,
                                                        attributes: nil)
            } catch {
                return
            }
        }
        try? data.write(to: URL(fileURLWithPath: cachePath(for: url)))
    }
    
    func loadCache(url: String) -> Data? {
        let path = cachePath(for: url)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return FileManager.default.contents(atPath: path)
    }
    
    func load(url: String, completion: @escaping (Data?) -> Void) {
        guard let URL = URL(string: url) else { completion(nil); return }
        URLSession.shared.dataTask(with: URLRequest(url: URL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)) { (data, _, _) in
            completion(data)
        }.resume()
    }

    private func cachePath(for url: String) -> String {
        Values.imagesDirectoryPath + "/\((url as NSString).hash)"
    }

    func clearCached(url: String) {
        cachedImages.removeAll(where: { $0.url == url })
        let path = cachePath(for: url)
        guard FileManager.default.fileExists(atPath: path) else { return; }
        try? FileManager.default.removeItem(atPath: path)
    }

    func clearCache() {
        cachedImages.removeAll()
        guard FileManager.default.fileExists(atPath: Values.imagesDirectoryPath) else { return }
        try? FileManager.default.removeItem(atPath: Values.imagesDirectoryPath)
    }
}

// NSPointerArray extension to avoid listener retaining
extension NSPointerArray {
    func append(_ listener: ImageLoaderListener) {
        let pointer = Unmanaged.passUnretained(listener as AnyObject).toOpaque()
        addPointer(pointer)
    }
    
    func removeListener(at index: Int) {
        guard index < count else { return }
        removePointer(at: index)
    }
    
    func remove(listener: ImageLoaderListener) {
        guard let index = allObjects.firstIndex(where: { ($0 as? ImageLoaderListener) === listener }) else { return }
        removeListener(at: index)
    }
    
    func contains(_ listener: ImageLoaderListener) -> Bool {
        allObjects.contains(where: { ($0 as? ImageLoaderListener) === listener })
    }
}
