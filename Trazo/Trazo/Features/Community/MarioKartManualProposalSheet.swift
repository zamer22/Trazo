import CoreLocation
import MapKit
import SwiftUI

struct MarioKartManualProposalSheet: View {
    @Environment(\.dismiss) private var dismiss

    let userLocation: CLLocationCoordinate2D?
    let profile: UserProfile?
    let onPropose: (RoutePlan) -> Void

    enum Modo: String, CaseIterable {
        case circular   = "Ida y vuelta por distancia"
        case soloIda    = "Solo ida por distancia"
        case destino    = "Hacia un destino"
        case pin        = "Pin en el mapa"
    }

    @State private var modo: Modo = .circular
    @State private var distanciaKm: Double = 5.0
    @State private var esIdaVueltaDestino = false
    @State private var searchService = AddressSearchService()
    @State private var destinoSeleccionado: MapDestination?
    @State private var pinCoordenada: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var cargando = false
    @State private var errorMsg: String?
    @State private var mostrarBuscador = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
                    encabezado
                    modoPicker
                    contenidoModo
                    if let errorMsg {
                        Text(errorMsg)
                            .font(TrazoTypography.caption())
                            .foregroundStyle(.red)
                    }
                    botonProponer
                }
                .padding(TrazoSpacing.xl)
            }
            .background(TrazoColors.background)
            .navigationBarHidden(true)
            .sheet(isPresented: $mostrarBuscador) {
                MarioKartLocationSearchSheet(
                    searchService: searchService,
                    onSelect: { destino in
                        destinoSeleccionado = destino
                        mostrarBuscador = false
                    }
                )
                .presentationDetents([.large])
                .presentationCornerRadius(TrazoRadius.lg)
                .presentationBackground(TrazoColors.background)
            }
            .onAppear {
                if let loc = userLocation {
                    searchService.setRegion(center: loc)
                    cameraPosition = .region(MKCoordinateRegion(
                        center: loc,
                        latitudinalMeters: 3000, longitudinalMeters: 3000
                    ))
                }
            }
        }
    }

    private var encabezado: some View {
        HStack {
            Text("Proponer Trazo")
                .font(TrazoTypography.title())
                .foregroundStyle(TrazoColors.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(TrazoColors.textSecondary)
            }
        }
    }

    private var modoPicker: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            Text("Tipo de Trazo")
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TrazoSpacing.sm) {
                ForEach(Modo.allCases, id: \.self) { m in
                    Button {
                        modo = m
                        errorMsg = nil
                    } label: {
                        VStack(spacing: TrazoSpacing.xs) {
                            Image(systemName: iconoModo(m))
                                .font(.title3)
                            Text(m.rawValue)
                                .font(TrazoTypography.caption())
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TrazoSpacing.md)
                        .background(modo == m ? TrazoColors.routeTeal : TrazoColors.surface)
                        .foregroundStyle(modo == m ? .white : TrazoColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
                    }
                }
            }
        }
    }

    private func iconoModo(_ m: Modo) -> String {
        switch m {
        case .circular:  return "arrow.triangle.2.circlepath"
        case .soloIda:   return "arrow.right"
        case .destino:   return "magnifyingglass"
        case .pin:       return "mappin.and.ellipse"
        }
    }

    @ViewBuilder
    private var contenidoModo: some View {
        switch modo {
        case .circular, .soloIda:
            distanciaSlider
        case .destino:
            destinoSection
        case .pin:
            pinSection
        }
    }

    private var distanciaSlider: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            HStack {
                Text("Distancia")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)
                Spacer()
                Text(String(format: "%.1f km", distanciaKm))
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.routeTeal)
            }
            Slider(value: $distanciaKm, in: 1...20, step: 0.5)
                .tint(TrazoColors.routeTeal)
            HStack {
                ForEach([3.0, 5.0, 10.0, 15.0], id: \.self) { d in
                    Button {
                        distanciaKm = d
                    } label: {
                        Text("\(Int(d)) km")
                            .font(TrazoTypography.caption())
                            .foregroundStyle(distanciaKm == d ? .white : TrazoColors.textSecondary)
                            .padding(.horizontal, TrazoSpacing.md)
                            .padding(.vertical, TrazoSpacing.sm)
                            .background(distanciaKm == d ? TrazoColors.routeTeal : TrazoColors.surface)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(TrazoSpacing.lg)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
    }

    private var destinoSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            Button { mostrarBuscador = true } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(TrazoColors.textSecondary)
                    Text(destinoSeleccionado?.name ?? "Buscar dirección")
                        .font(TrazoTypography.body())
                        .foregroundStyle(destinoSeleccionado == nil ? TrazoColors.textSecondary : TrazoColors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(TrazoSpacing.md)
                .background(TrazoColors.background)
                .clipShape(Capsule())
            }

            if destinoSeleccionado != nil {
                togglesIdaVuelta
            }
        }
        .padding(TrazoSpacing.lg)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
    }

    private var pinSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            Text("Mantén presionado en el mapa para colocar el pin")
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.textSecondary)

            MapReader { proxy in
                Map(position: $cameraPosition) {
                    UserAnnotation()
                    if let coord = pinCoordenada {
                        Annotation("", coordinate: coord) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(TrazoColors.accentOrange)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                        .onEnded { value in
                            if case .second(true, let drag?) = value,
                               let coord = proxy.convert(drag.location, from: .local) {
                                pinCoordenada = coord
                            }
                        }
                )
            }

            if pinCoordenada != nil {
                togglesIdaVuelta
            }
        }
        .padding(TrazoSpacing.lg)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
    }

    private var togglesIdaVuelta: some View {
        HStack(spacing: TrazoSpacing.sm) {
            Button {
                esIdaVueltaDestino = false
            } label: {
                Label("Solo ida", systemImage: "arrow.right")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(!esIdaVueltaDestino ? .white : TrazoColors.textSecondary)
                    .padding(.horizontal, TrazoSpacing.md)
                    .padding(.vertical, TrazoSpacing.sm)
                    .background(!esIdaVueltaDestino ? TrazoColors.routeTeal : TrazoColors.background)
                    .clipShape(Capsule())
            }
            Button {
                esIdaVueltaDestino = true
            } label: {
                Label("Ida y vuelta", systemImage: "arrow.left.arrow.right")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(esIdaVueltaDestino ? .white : TrazoColors.textSecondary)
                    .padding(.horizontal, TrazoSpacing.md)
                    .padding(.vertical, TrazoSpacing.sm)
                    .background(esIdaVueltaDestino ? TrazoColors.routeTeal : TrazoColors.background)
                    .clipShape(Capsule())
            }
        }
    }

    private var botonProponer: some View {
        TrazoButton(
            title: cargando ? "Calculando..." : "Proponer al club",
            style: .primary,
            isEnabled: !cargando && puedeProponer
        ) {
            Task { await proponer() }
        }
    }

    private var puedeProponer: Bool {
        switch modo {
        case .circular, .soloIda: return userLocation != nil
        case .destino: return destinoSeleccionado != nil && userLocation != nil
        case .pin: return pinCoordenada != nil && userLocation != nil
        }
    }

    private func proponer() async {
        guard let userLoc = userLocation else {
            errorMsg = "No pudimos obtener tu ubicación."
            return
        }
        cargando = true
        errorMsg = nil
        defer { cargando = false }

        do {
            let plan: RoutePlan
            switch modo {
            case .circular:
                plan = try await RouteCalculator.calculateCircular(
                    distanciaKm: distanciaKm, from: userLoc, profile: profile)
            case .soloIda:
                plan = try await RouteCalculator.calculateOneWay(
                    distanciaKm: distanciaKm, from: userLoc, profile: profile)
            case .destino:
                guard let dest = destinoSeleccionado else { return }
                if esIdaVueltaDestino {
                    plan = try await RouteCalculator.calculateRoundTrip(
                        to: dest, from: userLoc, profile: profile)
                } else {
                    plan = try await RouteCalculator.calculate(
                        to: dest, from: userLoc, profile: profile)
                }
            case .pin:
                guard let coord = pinCoordenada else { return }
                let dest = MapDestination(name: "Punto en el mapa", coordinate: coord)
                if esIdaVueltaDestino {
                    plan = try await RouteCalculator.calculateRoundTrip(
                        to: dest, from: userLoc, profile: profile)
                } else {
                    plan = try await RouteCalculator.calculate(
                        to: dest, from: userLoc, profile: profile)
                }
            }
            onPropose(plan)
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

// Sheet de búsqueda específico para Mario Kart (reutiliza AddressSearchService)
struct MarioKartLocationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var searchService: AddressSearchService
    let onSelect: (MapDestination) -> Void
    @State private var resolving = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: TrazoSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(TrazoColors.textSecondary)
                    TextField("Buscar dirección", text: $searchService.query)
                        .font(TrazoTypography.body())
                        .focused($focused)
                    if !searchService.query.isEmpty {
                        Button { searchService.query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(TrazoColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, TrazoSpacing.lg)
                .padding(.vertical, TrazoSpacing.md)
                .background(TrazoColors.elevated.opacity(0.5))
                .clipShape(Capsule())
                .padding(.horizontal, TrazoSpacing.lg)
                .padding(.top, TrazoSpacing.md)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(searchService.results.enumerated()), id: \.offset) { _, result in
                            Button {
                                Task { await seleccionar(result) }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(TrazoTypography.body())
                                        .foregroundStyle(TrazoColors.textPrimary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(TrazoTypography.caption())
                                            .foregroundStyle(TrazoColors.textSecondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, TrazoSpacing.lg)
                                .padding(.vertical, TrazoSpacing.md)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .background(TrazoColors.background)
            .navigationTitle("Buscar destino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .onAppear { focused = true }
        .overlay {
            if resolving {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md))
            }
        }
    }

    private func seleccionar(_ completion: MKLocalSearchCompletion) async {
        resolving = true
        defer { resolving = false }
        if let dest = try? await searchService.resolve(completion) {
            searchService.query = ""
            searchService.results = []
            onSelect(dest)
        }
    }
}
