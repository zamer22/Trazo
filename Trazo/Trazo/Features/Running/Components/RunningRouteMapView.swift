import MapKit
import SwiftUI

struct RunningRouteMapView: View {
    var userLocation: CLLocationCoordinate2D?
    var destination: MapDestination?
    var routeCoordinates: [CLLocationCoordinate2D]
    var allowsPlacingPin: Bool = false
    var recenterTrigger: Int = 0
    var destinationFitTrigger: Int = 0
    var mapSize: CGSize = .zero
    var mapEdgePadding: UIEdgeInsets = .zero
    var onMapLongPress: ((CLLocationCoordinate2D) -> Void)?
    var onPinDoubleTap: (() -> Void)?

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasSetInitialCamera = false

    private var canFitWithEdgePadding: Bool {
        mapSize.width > 0 && mapSize.height > 0 && mapEdgePadding.bottom > 0
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: .all) {
                UserAnnotation()

                if let destination {
                    Annotation("", coordinate: destination.coordinate) {
                        if let onPinDoubleTap {
                            DestinationPinView(onDoubleTap: onPinDoubleTap)
                        } else {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(TrazoColors.accentOrange)
                                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
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
            .onAppear { setInitialCameraIfNeeded() }
            .onChange(of: routeCoordinates.count) { _, _ in fitRouteCamera() }
            .onChange(of: mapEdgePadding.bottom) { _, _ in
                fitRouteCamera()
                fitUserAndDestination()
            }
            .onChange(of: mapSize.height) { _, _ in
                fitRouteCamera()
                fitUserAndDestination()
            }
            .onChange(of: destinationFitTrigger) { _, _ in fitUserAndDestination() }
            .onChange(of: userLocation?.latitude) { _, _ in
                if destination != nil, destinationFitTrigger > 0 {
                    fitUserAndDestination()
                }
            }
            .onChange(of: recenterTrigger) { _, _ in centerOnUser() }
            .simultaneousGesture(longPressGesture(proxy: proxy))
        }
    }

    private func longPressGesture(proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onEnded { value in
                guard allowsPlacingPin,
                      let onMapLongPress,
                      case .second(true, let drag?) = value,
                      let coordinate = proxy.convert(drag.location, from: .local) else { return }
                onMapLongPress(coordinate)
            }
    }

    private func setInitialCameraIfNeeded() {
        guard !hasSetInitialCamera else { return }
        hasSetInitialCamera = true

        if !routeCoordinates.isEmpty {
            fitRouteCamera()
        } else if let userLocation {
            cameraPosition = .region(MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            ))
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

    private func fitUserAndDestination() {
        guard destinationFitTrigger > 0,
              let userLocation,
              let destination,
              canFitWithEdgePadding else { return }

        let coordinates = [userLocation, destination.coordinate]
        withAnimation(.easeInOut(duration: 0.45)) {
            cameraPosition = MapCameraFitter.cameraPosition(
                for: coordinates,
                mapSize: mapSize,
                edgePadding: mapEdgePadding
            )
        }
    }

    private func fitRouteCamera() {
        guard !routeCoordinates.isEmpty, canFitWithEdgePadding else { return }

        cameraPosition = MapCameraFitter.cameraPosition(
            for: routeCoordinates,
            mapSize: mapSize,
            edgePadding: mapEdgePadding
        )
    }
}
