import Foundation

enum SupabaseConfig {
    static var url: URL? {
        string(for: "SupabaseURL").flatMap(URL.init(string:))
    }

    static var anonKey: String? {
        string(for: "SupabaseAnonKey")
    }

    static var isConfigured: Bool {
        url != nil && anonKey != nil
    }

    private static func string(for key: String) -> String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !value.isEmpty,
           !value.hasPrefix("YOUR_") {
            return value
        }

        if let secretsURL = Bundle.main.url(forResource: "SupabaseSecrets", withExtension: "plist"),
           let data = try? Data(contentsOf: secretsURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
           let value = plist[key],
           !value.isEmpty,
           !value.hasPrefix("YOUR_") {
            return value
        }

        return nil
    }
}
