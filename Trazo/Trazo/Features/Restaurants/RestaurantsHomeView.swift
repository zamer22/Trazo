import CoreLocation
import MapKit
import SwiftUI

struct RestaurantsHomeView: View {
    @Environment(\.currentUserProfile) private var profile
    @State private var locationManager = LocationManager()
    @State private var restaurantes: [Restaurante] = []
    @State private var recomendados: [Restaurante] = []
    @State private var frecuentes: [Restaurante] = []
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .descubrir
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var seleccionado: Restaurante?
    @State private var cargando = false
    @State private var mostrarPasaporte = false

    private let categorias: [(tipo: String, label: String)] = [
        ("cafe", "Cafés"), ("panaderia", "Panaderías"), ("saludable", "Saludable"),
        ("tacos", "Tacos"), ("bar", "Bares"), ("pizzeria", "Pizzerías"),
        ("hamburgueseria", "Hamburguesas"), ("restaurante", "Restaurantes")
    ]

    enum ViewMode: String, CaseIterable {
        case descubrir = "Descubrir"
        case mapa      = "Mapa"
        case lista     = "Lista"
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
                        case .descubrir: descubrirView
                        case .mapa:      mapaView
                        case .lista:     listaView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                TrazoBottomSearchBar(text: $searchText, placeholder: "Buscar restaurantes...")
                    .onChange(of: searchText) { _, texto in
                        if !texto.isEmpty { Task { await buscar(texto) } }
                        else { Task { await cargarTodo() } }
                    }
            }
            .background(TrazoColors.background)
            .navigationBarHidden(true)
            .sheet(item: $seleccionado) { rest in
                RestauranteDetalleSheet(restaurante: rest, userId: profile?.id)
            }
            .sheet(isPresented: $mostrarPasaporte) {
                if let uid = profile?.id {
                    PasaporteCuponesView(userId: uid)
                }
            }
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
            Task { await cargarTodo() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            HStack {
                Text("Locales")
                    .font(TrazoTypography.largeTitle())
                    .foregroundStyle(TrazoColors.textPrimary)
                Spacer()
                Button { mostrarPasaporte = true } label: {
                    HStack(spacing: TrazoSpacing.xs) {
                        Image(systemName: "ticket.fill")
                        Text("Pasaporte")
                            .font(TrazoTypography.caption().weight(.semibold))
                    }
                    .foregroundStyle(TrazoColors.accentOrange)
                    .padding(.horizontal, TrazoSpacing.md)
                    .padding(.vertical, TrazoSpacing.sm)
                    .background(TrazoColors.accentOrange.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
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

    // MARK: - Descubrir (recomendaciones)

    private var descubrirView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrazoSpacing.lg) {
                let cercanos = restaurantes.sorted {
                    guard let loc = locationManager.userLocation else { return false }
                    return $0.distanciaDesde(loc) < $1.distanciaDesde(loc)
                }

                if !cercanos.isEmpty {
                    sectionHeader("Cercanos")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: TrazoSpacing.md) {
                            ForEach(cercanos.prefix(10)) { r in
                                Button { seleccionado = r } label: { recomendacionCard(r) }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, TrazoSpacing.lg)
                    }
                }

                if !recomendados.isEmpty {
                    sectionHeader("Mejor calificados")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: TrazoSpacing.md) {
                            ForEach(recomendados.prefix(8)) { r in
                                Button { seleccionado = r } label: { recomendacionCard(r) }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, TrazoSpacing.lg)
                    }
                }

                if !frecuentes.isEmpty {
                    sectionHeader("Mis locales")
                    ForEach(frecuentes.prefix(5)) { r in
                        Button { seleccionado = r } label: { restauranteRow(r) }
                        .buttonStyle(.plain)
                        .padding(.horizontal, TrazoSpacing.lg)
                    }
                }

                ForEach(categorias, id: \.tipo) { cat in
                    let lista = restaurantes.filter { $0.tipo == cat.tipo }
                        .sorted { a, b in
                            guard let loc = locationManager.userLocation else { return false }
                            return a.distanciaDesde(loc) < b.distanciaDesde(loc)
                        }
                    if !lista.isEmpty {
                        sectionHeader(cat.label)
                        ForEach(lista.prefix(4)) { r in
                            Button { seleccionado = r } label: { restauranteRow(r) }
                            .buttonStyle(.plain)
                            .padding(.horizontal, TrazoSpacing.lg)
                        }
                    }
                }
            }
            .padding(.bottom, 140)
            .padding(.top, TrazoSpacing.sm)
        }
    }

    private func sectionHeader(_ titulo: String) -> some View {
        Text(titulo)
            .font(TrazoTypography.headline())
            .foregroundStyle(TrazoColors.textPrimary)
            .padding(.horizontal, TrazoSpacing.lg)
            .padding(.top, TrazoSpacing.sm)
    }

    private func recomendacionCard(_ r: Restaurante) -> some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            ZStack(alignment: .topTrailing) {
                if let urlStr = r.fotoUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                                .frame(width: 200, height: 110).clipped()
                        default:
                            placeholderImagen(r)
                        }
                    }
                } else {
                    placeholderImagen(r)
                }
                Text(r.etiquetaTipo)
                    .font(.system(size: 10).weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(r.colorTipo.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(6)
            }
            .frame(width: 200, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))

            Text(r.nombre)
                .font(TrazoTypography.headline())
                .foregroundStyle(TrazoColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: 200, alignment: .leading)

            HStack(spacing: TrazoSpacing.sm) {
                if r.totalCalificaciones > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(TrazoColors.accentOrange)
                        Text(String(format: "%.1f", r.ratingPromedio)).font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textPrimary)
                        Text("(\(r.totalCalificaciones))").font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary)
                    }
                } else {
                    Text("Nuevo").font(TrazoTypography.caption()).foregroundStyle(TrazoColors.routeTeal)
                }
                if let loc = locationManager.userLocation {
                    Text("·").foregroundStyle(TrazoColors.textSecondary).font(TrazoTypography.caption())
                    Text(r.distanciaFormateada(desde: loc)).font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary)
                }
            }
        }
        .frame(width: 200, alignment: .leading)
    }

    private func placeholderImagen(_ r: Restaurante) -> some View {
        RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous)
            .fill(r.colorTipo.opacity(0.15))
            .frame(width: 200, height: 110)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: r.icono).font(.system(size: 32)).foregroundStyle(r.colorTipo)
                }
            }
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
                .padding(.bottom, 140)
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
                    HStack(spacing: 4) {
                        Text(r.etiquetaTipo)
                            .font(TrazoTypography.caption())
                            .foregroundStyle(r.colorTipo)
                        if let desc = r.descripcion {
                            Text("· \(desc)")
                                .font(TrazoTypography.caption())
                                .foregroundStyle(TrazoColors.textSecondary)
                                .lineLimit(1)
                        }
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

    private func cargarTodo() async {
        cargando = true
        defer { cargando = false }
        let loc = locationManager.userLocation ?? CLLocationCoordinate2D(latitude: 25.686, longitude: -100.316)
        async let cercanos: [Restaurante] = (try? await RestaurantesService.fetchCercanos(lat: loc.latitude, lon: loc.longitude)) ?? []
        async let recos: [Restaurante] = (try? await RestaurantesService.fetchRecomendados(lat: loc.latitude, lon: loc.longitude)) ?? []
        async let visitados: [Restaurante] = {
            guard let uid = profile?.id else { return [] }
            return (try? await RestaurantesService.visitasDelUsuario(userId: uid)) ?? []
        }()
        let (r1, r2, r3) = await (cercanos, recos, visitados)
        restaurantes = r1
        recomendados = r2
        frecuentes = r3
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
        } else if let primero = restaurantes.first {
            cameraPosition = .camera(MapCamera(centerCoordinate: primero.coordinate, distance: 2500))
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
    @State private var cupones: [CuponRestaurante] = []
    @State private var totalVisitas: Int = 0
    @State private var registrandoVisita = false
    @State private var cuponesDesbloqueadosAlerta: [RestaurantesService.CuponDesbloqueado] = []
    @State private var mostrarAlertaCupones = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
                    encabezado
                    if let desc = restaurante.descripcion {
                        Text(desc).font(TrazoTypography.body()).foregroundStyle(TrazoColors.textSecondary)
                    }
                    visitasSection
                    cuponesSection
                    ratingSection
                    abrirEnMapasButton
                }
                .padding(TrazoSpacing.xl)
            }
            .background(TrazoColors.background)
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
        .presentationCornerRadius(TrazoRadius.lg)
        .task {
            await cargarDatos()
        }
        .alert("Cupón desbloqueado", isPresented: $mostrarAlertaCupones) {
            Button("Genial") {}
        } message: {
            Text(cuponesDesbloqueadosAlerta.map { "\($0.titulo) (\($0.codigo))" }.joined(separator: "\n"))
        }
    }

    private var encabezado: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                Text(restaurante.nombre).font(TrazoTypography.title()).foregroundStyle(TrazoColors.textPrimary)
                HStack(spacing: TrazoSpacing.sm) {
                    Text(restaurante.etiquetaTipo)
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
                            Text("(\(restaurante.totalCalificaciones))")
                                .font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary)
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

    private var visitasSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(TrazoColors.routeTeal)
                Text("Tus visitas")
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.textPrimary)
                Spacer()
                Text("\(totalVisitas)")
                    .font(TrazoTypography.title())
                    .foregroundStyle(TrazoColors.routeTeal)
            }
            Button {
                Task { await registrarVisita() }
            } label: {
                HStack {
                    if registrandoVisita {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text(registrandoVisita ? "Registrando..." : "Registrar visita")
                }
                .font(TrazoTypography.body().weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, TrazoSpacing.md)
                .background(TrazoColors.routeTeal)
                .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
            }
            .disabled(registrandoVisita || userId == nil)
        }
        .padding(TrazoSpacing.lg)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
    }

    private var cuponesSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(TrazoColors.accentOrange)
                Text("Cupones disponibles")
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.textPrimary)
            }
            if cupones.isEmpty {
                Text("Este local aún no tiene cupones.")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)
            } else {
                ForEach(cupones) { c in
                    cuponRow(c)
                }
            }
        }
        .padding(TrazoSpacing.lg)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
    }

    private func cuponRow(_ c: CuponRestaurante) -> some View {
        let desbloqueado = totalVisitas >= c.visitasRequeridas
        return HStack(spacing: TrazoSpacing.md) {
            VStack {
                Image(systemName: desbloqueado ? "ticket.fill" : "lock.fill")
                    .font(.title3)
                    .foregroundStyle(desbloqueado ? TrazoColors.accentOrange : TrazoColors.textSecondary)
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(c.titulo)
                    .font(TrazoTypography.body().weight(.semibold))
                    .foregroundStyle(TrazoColors.textPrimary)
                if let d = c.descripcion {
                    Text(d)
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)
                        .lineLimit(2)
                }
                HStack(spacing: TrazoSpacing.sm) {
                    if let pct = c.descuentoPorcentaje {
                        Text("\(pct)% off")
                            .font(TrazoTypography.caption().weight(.bold))
                            .foregroundStyle(TrazoColors.accentOrange)
                    }
                    Text(desbloqueado ? "Código: \(c.codigo)" : "Faltan \(c.visitasRequeridas - totalVisitas) visitas")
                        .font(TrazoTypography.caption())
                        .foregroundStyle(desbloqueado ? TrazoColors.textPrimary : TrazoColors.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, TrazoSpacing.sm)
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(TrazoColors.accentOrange)
                Text("Tu calificación")
                    .font(TrazoTypography.headline()).foregroundStyle(TrazoColors.textPrimary)
            }
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
        .padding(TrazoSpacing.lg)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
    }

    private var abrirEnMapasButton: some View {
        Button {
            let nombreCodificado = restaurante.nombre.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let url = URL(string: "maps://?ll=\(restaurante.latitud),\(restaurante.longitud)&q=\(nombreCodificado)")
            if let url { UIApplication.shared.open(url) }
        } label: {
            HStack {
                Image(systemName: "map.fill")
                Text("Abrir en Mapas")
            }
            .font(TrazoTypography.body().weight(.semibold))
            .foregroundStyle(TrazoColors.routeTeal)
            .frame(maxWidth: .infinity)
            .padding(.vertical, TrazoSpacing.md)
            .background(TrazoColors.routeTeal.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
        }
    }

    private func cargarDatos() async {
        if let uid = userId {
            miRating = await RestaurantesService.miCalificacion(restauranteId: restaurante.id, userId: uid) ?? 0
            totalVisitas = await RestaurantesService.totalVisitas(restauranteId: restaurante.id, userId: uid)
        }
        cupones = (try? await RestaurantesService.cuponesDelRestaurante(restauranteId: restaurante.id)) ?? []
    }

    private func guardarRating(_ rating: Int) async {
        guard let uid = userId else { return }
        guardandoRating = true
        defer { guardandoRating = false }
        try? await RestaurantesService.calificar(restauranteId: restaurante.id, userId: uid, rating: rating)
    }

    private func registrarVisita() async {
        guard userId != nil else { return }
        registrandoVisita = true
        defer { registrandoVisita = false }
        if let resultado = try? await RestaurantesService.registrarVisita(restauranteId: restaurante.id) {
            totalVisitas = resultado.totalVisitas
            if !resultado.cuponesDesbloqueados.isEmpty {
                cuponesDesbloqueadosAlerta = resultado.cuponesDesbloqueados
                mostrarAlertaCupones = true
            }
        }
    }
}

// MARK: - Pasaporte de cupones

struct PasaporteCuponesView: View {
    @Environment(\.dismiss) private var dismiss
    let userId: UUID

    @State private var cupones: [CuponConRestaurante] = []
    @State private var visitas: [Restaurante] = []
    @State private var cargando = true
    @State private var tab: Tab = .cupones

    enum Tab: String, CaseIterable {
        case cupones = "Cupones"
        case visitas = "Visitas"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Vista", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(TrazoSpacing.lg)

                ScrollView {
                    VStack(spacing: TrazoSpacing.md) {
                        if cargando {
                            ProgressView().padding(.top, 40)
                        } else {
                            switch tab {
                            case .cupones: cuponesList
                            case .visitas: visitasList
                            }
                        }
                    }
                    .padding(.horizontal, TrazoSpacing.lg)
                    .padding(.bottom, TrazoSpacing.xl)
                }
            }
            .background(TrazoColors.background)
            .navigationTitle("Pasaporte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .task { await cargar() }
    }

    private var cuponesList: some View {
        Group {
            if cupones.isEmpty {
                VStack(spacing: TrazoSpacing.md) {
                    Image(systemName: "ticket")
                        .font(.system(size: 56))
                        .foregroundStyle(TrazoColors.textSecondary)
                    Text("Aún no tienes cupones")
                        .font(TrazoTypography.headline())
                        .foregroundStyle(TrazoColors.textPrimary)
                    Text("Registra visitas a locales para desbloquear cupones.")
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
            } else {
                ForEach(cupones) { cwr in
                    cuponPasaporteCard(cwr)
                }
            }
        }
    }

    private func cuponPasaporteCard(_ cwr: CuponConRestaurante) -> some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            HStack {
                Image(systemName: cwr.restaurante.icono)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(cwr.restaurante.colorTipo)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(cwr.restaurante.nombre)
                        .font(TrazoTypography.headline())
                        .foregroundStyle(TrazoColors.textPrimary)
                    Text(cwr.cupon.titulo)
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)
                }
                Spacer()
                if let pct = cwr.cupon.descuentoPorcentaje {
                    Text("\(pct)%")
                        .font(TrazoTypography.title())
                        .foregroundStyle(TrazoColors.accentOrange)
                }
            }
            HStack(spacing: TrazoSpacing.sm) {
                Text(cwr.cupon.codigo)
                    .font(TrazoTypography.body().monospaced().weight(.bold))
                    .foregroundStyle(TrazoColors.textPrimary)
                    .padding(.horizontal, TrazoSpacing.md)
                    .padding(.vertical, TrazoSpacing.sm)
                    .background(TrazoColors.accentOrange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
                Spacer()
                if cwr.canjeado {
                    Text("Canjeado")
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)
                } else {
                    Text("Activo")
                        .font(TrazoTypography.caption().weight(.semibold))
                        .foregroundStyle(TrazoColors.routeTeal)
                }
            }
        }
        .padding(TrazoSpacing.lg)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
    }

    private var visitasList: some View {
        Group {
            if visitas.isEmpty {
                VStack(spacing: TrazoSpacing.md) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 56))
                        .foregroundStyle(TrazoColors.textSecondary)
                    Text("Aún no has visitado ningún local")
                        .font(TrazoTypography.headline())
                        .foregroundStyle(TrazoColors.textPrimary)
                }
                .padding(.top, 60)
            } else {
                ForEach(visitas) { r in
                    HStack(spacing: TrazoSpacing.md) {
                        Image(systemName: r.icono)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(r.colorTipo)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.nombre)
                                .font(TrazoTypography.body().weight(.semibold))
                                .foregroundStyle(TrazoColors.textPrimary)
                            Text(r.tipo.capitalized)
                                .font(TrazoTypography.caption())
                                .foregroundStyle(TrazoColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(TrazoColors.routeTeal)
                    }
                    .padding(TrazoSpacing.md)
                    .background(TrazoColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
                }
            }
        }
    }

    private func cargar() async {
        cargando = true
        defer { cargando = false }
        async let c = (try? await RestaurantesService.cuponesConRestaurante(userId: userId)) ?? []
        async let v = (try? await RestaurantesService.visitasDelUsuario(userId: userId)) ?? []
        let (cuponesR, visitasR) = await (c, v)
        cupones = cuponesR
        visitas = visitasR
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
