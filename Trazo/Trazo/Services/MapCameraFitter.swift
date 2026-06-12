import CoreLocation
import MapKit
import SwiftUI

enum MapCameraFitter {
    static func cameraPosition(
        for coordinates: [CLLocationCoordinate2D],
        mapSize: CGSize,
        edgePadding: UIEdgeInsets
    ) -> MapCameraPosition {
        guard mapSize.width > 0, mapSize.height > 0 else { return .automatic }

        let rect = boundingRect(for: coordinates)
        let mapView = MKMapView(frame: CGRect(origin: .zero, size: mapSize))
        mapView.setVisibleMapRect(rect, edgePadding: edgePadding, animated: false)
        return .region(mapView.region)
    }

    private static func boundingRect(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        guard !coordinates.isEmpty else { return .world }

        if coordinates.count == 1, let point = coordinates.first {
            let mapPoint = MKMapPoint(point)
            let meters: Double = 350
            let mapPoints = meters * MKMapPointsPerMeterAtLatitude(point.latitude)
            return MKMapRect(
                x: mapPoint.x - mapPoints,
                y: mapPoint.y - mapPoints,
                width: mapPoints * 2,
                height: mapPoints * 2
            )
        }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        var rect = polyline.boundingMapRect

        let minMeters: Double = 250
        if let first = coordinates.first {
            let minPoints = minMeters * MKMapPointsPerMeterAtLatitude(first.latitude)
            if rect.width < minPoints {
                rect = rect.insetBy(dx: -(minPoints - rect.width) / 2, dy: 0)
            }
            if rect.height < minPoints {
                rect = rect.insetBy(dx: 0, dy: -(minPoints - rect.height) / 2)
            }
        }

        return rect
    }
}
