import Foundation
import MapKit

@MainActor
@Observable
final class AddressSearchService: NSObject {
    var query = "" {
        didSet {
            completer.queryFragment = query
            if query.isEmpty {
                results = []
            }
        }
    }

    var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func resolve(_ completion: MKLocalSearchCompletion) async throws -> MapDestination {
        let request = MKLocalSearch.Request(completion: completion)
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first,
              let coordinate = item.placemark.location?.coordinate else {
            throw RouteCalculatorError.noRouteFound
        }

        let name = [completion.title, completion.subtitle]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        return MapDestination(name: name.isEmpty ? "Destino" : name, coordinate: coordinate)
    }
}

extension AddressSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            results = completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            results = []
        }
    }
}
