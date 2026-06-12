import Foundation

enum DeepLinkRouter {
    static func inviteCode(from url: URL) -> String? {
        let scheme = url.scheme?.lowercased()

        if scheme == "trazo", url.host?.lowercased() == "join" {
            return codeFromPath(url.path)
        }

        if scheme == "https" || scheme == "http" {
            let host = url.host?.lowercased()
            guard host == "trazo.app" || host == "www.trazo.app" else { return nil }

            let components = url.pathComponents.filter { $0 != "/" }
            guard components.count >= 2, components[0].lowercased() == "join" else { return nil }
            return components[1].removingPercentEncoding
        }

        return nil
    }

    private static func codeFromPath(_ path: String) -> String? {
        let code = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return code.isEmpty ? nil : code.removingPercentEncoding
    }
}
