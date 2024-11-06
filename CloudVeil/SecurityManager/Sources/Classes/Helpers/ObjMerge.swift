import ObjectMapper

public class ObjMerge<Key, Value>: TransformType where Key: Hashable {
    public typealias Object = [Key: Value]
    public typealias JSON = [Key: Value]
    public func transformFromJSON(_ value: Any?) -> Object? {
        if let dict = value as? Object {
            return dict
        } else if let dictArray = value as? [Object] {
            var result: Object = [:]

            for dict in dictArray {
                result.merge(dict) { (current, _) in current }
            }

            return result
        }
        return nil
    }
    public func transformToJSON(_ value: Object?) -> JSON? {
        return value
    }
}
