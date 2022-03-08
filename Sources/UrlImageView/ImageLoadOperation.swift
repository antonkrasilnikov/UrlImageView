//
//  ImageLoadOperation.swift
//
//  Created by Антон Красильников on 08.03.2022.
//

import Foundation

class ImageLoadOperation: Operation {

    public typealias AsyncBlock = (@escaping () -> Void) -> Void

    open override var isAsynchronous: Bool {
        return true
    }

    var block: AsyncBlock

    public init(block: @escaping AsyncBlock) {
        self.block = block
        super.init()
    }

    var _isFinished: Bool = false

    open override var isFinished: Bool {
        set {
            willChangeValue(forKey: "isFinished")
            _isFinished = newValue
            didChangeValue(forKey: "isFinished")
        }

        get {
            return _isFinished
        }
    }

    var _isExecuting: Bool = false

    open override var isExecuting: Bool {
        set {
            willChangeValue(forKey: "isExecuting")
            _isExecuting = newValue
            didChangeValue(forKey: "isExecuting")
        }

        get {
            return _isExecuting
        }
    }

    open override func start() {
        isExecuting = true

        block{
            self.isExecuting = false
            self.isFinished = true
        }

    }
}
