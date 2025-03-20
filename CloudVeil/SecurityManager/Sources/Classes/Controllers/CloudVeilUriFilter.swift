import Foundation

public struct CloudVeilUriFilter {
    private static let ignoredSchemesAndPaths: [String] = [
        "tg://addemoji",
        "tg://addlist",
        "tg://addstickers",
        "tg://folder"
    ]

    private static let ignoredSchemes: Set<String> = [
        "tonsite"
    ]

    private static let ignoredPaths: Set<String> = [
        "addemoji",
        "addlist",
        "addstickers",
        "folder"
    ]

    private static let ignoredDomains: [String] = [
        ".ton"
    ]

    public static func shouldIgnoreURLString(_ url: String) -> Bool {
        guard let uri = URL(string: url) else {
            return false
        }
        return shouldIgnoreURL(uri)
    }

    public static func shouldIgnoreURL(_ url: URL) -> Bool {
        if let scheme = url.scheme?.lowercased(), ignoredSchemes.contains(scheme) {
            return true
        }

        // Check if the URI matches any of the ignoredSchemesAndPaths
        let uriString = url.absoluteString
        if ignoredSchemesAndPaths.contains(where: { uriString.hasPrefix($0) }) {
            return true
        }

        // Ignore ".ton" domains
        if let host = url.host?.lowercased(), ignoredDomains.contains(where: { host.hasSuffix($0) }) {
            return true
        }

        // Ignore paths that are in the ignoredPaths list
        let path = url.path.lowercased().replacingOccurrences(of: "/", with: "")
        if ignoredPaths.contains(where: { path.starts(with: $0) }) {
            return true
        }

        return false
    }
}
