//
//  CachedImage.swift
//
//  Created by Антон Красильников on 08.03.2022.
//

import Foundation
import UIKit

class CachedImage: Equatable {
    
    let url: String
    var image: UIImage
    var length: Int
    
    init(url: String,
         image: UIImage,
         length: Int) {
        self.url = url
        self.image = image
        self.length = length
    }

    init?(url: String, data: Data) {
        guard let image = UIImage(data: data) else { return nil }
        self.url = url
        self.image = image
        self.length = data.count
    }

    static func == (lhs: CachedImage, rhs: CachedImage) -> Bool {
        lhs.url == rhs.url
    }
}
