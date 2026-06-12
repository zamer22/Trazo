import MapKit
import SwiftUI

struct RunningRouteMapView: View {
    var userLocation: CLLocationCoordinate2D?
    var destination: MapDestination?
    var routeCoordinates: [CLLocationCoordinate2D]
    var allowsPlacingPin: Bool = false
    var recenterTrigger: Int = 0
    var onMapTap: ((CLLocationCoordinate2D) -> Void)?
    var onPinDoubleTap: (() -> Void)?

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: .all) {
                UserAnnotation()

                if let destination {
                    Annotation(destination.name, coordinate: destination.coordinate) {
                        if let onPinDoubleTap {
                            DestinationPinView(onDoubleTap: onPinDoubleTap)
                        } else {
                            Image(systemName: "flag.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(TrazoColors.routeTeal)
                                .background(Circle().fill(.white).padding(2))
                        }
                    }
                }

                if !routeCoordinates.isEmpty {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(
                            TrazoColors.routeTeal,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                        )

                    if let start = routeCoordinates.first {
                        Annotation("Inicio", coordinate: start) {
                            Circle()
                                .fill(.white)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(TrazoColors.routeTeal, lineWidth: 3))
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted))
            .onAppear { updateCamera() }
            .onChange(of: destination) { _, _ in updateCamera() }
            .onChange(of: routeCoordinates.count) { _, _ in updateCamera() }
            .onChange(of: recenterTrigger) { _, _ in centerOnUser() }
            .onTapGesture { screenPoint in
                guard allowsPlacingPin, let onMapTap,
                      let coordinate = proxy.convert(screenPoint, from: .local) else { return }
                onMapTap(coordinate)
            }
        }
    }

    private func centerOnUser() {
        guard let userLocation else {
            cameraPosition = .userLocation(fallback: .automatic)
            return
        }

        cameraPosition = .region(MKCoordinateRegion(
            center: userLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    private func updateCamera() {
        if !routeCoordinates.isEmpty {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            let rect = polyline.boundingMapRect
            cameraPosition = .rect(rect.insetBy(dx: -rect.width * 0.25, dy: -rect.height * 0.25))
        } else if let destination {
            cameraPosition = .region(MKCoordinateRegion(
                center: destination.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
        } else if let userLocation {
            cameraPosition = .region(MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
        } else {
            cameraPosition = .automatic
        }
    }
}
