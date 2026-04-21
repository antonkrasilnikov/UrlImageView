//
//  CachedImage.swift
//
//  Created by Антон Красильников on 08.03.2022.
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

class CachedImage: Equatable {
    
    let url: String
    var image: SystemImage
    var length: Int
    
    init(url: String,
         image: SystemImage,
         length: Int) {
        self.url = url
        self.image = image
        self.length = length
    }

    init?(url: String, data: Data) {
        guard let image = SystemImage(data: data) else { return nil }
        self.url = url
        self.image = image
        self.length = data.count
    }

    static func == (lhs: CachedImage, rhs: CachedImage) -> Bool {
        lhs.url == rhs.url
    }
}
