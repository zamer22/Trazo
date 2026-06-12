import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://lxibsnekdwzyqxbsymnj.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx4aWJzbmVrZHd6eXF4YnN5bW5qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyMzI5MTQsImV4cCI6MjA5NjgwODkxNH0.cznF6GiL935L5Gq997KLY-yD4yEjO7lR_plPpcJV0Vo"
}

enum SupabaseService {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
}
