import Foundation
import UIKit

class UrlImageLoader: NSObject {

    private static var _instances: [UrlImageLoader] = []

    class func load(urls: [String], timeout: TimeInterval? = nil, completion: @escaping ([String:UIImage]) -> Void) {
        let instance = UrlImageLoader()
        _instances.append(instance)
        instance.load(urls: urls, timeout: timeout, completion: completion)
    }

    private var imageDct: [String:UIImage] = [:]
    private var failedUrls: [String] = []
    private var urls: [String] = []
    private var completion: (([String:UIImage]) -> Void)? {
        didSet {
            if completion == nil {
                Self._instances.removeAll(where: { $0 === self })
            }
        }
    }
    private var timeout: TimeInterval?
    private var timer: Timer?

    deinit {
        ImageLoader.remove(listener: self)
    }

    func load(urls: [String], timeout: TimeInterval? = nil, completion: @escaping ([String:UIImage]) -> Void) {
        self.urls = urls
        self.completion = completion
        self.timeout = timeout
        if let timeout = timeout {
            timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(timerAction), userInfo: nil, repeats: false)
        }
        load()
    }

    private func isImageCashed(for url: String) -> Bool {

        guard imageDct[url] == nil else {
            return true
        }

        if let image = ImageLoader.loadedImage(url: url) {
            imageDct[url] = image
            return true
        }

        return false
    }

    private func load() {

        for url in urls {
            if !isImageCashed(for: url) {
                ImageLoader.load(url: url, for: self)
            }
        }

        _notifyIfNeeded()
    }

    private func resetTimoutTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func loadedImages() -> (Bool, [String:UIImage]) {
        var dct: [String:UIImage] = [:]

        var isLoaded = true

        urls.forEach({
            if let image = imageDct[$0] {
                dct[$0] = image
            }else if !failedUrls.contains($0) {
                isLoaded = isLoaded && false
            }
        })

        return (isLoaded,dct)
    }

    @objc private func timerAction() {

        resetTimoutTimer()

        ImageLoader.remove(listener: self)

        let (_, dct) = loadedImages()

        if let completion = completion {
            self.completion = nil
            completion(dct)
        }
    }

    private func _notifyIfNeeded() {
        let (isLoaded, dct) = loadedImages()

        if isLoaded, let completion = completion {
            self.completion = nil
            resetTimoutTimer()
            completion(dct)
        }
    }
}

extension UrlImageLoader: ImageLoaderListener {
    func imageDidLoad(url: String, image: UIImage) {
        ImageLoader.remove(listener: self, url: url)
        imageDct[url] = image
        _notifyIfNeeded()
    }
    func imageDidFail(url: String) {
        ImageLoader.remove(listener: self, url: url)
        failedUrls.append(url)
        _notifyIfNeeded()
    }
    func imageDidStartLoading(url: String) {}
}
