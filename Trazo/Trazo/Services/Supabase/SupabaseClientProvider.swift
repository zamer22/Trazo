import Foundation

#if canImport(Supabase)
import Supabase
#endif

@MainActor
enum SupabaseClientProvider {
    #if canImport(Supabase)
    static let shared: SupabaseClient? = {
        guard let url = SupabaseConfig.url,
              let anonKey = SupabaseConfig.anonKey else {
            return nil
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }()
    #else
    static let shared: Any? = nil
    #endif

    static var isAvailable: Bool {
        #if canImport(Supabase)
        shared != nil
        #else
        false
        #endif
    }
}
