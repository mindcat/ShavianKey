//
//  Utils.swift
//  KeyBoard
//
//  Created by koteczek on 10/28/25.
//

import Foundation

// credit: https://stackoverflow.com/a/47081889
struct BidiMap<F: Hashable, T: Hashable> {

    public let forward: [F: T]

    public let backward: [T: F]

    public var count: Int {
        return forward.count
    }
    
    init?(_ dict: [F: T] = [:]) {
        self.init(Array(dict))
    }
    
    init?(_ values: [(F, T)]) {
        let forwardKeys = values.map { $0.0 }
        if Set(forwardKeys).count != forwardKeys.count {
            print("BidiMap init failed: Duplicate keys (F) found.")
            return nil
        }
        
        let backwardKeys = values.map { $0.1 }
        if Set(backwardKeys).count != backwardKeys.count {
            print("BidiMap init failed: Duplicate values (T) found.")
            return nil
        }
        
        self.forward = [F: T](uniqueKeysWithValues: values)
        
        let backwardValues = values.map { ($0.1, $0.0) }
        self.backward = [T: F](uniqueKeysWithValues: backwardValues)
    }

    subscript(_ key: F) -> T? {
        return forward[key]
    }

    subscript(_ key: T) -> F? {
        return backward[key]
    }

    subscript(to key: T) -> F? {
        return backward[key]
    }

    subscript(from key: F) -> T? {
        return forward[key]
    }
}
