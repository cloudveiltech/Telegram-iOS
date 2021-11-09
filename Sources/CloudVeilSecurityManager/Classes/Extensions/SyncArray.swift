
import Foundation
import ObjectMapper

public class SyncArray<T> {
    public var array: [T] = []
    private let accessQueue = DispatchQueue(label: "SynchronizedArrayAccess", attributes: .concurrent)

    init() {}
    
    init(_ from: [T]) {
        self.array.append(contentsOf: from)
    }
    
    public func append(_ newElement: T) {
        self.accessQueue.async(flags:.barrier) {
            self.array.append(newElement)
        }
    }

    public func removeAtIndex(index: Int) {
        self.accessQueue.async(flags:.barrier) {
            self.array.remove(at: index)
        }
    }
    
    public var count: Int {
        var count = 0

        self.accessQueue.sync {
            count = self.array.count
        }

        return count
    }

    public func first() -> T? {
        var element: T?

        self.accessQueue.sync {
            if !self.array.isEmpty {
                element = self.array[0]
            }
        }

        return element
    }

    public subscript(index: Int) -> T {
        set {
            self.accessQueue.async(flags:.barrier) {
                self.array[index] = newValue
            }
        }
        get {
            var element: T!
            self.accessQueue.sync {
                element = self.array[index]
            }

            return element
        }
    }
    
    public func firstIndex(where predicate: ((T) -> Bool)) -> Int? {
        var index: Int? = nil
        self.accessQueue.sync {
            for i in 0...array.count {
                let whereResult = predicate(array[i])
                if  whereResult {
                    index = i
                    break
                }
            }
        }
        
        return index
    }
}
