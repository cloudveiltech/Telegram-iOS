//
//  Array+Ext.swift
//  PlannerEvo
//
//  Created by Dmitriy Virych on 10/5/17.
//  Copyright © 2017 Requestum. All rights reserved.
//

import Foundation

extension Sequence where Element == String {
    
    func mostCommon() -> String {
        
        var namesCountDict = [String : Int]()
        for name in self {
            namesCountDict[name] = namesCountDict[name] != nil ? namesCountDict[name]! + 1 : 1
        }
        
        var mostCommonName = ""
        
        for key in namesCountDict.keys {
            
            if mostCommonName == "" {
                mostCommonName = key
            } else if let count = namesCountDict[key], count > namesCountDict[mostCommonName] ?? 0  {
                mostCommonName = key
            }
        }
        
        return mostCommonName
    }
}

extension Sequence where Element == Int {
    
    func sum() -> Int {
        
        var sum = 0
        
        for el in self {
            sum += el
        }
        
        return sum
    }
}

extension MutableCollection where Element == Index {
    
    mutating func shuffle() {
    
        let c = count
        
        guard c > 1 else { return }
        
        for (firstUnshuffled , unshuffledCount) in zip(indices, stride(from: c, to: 1, by: -1)) {
            
            let d: Int = numericCast(arc4random_uniform(numericCast(unshuffledCount)))
           
            guard d != 0 else { continue }
            
            let i = index(firstUnshuffled, offsetBy: d)
            
            self.swapAt(firstUnshuffled, i)
        }
    }
}

extension Array where Element: Hashable {
    
    func sort(withStartElement el: Element) -> [Element] {
        
        var out: [Array.Element] = []
        
        if let index = self.index(where: { $0.hashValue == el.hashValue }) {
            
            out.append(contentsOf: self[index ..< count])
            out.append(contentsOf: self[0 ..< index])
        }
        
        return out.isEmpty ? self : out
    }
}


extension Array {
    
    func chunks(_ chunkSize: Int) -> [[Element]] {
        return stride(from: 0, to: self.count, by: chunkSize).map {
            Array(self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
    }
}

