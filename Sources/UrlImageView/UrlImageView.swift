//
//  UrlImageView.swift
//
//  Created by Антон Красильников on 07.03.2022.
//

import Foundation
import UIKit

/// remote image render view
/// ```
///let imageView = UrlImageView()
///imageView.url = "https://file-examples-com.github.io/uploads/2017/10/file_example_PNG_500kB.png"
/// ```

public class UrlImageView: UIImageView, ImageLoaderListener {
    
    /// placeholder image shown in load
    public var placeholder: UIImage? {
        didSet {
            guard image == nil else { return }
            image = placeholder
        }
    }
    
    /// set true if it's needed to synchronously render image from cache
    public var syncStorageLoad: Bool = false
    
    /// image link
    public var url: String? {
        didSet {
            
            guard oldValue != self.url else { return }
            if let oldValue = oldValue {
                ImageLoader.remove(listener: self, url: oldValue)
            }
            guard let url = self.url else { image = nil; return }
            
            if syncStorageLoad {
                if let image = ImageLoader.cachedImage(url: url) {
                    self.image = image
                    return
                }
                if let image = ImageLoader.loadedImage(url: url) {
                    self.image = image
                    return
                }
            }
            
            image = nil
            ImageLoader.load(url: url, for: self)
        }
    }
    
    public override var image: UIImage? {
        set {
            super.image = newValue ?? placeholder
        }
        get {
            super.image
        }
    }
    
    deinit {
        ImageLoader.remove(listener: self)
    }
    
    public func imageDidLoad(url imageUrl: String, image: UIImage) {
        ImageLoader.remove(listener: self, url: imageUrl)
        
        guard imageUrl == url else { return }
        
        self.image = image
    }
    
}
