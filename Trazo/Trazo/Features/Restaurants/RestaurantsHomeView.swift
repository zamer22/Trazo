import CoreLocation
import MapKit
import SwiftUI

struct RestaurantsHomeView: View {
    @Environment(\.currentUserProfile) private var profile
    @State private var locationManager = LocationManager()
    @State private var restaurantes: [Restaurante] = []
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .map
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var seleccionado: Restaurante?
    @State private var cargando = false

    enum ViewMode: String, CaseIterable {
        case map  = "Mapa"
        case list = "Lista"
    }

    private var restaurantesFiltrados: [Restaurante] {
        guard !searchText.isEmpty else { return restaurantes }
        return restaurantes.filter { $0.nombre.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header
                    Group {
                        switch viewMode {
                        case .map:  mapaView
                        case .list: listaView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                TrazoBottomSearchBar(text: $searchText, placeholder: "Buscar restaurantes...")
                    .onChange(of: searchText) { _, texto in
                        if !texto.isEmpty { Task { await buscar(texto) } }
                        else { Task { await cargarCercanos() } }
                    }
            }
            .background(TrazoColors.background)
            .navigationBarHidden(true)
            .sheet(item: $seleccionado) { RestauranteDetalleSheet(restaurante: $0, userId: profile?.id) }
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
            Task { await cargarCercanos() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            Text("Locales")
                .font(TrazoTypography.largeTitle())
                .foregroundStyle(TrazoColors.textPrimary)
            Picker("Vista", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TrazoSpacing.lg)
        .padding(.top, TrazoSpacing.sm)
        .padding(.bottom, TrazoSpacing.md)
    }

    // MARK: - Mapa

    private var mapaView: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            ForEach(restaurantesFiltrados) { r in
                Annotation(r.nombre, coordinate: r.coordinate, anchor: .bottom) {
                    Button { seleccionado = r } label: {
                        VStack(spacing: 2) {
                            Image(systemName: r.icono)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(7)
                                .background(r.colorTipo)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                            Triangle()
                                .fill(r.colorTipo)
                                .frame(width: 8, height: 5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { }
        .onAppear { centrarMapa() }
    }

    // MARK: - Lista

    private var listaView: some View {
        ScrollView {
            if cargando && restaurantes.isEmpty {
                ProgressView().tint(TrazoColors.routeTeal).padding(.top, 60)
            } else {
                LazyVStack(spacing: TrazoSpacing.md) {
                    ForEach(restaurantesFiltrados) { r in
                        Button { seleccionado = r } label: {
                            restauranteRow(r)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, TrazoSpacing.lg)
                .padding(.bottom, 120)
            }
        }
    }

    private func restauranteRow(_ r: Restaurante) -> some View {
        TrazoCard {
            HStack(spacing: TrazoSpacing.md) {
                RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous)
                    .fill(r.colorTipo.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: r.icono).foregroundStyle(r.colorTipo).font(.title3)
                    }
                VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                    Text(r.nombre)
                        .font(TrazoTypography.headline())
                        .foregroundStyle(TrazoColors.textPrimary)
                    HStack(spacing: TrazoSpacing.sm) {
                        if r.totalCalificaciones > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill").font(.caption2).foregroundStyle(TrazoColors.accentOrange)
                                Text(String(format: "%.1f", r.ratingPromedio))
                                    .font(TrazoTypography.caption())
                                    .foregroundStyle(TrazoColors.textPrimary)
                                Text("(\(r.totalCalificaciones))")
                                    .font(TrazoTypography.caption())
                                    .foregroundStyle(TrazoColors.textSecondary)
                            }
                            Text("·")
                                .foregroundStyle(TrazoColors.textSecondary)
                                .font(TrazoTypography.caption())
                        }
                        if let loc = locationManager.userLocation {
                            Text(r.distanciaFormateada(desde: loc))
                                .font(TrazoTypography.caption())
                                .foregroundStyle(TrazoColors.textSecondary)
                        }
                    }
                    if let desc = r.descripcion {
                        Text(desc)
                            .font(TrazoTypography.caption())
                            .foregroundStyle(TrazoColors.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(TrazoColors.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private func cargarCercanos() async {
        cargando = true
        defer { cargando = false }
        let loc = locationManager.userLocation ?? CLLocationCoordinate2D(latitude: 25.686, longitude: -100.316)
        restaurantes = (try? await RestaurantesService.fetchCercanos(lat: loc.latitude, lon: loc.longitude)) ?? []
        centrarMapa()
    }

    private func buscar(_ texto: String) async {
        restaurantes = (try? await RestaurantesService.buscar(texto: texto)) ?? []
    }

    private func centrarMapa() {
        if let loc = locationManager.userLocation {
            withAnimation {
                cameraPosition = .camera(MapCamera(centerCoordinate: loc, distance: 2000))
            }
        }
    }
}

// MARK: - Detalle sheet

struct RestauranteDetalleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let restaurante: Restaurante
    let userId: UUID?
    @State private var miRating: Int = 0
    @State private var guardandoRating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
                    encabezado
                    if let desc = restaurante.descripcion {
                        Text(desc).font(TrazoTypography.body()).foregroundStyle(TrazoColors.textSecondary)
                    }
                    ratingSection
                    abrirEnMapasButton
                }
                .padding(TrazoSpacing.xl)
            }
            .background(TrazoColors.background)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(TrazoRadius.lg)
        .task {
            if let uid = userId {
                miRating = await RestaurantesService.miCalificacion(restauranteId: restaurante.id, userId: uid) ?? 0
            }
        }
    }

    private var encabezado: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                Text(restaurante.nombre).font(TrazoTypography.title()).foregroundStyle(TrazoColors.textPrimary)
                HStack(spacing: TrazoSpacing.sm) {
                    Text(restaurante.tipo.capitalized)
                        .font(TrazoTypography.caption())
                        .foregroundStyle(.white)
                        .padding(.horizontal, TrazoSpacing.sm).padding(.vertical, 3)
                        .background(restaurante.colorTipo)
                        .clipShape(Capsule())
                    if restaurante.totalCalificaciones > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(TrazoColors.accentOrange)
                            Text(String(format: "%.1f", restaurante.ratingPromedio))
                                .font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textPrimary)
                        }
                    }
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(TrazoColors.textSecondary)
            }
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            Text("Tu calificación")
                .font(TrazoTypography.headline()).foregroundStyle(TrazoColors.textPrimary)
            HStack(spacing: TrazoSpacing.md) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        miRating = star
                        Task { await guardarRating(star) }
                    } label: {
                        Image(systemName: star <= miRating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(star <= miRating ? TrazoColors.accentOrange : TrazoColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                if guardandoRating { ProgressView().scaleEffect(0.8) }
            }
        }
    }

    private var abrirEnMapasButton: some View {
        Button {
            let url = URL(string: "maps://?ll=\(restaurante.latitud),\(restaurante.longitud)&q=\(restaurante.nombre.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
            if let url { UIApplication.shared.open(url) }
        } label: {
            HStack {
                Image(systemName: "map.fill")
                Text("Abrir en Mapas")
            }
        }
    }

    private func guardarRating(_ rating: Int) async {
        guard let uid = userId else { return }
        guardandoRating = true
        defer { guardandoRating = false }
        try? await RestaurantesService.calificar(restauranteId: restaurante.id, userId: uid, rating: rating)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
