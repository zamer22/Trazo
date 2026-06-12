import CoreLocation
import Foundation

struct RecentSearch: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    func asMapDestination() -> MapDestination {
        let name = [title, subtitle]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return MapDestination(
            name: name.isEmpty ? "Destino" : name,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
    }
}

@MainActor
@Observable
final class SearchHistoryStore {
    private(set) var items: [RecentSearch] = []

    private let maxCount = 10
    private let storageKey = "trazo.searchHistory"

    init() {
        load()
    }

    func add(destination: MapDestination, title: String, subtitle: String = "") {
        let resolvedTitle = title.isEmpty ? destination.name : title
        let entry = RecentSearch(
            id: UUID(),
            title: resolvedTitle,
            subtitle: subtitle,
            latitude: destination.coordinate.latitude,
            longitude: destination.coordinate.longitude
        )

        items.removeAll { existing in
            isSameLocation(existing, entry) || existing.title == entry.title
        }
        items.insert(entry, at: 0)
        items = Array(items.prefix(maxCount))
        save()
    }

    private func isSameLocation(_ lhs: RecentSearch, _ rhs: RecentSearch) -> Bool {
        let a = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
        let b = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)
        return a.distance(from: b) < 80
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([RecentSearch].self, from: data) else {
            return
        }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
