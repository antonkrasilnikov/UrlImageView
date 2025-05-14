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
        if let data = loader.loadCache(url: url) {
            return UIImage(data: data)
        }
        return nil
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
    
    var listeners: [String:NSPointerArray] = [:]
    
    var cachedImages: [CachedImage] = []
    var toLoadImages: [String] = []
    var loadingImages: [String] = []
    let loaderQueue: OperationQueue = {
        $0.qualityOfService = .userInitiated
        $0.maxConcurrentOperationCount = Values.MAX_LOADING_COUNT
        return $0
    }(OperationQueue())
    
    var _cacheSize = 0
    
    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(memoryWarningAction),
                                               name: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil)
    }
    
    @objc
    func memoryWarningAction() {
        cachedImages.removeAll()
        _cacheSize = 0
    }
    
    func add(listener: ImageLoaderListener, url: String) {
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
    
    func remove(listener: ImageLoaderListener, url: String? = nil) {
        for url in (url != nil ? [url!] : Array(listeners.keys)) {
            listeners[url]?.remove(listener: listener)
        }
    }

    func listeners(for url: String) -> [ImageLoaderListener] {
        listeners[url]?.compact()
        return listeners[url]?.allObjects.compactMap({ $0 as? ImageLoaderListener }) ?? []
    }
    
    func cachedImage(for url: String) -> CachedImage? {
        if let image = cachedImages.first(where: { $0.url == url }) {
            // move requested image to top of cache
            cachedImages.removeAll(where: { $0 == image })
            cachedImages.insert(image, at: 0)
            
            return image
        }
        return nil
    }
    
    func notifyImageDidLoad(cachedImage: CachedImage) {
        let urlListeners = listeners(for: cachedImage.url)
        listeners[cachedImage.url] = NSPointerArray.weakObjects()
        urlListeners.forEach({ $0.imageDidLoad(url: cachedImage.url, image: cachedImage.image) })
    }
    
    func notifyImageDidFail(url: String) {
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
    
    func taskUpdate() {
        
        // hold image loading in case of max tasks count
        guard
            loadingImages.count < Values.MAX_LOADING_COUNT,
            let url = toLoadImages.last
        else {
            return
        }
        
        loadingImages.append(url)
        toLoadImages.removeAll(where: { $0 == url })
        
        let completion: (Data?) -> Void = { data in
            
            let cachedImage: CachedImage?
            
            if let data = data, let image = UIImage(data: data) {
                cachedImage = .init(url: url, image: image, length: data.count)
            }else{
                cachedImage = nil
            }
            
            OperationQueue.main.addOperation { [weak self] in
                
                guard let self = self else { return }
                
                self.loadingImages.removeAll(where: { $0 == url })
                
                if let cachedImage = cachedImage {
                    self.renewCache(with: cachedImage)
                    self.notifyImageDidLoad(cachedImage: cachedImage)
                }else{
                    self.notifyImageDidFail(url: url)
                }
                self.taskUpdate()
            }
            
        }
        
        let operation: ImageLoadOperation
        
        // check if image has been loaded and get it from storage, else start loading
        if isImageLoaded(url: url) {
            operation = .init(block: { finishCallback in
                completion(self.loadCache(url: url))
                finishCallback()
            })
        }else{
            operation = .init(block: { finishCallback in
                self.load(url: url) { [weak self] data in
                    
                    guard let self = self else { finishCallback(); return }
                    
                    if let data = data {
                        self.cache(data: data, url: url)
                    }
                    
                    completion(data)
                    finishCallback()
                }
            })
        }
        
        loaderQueue.addOperation(operation)
    }
    
    func isImageLoaded(url: String) -> Bool {
        FileManager.default.fileExists(atPath: cachePath(for: url))
    }
    
    func renewCache(with cachedImage: CachedImage) {
        if !cachedImages.contains(cachedImage) {
            // check if max cache's max size has reached and pop useless one
            if cachedImages.count > Values.MAX_IMAGE_CACHE_COUNT || _cacheSize > Values.MAX_CACHE_WEIGHT {
                let imageToRemove = cachedImages.last!
                _cacheSize -= imageToRemove.length
                cachedImages.removeLast()
            }else{
                _cacheSize -= cachedImage.length
                cachedImages.removeAll(where: { $0 == cachedImage })
            }
            cachedImages.insert(cachedImage, at: 0)
            _cacheSize += cachedImage.length
        }
    }
    
    func cache(data: Data, url: String) {
        
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
        guard FileManager.default.fileExists(atPath: path) else {
            return nil;
        }
        
        return FileManager.default.contents(atPath: path)
    }
    
    func load(url: String, completion: @escaping (Data?) -> Void) {
        
        guard let URL = URL(string: url) else { completion(nil); return }
        
        let request = URLRequest(url: URL)
        
        URLSession.shared.dataTask(with: request) { (data, _, _) in
            completion(data)
        }.resume()
    }

    func cachePath(for url: String) -> String {
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
        _cacheSize = 0
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
    
    func remove(listener: AnyObject) {
        if let index = allObjects.firstIndex(where: { obj in
            if let obj = obj as? ImageLoaderListener, listener === obj {
                return true
            }
            return false
        }) {
            removeListener(at: index)
        }
    }
    
    func contains(_ listener: ImageLoaderListener) -> Bool {
        allObjects.contains(where: { obj in
            if let obj = obj as? ImageLoaderListener, listener === obj {
                return true
            }
            return false
        })
    }

}
